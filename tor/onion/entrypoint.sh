#!/bin/sh
set -eu

mkdir -p /var/lib/tor/hidden_service
chmod 700 /var/lib/tor /var/lib/tor/hidden_service
chown -R debian-tor:debian-tor /var/lib/tor

AUTH1_CERT="/shared/authority1/keys/authority_certificate"
AUTH1_FINGERPRINT_FILE="/shared/authority1/fingerprint"
AUTH2_CERT="/shared/authority2/keys/authority_certificate"
AUTH2_FINGERPRINT_FILE="/shared/authority2/fingerprint"
echo "[onion-web] Waiting for private directory authority certificate..."
for i in $(seq 1 120); do
  if [ -f "$AUTH1_CERT" ] && [ -f "$AUTH1_FINGERPRINT_FILE" ] && [ -f "$AUTH2_CERT" ] && [ -f "$AUTH2_FINGERPRINT_FILE" ]; then
    break
  fi
  sleep 1
done

if [ ! -f "$AUTH1_CERT" ] || [ ! -f "$AUTH1_FINGERPRINT_FILE" ] || [ ! -f "$AUTH2_CERT" ] || [ ! -f "$AUTH2_FINGERPRINT_FILE" ]; then
  echo "[onion-web] Missing authority files."
  exit 1
fi

DIRAUTH1_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH1_CERT" | head -n 1)"
DIRAUTH1_IDENTITY="$(awk '{print $2}' "$AUTH1_FINGERPRINT_FILE" | head -n 1)"
DIRAUTH2_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH2_CERT" | head -n 1)"
DIRAUTH2_IDENTITY="$(awk '{print $2}' "$AUTH2_FINGERPRINT_FILE" | head -n 1)"
if [ -z "${DIRAUTH1_V3IDENT:-}" ] || [ -z "${DIRAUTH1_IDENTITY:-}" ] || [ -z "${DIRAUTH2_V3IDENT:-}" ] || [ -z "${DIRAUTH2_IDENTITY:-}" ]; then
  echo "[onion-web] Failed to parse authority fingerprints."
  exit 1
fi

cat > /etc/tor/torrc <<EOF
DataDirectory /var/lib/tor
Log notice stdout
RunAsDaemon 0
TestingTorNetwork 1
DirAuthority auth1 orport=7001 no-v2 v3ident=${DIRAUTH1_V3IDENT} 172.28.0.10:7000 ${DIRAUTH1_IDENTITY}
DirAuthority auth2 orport=7001 no-v2 v3ident=${DIRAUTH2_V3IDENT} 172.28.0.11:7000 ${DIRAUTH2_IDENTITY}

SocksPort 0
ClientOnly 1
EnforceDistinctSubnets 0
HiddenServiceDir /var/lib/tor/hidden_service
HiddenServiceVersion 3
HiddenServicePort 80 127.0.0.1:8080
EOF

echo "[onion-web] Starting nginx..."
nginx

echo "[onion-web] Starting tor hidden service..."
exec su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor
