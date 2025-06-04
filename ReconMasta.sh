#!/usr/bin/env bash

# 🎨 Colores
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Uso: $0 [opciones]

Opciones:
  -h, --help        Mostrar esta ayuda y salir
  -v                Salida verbal
  -vv               Salida muy detallada
  -d, --debug       Modo depuración (traza comandos en run.log)
  --nuclei          Ejecutar Nuclei automáticamente
  --no-nuclei       Omitir Nuclei
EOF
}

# 🚨 Manejo de errores suaves
set -euo pipefail
trap 'echo -e "${RED}[!] Error en la línea $LINENO. Abortando.${NC}" >&2' ERR

# Debug flag
DEBUG_MODE=0

# 📦 Dependencias requeridas
REQUIRED_CMDS=(
    anew
    subfinder
    assetfinder
    findomain
    amass
    httpx
    jq
    dnsrecon
    whois
    aquatone
    nuclei
    subjack
)

MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_CMDS+=("$cmd")
    fi
done
if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    echo -e "${RED}[!] Faltan las siguientes dependencias:${NC} ${MISSING_CMDS[*]}"
    echo -e "Instálalas ejecutando ./setup.sh o asegurate de que están en el PATH."
    exit 1
fi

echo -e "${BLUE}[i] Utiliza este script únicamente en sistemas para los que tengas autorización.${NC}"

# 🧠 Verbosidad
VERBOSE=0
NUCLEI_CHOICE="ask"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1 ;;
        -vv) VERBOSE=2 ;;
        -d|--debug) DEBUG_MODE=1 ;;
        --nuclei) NUCLEI_CHOICE="yes" ;;
        --no-nuclei) NUCLEI_CHOICE="no" ;;
        -h|--help) usage; exit 0 ;;
        *) echo -e "${RED}[!] Opción desconocida: $1${NC}"; usage; exit 1 ;;
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

# Decidir ejecución de Nuclei
if [[ "$NUCLEI_CHOICE" == "ask" ]]; then
    read -p "🚀 ¿Ejecutar Nuclei después de resolver hosts? (s/n): " resp_nuclei
    if [[ "$resp_nuclei" == "s" ]]; then
        NUCLEI_CHOICE="yes"
    else
        NUCLEI_CHOICE="no"
    fi
fi

# 📁 Estructura
empresa_slug=$(echo "$empresa" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
base="output/$empresa_slug/$fecha/results"
subs="$base/subdomains"
scan="$base/analysis"
mkdir -p "$subs" "$scan"

LOG_FILE="$base/run.log"
if [[ $DEBUG_MODE -eq 1 ]]; then
    export PS4='+ $(date "+%H:%M:%S") '
    set -x
fi
exec > >(tee -a "$LOG_FILE") 2>&1

echo "$dominio" > "$subs/domain.txt"
> "$subs/subdominios.txt"

enum_subdomains() {
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
        curl -s "https://crt.sh/?q=%25.$dominio&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > "$subs/crtsh.txt" || true
        [[ -s "$subs/crtsh.txt" ]] && cat "$subs/crtsh.txt" | anew "$subs/subdominios.txt"
    fi

    log "${YELLOW}[*] DNSrecon (modo pasivo)...${NC}"
    if command -v dnsrecon &>/dev/null; then
        dnsrecon -d "$dominio" -a > "$subs/dnsrecon.txt"
        grep -oE "\\b([a-zA-Z0-9_-]+\\.)+$dominio\\b" "$subs/dnsrecon.txt" | anew "$subs/subdominios.txt" || true
    fi
}

resolve_hosts() {
    log "${YELLOW}[*] Resolviendo con httpx...${NC}"
    touch "$subs/subdominios.txt" "$subs/hosts_vivos.txt" "$subs/hosts_urls.txt"
    if command -v httpx &>/dev/null; then
        cat "$subs/subdominios.txt" | httpx --threads 50 -sc -title -ip -td -probe -o "$subs/hosts_vivos.txt"
        awk '{print $1}' "$subs/hosts_vivos.txt" > "$subs/hosts_urls.txt"
    fi
}

scan_nuclei() {
    log "${YELLOW}[*] Escaneando con Nuclei...${NC}"
    if command -v nuclei &>/dev/null; then
        nuclei -l "$subs/hosts_urls.txt" -o "$scan/nuclei.txt"
    else
        log "${RED}[!] 'nuclei' no está instalado. Saltando.${NC}"
    fi
}

check_takeover() {
    log "${YELLOW}[*] Comprobando posibles subdomain takeovers...${NC}"
    if command -v subjack &>/dev/null; then
        subjack -w "$subs/subdominios.txt" -t 100 -timeout 30 -ssl -o "$scan/takeover.txt" -v
    else
        log "${RED}[!] 'subjack' no está instalado. Saltando comprobación de takeover.${NC}"
    fi
    awk '{print $1}' "$subs/hosts_vivos.txt" > "$subs/hosts_urls.txt"
}

detect_infra() {
    log "${YELLOW}[*] Analizando IPs para detección de infraestructura directa...${NC}"
    touch "$scan/infra_directa.txt" "$scan/ipinfo_tmp.txt"
    if command -v whois &>/dev/null; then
        awk '{print $3}' "$subs/hosts_vivos.txt" | sort -u > "$scan/ips_detectadas.txt"
        while read -r ip; do
            org=$(whois "$ip" | grep -Ei 'OrgName|NetName|Organization' | head -1 || true)
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
}

take_screenshots() {
    log "${YELLOW}[*] Screenshots con Aquatone...${NC}"
    if command -v aquatone &>/dev/null; then
        cat "$subs/hosts_vivos.txt" | aquatone -chrome-path /usr/bin/chromium -out "$subs/aquatone" > /dev/null 2>&1 || true
        log "${GREEN}[+] Screenshots guardados en: $subs/aquatone${NC}"
    fi
}

generate_summary() {
    total_subs=$(wc -l < "$subs/subdominios.txt" 2>/dev/null || echo 0)
    total_vivos=$(wc -l < "$subs/hosts_vivos.txt" 2>/dev/null || echo 0)
    nuclei_hallazgos=$(wc -l < "$scan/nuclei.txt" 2>/dev/null || echo 0)
    takeover_hallazgos=$(wc -l < "$scan/takeover.txt" 2>/dev/null || echo 0)

    {
        echo "🗓 Recon para $empresa - $dominio"
        echo "📅 Fecha: $(date)"
        echo "🔎 Subdominios únicos:     $total_subs"
        echo "🌐 Hosts con respuesta:    $total_vivos"
        echo "🚨 Hallazgos de Nuclei:    $nuclei_hallazgos"
        echo "🎣 Posibles takeovers:     $takeover_hallazgos"
        echo "📁 Resultados en:          $base"
    } > "$base/resumen.txt"
    echo -e "${GREEN}\n✅ Recon finalizado para $dominio${NC}"
    cat "$base/resumen.txt"
}

enum_subdomains
resolve_hosts
[[ "$NUCLEI_CHOICE" == "yes" ]] && scan_nuclei
check_takeover
detect_infra
take_screenshots
generate_summary
