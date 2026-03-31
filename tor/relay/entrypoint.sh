#!/bin/sh
set -eu

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

AUTH1_CERT="/shared/authority1/keys/authority_certificate"
AUTH1_FINGERPRINT_FILE="/shared/authority1/fingerprint"
AUTH2_CERT="/shared/authority2/keys/authority_certificate"
AUTH2_FINGERPRINT_FILE="/shared/authority2/fingerprint"
echo "[relay] Waiting for private directory authority certificate..."
for i in $(seq 1 120); do
  if [ -f "$AUTH1_CERT" ] && [ -f "$AUTH1_FINGERPRINT_FILE" ] && [ -f "$AUTH2_CERT" ] && [ -f "$AUTH2_FINGERPRINT_FILE" ]; then
    break
  fi
  sleep 1
done

if [ ! -f "$AUTH1_CERT" ] || [ ! -f "$AUTH1_FINGERPRINT_FILE" ] || [ ! -f "$AUTH2_CERT" ] || [ ! -f "$AUTH2_FINGERPRINT_FILE" ]; then
  echo "[relay] Missing authority files."
  exit 1
fi

DIRAUTH1_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH1_CERT" | head -n 1)"
DIRAUTH1_IDENTITY="$(awk '{print $2}' "$AUTH1_FINGERPRINT_FILE" | head -n 1)"
DIRAUTH2_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH2_CERT" | head -n 1)"
DIRAUTH2_IDENTITY="$(awk '{print $2}' "$AUTH2_FINGERPRINT_FILE" | head -n 1)"
if [ -z "${DIRAUTH1_V3IDENT:-}" ] || [ -z "${DIRAUTH1_IDENTITY:-}" ] || [ -z "${DIRAUTH2_V3IDENT:-}" ] || [ -z "${DIRAUTH2_IDENTITY:-}" ]; then
  echo "[relay] Failed to parse authority fingerprints."
  exit 1
fi
export DIRAUTH1_V3IDENT
export DIRAUTH1_IDENTITY
export DIRAUTH2_V3IDENT
export DIRAUTH2_IDENTITY

export RELAY_NICKNAME="${RELAY_NICKNAME:-DemoRelay}"
envsubst < /etc/tor/torrc.template > /etc/tor/torrc

echo "[relay] Starting relay: ${RELAY_NICKNAME}"
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor
