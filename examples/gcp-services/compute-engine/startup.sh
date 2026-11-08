#!/bin/bash
# Runs as root on every boot. Installs nginx the first time, then writes a
# page that names this VM and its zone.
set -euo pipefail

if ! command -v nginx >/dev/null; then
  apt-get update
  apt-get install -y nginx
fi

zone=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/zone)

cat >/var/www/html/index.html <<HTML
<h1>Hello from $(hostname)</h1>
<p>Zone: ${zone##*/}</p>
HTML
