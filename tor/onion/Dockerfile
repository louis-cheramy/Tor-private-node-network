FROM debian:bookworm-slim

RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bookworm-backports.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends -t bookworm-backports tor \
    && apt-get install -y --no-install-recommends nginx ca-certificates dos2unix gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY tor/onion/torrc.template /etc/tor/torrc.template
COPY tor/onion/default.conf /etc/nginx/conf.d/default.conf
COPY tor/onion/entrypoint.sh /entrypoint.sh
COPY web/index.html /usr/share/nginx/html/index.html

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]