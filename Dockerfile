# bybatkhuu/nginx:${BUILD_IMG_TAG}

ARG BASE_IMAGE=python:3.9.16-slim-bullseye
ARG DEBIAN_FRONTEND=noninteractive


# Here is the builder image
FROM ${BASE_IMAGE} as builder

ARG DEBIAN_FRONTEND

ARG NGINX_VERSION=1.23.2

# Set the SHELL to bash with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN rm -vrf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache/* && \
	apt-get clean -y && \
	apt-get update --fix-missing -o Acquire::CompressionTypes::Order::=gz && \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		build-essential \
		wget \
		tar \
		libpcre3 \
		libpcre3-dev \
		zlib1g \
		zlib1g-dev \
		libssl-dev \
		openssl \
		libgeoip-dev && \
	wget -nv --show-progress --progress=bar:force:noscroll https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O nginx.tar.gz && \
	tar -xzf nginx.tar.gz && \
	mv nginx-${NGINX_VERSION} nginx && \
	cd nginx && \
	./configure \
		--sbin-path=/usr/bin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/dev/stderr \
		--http-log-path=/dev/stdout \
		--pid-path=/run/nginx.pid \
		--lock-path=/var/lock/nginx.lock \
		--http-client-body-temp-path=/var/lib/nginx/body \
		--http-proxy-temp-path=/var/lib/nginx/proxy \
		--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
		--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
		--http-scgi-temp-path=/var/lib/nginx/scgi \
		--with-debug \
		--with-compat \
		--with-pcre-jit \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--with-http_realip_module \
		--with-http_auth_request_module \
		--with-http_v2_module \
		--with-http_slice_module \
		--with-threads \
		--with-http_addition_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_sub_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-http_mp4_module \
		--with-http_geoip_module \
		--without-http_autoindex_module \
		--without-mail_pop3_module \
		--without-mail_imap_module \
		--without-mail_smtp_module && \
	make && \
	rm -rf auto contrib CHANGE* LICENSE README configure


# Here is the production image
FROM ${BASE_IMAGE} as app

ARG DEBIAN_FRONTEND

ENV	PYTHONIOENCODING=utf-8

WORKDIR /root

# Set the SHELL to bash with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Installing system dependencies
RUN rm -vrf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache/* && \
	apt-get clean -y && \
	apt-get update --fix-missing -o Acquire::CompressionTypes::Order::=gz && \
	apt-get install -y --no-install-recommends \
		locales \
		tzdata \
		procps \
		iputils-ping \
		net-tools \
		curl \
		nano \
		make \
		openssl \
		libgeoip-dev \
		libaugeas0 \
		cron && \
	apt-get clean -y && \
	sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=en_US.UTF-8 && \
	echo "LANGUAGE=en_US.UTF-8" >> /etc/default/locale && \
	echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
	addgroup --gid 11000 www-group && \
	echo -e "\nalias ls='ls -aF --group-directories-first --color=auto'" >> /root/.bashrc && \
	echo -e "alias ll='ls -alhF --group-directories-first --color=auto'\n" >> /root/.bashrc && \
	mkdir -vp /var/lib/nginx /var/log/nginx /var/www/.well-known/acme-challenge /etc/nginx/modules-enabled /etc/nginx/conf.d /etc/nginx/sites-enabled /etc/nginx/ssl /etc/letsencrypt/live && \
	pip install --timeout 60 --no-cache-dir --upgrade pip && \
	pip install --timeout 60 --no-cache-dir certbot certbot-nginx && \
	pip cache purge && \
	echo -e "\n0 1 1 * * root /usr/local/bin/pip install --timeout 60 --no-cache-dir --upgrade certbot certbot-nginx >> /var/log/cron.log 2>&1" >> /etc/crontab && \
	echo "#0 2 1 * * root /usr/local/bin/python -c 'import random; import time; time.sleep(random.random() * 3000)' && certbot renew -q >> /var/log/cron.log 2>&1" >> /etc/crontab && \
	echo "#10 2 1 * * root /usr/bin/nginx -s reload >> /var/log/cron.log 2>&1" >> /etc/crontab && \
	rm -vrf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache/*

ENV	LANG=en_US.UTF-8 \
	LANGUAGE=en_US.UTF-8 \
	LC_ALL=en_US.UTF-8

COPY --from=builder --chown=root:root /nginx /root/nginx
COPY ./scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN cd nginx && \
	chown -R www-data:www-group /var/www /var/log/nginx && \
	make install && \
	cd .. && \
	chmod +x /docker-entrypoint.sh && \
	rm -rf nginx
COPY ./configs/ /etc/nginx/


ENTRYPOINT ["/bin/bash", "-i", "-c"]
CMD ["/docker-entrypoint.sh"]
# CMD ["service cron start && nginx -g 'daemon off;'"]
# CMD ["service cron start && nginx && tail -n 100 -f /var/log/nginx/access.log"]
