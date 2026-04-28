FROM debian:bookworm-slim

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bookworm-backports.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends -t bookworm-backports tor torsocks \
    && apt-get install -y --no-install-recommends curl ca-certificates dos2unix python3 gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY tor/client/torrc.template /etc/tor/torrc.template
COPY tor/client/entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 3000
EXPOSE 9050

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]