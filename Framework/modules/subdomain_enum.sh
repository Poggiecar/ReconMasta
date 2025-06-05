#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="config.yaml"
DOMAIN="$1"
OUTDIR="$2"
mkdir -p "$OUTDIR"

echo "[*] Subdomain enumeration for: $DOMAIN"
> "$OUTDIR/subdominios.txt"

# Leer flags desde config.yaml
SUBFINDER_FLAGS=$(grep '^subfinder_flags:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)
AMASS_FLAGS=$(grep '^amass_flags:' "$CONFIG_FILE" | cut -d':' -f2- | xargs)
AMASS_CONFIG=$(grep '^amass_config_path:' "$CONFIG_FILE" | cut -d':' -f2- | xargs | sed 's#~#'"$HOME"'#')

ENABLE_CRTSH=$(grep '^enable_crtsh:' "$CONFIG_FILE" | cut -d':' -f2 | xargs)
ENABLE_DNSRECON=$(grep '^enable_dnsrecon:' "$CONFIG_FILE" | cut -d':' -f2 | xargs)

# Subfinder
subfinder -d "$DOMAIN" $SUBFINDER_FLAGS -o "$OUTDIR/subfinder.txt" && cat "$OUTDIR/subfinder.txt" | anew "$OUTDIR/subdominios.txt"

# Assetfinder
assetfinder --subs-only "$DOMAIN" > "$OUTDIR/assetfinder.txt" && cat "$OUTDIR/assetfinder.txt" | anew "$OUTDIR/subdominios.txt"

# Findomain
echo "$DOMAIN" > "$OUTDIR/tmpdomain.txt"
findomain -f "$OUTDIR/tmpdomain.txt" -u "$OUTDIR/findomain.txt" && cat "$OUTDIR/findomain.txt" | anew "$OUTDIR/subdominios.txt"
rm "$OUTDIR/tmpdomain.txt"

# Amass con config opcional
if [[ -f "$AMASS_CONFIG" ]]; then
    amass enum $AMASS_FLAGS -config "$AMASS_CONFIG" -d "$DOMAIN" -o "$OUTDIR/amass.txt"
else
    amass enum $AMASS_FLAGS -d "$DOMAIN" -o "$OUTDIR/amass.txt"
fi
cat "$OUTDIR/amass.txt" | anew "$OUTDIR/subdominios.txt"

# crt.sh opcional
if [[ "$ENABLE_CRTSH" == "true" ]]; then
    curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" | jq -r '.[].name_value' | sed 's/\\*\\.//g' | sort -u > "$OUTDIR/crtsh.txt" || true
    cat "$OUTDIR/crtsh.txt" | anew "$OUTDIR/subdominios.txt"
fi

# dnsrecon opcional
if [[ "$ENABLE_DNSRECON" == "true" ]]; then
    dnsrecon -d "$DOMAIN" -a > "$OUTDIR/dnsrecon.txt"
    grep -oE "\\b([a-zA-Z0-9_-]+\\.)+$DOMAIN\\b" "$OUTDIR/dnsrecon.txt" | anew "$OUTDIR/subdominios.txt"
fi

sort -u "$OUTDIR/subdominios.txt" -o "$OUTDIR/subdominios.txt"
echo "[✓] Total subdomains: $(wc -l < "$OUTDIR/subdominios.txt")"
