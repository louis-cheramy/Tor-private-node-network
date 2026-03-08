#!/bin/sh
set -eu

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

export RELAY_NICKNAME="${RELAY_NICKNAME:-DemoRelay}"
envsubst < /etc/tor/torrc.template > /etc/tor/torrc

echo "[relay] Starting relay: ${RELAY_NICKNAME}"
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor
