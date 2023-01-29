# Certbot examples

## DNS CloudFlare (wildcard subdomain)

```sh
# Obtain certificates:
certbot certonly -n --agree-tos --keep --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini -m user@email.com -d example.com,*.example.com

# Renew certificates:
certbot renew -n --keep --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini
```

## TEST - DNS CloudFlare (wildcard subdomain)

```sh
# Obtain certificates:
certbot certonly --staging -n --agree-tos --force-renewal --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini -m user@email.com -d example.com,*.example.com

# Renew certificates:
certbot renew --staging -n --force-renewal --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini
```

## Webroot (multiple subdomains)

```sh
# Obtain certificates:
certbot certonly -n --agree-tos --keep --webroot -w /var/www -m user@email.com -d example.com,www.example.com,api.example.com

# Renew certificates:
certbot renew -n --keep --webroot -w /var/www
```

## [INTERACTIVE] Webroot (wildcard subdomain)

```sh
# Obtain certificates:
certbot certonly --agree-tos --keep --webroot -w /var/www -m user@email.com -d example.com,*.example.com

# Renew certificates:
certbot renew --keep --webroot -w /var/www
```

## [INTERACTIVE] TEST - Webroot (wildcard subdomain)

```sh
# Obtain certificates:
certbot certonly --staging --agree-tos --force-renewal --webroot -w /var/www -m user@email.com -d example.com,*.example.com

# Renew certificates:
certbot renew --staging --force-renewal --webroot -w /var/www
```
