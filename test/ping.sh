#!/bin/bash
set -euo pipefail

connect() {
    echo -n "Trying http://$1/... "
    curl -s -o /dev/null -w "%{http_code}\n" $1
}

ip1=$(terraform output -json 'ip_address_simple_cluster'  | jq -r .[0].ip)
ip2=$(terraform output -json 'ip_address_ha_cluster'  | jq -r .[0].ip)

connect $ip1
connect $ip2