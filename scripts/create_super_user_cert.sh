#!/bin/bash

set -euo pipefail

if [[ -z "$ENVIRONMENT_NAME" ]]; then
  echo "Enter an environment name (e.g. haas-218): "
  read -r ENVIRONMENT_NAME
fi

if [[ -z "$NSXT_PASSWORD" ]]; then
  echo "Enter nsx-t admin password: "
  read -s NSXT_PASSWORD
fi

NSX_SUPERUSER_CERT_FILE="pks-nsx-t-superuser.crt"
NSX_SUPERUSER_KEY_FILE="pks-nsx-t-superuser.key"
NSX_MANAGER="nsxmgr-01.${ENVIRONMENT_NAME}.pez.pivotal.io"
NSXT_USER=admin
PI_NAME="pks-nsx-t-superuser"

openssl req \
 -newkey rsa:2048 \
 -x509 \
 -nodes \
 -keyout "$NSX_SUPERUSER_KEY_FILE" \
 -new \
 -out "$NSX_SUPERUSER_CERT_FILE" \
 -subj /CN=pks-nsx-t-superuser \
 -extensions client_server_ssl \
 -config <(
cat /etc/ssl/openssl.cnf \
	<(printf '[client_server_ssl]\nextendedKeyUsage	= clientAuth\n')) \
    -sha256 \
	-days 730

# convert PEM to single-line json form, if needed
CERT_PEM=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' <(echo -n "${NSX_SUPERUSER_CERT_FILE}"))

cert_request=$(cat <<END
{
 "display_name": "$PI_NAME",
 "pem_encoded": "$(awk '{printf "%s\\n", $0}' $NSX_SUPERUSER_CERT_FILE)"
 }
END
)

curl -k -X POST \
  "https://${NSX_MANAGER}/api/v1/trust-management/certificates?action=import" \
  -u "$NSXT_USER:$NSXT_PASSWORD" \
  -H 'content-type: application/json' \
  -d "$cert_request"
