#!/bin/bash
set -euo pipefail

INPUT=${1:-"amass_output.txt"}
OUTDIR="parsed_$(basename "$INPUT" .txt)"
mkdir -p "$OUTDIR"

echo "[*] Analizando archivo: $INPUT"
echo "[*] Resultados separados en: $OUTDIR"

# 1. Separar por tipo de registro
grep "a_record" "$INPUT" > "$OUTDIR/a_records.txt" || true
grep "cname_record" "$INPUT" > "$OUTDIR/cname_records.txt" || true
grep "ptr_record" "$INPUT" > "$OUTDIR/ptr_records.txt" || true
grep "mx_record" "$INPUT" > "$OUTDIR/mx_records.txt" || true
grep "ns_record" "$INPUT" > "$OUTDIR/ns_records.txt" || true

# 2. Extraer subdominios únicos
awk '{print $1}' "$INPUT" | sort -u > "$OUTDIR/subdominios_unicos.txt"

# 3. IPs
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$INPUT" | sort -u > "$OUTDIR/ips_todas.txt"
grep -E '^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.|^192\.168\.' "$OUTDIR/ips_todas.txt" > "$OUTDIR/ips_privadas.txt" || true
grep -v -f "$OUTDIR/ips_privadas.txt" "$OUTDIR/ips_todas.txt" > "$OUTDIR/ips_publicas.txt" || true

# 4. Entornos sensibles
grep -Ei 'dev|test|staging|demo|preprod|vpn|internal' "$INPUT" > "$OUTDIR/entornos_sensibles.txt" || true

# 5. Clasificación por proveedor (por CNAME o dominio)
declare -A proveedores=(
  ["azure"]="azure|cloudapp|azurefd"
  ["cloudflare"]="cloudflare"
  ["akamai"]="akamai|edgekey|akamaiedge|edgesuite"
  ["amazon"]="elb.amazonaws.com|s3.amazonaws.com"
  ["incapsula"]="incapdns"
  ["fastly"]="fastly"
  ["sap"]="ondemand.com"
)

for proveedor in "${!proveedores[@]}"; do
  grep -Ei "${proveedores[$proveedor]}" "$OUTDIR/cname_records.txt" > "$OUTDIR/proveedor_${proveedor}.txt" || true
done

# 6. Hosts listos para escaneo HTTP (a_record)
awk '{print $1}' "$OUTDIR/a_records.txt" > "$OUTDIR/hosts_httpx.txt"

# 7. Estadísticas
echo "[+] Total subdominios únicos: $(wc -l < "$OUTDIR/subdominios_unicos.txt")"
echo "[+] IPs públicas:             $(wc -l < "$OUTDIR/ips_publicas.txt")"
echo "[+] IPs privadas:             $(wc -l < "$OUTDIR/ips_privadas.txt")"
echo "[+] Registros CNAME Azure:    $(wc -l < "$OUTDIR/proveedor_azure.txt" 2>/dev/null || echo 0)"

echo "[✓] Listo. Puedes empezar con httpx, crawler o revisar a mano $OUTDIR."

