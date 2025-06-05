#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.yaml"

SUBFILE="$1/subdominios.txt"
OUTFILE="$1/hosts_vivos.txt"
URLFILE="$1/hosts_urls.txt"

# Leer flags de httpx desde config.yaml
HTTPX_FLAGS=$(grep '^httpx_flags:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)

echo "[*] Resolving and probing hosts with httpx..."

httpx -l "$SUBFILE" $HTTPX_FLAGS -o "$OUTFILE"
awk '{print $1}' "$OUTFILE" > "$URLFILE"
