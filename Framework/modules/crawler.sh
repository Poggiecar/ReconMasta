#!/bin/bash
set -euo pipefail

# 🎨 Colores
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# 🧠 Variables
DEPTH=4
KATANA_EXTRA=""
GOSPIDER_EXTRA=""
VERBOSE=0
OUTDIR=""
DOMAIN=""
LIST_FILE=""

# 📜 Ayuda
function usage() {
cat <<EOF
Uso: $0 [opciones] dominio.com

Opciones:
  -h, --help            Mostrar esta ayuda
  -t archivo.txt        Usar una lista de dominios
  -o carpeta            Carpeta de salida personalizada
  -v                    Verbose nivel 1
  -vv                   Verbose nivel 2
  --deep                Crawling profundo (más JS)
EOF
exit 1
}

# 🧩 Verbosidad
log()   { [[ $VERBOSE -ge 1 ]] && echo -e "${YELLOW}[v] $*${NC}"; }
logv()  { [[ $VERBOSE -ge 2 ]] && echo -e "${BLUE}[vv] $*${NC}"; }

# ✅ Dependencias
function check_dependencies() {
    echo "[*] Verificando herramientas necesarias..."
    for cmd in katana gospider uro python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}[-] Falta la herramienta: $cmd${NC}"
            exit 1
        fi
    done
}

# 🔍 Katana
function run_katana() {
    echo "[*] Katana..."
    katana -u "$1" -jc -iqp -rl 150 -v $KATANA_EXTRA | grep -o 'http[^ ]*' | uro > "$2/katana.txt"
    logv "Katana finalizado."
}

# 🔍 Gospider
function run_gospider() {
    echo "[*] Gospider..."
    gospider -s "$1" -q --sitemap --robots --no-redirect -v --subs -d "$DEPTH" --user-agent web $GOSPIDER_EXTRA | uro > "$2/gospider.txt"
    logv "Gospider finalizado."
}

# 🕸 WebSpider
function run_webspider() {
    echo "[*] WebSpider.py..."
    [[ -f data.txt ]] && rm -f data.txt
    python3 "$(dirname "$0")/WebSpider.py" "$1"
    mv data.txt "$2/webspider.txt"
    logv "WebSpider finalizado."
}

# 🧹 Unificación y análisis
function unify_results() {
    echo "[*] Unificando resultados..."
    cat "$1"/*.txt | sort -u > "$1/crawler_combined.txt"

    grep -Ei '\.js$|\.php$|\.json$|/api/|admin|login|logout|debug' "$1/crawler_combined.txt" > "$1/crawler_interesting.txt"

    grep -Ei 'apikey|token|auth|pass|secret|key=' "$1/crawler_combined.txt" > "$1/posibles_secretos.txt" || true

    cp "$1/crawler_combined.txt" "$1/urls.txt"
    logv "Unificación finalizada."
}

# 📊 Resumen
function print_summary() {
    echo -e "\n${GREEN}[✓] Crawler finalizado.${NC}"
    echo "[*] Unificadas:     $1/crawler_combined.txt ($(wc -l < "$1/crawler_combined.txt") URLs)"
    echo "[*] Interesantes:   $1/crawler_interesting.txt ($(wc -l < "$1/crawler_interesting.txt") coincidencias)"
    echo "[*] Secretos:       $1/posibles_secretos.txt ($(wc -l < "$1/posibles_secretos.txt" 2>/dev/null || echo 0))"
    echo "[*] Para análisis:  $1/urls.txt"
}

# 🚨 Argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -v) VERBOSE=1 ;;
        -vv) VERBOSE=2 ;;
        -t) LIST_FILE="$2"; shift ;;
        -o) OUTDIR="$2"; shift ;;
        --deep)
            DEPTH=6
            KATANA_EXTRA="-d 3"
            GOSPIDER_EXTRA="--js"
            ;;
        -*)
            echo "Opción desconocida: $1"
            usage
            ;;
        *)
            DOMAIN="$1"
            ;;
    esac
    shift
done

# 🚦 Validación
if [[ -z "$DOMAIN" && -z "$LIST_FILE" ]]; then
    echo -e "${RED}[!] Debes especificar un dominio o lista con -t${NC}"
    usage
fi

check_dependencies

# 🚀 Modo lista
if [[ -n "$LIST_FILE" ]]; then
    while read -r DOMAIN; do
        [[ -z "$DOMAIN" ]] && continue
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        DIR="${OUTDIR:-crawler_output}/${DOMAIN}_${TIMESTAMP}"
        mkdir -p "$DIR"
        echo -e "\n[+] Objetivo: $DOMAIN"
        run_katana "$DOMAIN" "$DIR" &
        run_gospider "$DOMAIN" "$DIR" &
        run_webspider "$DOMAIN" "$DIR" &
        wait
        unify_results "$DIR"
        print_summary "$DIR"
    done < "$LIST_FILE"
else
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    DIR="${OUTDIR:-crawler_output}/${DOMAIN}_${TIMESTAMP}"
    mkdir -p "$DIR"
    echo "[+] Objetivo: $DOMAIN"
    run_katana "$DOMAIN" "$DIR" &
    run_gospider "$DOMAIN" "$DIR" &
    run_webspider "$DOMAIN" "$DIR" &
    wait
    unify_results "$DIR"
    print_summary "$DIR"
fi
