#!/bin/sh
set -eu

mkdir -p /var/lib/tor/hidden_service
chmod 700 /var/lib/tor /var/lib/tor/hidden_service
chown -R debian-tor:debian-tor /var/lib/tor

echo "[onion-web] Starting nginx..."
nginx

echo "[onion-web] Starting tor hidden service..."
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor
