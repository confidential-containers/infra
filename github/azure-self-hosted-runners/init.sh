#!/bin/bash

set -euo pipefail

: "${GARM_HOSTNAME:?required}"
: "${GARM_JWT_SECRET:?required}"
: "${GARM_DB_PASSPHRASE:?required}"
: "${GITHUB_CONFIG:?required}"
python3 /template_config.py config.toml > /etc/garm/config.toml

: "${SUBSCRIPTION_ID:?required}"
: "${AZURE_CLIENT_ID:?required}"
python3 /template_config.py azure-config.toml > /etc/garm/azure-config.toml

if [ -f /etc/garm/db.sqlite ]; then
	echo "database already exists, skipping init"
	exit 0
fi

echo "start garm"

nohup /usr/bin/garm -config /etc/garm/config.toml & GARM_PID=$!
sleep 10

echo "initialize garm (pid $GARM_PID)"

garm-cli init \
	--name local \
	--email root@localhost \
	--url http://localhost:9997 \
	--password "$GARM_ADMIN_PW" \
	--username admin

echo "stop garm (pid $GARM_PID)"

kill "$GARM_PID"

echo "initialization complete"
