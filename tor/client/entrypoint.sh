#!/bin/sh
set -eu

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor &
TOR_PID=$!

echo "[tor-client] Waiting for tor bootstrap..."
sleep 20

HOSTNAME_FILE="/shared/onion/hostname"
if [ ! -f "$HOSTNAME_FILE" ]; then
  echo "[tor-client] Onion hostname not ready yet. Start test manually later."
  wait "$TOR_PID"
  exit 0
fi

ONION_ADDR="$(tr -d '\r\n' < "$HOSTNAME_FILE")"
echo "[tor-client] Onion service detected: $ONION_ADDR"
echo "[tor-client] Testing request through Tor SOCKS proxy..."

set +e
curl --socks5-hostname 127.0.0.1:9050 "http://$ONION_ADDR" --max-time 30
RESULT=$?
set -e

if [ "$RESULT" -ne 0 ]; then
  echo "[tor-client] Request failed (maybe tor still bootstrapping)."
else
  echo
  echo "[tor-client] Request succeeded."
fi

wait "$TOR_PID"
