#!/bin/bash
# Runs as root on every boot. Mounts the data disk, installs nginx the first
# time, then writes a page that names this VM and its zone.
set -euo pipefail

# The data disk: format it only if it has no filesystem yet, then mount it.
disk=/dev/disk/by-id/google-data
if ! blkid "$disk" >/dev/null; then
  mkfs.ext4 -m 0 "$disk"
fi
mkdir -p /mnt/data
mountpoint -q /mnt/data || mount -o discard,defaults "$disk" /mnt/data

# On first boot, unattended-upgrades may hold the apt lock: wait up to 5 minutes.
if ! command -v nginx >/dev/null; then
  apt-get -o DPkg::Lock::Timeout=300 update
  apt-get -o DPkg::Lock::Timeout=300 install -y nginx
fi

zone=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/zone)

cat >/var/www/html/index.html <<HTML
<h1>Hello from $(hostname)</h1>
<p>Zone: ${zone##*/}</p>
HTML
