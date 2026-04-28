#!/bin/sh
set -eu

echo "[tor-client] Initializing the Tor client..."

# Secure the data directory
mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

# Wait for the authorities' certificates
echo "[tor-client] Waiting for authority certificates..."
while [ ! -f "/shared/authority1/fingerprint" ] || [ ! -f "/shared/authority2/fingerprint" ]; do
  sleep 1
done

# Extract fingerprints
export DIRAUTH1_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority1/keys/authority_certificate)
export DIRAUTH1_IDENTITY=$(awk '{print $2}' /shared/authority1/fingerprint)

export DIRAUTH2_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority2/keys/authority_certificate)
export DIRAUTH2_IDENTITY=$(awk '{print $2}' /shared/authority2/fingerprint)

# Render torrc from the template
envsubst < /etc/tor/torrc.template > /etc/tor/torrc

# Start Tor in the foreground
echo "[tor-client] Starting the Tor daemon..."
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor
TOR_PID=$!

echo "[tor-client] Tor is running (PID: $TOR_PID)"
