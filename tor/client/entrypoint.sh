#!/bin/sh
set -eu

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

AUTH1_CERT="/shared/authority1/keys/authority_certificate"
AUTH1_FINGERPRINT_FILE="/shared/authority1/fingerprint"
AUTH2_CERT="/shared/authority2/keys/authority_certificate"
AUTH2_FINGERPRINT_FILE="/shared/authority2/fingerprint"
echo "[tor-client] Waiting for private directory authority certificate..."
for i in $(seq 1 120); do
  if [ -f "$AUTH1_CERT" ] && [ -f "$AUTH1_FINGERPRINT_FILE" ] && [ -f "$AUTH2_CERT" ] && [ -f "$AUTH2_FINGERPRINT_FILE" ]; then
    break
  fi
  sleep 1
done

if [ ! -f "$AUTH1_CERT" ] || [ ! -f "$AUTH1_FINGERPRINT_FILE" ] || [ ! -f "$AUTH2_CERT" ] || [ ! -f "$AUTH2_FINGERPRINT_FILE" ]; then
  echo "[tor-client] Missing authority files."
  exit 1
fi

DIRAUTH1_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH1_CERT" | head -n 1)"
DIRAUTH1_IDENTITY="$(awk '{print $2}' "$AUTH1_FINGERPRINT_FILE" | head -n 1)"
DIRAUTH2_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$AUTH2_CERT" | head -n 1)"
DIRAUTH2_IDENTITY="$(awk '{print $2}' "$AUTH2_FINGERPRINT_FILE" | head -n 1)"
if [ -z "${DIRAUTH1_V3IDENT:-}" ] || [ -z "${DIRAUTH1_IDENTITY:-}" ] || [ -z "${DIRAUTH2_V3IDENT:-}" ] || [ -z "${DIRAUTH2_IDENTITY:-}" ]; then
  echo "[tor-client] Failed to parse authority fingerprints."
  exit 1
fi

cat > /etc/tor/torrc <<EOF
DataDirectory /var/lib/tor
Log notice stdout
RunAsDaemon 0
TestingTorNetwork 1
DirAuthority auth1 orport=7001 no-v2 v3ident=${DIRAUTH1_V3IDENT} 172.28.0.10:7000 ${DIRAUTH1_IDENTITY}
DirAuthority auth2 orport=7001 no-v2 v3ident=${DIRAUTH2_V3IDENT} 172.28.0.11:7000 ${DIRAUTH2_IDENTITY}

SocksPort 127.0.0.1:9050
ControlPort 127.0.0.1:9051
CookieAuthentication 1
ClientUseIPv4 1
ClientOnly 1
EnforceDistinctSubnets 0
EOF

su -s /bin/sh -c "tor -f /etc/tor/torrc" debian-tor &
TOR_PID=$!

echo "[tor-client] Tor daemon started (pid: $TOR_PID)"
echo "[tor-client] Starting dashboard API on 0.0.0.0:3000 ..."
python3 /dashboard_api.py
