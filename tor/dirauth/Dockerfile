FROM debian:bookworm-slim

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bookworm-backports.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends -t bookworm-backports tor \
    && apt-get install -y --no-install-recommends ca-certificates dos2unix \
    && rm -rf /var/lib/apt/lists/*

COPY tor/dirauth/torrc /etc/tor/torrc
COPY tor/dirauth/entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
