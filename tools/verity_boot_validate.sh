#!/bin/bash
# Validate that a buckos verity_image boots *measured* in QEMU.
#
# Proves the dm-verity attestation chain end to end:
#   1. build the measured image (root.img + hash.img + roothash + cmdline) from
#      //packages/linux/system:buckos-verity-image,
#   2. build a dm-verity-built-in kernel (buckos-kernel-verity) + the
#      dynamic-capable verity initramfs (glibc + busybox + cryptsetup),
#   3. POSITIVE boot: kernel + initramfs + the data/hash disks, cmdline carrying
#      `roothash=<hex>`.  The initramfs (defs/scripts/verity-initramfs-init.sh)
#      runs `veritysetup open` from that roothash, mounts the verified rootfs,
#      reads a real file through dm-verity, and prints VERITY-BOOT-OK.
#   4. NEGATIVE boot: flip one byte in the data image.  dm-verity must reject the
#      read (EIO) -> the marker is VERITY-BOOT-FAIL, never VERITY-BOOT-OK.  A
#      tampered image that still booted would defeat the whole point.
#
# Requires: KVM + a QEMU with -cpu host (buckos userspace is x86-64-v3).
set -eu
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

GEN=buck-out/v2/gen/buckos
find1() { find "$GEN" -path "$1" 2>/dev/null | head -1; }
QEMU=${QEMU:-/opt/fb-qemu/bin/qemu-system-x86_64}
BUCK=${BUCK:-./buck2}
W=${W:-/tmp/verity_boot_work}; rm -rf "$W"; mkdir -p "$W"

echo "### 1. build measured image + kernel + initramfs (buck2)"
$BUCK build \
    //packages/linux/system:buckos-verity-image \
    //packages/linux/kernel/buckos-kernel:buckos-kernel-verity \
    //packages/linux/system:buckos-verity-initramfs >/dev/null 2>&1

ROOTIMG=$PWD/$(find1 '*buckos-verity-image*/buckos-verity-image.root.img')
HASHIMG=$PWD/$(find1 '*buckos-verity-image*/buckos-verity-image.hash.img')
RHFILE=$PWD/$(find1 '*buckos-verity-image*/buckos-verity-image.roothash')
CMDFILE=$PWD/$(find1 '*buckos-verity-image*/buckos-verity-image.cmdline')
BZIMAGE=$PWD/$(find1 '*buckos-kernel-verity*/build-tree/arch/x86/boot/bzImage')
INITRD=$PWD/$(find "$GEN" -path '*buckos-verity-initramfs*' -name '*.cpio.gz' 2>/dev/null | head -1)

for f in "$ROOTIMG" "$HASHIMG" "$RHFILE" "$CMDFILE" "$BZIMAGE" "$INITRD"; do
    [ -f "$f" ] || { echo "missing artifact: $f"; exit 1; }
done
ROOTHASH=$(cat "$RHFILE")
BASECMD=$(cat "$CMDFILE")
echo "### roothash=$ROOTHASH"
echo "### cmdline=$BASECMD"

boot() {
    # $1=data image  $2=label  -> echoes the QEMU serial log path
    local data=$1 label=$2 log="$W/qemu-$2.log"
    timeout 120 "$QEMU" -enable-kvm -cpu host -display none -serial stdio \
        -monitor none -m 1024 -smp 2 -no-reboot \
        -kernel "$BZIMAGE" -initrd "$INITRD" \
        -append "console=ttyS0 $BASECMD panic=3" \
        -drive file="$data",if=virtio,format=raw \
        -drive file="$HASHIMG",if=virtio,format=raw \
        > "$log" 2>&1 || true
    echo "$log"
}

echo "### 2. POSITIVE boot (untampered image must verify)"
POS=$(boot "$ROOTIMG" pos)

echo "### 3. NEGATIVE boot (tampered image must be rejected)"
TAMPER="$W/tampered.root.img"
cp "$ROOTIMG" "$TAMPER"
# Flip one byte well inside the data region (past the superblock area).
sz=$(stat -c %s "$TAMPER")
off=$((sz / 2))
printf '\xFF' | dd of="$TAMPER" bs=1 seek="$off" count=1 conv=notrunc status=none
NEG=$(boot "$TAMPER" neg)

echo "### result"
rc=0
if grep -aq VERITY-BOOT-OK "$POS"; then
    echo "POSITIVE: PASS (untampered image verified + mounted)"
else
    echo "POSITIVE: FAIL (no VERITY-BOOT-OK)"; tail -20 "$POS"; rc=1
fi
if grep -aq VERITY-BOOT-OK "$NEG"; then
    echo "NEGATIVE: FAIL (tampered image booted!)"; tail -20 "$NEG"; rc=1
else
    echo "NEGATIVE: PASS (tampered image rejected by dm-verity)"
fi
[ $rc -eq 0 ] && echo "VERITY_BOOT_VALIDATED" || echo "VERITY_BOOT_NOT_VALIDATED (logs in $W)"
exit $rc
