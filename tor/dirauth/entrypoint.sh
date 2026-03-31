#!/bin/sh
set -eu

mkdir -p /var/lib/tor
chmod 700 /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor

DIRAUTH_NICKNAME="${DIRAUTH_NICKNAME:-LocalDirAuth}"
DIRAUTH_IP="${DIRAUTH_IP:-172.28.0.10}"
DIRAUTH_ORPORT="${DIRAUTH_ORPORT:-7001}"
DIRAUTH_DIRPORT="${DIRAUTH_DIRPORT:-7000}"
PEER_IP="${PEER_IP:-172.28.0.11}"
PEER_ORPORT="${PEER_ORPORT:-7001}"
PEER_DIRPORT="${PEER_DIRPORT:-7000}"

mkdir -p /var/lib/tor/keys
if [ ! -f /var/lib/tor/keys/authority_signing_key ] || [ ! -f /var/lib/tor/keys/authority_certificate ]; then
  echo "[dirauth] Generating authority keys with tor-gencert..."
  printf '\n' | tor-gencert \
    --create-identity-key \
    --passphrase-fd 0 \
    -i /var/lib/tor/keys/authority_identity_key \
    -s /var/lib/tor/keys/authority_signing_key \
    -c /var/lib/tor/keys/authority_certificate \
    -m 12 \
    -a "${DIRAUTH_IP}:${DIRAUTH_DIRPORT}"
fi

chmod 600 /var/lib/tor/keys/authority_identity_key /var/lib/tor/keys/authority_signing_key /var/lib/tor/keys/authority_certificate
chown -R debian-tor:debian-tor /var/lib/tor/keys

SELF_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' /var/lib/tor/keys/authority_certificate | head -n 1)"
if [ -z "${SELF_V3IDENT:-}" ]; then
  echo "[dirauth] Failed to parse self v3ident."
  exit 1
fi

cat > /tmp/torrc.fingerprint <<EOF
DataDirectory /var/lib/tor
Nickname ${DIRAUTH_NICKNAME}
SocksPort 0
ORPort auto
EOF
SELF_FINGERPRINT_LINE="$(su -s /bin/sh -c "tor -f /tmp/torrc.fingerprint --list-fingerprint 2>/dev/null | awk -v nick='${DIRAUTH_NICKNAME}' '\$1==nick {printf(\"%s \", \$1); for (i=2;i<=NF;i++) printf(\"%s\", \$i); printf(\"\\n\"); exit}'" debian-tor || true)"
if [ -z "${SELF_FINGERPRINT_LINE:-}" ]; then
  echo "[dirauth] Failed to generate self fingerprint line."
  exit 1
fi
printf "%s\n" "$SELF_FINGERPRINT_LINE" > /var/lib/tor/fingerprint

SELF_IDENTITY="$(awk '{print $2}' /var/lib/tor/fingerprint | head -n 1)"
if [ -z "${SELF_IDENTITY:-}" ]; then
  echo "[dirauth] Failed to parse self identity fingerprint."
  exit 1
fi

PEER_CERT="/peer_authority/keys/authority_certificate"
PEER_FINGERPRINT_FILE="/peer_authority/fingerprint"
echo "[dirauth] Waiting for peer authority fingerprints..."
for i in $(seq 1 180); do
  if [ -f "$PEER_CERT" ] && [ -f "$PEER_FINGERPRINT_FILE" ]; then
    break
  fi
  sleep 1
done

if [ ! -f "$PEER_CERT" ] || [ ! -f "$PEER_FINGERPRINT_FILE" ]; then
  echo "[dirauth] Missing peer authority files."
  exit 1
fi

PEER_V3IDENT="$(awk '/^fingerprint / {for (i=2;i<=NF;i++) printf("%s",$i); print ""}' "$PEER_CERT" | head -n 1)"
PEER_IDENTITY="$(awk '{print $2}' "$PEER_FINGERPRINT_FILE" | head -n 1)"
if [ -z "${PEER_V3IDENT:-}" ] || [ -z "${PEER_IDENTITY:-}" ]; then
  echo "[dirauth] Failed to parse peer authority fingerprints."
  exit 1
fi

cat > /tmp/torrc.dirauth <<EOF
DataDirectory /var/lib/tor
Log notice stdout
RunAsDaemon 0
TestingTorNetwork 1

Nickname ${DIRAUTH_NICKNAME}
ContactInfo local-dirauth@invalid
Address ${DIRAUTH_IP}
SocksPort 0
ORPort ${DIRAUTH_ORPORT}
DirPort ${DIRAUTH_DIRPORT}

AuthoritativeDirectory 1
V3AuthoritativeDirectory 1
DirAuthority auth1 orport=${DIRAUTH_ORPORT} no-v2 v3ident=${SELF_V3IDENT} ${DIRAUTH_IP}:${DIRAUTH_DIRPORT} ${SELF_IDENTITY}
DirAuthority auth2 orport=${PEER_ORPORT} no-v2 v3ident=${PEER_V3IDENT} ${PEER_IP}:${PEER_DIRPORT} ${PEER_IDENTITY}
V3AuthVotingInterval 60
V3AuthVoteDelay 10
V3AuthDistDelay 10
TestingV3AuthInitialVotingInterval 20
TestingV3AuthInitialVoteDelay 5
TestingV3AuthInitialDistDelay 5
TestingDirAuthVoteExit 0
TestingDirAuthVoteGuard 1
TestingDirAuthVoteHSDir 1

AssumeReachable 1
ExitPolicy reject *:*
EnforceDistinctSubnets 0
EOF

echo "[dirauth] Starting private Tor directory authority..."
exec su -s /bin/sh -c "tor -f /tmp/torrc.dirauth" debian-tor
