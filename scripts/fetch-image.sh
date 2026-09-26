#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

die() { echo "$*" >&2; exit 1; }

releases() {
  for d in images/*/; do
    [ -f "$d/image.conf" ] && basename "$d"
  done
}

REL="${1:-}"
if [ -z "$REL" ]; then
  echo "usage: $(basename "$0") <release>"
  releases | sed 's/^/  /'
  exit 1
fi

DIR="images/$REL"
CONF="$DIR/image.conf"
ISO="$DIR/image.iso"

[ -f "$CONF" ] || die "no such image: $CONF"

conf() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | head -1; }

URL=$(conf url)
SHA=$(conf sha256)
KERNEL=$(conf kernel)
INITRD=$(conf initrd)

[ -n "$URL" ]    || die "$CONF: missing 'url'"
[ -n "$SHA" ]    || die "$CONF: missing 'sha256'"
[ -n "$KERNEL" ] || die "$CONF: missing 'kernel'"
[ -n "$INITRD" ] || die "$CONF: missing 'initrd'"

command -v bsdtar >/dev/null || die "bsdtar is required: sudo apt install libarchive-tools"

extract() {
  local member="$1" dest="$2"
  echo "==> extracting $member"
  if ! bsdtar -xOf "$ISO" "$member" > "$dest.part" 2>/dev/null; then
    rm -f "$dest.part"
    die "$member is not in $ISO -- check 'kernel' and 'initrd' in $CONF"
  fi
  if [ ! -s "$dest.part" ]; then
    rm -f "$dest.part"
    die "$member is empty in $ISO"
  fi
  mv "$dest.part" "$dest"
}

echo "==> $REL"

if [ ! -s "$ISO" ]; then
  echo "==> downloading $(basename "$URL")"
  curl -fL --progress-bar -C - -o "$ISO.part" "$URL" || die "download failed: $URL"
  mv "$ISO.part" "$ISO"
fi

echo "==> verifying sha256"
ACTUAL=$(sha256sum "$ISO" | cut -d' ' -f1)
[ "$ACTUAL" = "$SHA" ] || die "checksum mismatch
  expected $SHA
  actual   $ACTUAL
  delete $ISO and re-run to download it again"

extract "$KERNEL" "$DIR/vmlinuz"
extract "$INITRD" "$DIR/initrd"

echo
echo "ready: $DIR"
du -h "$ISO" "$DIR/vmlinuz" "$DIR/initrd" | awk '{printf "  %-6s %s\n", $1, $2}'
