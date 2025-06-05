#!/usr/bin/env bash
set -euo pipefail

INFILE="$1/hosts_vivos.txt"
OUTFILE="$2/infra_directa.txt"

awk '{print $3}' "$INFILE" | sort -u > "$2/ips_detectadas.txt"

while read -r ip; do
    org=$(whois "$ip" | grep -Ei 'OrgName|NetName|Organization' | head -1 || true)
    if echo "$org" | grep -Eiq 'ovh|digitalocean|linode|hetzner|vultr|contabo'; then
        echo -e "$ip\t$org" >> "$OUTFILE"
    fi
done < "$2/ips_detectadas.txt"

[[ -s "$OUTFILE" ]] && cat "$OUTFILE"
