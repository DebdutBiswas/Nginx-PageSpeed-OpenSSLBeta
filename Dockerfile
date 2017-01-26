# To deploy this container directly from Docker Hub, use:
#
#        docker run --cap-drop=all --name nginx -d -p 80:8080 ajhaydock/nginx
#
# To build and run this container locally, try a command like:
#
#        docker build -t nginx .
#        docker run --cap-drop=all --name nginx -d -p 80:8080 nginx
#

FROM fedora:latest
MAINTAINER Alex Haydock <alex@alexhaydock.co.uk>

# Nginx Version (See: https://nginx.org/en/CHANGES)
ENV NGNXVER 1.11.8

# PageSpeed Version (See: https://modpagespeed.com/doc/release_notes)
ENV PSPDVER latest-beta

# OpenSSL Version (See: https://www.openssl.org/source/)
ENV OSSLVER 1.1.0d

# Build as root (we drop privileges later when actually running the container)
USER root
WORKDIR /root

# Add 'nginx' user
RUN useradd nginx --home-dir /usr/share/nginx --no-create-home --shell /sbin/nologin

# Install deps
RUN dnf install -y \
    gcc \
    gcc-c++ \
    git \
    gperftools-devel \
    make \
    pcre-devel \
    tar \
    unzip \
    wget \
    zlib-devel \
  && dnf clean all

# Download nginx
RUN cd ~ \
  && wget --https-only https://nginx.org/download/nginx-$NGNXVER.tar.gz \
  && tar -xzvf nginx-$NGNXVER.tar.gz \
  && rm -v nginx-$NGNXVER.tar.gz

# Download PageSpeed
RUN cd ~ \
  && wget --https-only https://github.com/pagespeed/ngx_pagespeed/archive/$PSPDVER.tar.gz \
  && tar -xzvf $PSPDVER.tar.gz \
  && rm -v $PSPDVER.tar.gz \
  && cd ngx_pagespeed-$PSPDVER/ \
  && echo "Downloading PSOL binary from the URL specified in the PSOL_BINARY_URL file..." \
  && PSOLURL=$(cat PSOL_BINARY_URL | grep https: | sed 's/$BIT_SIZE_NAME/x64/g') \
  && wget --https-only $PSOLURL \
  && tar -xzvf *.tar.gz \
  && rm -v *.tar.gz

# Download OpenSSL
RUN cd ~ \
  && wget --https-only https://www.openssl.org/source/openssl-$OSSLVER.tar.gz \
  && tar -xzvf openssl-$OSSLVER.tar.gz \
  && rm -v openssl-$OSSLVER.tar.gz

# Download ngx_headers_more Module
RUN git clone https://github.com/openresty/headers-more-nginx-module.git "$HOME/ngx_headers_more"

# Configure Nginx
# Config options stolen from the current packaged version of nginx for Fedora 25.
# cc-opt tweaked to use -fstack-protector-all, and -fPIE added to build position-independent.
# Removed any of the modules that the Fedora team was building with "=dynamic" as they stop us being able to build with -fPIE and require the less-hardened -fPIC option instead. (https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html)
# Also removed the --with-debug flag (I don't need debug-level logging) and --with-ipv6 as the flag is now deprecated.
# Removed all the mail modules as I have no intention of using this as a mailserver proxy.
# The final tweaks are my --add-module lines at the bottom, and the --with-openssl
# argument, to point the build to the OpenSSL Beta we downloaded earlier.
RUN cd ~/nginx-$NGNXVER/ \
  && ./configure \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib64/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
    --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
    --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
    --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
    --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/lock/subsys/nginx \
    --user=nginx \
    --group=nginx \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-pcre \
    --with-pcre-jit \
    --with-stream \
    --with-stream_ssl_module \
    --with-google_perftools_module \
    --with-cc-opt='-O2 -g -fPIE -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-all --param=ssp-buffer-size=4 -grecord-gcc-switches' \
    --with-ld-opt='-Wl,-z,relro -Wl,-E' \
    --add-module="$HOME/ngx_headers_more" \
    --add-module="$HOME/ngx_pagespeed-$PSPDVER" \
    --with-openssl="$HOME/openssl-$OSSLVER"

# Build Nginx
RUN cd ~/nginx-$NGNXVER/ \
  && make \
  && make install

# Make sure the permissions are set correctly on our webroot, logdir and pidfile so that we can run the webserver as non-root.
RUN chown -R nginx:nginx /usr/share/nginx \
  && chown -R nginx:nginx /var/log/nginx \
  && mkdir -p /var/lib/nginx/tmp \
  && chown -R nginx:nginx /var/lib/nginx \
  && touch /run/nginx.pid \
  && chown -R nginx:nginx /run/nginx.pid

# Configure nginx to listen on 8080 instead of 80 (we can't bind to <1024 as non-root)
RUN perl -pi -e 's,80;,8080;,' /etc/nginx/nginx.conf

# Print built version
RUN nginx -V

# Launch Nginx in container as non-root
USER nginx
WORKDIR /usr/share/nginx

# Launch command
CMD ["nginx", "-g", "daemon off;"]
