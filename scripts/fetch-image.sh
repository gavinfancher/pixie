#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

REL="${1:-}"
[ -n "$REL" ] || { echo "usage: $0 <release>"; ls images; exit 1; }

DIR="images/$REL"
ISO="$DIR/image.iso"
[ -f "$DIR/image.conf" ] || { echo "no such image: $REL"; ls images; exit 1; }

conf() { sed -n "s/^ *$1 *= *//p" "$DIR/image.conf"; }

if [ ! -s "$ISO" ]; then
  curl -fL --progress-bar -C - -o "$ISO.part" "$(conf url)"
  mv "$ISO.part" "$ISO"
fi

echo "$(conf sha256)  $ISO" | sha256sum -c

bsdtar -xOf "$ISO" "$(conf kernel)" > "$DIR/vmlinuz.part"
mv "$DIR/vmlinuz.part" "$DIR/vmlinuz"

bsdtar -xOf "$ISO" "$(conf initrd)" > "$DIR/initrd.part"
mv "$DIR/initrd.part" "$DIR/initrd"
