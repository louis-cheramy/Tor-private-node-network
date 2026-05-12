#!/bin/sh
set -eu

echo "[onion-web] Initializing the hidden service..."

# Keep Tor directories secure
mkdir -p /var/lib/tor/hidden_service
chmod 700 /var/lib/tor /var/lib/tor/hidden_service
chown -R debian-tor:debian-tor /var/lib/tor

# Wait for the authorities' certificates
echo "[onion-web] Waiting for authority certificates..."
while [ ! -f "/shared/authority1/fingerprint" ] || [ ! -f "/shared/authority2/fingerprint" ]; do
  sleep 1
done

# Extract fingerprints for templating
export DIRAUTH1_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority1/keys/authority_certificate)
export DIRAUTH1_IDENTITY=$(awk '{print $2}' /shared/authority1/fingerprint)

export DIRAUTH2_V3IDENT=$(awk '/^fingerprint / {print $2}' /shared/authority2/keys/authority_certificate)
export DIRAUTH2_IDENTITY=$(awk '{print $2}' /shared/authority2/fingerprint)

# Render torrc from the template
envsubst < /etc/tor/torrc.template > /etc/tor/torrc

# Start Nginx in the background
echo "[onion-web] Starting Nginx..."
nginx

# Start Tor in the foreground
echo "[onion-web] Starting Tor..."
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor