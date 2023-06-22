FROM alpine:latest AS compile-image

#RUN python -m venv /opt/venv
# Make sure we use the virtualenv:
#ENV PATH="/opt/venv/bin:$PATH"
ENV VER="3.2.1"

RUN apk add --no-cache --virtual \
    .build-deps gcc g++ automake autoconf make musl-dev git \
    libffi-dev rust cargo openssl-dev jq curl python3 py3-pip

# Download latest release of Sabnzd
RUN mkdir -p /opt/SABnzbd && \
    curl -s https://api.github.com/repos/sabnzbd/sabnzbd/releases/latest | \
    jq -r ".assets[] | select(.name | contains(\"src.tar.gz\")) | .browser_download_url" | \
    xargs -I {} curl {} -L -o /tmp/SABnzbd.tgz && \
    tar xvfz /tmp/SABnzbd.tgz -C /opt/SABnzbd --strip-components=1

RUN cd /opt/SABnzbd/ && \
    pip install -r requirements.txt -t .

RUN cd /opt && \
    git clone https://github.com/Parchive/par2cmdline.git && \
    cd par2cmdline && \
    aclocal && automake --add-missing && autoconf && \
    ./configure && make && make install

# ----------------------------------------------------------- #
FROM alpine:latest
MAINTAINER Paul Poloskov <pavel@poloskov.net>

ENV PUID 1001
ENV PGID 1001
ENV TZ "Europe/Moscow"
ENV XDG_DATA_HOME="/config"
ENV XDG_CONFIG_HOME="/config" 

RUN apk add --no-cache unzip ca-certificates tzdata py3-cffi openssl p7zip && \
    addgroup -g ${PGID} notroot && \
    adduser -D -H -G notroot -u ${PUID} notroot && \
    mkdir /config /downloads /watch /incomplete && \
    chown notroot:notroot /config /downloads /watch /incomplete

EXPOSE 8080

HEALTHCHECK CMD netstat -an | grep 8080 > /dev/null; if [ 0 != $? ]; then exit 1 ; fi;

VOLUME ["/config", "/downloads", "/watch", "/incomplete"]

COPY --from=compile-image /opt/ /opt/
COPY --from=compile-image \
    /usr/local/bin/par2 \
    /usr/local/bin/par2create \
    /usr/local/bin/par2repair \
    /usr/local/bin/par2verify /usr/local/bin/

ENTRYPOINT python /opt/SABnzbd/SABnzbd.py -b 0 -s 0.0.0.0:8080 -f /config/sabnzbd.ini
