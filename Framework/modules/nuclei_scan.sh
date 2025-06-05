#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.yaml"
HOSTS="$1/hosts_urls.txt"
OUTFILE="$2/nuclei.txt"

NUCLEI_FLAGS=$(grep '^nuclei_flags:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)

if [[ ! -s "$HOSTS" ]]; then
  echo "[!] No hay hosts para escanear con nuclei."
  exit 0
fi

echo "[*] Ejecutando escaneo nuclei..."
nuclei -l "$HOSTS" $NUCLEI_FLAGS -o "$OUTFILE"
