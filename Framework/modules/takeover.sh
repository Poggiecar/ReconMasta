#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.yaml"
SUBS="$1/subdominios.txt"
OUTFILE="$2/takeover.txt"

SUBJACK_FLAGS=$(grep '^subjack_flags:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)

if [[ ! -s "$SUBS" ]]; then
  echo "[!] No hay subdominios para analizar con subjack."
  exit 0
fi

echo "[*] Analizando takeover con subjack..."
subjack -w "$SUBS" $SUBJACK_FLAGS -o "$OUTFILE"
