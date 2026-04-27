#!/bin/sh
set -eu

echo "[relay] Initializing relay ${RELAY_NICKNAME:-DemoRelay}..."

# Keep Tor directories secure
mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

# Wait for the authorities' certificates
echo "[relay] Waiting for authority certificates..."
while [ ! -f "/shared/authority1/fingerprint" ] || [ ! -f "/shared/authority2/fingerprint" ]; do
  sleep 1
done

# Extract fingerprints for templating
export DIRAUTH1_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority1/keys/authority_certificate)
export DIRAUTH1_IDENTITY=$(awk '{print $2}' /shared/authority1/fingerprint)

export DIRAUTH2_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority2/keys/authority_certificate)
export DIRAUTH2_IDENTITY=$(awk '{print $2}' /shared/authority2/fingerprint)

# Default values in case docker-compose does not set them
export RELAY_NICKNAME="${RELAY_NICKNAME:-DemoRelay}"
export RELAY_ADDRESS="${RELAY_ADDRESS:-127.0.0.1}"

# Render torrc from the template
envsubst < /etc/tor/torrc.template > /etc/tor/torrc

# Start Tor
echo "[relay] Starting Tor..."
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor