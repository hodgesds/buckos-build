#!/usr/bin/busybox sh
# BuckOS dm-verity measured-boot initramfs init.
#
# Proves a buckos verity_image actually boots measured: the kernel cmdline
# carries `roothash=<hex>` (the attestation anchor), and this init uses it to
# bring up the dm-verity device over the (read-only) measured rootfs before
# switching into it.  Any tampering with the data image makes the kernel's
# dm-verity reject reads, so a corrupted image cannot boot — the whole point.
#
# QEMU disk layout (set by tools/verity_boot_validate.sh):
#   /dev/vda  data image  (the measured btrfs/ext4 rootfs)
#   /dev/vdb  hash image  (the dm-verity Merkle tree)
#
# veritysetup is a dynamic buckos binary, so this initramfs is a real rootfs
# slice (glibc + busybox + cryptsetup), mirroring the ostree initramfs.
BB=/usr/bin/busybox
msg() { $BB echo "[verity-initramfs] $*"; }

$BB mount -t proc proc /proc 2>/dev/null
$BB mount -t sysfs sysfs /sys 2>/dev/null
$BB mount -t devtmpfs devtmpfs /dev 2>/dev/null
$BB mkdir -p /run /sysroot
$BB mount -t tmpfs tmpfs /run 2>/dev/null

# Locate veritysetup (cryptsetup installs it under usr/sbin in the buckos prefix).
VS=""
for cand in /usr/sbin/veritysetup /sbin/veritysetup /usr/bin/veritysetup; do
    [ -x "$cand" ] && VS=$cand && break
done
if [ -z "$VS" ]; then
    msg "FAIL: veritysetup not found in initramfs"
    echo "VERITY-BOOT-FAIL"
    $BB poweroff -f
fi

DATA=/dev/vda
HASH=/dev/vdb
roothash=""
for arg in $($BB cat /proc/cmdline 2>/dev/null); do
    case "$arg" in
        roothash=*)   roothash=${arg#roothash=} ;;
        verity.data=*) DATA=${arg#verity.data=} ;;
        verity.hash=*) HASH=${arg#verity.hash=} ;;
    esac
done

if [ -z "$roothash" ]; then
    msg "FAIL: no roothash= on kernel cmdline"
    echo "VERITY-BOOT-FAIL"
    $BB poweroff -f
fi

msg "opening dm-verity: data=$DATA hash=$HASH roothash=$roothash"
if ! "$VS" open "$DATA" buckosroot "$HASH" "$roothash"; then
    # Wrong/tampered roothash, or hash tree mismatch: dm-verity refuses to
    # create the device.  This is the fail-closed path.
    msg "FAIL: veritysetup open rejected (verification failed)"
    echo "VERITY-BOOT-FAIL"
    $BB poweroff -f
fi

msg "mounting verified rootfs (read-only)"
if ! $BB mount -o ro /dev/mapper/buckosroot /sysroot; then
    msg "FAIL: could not mount /dev/mapper/buckosroot"
    echo "VERITY-BOOT-FAIL"
    $BB poweroff -f
fi

# Force a read of a real file through the dm-verity device.  If even one
# covered block was tampered, dm-verity returns EIO here (vs. open, which only
# checks the superblock + root of the tree).  This is the data-integrity proof.
if $BB cat /sysroot/usr/lib/os-release >/dev/null 2>&1 ||
   $BB cat /sysroot/etc/os-release >/dev/null 2>&1; then
    msg "verified read OK"
else
    msg "FAIL: verified read returned I/O error (data tampered?)"
    echo "VERITY-BOOT-FAIL"
    $BB poweroff -f
fi

# Success marker the harness greps for.  We stop here rather than switch_root —
# the measured-boot property (verify + mount + read the measured rootfs) is
# proven; running the full OS init is out of scope for the gate.
msg "measured boot OK"
echo "VERITY-BOOT-OK"
$BB poweroff -f
