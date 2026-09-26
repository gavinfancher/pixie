#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

IPXE_URL=https://boot.ipxe.org/x86_64-efi/ipxe.efi

if [ ! -s boot/ipxe.efi ]; then
  echo "==> downloading ipxe.efi"
  curl -fL -o boot/ipxe.efi.part "$IPXE_URL"
  mv boot/ipxe.efi.part boot/ipxe.efi
fi

for conf in images/*/image.conf; do
  [ -e "$conf" ] || continue
  rel=$(basename "$(dirname "$conf")")
  if [ -s "images/$rel/vmlinuz" ] && [ -s "images/$rel/initrd" ]; then
    echo "==> $rel ready"
  else
    ./scripts/fetch-image.sh "$rel"
  fi
done

echo "==> bootstrap complete"
