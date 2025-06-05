#!/usr/bin/env bash
set -euo pipefail

SUBFILE="$1/subdominios.txt"
OUTFILE="$1/hosts_vivos.txt"
URLFILE="$1/hosts_urls.txt"

echo "[*] Resolving and probing hosts with httpx..."

httpx -l "$SUBFILE" --threads 50 -sc -title -ip -td -probe -o "$OUTFILE"
awk '{print $1}' "$OUTFILE" > "$URLFILE"
