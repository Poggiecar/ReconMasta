#!/usr/bin/env bash
set -euo pipefail

# ReconMasta.sh - Orquestador principal del framework de reconocimiento ofensivo
# Autor: Ecar Poggi

# Cargar configuración
CONFIG_FILE="config.yaml"

# Validar configuración y argumentos
# TODO: parsear YAML o convertirlo a .env si preferís más simple

# Crear carpeta de resultados
OUTDIR="outputs/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

# Ejecutar módulos
echo "[*] Iniciando reconocimiento ofensivo con ReconMasta..."

bash modules/subdomain_enum.sh "$1" "$OUTDIR"
bash modules/dns_resolve.sh "$1" "$OUTDIR"
bash modules/crawler.sh "$1" "$OUTDIR"
bash modules/tech_ports_scan.sh "$1" "$OUTDIR"
bash modules/screenshots.sh "$1" "$OUTDIR"
bash modules/nuclei_scan.sh "$1" "$OUTDIR"
bash modules/subjack_scan.sh "$1" "$OUTDIR"
bash modules/osint.sh "$1" "$OUTDIR"
bash modules/parse_amass.sh "$OUTDIR"
bash modules/crawler.sh "$TARGET" -o outputs

echo "[✓] Reconocimiento completo. Resultados en: $OUTDIR"
