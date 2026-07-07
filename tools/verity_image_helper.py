#!/usr/bin/env python3
"""Build a dm-verity measured disk image from a rootfs, hatch-image style.

Produces the same artifact set the hatch-image mkosi build emits for its
TEE/confidential boot flow, but from a buckos-built rootfs:

  * <name>.root.img      the root filesystem image (the measured data device)
  * <name>.hash.img      the dm-verity hash tree (Merkle tree over the data)
  * <name>.roothash      the dm-verity root hash (hex), the attestation anchor
  * <name>.cmdline       kernel cmdline with `roothash=<hex>` appended

The root hash binds every byte of the rootfs: any change to the data image
changes the hash. Measured into the cmdline (and thus into the TEE during
boot), it is what a verifier checks against a signed manifest.

Two tool sources, mirroring the rest of buckos:
  * mke2fs / mkfs.btrfs come from the toolchain host PATH (--hermetic-path),
    same as disk_image_helper.
  * veritysetup is a buckos-built PIE; we launch it through the seed loader
    with its dep lib closure on --library-path (same trick as ostree_helper),
    so it resolves libcryptsetup/openssl/popt/json-c/libdevmapper/util-linux
    without relying on absolute RUNPATHs. `veritysetup format` is pure
    userspace (it never touches the kernel dm subsystem), so no root needed.

Reproducibility: a fixed verity salt + UUID and fixed filesystem UUID/hash
seed (plus SOURCE_DATE_EPOCH pinned in _env) make the root hash a
deterministic function of the rootfs contents — the property the whole
attestation story depends on.
"""

import argparse
import os
import re
import subprocess
import sys

from _env import add_path_args, clean_env, setup_path

# Fixed btrfs per-device UUID (random by default) — one of several knobs needed
# for reproducible btrfs; see the note in _populate_image.
_DEVICE_UUID = "b00c0511-dddd-eeee-ffff-000011112222"


def _run(cmd, env, capture=False):
    result = subprocess.run(
        cmd,
        env=env,
        stdout=subprocess.PIPE if capture else None,
        text=True,
    )
    if result.returncode != 0:
        print(
            f"error: {os.path.basename(str(cmd[0]))} failed (exit {result.returncode})",
            file=sys.stderr,
        )
        sys.exit(1)
    return result


