#!/usr/bin/env bash
set -euo pipefail

HOST=${HOST:-"localhost"}
PORT=${PORT:-"9650"}

curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' -H 'content-type:application/json' http://$HOST:$PORT/ext/health | jq
