#!/bin/sh
set -eu

echo "[dirauth] Initializing ${DIRAUTH_NICKNAME}..."

# Keep Tor directories secure
mkdir -p /var/lib/tor/keys
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

# Generate authority keys if needed
if [ ! -f /var/lib/tor/keys/authority_signing_key ]; then
  echo "[dirauth] Generating new Tor keys..."
  printf '\n' | tor-gencert \
    --create-identity-key \
    --passphrase-fd 0 \
    -i /var/lib/tor/keys/authority_identity_key \
    -s /var/lib/tor/keys/authority_signing_key \
    -c /var/lib/tor/keys/authority_certificate \
    -m 12 \
    -a "${DIRAUTH_IP}:${DIRAUTH_DIRPORT}"
fi

# Fix permissions after generation
chmod 600 /var/lib/tor/keys/*
chown -R debian-tor:debian-tor /var/lib/tor/keys

# Extract the local fingerprint
SELF_V3IDENT=$(awk '/^fingerprint / {print $2}' /var/lib/tor/keys/authority_certificate)

# Use a minimal torrc to bypass strict validation
cat > /tmp/torrc.fingerprint <<EOF
DataDirectory /var/lib/tor
Nickname ${DIRAUTH_NICKNAME}
SocksPort 0
ORPort auto
EOF

echo "[dirauth] Generating the base fingerprint..."
su -s /bin/sh -c "tor -f /tmp/torrc.fingerprint --list-fingerprint" debian-tor

SELF_IDENTITY=$(awk '{print $2}' /var/lib/tor/fingerprint)

# Wait for the peer container (DirAuth2)
PEER_CERT="/peer_authority/keys/authority_certificate"
PEER_FGP="/peer_authority/fingerprint"

echo "[dirauth] Waiting for the other DirAuth keys..."
while [ ! -f "$PEER_CERT" ] || [ ! -f "$PEER_FGP" ]; do
  sleep 1
done

PEER_V3IDENT=$(awk '/^fingerprint / {print $2}' "$PEER_CERT")
PEER_IDENTITY=$(awk '{print $2}' "$PEER_FGP")

# Render the final configuration
FINAL_TORRC="/tmp/torrc.final"
cp /etc/tor/torrc $FINAL_TORRC

cat <<EOF >> $FINAL_TORRC

Nickname ${DIRAUTH_NICKNAME}
Address ${DIRAUTH_IP}
ORPort ${DIRAUTH_ORPORT}
DirPort ${DIRAUTH_DIRPORT}

DirAuthority auth1 orport=${DIRAUTH_ORPORT} no-v2 v3ident=${SELF_V3IDENT} ${DIRAUTH_IP}:${DIRAUTH_DIRPORT} ${SELF_IDENTITY}
DirAuthority auth2 orport=${PEER_ORPORT} no-v2 v3ident=${PEER_V3IDENT} ${PEER_IP}:${PEER_DIRPORT} ${PEER_IDENTITY}
EOF

# Start Tor with the final configuration
echo "[dirauth] Starting Tor..."
exec su -s /bin/sh -c "tor -f $FINAL_TORRC" debian-tor