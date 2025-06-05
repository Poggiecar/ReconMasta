#!/usr/bin/env bash
set -euo pipefail

# 🎨 Colores
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m'

# 📋 Ayuda
usage() {
cat <<EOF
Uso: $0 [opciones] dominio.com

Opciones:
  -h, --help        Mostrar esta ayuda y salir
  -v                Salida verbal
  -vv               Salida muy detallada
  -d, --debug       Modo depuración (traza comandos en run.log)
  --nuclei          Ejecutar Nuclei automáticamente
  --no-nuclei       Omitir Nuclei
EOF
exit 1
}

# 🧠 Flags
VERBOSE=0
DEBUG_MODE=0
NUCLEI="ask"

# 🛠 Parsear argumentos
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1; shift ;;
        -vv) VERBOSE=2; shift ;;
        -d|--debug) DEBUG_MODE=1; shift ;;
        --nuclei) NUCLEI="yes"; shift ;;
        --no-nuclei) NUCLEI="no"; shift ;;
        -h|--help) usage ;;
        -*|--*) echo -e "${RED}[!] Opción desconocida: $1${NC}"; usage ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL[@]}"

[[ $# -ne 1 ]] && usage
TARGET="$1"

# 📅 Directorios
DATE=$(date +%Y-%m-%d)
OUTDIR="outputs/${TARGET}_${DATE}"
ANALYSIS_DIR="$OUTDIR/analysis"
mkdir -p "$OUTDIR" "$ANALYSIS_DIR"

# 📢 Verbosidad
log()   { [[ $VERBOSE -ge 1 ]] && echo -e "${YELLOW}[v] $*${NC}"; }
logvv() { [[ $VERBOSE -ge 2 ]] && echo -e "${BLUE}[vv] $*${NC}"; }

# 🐞 Debug mode
if [[ "$DEBUG_MODE" -eq 1 ]]; then
    export PS4='+ $(date "+%H:%M:%S") '
    exec > >(tee "$OUTDIR/run.log") 2>&1
    set -x
fi

echo -e "${BLUE}[*] Iniciando ReconMasta para: $TARGET${NC}"

# ▶️ Módulo 1: Subdomains
bash modules/subdomain_enum.sh "$TARGET" "$OUTDIR"

# ▶️ Módulo 2: Hosts vivos
bash modules/resolve_hosts.sh "$OUTDIR"

# ▶️ Módulo 3: Screenshots
bash modules/screenshots.sh "$OUTDIR"

# ▶️ Módulo 4: Nuclei si se permite
if [[ "$NUCLEI" == "ask" ]]; then
    read -p "¿Ejecutar nuclei? (s/n): " RES
    [[ "$RES" == "s" ]] && NUCLEI="yes" || NUCLEI="no"
fi

if [[ "$NUCLEI" == "yes" ]]; then
    bash modules/nuclei_scan.sh "$OUTDIR" "$ANALYSIS_DIR"
fi

# ▶️ Módulo 5: Takeover
bash modules/takeover.sh "$OUTDIR" "$ANALYSIS_DIR"

# ▶️ Módulo 6: OSINT
bash modules/osint.sh "$OUTDIR" "$ANALYSIS_DIR"

# ▶️ Módulo 7: Amass parsing (si existe)
[[ -f "$OUTDIR/amass.txt" ]] && bash modules/parse_amass.sh "$OUTDIR/amass.txt"

# ✅ Resumen
echo -e "${GREEN}[✓] ReconMasta finalizado. Resultados en: $OUTDIR${NC}"
