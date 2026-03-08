FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends tor gettext-base ca-certificates dos2unix \
    && rm -rf /var/lib/apt/lists/*

COPY tor/relay/torrc.template /etc/tor/torrc.template
COPY tor/relay/entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
