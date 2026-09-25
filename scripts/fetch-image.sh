#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REL="${1:-}"
if [ -z "$REL" ]; then
  echo "usage: $0 <release>"
  echo "available:"; ls -1 images 2>/dev/null | sed 's/^/  /'
  exit 1
fi

DIR="images/$REL"
CONF="$DIR/image.conf"
[ -f "$CONF" ] || { echo "no such image: $CONF"; exit 1; }

conf() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | head -1; }

URL=$(conf url)
SHA=$(conf sha256)
KERNEL=$(conf kernel)
INITRD=$(conf initrd)
for key in url sha256 kernel initrd; do
  [ -n "$(conf "$key")" ] || { echo "$CONF is missing '$key'"; exit 1; }
done

command -v bsdtar >/dev/null || {
  echo "bsdtar is required:  sudo apt install libarchive-tools"; exit 1; }

ISO="$DIR/image.iso"

echo "==> $REL"

if [ ! -s "$ISO" ]; then
  echo "==> downloading $(basename "$URL")"
  curl -fL --progress-bar -C - -o "$ISO.part" "$URL"
  mv "$ISO.part" "$ISO"
fi

echo "==> verifying sha256"
ACTUAL=$(sha256sum "$ISO" | cut -d' ' -f1)
if [ "$ACTUAL" != "$SHA" ]; then
  echo "CHECKSUM MISMATCH"
  echo "  expected $SHA"
  echo "  actual   $ACTUAL"
  echo "Delete $ISO and re-run to download again."
  exit 1
fi

echo "==> extracting $KERNEL"
bsdtar -xOf "$ISO" "$KERNEL" > "$DIR/vmlinuz"
echo "==> extracting $INITRD"
bsdtar -xOf "$ISO" "$INITRD" > "$DIR/initrd"

echo
echo "ready: $DIR"
ls -lh "$DIR" | tail -n +2 | awk '{printf "  %-12s %s\n", $9, $5}'
