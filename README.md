# pixie

Netboot a machine and install Ubuntu Server over the network.

Runs on a small Linux VM and adds PXE to an existing network without changing
it: the UniFi gateway keeps handing out IP addresses, and pixie answers only
the "which boot file?" half of the same request.

## Requirements

**The server** — a Linux VM with Docker, at a static `10.0.0.55` (reserved in
UniFi), on the same flat network as the machines you boot. PXE begins as a
broadcast, so a router between them will break it.

**The client** — x86, UEFI, with:

- **Secure Boot disabled.** `ipxe.efi` is unsigned; Secure Boot rejects it and
  falls through to the next boot device as if nothing happened.
- **IPv4 network boot enabled.** Some firmware ships IPv6-only.

## Setup

```sh
docker compose up -d
```

That is the whole thing. A `bootstrap` service runs first and downloads
anything missing -- `ipxe.efi`, and every image declared under `images/` --
then dnsmasq and nginx start. Nothing needs installing on the host but Docker.

The first run takes a while (~3GB per release). Later runs take a second,
because bootstrap only fetches what is absent.

## Booting a machine

Power on, pick network boot (usually F12). A menu appears.

Choosing a release installs Ubuntu **unattended and erases the disk**. The
menu defaults to "boot from local disk" after 30 seconds, so a machine that
netboots by accident is left alone.

When it reboots, log in with your SSH key:

```sh
ssh gavin@<new-machine-ip>
```

There is no password on the account -- keys only. Set one later with Ansible
if you want a console fallback.

Watch what happens: `docker compose logs -f dnsmasq`

## Adding a release

```sh
mkdir images/ubuntu-24.04
$EDITOR images/ubuntu-24.04/image.conf    # copy an existing one
docker compose up -d                      # bootstrap fetches it
```

Then add an `item` and a matching label in `boot/boot.ipxe`.

## Deploying changes

Edit here, push to the VM:

```sh
rsync -a --delete --exclude '.git' --exclude 'thoughts.md' \
  --exclude 'ipxe.efi' --exclude 'image.iso' --exclude 'vmlinuz' --exclude 'initrd' \
  ./ ubuntu@10.0.0.55:~/pixie/
```

Those excludes matter: without them `--delete` erases the images.

| Changed | Then |
|---|---|
| `boot/boot.ipxe` | nothing — it is read on each request |
| `dnsmasq.conf` | `docker compose restart` |
| `docker-compose.yml`, `Dockerfile` | `docker compose up -d --build` |

## How it works

```
machine firmware
   │  DHCP (broadcast)
   ├────────────▶ UniFi:  "here is your IP"
   └────────────▶ pixie:  "here is your boot file"
   │
   ▼  ipxe.efi over TFTP (1MB)
 iPXE  ──▶ boot.ipxe  ──▶ menu
   │
   ▼  HTTP
 kernel + initrd, then the installer fetches the ISO
```

TFTP carries only the 1MB handoff; it is too slow for anything larger. That
is why there are two services.

## Files

| Path | What |
|---|---|
| `dnsmasq.conf` | The PXE rules |
| `boot/boot.ipxe` | The menu, and how each release boots |
| `images/<release>/image.conf` | Where an ISO comes from and what is inside it |
| `autoinstall/user-data` | The installer's answers. Holds no secret: SSH key only |
| `scripts/bootstrap.sh` | Fetches anything missing; runs before the servers |
| `scripts/fetch-image.sh` | Downloads, verifies, extracts one image |
| `docker-compose.yml` | dnsmasq needs host networking for broadcasts; nginx does not |

Images are not in git — `image.conf` is the recipe, `fetch-image.sh` rebuilds
them.

## Things that cost us time

- **`autoinstall/user-data` cannot be renamed and cannot lose its first
  line.** cloud-init appends the literal name `user-data` to the `s=` URL,
  and `#cloud-config` is what identifies the format -- it is not a comment.
  Break either and you silently get the interactive installer.
- **The trailing slash on `ds=nocloud-net;s=http://.../autoinstall/`** is
  required for the same reason, and fails the same silent way.
- **`dhcp-match=set:ipxe,175` in `dnsmasq.conf` is load-bearing.** iPXE
  announces itself with DHCP option 175; without that tag we would hand iPXE
  another copy of iPXE forever.
- **`images/` and `autoinstall/` cannot nest** under the nginx web root.
  Docker cannot create a mountpoint inside a read-only bind mount.
- **`kernel = casper/vmlinuz` is Ubuntu-specific.** It is declared per image
  so another distro is a new `image.conf`, not a change to the script.
- **Every machine installs with the hostname `ubuntu`** on purpose. Ansible
  renames them; a hostname is configuration, and this file runs once.

- **`${next-server}` does not work here.** Once iPXE starts it makes its own
  DHCP request, UniFi answers that one too, and overwrites `next-server` with
  the gateway. The machine then asks the router for the installer. The server
  address is written out in `boot.ipxe` instead.
- **Secure Boot fails silently** — "image did not authenticate", then it moves
  on to the next boot device.
- **A container on the default bridge never sees DHCP**, because DHCP is a
  broadcast. Hence `network_mode: host` on dnsmasq only.
