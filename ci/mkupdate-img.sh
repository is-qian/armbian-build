#!/usr/bin/env bash
# Pack an Armbian image into a Rockchip update.img (RKDevTool upgrade format).
# Layout mirrors the Armbian image: SPL via MiniLoaderAll (converted to the
# IDBlock on flash), u-boot.itb at 0x4000, rootfs at 0x8000.
set -euo pipefail

CI_DIR="$(cd "$(dirname "$0")" && pwd)"
IMG="${1:?usage: mkupdate-img.sh <armbian.img>}"
LOADER="$CI_DIR/../cache/sources/rkbin-tools/rk35/rk356x_spl_loader_v1.21.113.bin"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rkfw.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/Image"
cp "$LOADER" "$WORK/Image/MiniLoaderAll.bin"

# trim zero padding after u-boot.itb so afptool does not pack 8 MiB of zeros
UBOOT_SECTORS=$(python3 -c "
data=open('$IMG','rb')
data.seek(16384*512)
buf=data.read(0x4000*512)
end=len(buf.rstrip(b'\x00'))
print((end+511)//512)")
dd if="$IMG" of="$WORK/Image/uboot.img" bs=512 skip=16384 count="$UBOOT_SECTORS" status=none

read -r ROOTFS_START ROOTFS_COUNT <<<"$(sfdisk -J "$IMG" | python3 -c "
import json,sys
p=json.load(sys.stdin)['partitiontable']['partitions'][0]
print(p['start'], p['size'])")"
dd if="$IMG" of="$WORK/Image/rootfs.img" bs=512 skip="$ROOTFS_START" count="$ROOTFS_COUNT" status=none

cat > "$WORK/Image/parameter.txt" <<'EOF2'
FIRMWARE_VER: 12.0.0
MACHINE_MODEL: RK3566
MACHINE_ID: 007
MANUFACTURER: RK3566
MAGIC: 0x5041524B
ATAG: 0x00200800
MACHINE: 0xffffffff
CHECK_MASK: 0x80
PWR_HLD: 0,0,A,0,1
TYPE: GPT
CMDLINE: mtdparts=rk29xxnand:0x00004000@0x00004000(uboot),-@0x00008000(rootfs:grow)
EOF2

cat > "$WORK/package-file" <<'EOF2'
package-file	package-file
bootloader	Image/MiniLoaderAll.bin
parameter	Image/parameter.txt
uboot		Image/uboot.img
rootfs		Image/rootfs.img
backup		RESERVED
EOF2

OUT="$(dirname "$IMG")/$(basename "$IMG" .img)-update.img"
cd "$WORK"
"$CI_DIR/rk-pack-tools/afptool" -pack . Image/update.img
"$CI_DIR/rk-pack-tools/rkImageMaker" -RK3568 Image/MiniLoaderAll.bin Image/update.img "$OUT" -os_type:androidos
echo "packed: $OUT"
