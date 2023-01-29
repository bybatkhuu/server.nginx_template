#!/bin/bash
set -euo pipefail


echo -e "INFO: Running certbot docker-entrypoint.sh...\n"

# CERTBOT_EMAIL=${CERTBOT_EMAIL:-user@example.com}
# CERTBOT_PRIMARY_DOMAIN=${CERTBOT_PRIMARY_DOMAIN:-example.com}
# CERTBOT_DOMAINS=${CERTBOT_DOMAINS:-example.com,*.example.com}


_main()
{
	if [ ! -d "/var/www/.well-known/acme-challenge" ]; then
		mkdir -vp /var/www/.well-known/acme-challenge || exit 2
	fi

	echo "INFO: Changing permissions..."
	chown -R www-data:www-group /var/www/.well-known || exit 2

	find /var/www/.well-known -type d -exec chmod 775 {} + || exit 2
	find /var/www/.well-known -type f -exec chmod 664 {} + || exit 2
	find /var/www/.well-known -type d -exec chmod ug+s {} + || exit 2

	if [ -d "/root/.secrets/certbot" ]; then
		find /root/.secrets/certbot -type d -exec chmod 770 {} + || exit 2
		find /root/.secrets/certbot -type f -exec chmod 600 {} + || exit 2
		find /root/.secrets/certbot -type d -exec chmod ug+s {} + || exit 2
	fi
	echo -e "SUCCESS: Done.\n"

	_CERTBOT_PARAM_STAGING=""
	_CERTBOT_PARAM_PLUGIN="--webroot -w /var/www"
	_CERTBOT_PIP_DNS_PLUGIN=""
	_IS_OBTAIN_NEW_CERTS=false

	## Parsing input:
	for _INPUT in "${@:-}"; do
		case ${_INPUT} in
			"")
				shift;;
			-n | --new)
				_IS_OBTAIN_NEW_CERTS=true
				shift;;
			-s | --staging)
				_CERTBOT_PARAM_STAGING="--staging"
				shift;;
			-d=* | --dns=*)
				_DNS_PLUGIN="${_INPUT#*=}"
				if [ "${_DNS_PLUGIN}" = "route53" ]; then
					_CERTBOT_PARAM_PLUGIN="--dns-dns-route53"
				elif [ "${_DNS_PLUGIN}" = "godaddy" ]; then
					_CERTBOT_PARAM_PLUGIN="--authenticator dns-${_DNS_PLUGIN} --dns-${_DNS_PLUGIN}-credentials /root/.secrets/certbot/${_DNS_PLUGIN}.ini"
				elif [ "${_DNS_PLUGIN}" = "google" ]; then
					_CERTBOT_PARAM_PLUGIN="--dns-${_DNS_PLUGIN} --dns-${_DNS_PLUGIN}-credentials /root/.secrets/certbot/${_DNS_PLUGIN}.json"
				elif [ "${_DNS_PLUGIN}" = "cloudflare" ] || [ "${_DNS_PLUGIN}" = "digitalocean" ]; then
					_CERTBOT_PARAM_PLUGIN="--dns-${_DNS_PLUGIN} --dns-${_DNS_PLUGIN}-credentials /root/.secrets/certbot/${_DNS_PLUGIN}.ini"
				else
					echo "ERROR: Unsupported DNS plugin -> ${_DNS_PLUGIN}"
					exit 1
				fi

				_CERTBOT_PIP_DNS_PLUGIN="certbot-dns-${_DNS_PLUGIN}"
				if [ "${_DNS_PLUGIN}" != "cloudflare" ]; then
					echo "INFO: Installing certbot DNS plugin -> ${_DNS_PLUGIN}..."
					pip install --timeout 60 --no-cache-dir ${_CERTBOT_PIP_DNS_PLUGIN} || exit 2
					pip cache purge || exit 2
					echo -e "SUCCESS: Done.\n"
				fi
				shift;;
			-b | --bash | bash | /bin/bash)
				/bin/bash
				exit 0;;
			*)
				echo "ERROR: Failed to parsing input -> ${@}"
				echo "USAGE: ${0} -n, --new | -s, --staging | -d=*, --dns=* [cloudflare | digitalocean | google | route53 | godaddy] | -b, --bash, bash, /bin/bash"
				exit 1;;
		esac
	done

	if [ ${_IS_OBTAIN_NEW_CERTS} == true ]; then
		echo "INFO: Obtaining new certificates..."
		certbot certonly -n --agree-tos --keep --max-log-backups 100 ${_CERTBOT_PARAM_STAGING} ${_CERTBOT_PARAM_PLUGIN} -m ${CERTBOT_EMAIL} -d ${CERTBOT_DOMAINS} || exit 2
		echo -e "SUCCESS: Done.\n"
	fi

	echo "INFO: Adding cron jobs..."
	echo -e "\n0 1 1 * * root /usr/local/bin/pip install --timeout 60 --no-cache-dir --upgrade certbot ${_CERTBOT_PIP_DNS_PLUGIN} >> /var/log/cron.log 2>&1" >> /etc/crontab || exit 2
	echo "0 2 * * 1 root /usr/local/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -n --keep --max-log-backups 100 ${_CERTBOT_PARAM_STAGING} ${_CERTBOT_PARAM_PLUGIN} >> /var/log/cron.log 2>&1" >> /etc/crontab || exit 2
	echo -e "SUCCESS: Done.\n"

	/bin/bash
}

_main "${@:-}"
