#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.yaml"
CHROME_PATH=$(grep '^aquatone_chrome_path:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)

if [[ ! -x "$CHROME_PATH" ]]; then
  echo "[!] Chrome no encontrado en: $CHROME_PATH"
  exit 0
fi

cat "$1/hosts_vivos.txt" | aquatone -chrome-path "$CHROME_PATH" -out "$1/aquatone" > /dev/null 2>&1 || true
