#!/bin/bash

# 🎨 Colores
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# 🚨 Manejo de errores suaves
set -uo pipefail
trap 'echo -e "${RED}[!] Algo falló. Abortando.${NC}" >&2' ERR

# 🧠 Verbosidad
VERBOSE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1 ;;
        -vv) VERBOSE=2 ;;
    esac
    shift
done
log() { [[ $VERBOSE -ge 1 ]] && echo -e "$1"; }
log_verbose() { [[ $VERBOSE -ge 2 ]] && echo -e "$1"; }

# 🧾 INPUT
read -p "🔎 Empresa: " empresa
read -p "🌐 Dominio objetivo (ej: example.com): " dominio
read -p "🔑 ¿Usar tus APIs de Amass? (s/n): " usar_apis
fecha=$(date +%Y-%m-%d)

# 📁 Estructura
empresa_slug=$(echo "$empresa" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
base="output/$empresa_slug/$fecha/results"
subs="$base/subdomains"
scan="$base/analysis"
mkdir -p "$subs" "$scan"

echo "$dominio" > "$subs/domain.txt"
> "$subs/subdominios.txt"

# 🔍 Subdomain enumeration

log "${YELLOW}[*] Subfinder...${NC}"
if command -v subfinder &>/dev/null; then
    subfinder -all -recursive -d "$dominio" -o "$subs/subfinder.txt" --silent
    [[ -s "$subs/subfinder.txt" ]] && cat "$subs/subfinder.txt" | anew "$subs/subdominios.txt"
fi

log "${YELLOW}[*] Assetfinder...${NC}"
if command -v assetfinder &>/dev/null; then
    assetfinder --subs-only "$dominio" > "$subs/assetfinder.txt"
    [[ -s "$subs/assetfinder.txt" ]] && cat "$subs/assetfinder.txt" | anew "$subs/subdominios.txt"
fi

log "${YELLOW}[*] Findomain...${NC}"
if command -v findomain &>/dev/null; then
    echo "$dominio" > "$subs/tmpdomain.txt"
    findomain -f "$subs/tmpdomain.txt" -u "$subs/findomain.txt" 2>/dev/null || log "${RED}[!] Findomain falló al consultar crt.sh, pero continuamos.${NC}"
    [[ -s "$subs/findomain.txt" ]] && cat "$subs/findomain.txt" | anew "$subs/subdominios.txt"
    rm "$subs/tmpdomain.txt"
fi

log "${YELLOW}[*] Amass...${NC}"
if command -v amass &>/dev/null; then
    CONFIG_PATH="$HOME/.config/amass/config.yaml"
    if [[ "$usar_apis" == "s" && -f "$CONFIG_PATH" ]]; then
        amass enum -passive -config "$CONFIG_PATH" -d "$dominio" -o "$subs/amass.txt"
    else
        log "${BLUE}[i] Usando Amass sin APIs.${NC}"
        amass enum -passive -d "$dominio" -o "$subs/amass.txt"
    fi
    [[ -s "$subs/amass.txt" ]] && cat "$subs/amass.txt" | anew "$subs/subdominios.txt"
fi

log "${YELLOW}[*] crt.sh...${NC}"
if command -v jq &>/dev/null; then
    curl -s "https://crt.sh/?q=%25.$dominio&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > "$subs/crtsh.txt"
    [[ -s "$subs/crtsh.txt" ]] && cat "$subs/crtsh.txt" | anew "$subs/subdominios.txt"
fi

log "${YELLOW}[*] DNSrecon (modo pasivo)...${NC}"
if command -v dnsrecon &>/dev/null; then
    dnsrecon -d "$dominio" -a > "$subs/dnsrecon.txt"
    grep -oE "\\b([a-zA-Z0-9_-]+\\.)+$dominio\\b" "$subs/dnsrecon.txt" | anew "$subs/subdominios.txt"
fi

# 🌐 Resolución con httpx
log "${YELLOW}[*] Resolviendo con httpx...${NC}"
touch "$subs/subdominios.txt"
touch "$subs/hosts_vivos.txt"
if command -v httpx &>/dev/null; then
    cat "$subs/subdominios.txt" | httpx --threads 50 -sc -title -ip -td -probe -o "$subs/hosts_vivos.txt"
fi
awk '{print $1}' "$subs/hosts_vivos.txt" > "$subs/hosts_urls.txt"

# 🚩 Infraestructura directa detectada (OVH, DigitalOcean, etc.)
log "${YELLOW}[*] Analizando IPs para detección de infraestructura directa...${NC}"
touch "$scan/infra_directa.txt"
touch "$scan/ipinfo_tmp.txt"

if command -v whois &>/dev/null; then
    awk '{print $3}' "$subs/hosts_vivos.txt" | sort -u > "$scan/ips_detectadas.txt"

    while read -r ip; do
        org=$(whois "$ip" | grep -Ei 'OrgName|NetName|Organization' | head -1)
        if echo "$org" | grep -Eiq 'ovh|digitalocean|linode|hetzner|vultr|contabo'; then
            echo -e "$ip\t$org" >> "$scan/infra_directa.txt"
        fi
    done < "$scan/ips_detectadas.txt"

    if [[ -s "$scan/infra_directa.txt" ]]; then
        echo -e "${RED}[!] Infraestructura directa detectada. Hosts prioritarios:${NC}"
        cat "$scan/infra_directa.txt"
    else
        log "${GREEN}[+] No se detectaron IPs asociadas a infraestructura directa.${NC}"
    fi
else
    log "${RED}[!] 'whois' no está instalado. Saltando detección de infraestructura directa.${NC}"
fi

# 🖼 Screenshots con Aquatone
log "${YELLOW}[*] Screenshots con Aquatone...${NC}"
if command -v aquatone &>/dev/null; then
    cat "$subs/hosts_vivos.txt" | aquatone -chrome-path /usr/bin/chromium -out "$subs/aquatone" > /dev/null 2>&1
    log "${GREEN}[+] Screenshots guardados en: $subs/aquatone${NC}"
fi

# 📄 Resumen
total_subs=$(wc -l < "$subs/subdominios.txt" 2>/dev/null || echo 0)
total_vivos=$(wc -l < "$subs/hosts_vivos.txt" 2>/dev/null || echo 0)

{
    echo "🗓 Recon para $empresa - $dominio"
    echo "📅 Fecha: $(date)"
    echo "🔎 Subdominios únicos:     $total_subs"
    echo "🌐 Hosts con respuesta:    $total_vivos"
    echo "📁 Resultados en:          $base"
} > "$base/resumen.txt"

# ✅ Final
echo -e "${GREEN}\n✅ Recon finalizado para $dominio${NC}"
cat "$base/resumen.txt"