def _parse_size(size_str):
    m = re.fullmatch(r"(\d+)\s*([KMGTkmgt])?[iI]?[bB]?", size_str)
    if not m:
        print(f"error: cannot parse size: {size_str}", file=sys.stderr)
        sys.exit(1)
    n = int(m.group(1))
    suffix = (m.group(2) or "").upper()
    mult = {"": 1, "K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
    return n * mult[suffix]


def _read_lib_dirs(path):
    with open(path) as fh:
        return ":".join(os.path.abspath(ln.strip()) for ln in fh if ln.strip())


def _populate_image(output, filesystem, label, rootfs, size_bytes, fs_uuid,
                    mkfs, mkfs_lib_dirs_file, ld, env):
    """Create and populate a filesystem image from a rootfs directory.

    Unprivileged populate-from-directory (mke2fs -d / mkfs.btrfs --rootdir);
    no mount, fakeroot, or losetup. mke2fs/mkfs.btrfs are buckos PIEs, launched
    through the seed loader with their dep lib closure (same as veritysetup),
    since they are not on the toolchain host PATH. UUID/hash-seed pinned for a
    stable hash.
    """
    mkfs = os.path.abspath(mkfs)
    lib_path = _read_lib_dirs(mkfs_lib_dirs_file)
    launch = [os.path.abspath(ld), "--library-path", lib_path, mkfs]
    if filesystem == "ext4":
        blocks = size_bytes // 4096
        _run(
            launch + [
                "-t", "ext4", "-F", "-L", label,
                "-U", fs_uuid, "-E", "hash_seed=" + fs_uuid,
                "-d", rootfs, output, str(blocks),
            ],
            env,
        )
    elif filesystem == "btrfs":
        _run(["truncate", "-s", str(size_bytes), output], env)
        # --shrink trims the image to the populated size so the verity tree only
        # covers real data; -U pins the fsid and --device-uuid the per-device
        # UUID (both random by default).  NOTE: these remove two non-determinism
        # sources but are NOT sufficient on their own — mkfs.btrfs --rootdir is
        # only byte-reproducible from btrfs-progs ~v6.13+ (SOURCE_DATE_EPOCH
        # support).  On older btrfs-progs the root hash still varies build to
        # build; use filesystem="ext4" (mke2fs -d, deterministic) when a stable
        # measurement is required.
        _run(
            launch + [
                "-f", "-L", label, "-U", fs_uuid,
                "--device-uuid", _DEVICE_UUID,
                "--shrink", "--rootdir", rootfs, output,
            ],
            env,
        )
    else:
        print(f"error: unsupported filesystem: {filesystem}", file=sys.stderr)
        sys.exit(1)


def _parse_root_hash(text):
    """Extract the hex root hash from `veritysetup format` output."""
    for line in text.splitlines():
        m = re.match(r"\s*Root hash:\s*([0-9a-fA-F]+)\s*$", line)
        if m:
            return m.group(1).lower()
    return None


def main():
    host_path = os.environ.get("PATH", "")

    ap = argparse.ArgumentParser(description="Build a dm-verity measured image")
    ap.add_argument("--rootfs", required=True, help="rootfs directory to measure")
    ap.add_argument("--root-output", required=True, help="output root fs image")
    ap.add_argument("--hash-output", required=True, help="output verity hash image")
    ap.add_argument("--roothash-output", required=True, help="output roothash text")
    ap.add_argument("--cmdline-output", required=True, help="output kernel cmdline")
    ap.add_argument("--veritysetup", required=True, help="buckos veritysetup PIE")
    ap.add_argument(
        "--lib-dirs-file",
        required=True,
        help="file of dep lib dirs (one per line) for veritysetup --library-path",
    )
    ap.add_argument("--mkfs", required=True, help="buckos mkfs PIE (mkfs.btrfs/mke2fs)")
    ap.add_argument(
        "--mkfs-lib-dirs-file",
        required=True,
        help="file of dep lib dirs (one per line) for mkfs --library-path",
    )
    ap.add_argument("--filesystem", default="ext4", help="ext4 or btrfs")
    ap.add_argument("--label", default="buckos")
    ap.add_argument("--size", default="4G", help="root image size (e.g. 4G)")
    ap.add_argument(
        "--base-cmdline",
        default="noresume",
        help="kernel cmdline prefix; ` roothash=<hex>` is appended",
    )
    # Fixed salt/uuid → deterministic root hash for a given rootfs.
    ap.add_argument(
        "--salt",
        default="00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
        help="verity salt (hex); fixed for reproducibility",
    )
    ap.add_argument(
        "--verity-uuid",
        default="b00c0511-1111-2222-3333-444455556666",
        help="verity superblock UUID; fixed for reproducibility",
    )
    ap.add_argument(
        "--fs-uuid",
        default="b00c0511-aaaa-bbbb-cccc-ddddeeeeffff",
        help="filesystem UUID/hash-seed; fixed for reproducibility",
    )
    add_path_args(ap)
    args = ap.parse_args()

    env = clean_env()
    setup_path(args, env, host_path)

    rootfs = os.path.abspath(args.rootfs)
    root_img = os.path.abspath(args.root_output)
    hash_img = os.path.abspath(args.hash_output)
    veritysetup = os.path.abspath(args.veritysetup)
    size_bytes = _parse_size(args.size)

    # mkfs and veritysetup are buckos PIEs: launch via the seed loader with
    # their dep lib closures, exactly like ostree_helper.
    ld = getattr(args, "ld_linux", None)
    if not ld:
        print("error: --ld-linux is required to run mkfs/veritysetup", file=sys.stderr)
        sys.exit(1)

    print(f"Building dm-verity image ({args.filesystem}, {args.size})...")
    _populate_image(
        root_img, args.filesystem, args.label, rootfs, size_bytes, args.fs_uuid,
        args.mkfs, args.mkfs_lib_dirs_file, ld, env,
    )

    # veritysetup `format` is pure userspace (no kernel dm needed).
    lib_path = _read_lib_dirs(args.lib_dirs_file)

    fmt = _run(
        [
            os.path.abspath(ld), "--library-path", lib_path, veritysetup,
            "format",
            "--hash", "sha256",
            "--data-block-size", "4096",
            "--hash-block-size", "4096",
            "--salt", args.salt,
            "--uuid", args.verity_uuid,
            root_img, hash_img,
        ],
        env,
        capture=True,
    )
    print(fmt.stdout)
    root_hash = _parse_root_hash(fmt.stdout)
    if not root_hash:
        print("error: could not parse root hash from veritysetup output", file=sys.stderr)
        sys.exit(1)

    with open(args.roothash_output, "w") as fh:
        fh.write(root_hash + "\n")
    with open(args.cmdline_output, "w") as fh:
        fh.write(f"{args.base_cmdline} roothash={root_hash}\n")

    print(f"✓ root image:  {root_img}")
    print(f"✓ hash image:  {hash_img}")
    print(f"✓ root hash:   {root_hash}")
    print(f"✓ cmdline:     {args.base_cmdline} roothash={root_hash}")


if __name__ == "__main__":
    main()
