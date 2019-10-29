#!/bin/bash

set -eo pipefail

if [[ -z "$PKS_SUBDOMAIN_NAME" ]]; then
echo "Enter the PKS subdomain (e.g. haas-218): "
    read -r PKS_SUBDOMAIN_NAME
fi

if [[ -z "$PKS_DOMAIN_NAME" ]]; then
  echo "Enter the PKS root domain (e.g. pez.pivotal.io): "
  read -r PKS_DOMAIN_NAME
fi

DOMAIN=${PKS_SUBDOMAIN_NAME}.${PKS_DOMAIN_NAME}
KEY_BITS=2048
DAYS=365

openssl req -new -x509 -nodes -sha256 -newkey rsa:${KEY_BITS} -days ${DAYS} \
 -keyout /tmp/${DOMAIN}.ca.key.pkcs8 \
 -out /tmp/${DOMAIN}.ca.crt \
 -config <( cat << EOF
[ req ]
prompt = no
distinguished_name    = dn
[ dn ]
C  = US
O = Pivotal
CN = PCFS
EOF
)

openssl rsa \
  -in /tmp/${DOMAIN}.ca.key.pkcs8 \
  -out /tmp/${DOMAIN}.ca.key

openssl req -nodes -sha256 -newkey rsa:${KEY_BITS} -days ${DAYS} \
 -keyout /tmp/${DOMAIN}.key \
 -out /tmp/${DOMAIN}.csr \
 -config <( cat << EOF
[ req ]
prompt = no
distinguished_name = dn
req_extensions = v3_req
[ dn ]
C  = US
O = Pivotal
CN = *.${DOMAIN}
[ v3_req ]
subjectAltName = DNS:*.${DOMAIN}, DNS:*.apps.${DOMAIN},DNS:*.sys.${DOMAIN}, DNS:*.login.sys.${DOMAIN},DNS:*.uaa.sys.${DOMAIN}, DNS:*.pks.${DOMAIN}
EOF
)

openssl x509 -req -sha256 -days ${DAYS} \
 -in /tmp/${DOMAIN}.csr \
 -CA /tmp/${DOMAIN}.ca.crt -CAkey /tmp/${DOMAIN}.ca.key.pkcs8 -CAcreateserial \
 -out /tmp/${DOMAIN}.host.crt \
 -extfile <( cat << EOF
basicConstraints = CA:FALSE
subjectAltName = DNS:*.${DOMAIN},DNS:*.apps.${DOMAIN},DNS:*.sys.${DOMAIN},DNS:*.login.sys.${DOMAIN},DNS:*.uaa.sys.${DOMAIN},DNS:*.pks.${DOMAIN}
subjectKeyIdentifier = hash
EOF
)

cat /tmp/${DOMAIN}.host.crt /tmp/${DOMAIN}.ca.crt > /tmp/${DOMAIN}.crt

echo "CSR: $(cat /tmp/${DOMAIN}.csr)"
echo "KEY: $(cat /tmp/${DOMAIN}.key)"
echo "CERT: $(cat /tmp/${DOMAIN}.crt)"

