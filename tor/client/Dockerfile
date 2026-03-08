FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends tor curl torsocks ca-certificates dos2unix \
    && rm -rf /var/lib/apt/lists/*

COPY tor/client/torrc /etc/tor/torrc
COPY tor/client/entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
