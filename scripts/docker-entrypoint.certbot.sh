#!/bin/bash
set -euo pipefail


echo -e "INFO: Running certbot docker-entrypoint.sh...\n"


_main()
{
	if [ ! -d "/var/www/.well-known/acme-challenge" ]; then
		mkdir -vp /var/www/.well-known/acme-challenge || exit 2

		echo "INFO: Setting permissions..."
		chown -R www-data:www-group /var/www || exit 2

		find /var/www -type d -exec chmod 775 {} + || exit 2
		find /var/www -type f -exec chmod 664 {} + || exit 2
		find /var/www -type d -exec chmod ug+s {} + || exit 2
		echo -e "SUCCESS: Done.\n"
	fi

	# Parsing input:
	# case ${1} in
	# 	"" | nginx)
	# 		_run_nginx
	# 		shift;;
	# 	-s=* | --https=*)
	# 		_HTTPS_TYPE="${1#*=}"
	# 		if [ "${_HTTPS_TYPE}" = "self" ]; then
	# 			_https_self
	# 		elif [ "${_HTTPS_TYPE}" = "lets" ]; then
	# 			_https_lets
	# 		fi
	# 		shift;;
	# 	bash | /bin/bash | /usr/bin/bash)
	# 		/bin/bash
	# 		shift;;
	# 	*)
	# 		echo "ERROR: Failed to parsing input -> ${@}"
	# 		echo "USAGE: ${0} nginx | -s=*, --https=* [self | lets] | bash"
	# 		exit 1;;
	# esac

	/bin/bash
}

_main "${@:-}"
