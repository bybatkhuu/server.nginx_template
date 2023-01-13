#!/bin/bash
set -euo pipefail


echo "Running docker-entrypoint.sh..."

_DH_FILE_PATH="/etc/nginx/ssl/dhparam.pem"
if [ ! -f "${_DH_FILE_PATH}" ]; then
	openssl dhparam -out ${_DH_FILE_PATH} 2048 || exit 2
fi

chown -R www-data:www-group /var/www /var/log/nginx || exit 2
service cron start || exit 2
nginx -g 'daemon off;' || exit 2
