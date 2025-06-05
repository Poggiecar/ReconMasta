#!/usr/bin/env bash
set -euo pipefail

SUDO=""
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
fi

echo "[*] Actualizando paquetes..."
$SUDO apt-get update -y

# 📦 Herramientas necesarias por apt
APT_PACKAGES=(git curl jq whois dnsrecon unzip python3-pip)

echo "[*] Instalando paquetes: ${APT_PACKAGES[*]}"
$SUDO apt-get install -y "${APT_PACKAGES[@]}"

# 🧪 Go tools
GO_TOOLS=(
    github.com/projectdiscovery/subfinder/v2/cmd/subfinder
    github.com/tomnomnom/assetfinder
    github.com/owasp-amass/amass/v4/...
    github.com/projectdiscovery/httpx/cmd/httpx
    github.com/projectdiscovery/nuclei/v3/cmd/nuclei
    github.com/tomnomnom/anew
    github.com/haccer/subjack
)

echo "[*] Instalando herramientas Go:"
for tool in "${GO_TOOLS[@]}"; do
    go install "$tool@latest"
done

# 🛰 Findomain
echo "[*] Instalando Findomain..."
FIND_URL=$(curl -s https://api.github.com/repos/findomain/findomain/releases/latest | grep 'findomain-linux.zip' | cut -d '"' -f4)
curl -L "$FIND_URL" -o /tmp/findomain.zip
unzip -q /tmp/findomain.zip -d /tmp/findomain
chmod +x /tmp/findomain/findomain
$SUDO mv /tmp/findomain/findomain /usr/local/bin/findomain
rm -rf /tmp/findomain*

# 📸 Aquatone
echo "[*] Instalando Aquatone..."
AQUA_URL=$(curl -s https://api.github.com/repos/michenriksen/aquatone/releases/latest | grep 'linux_amd64' | cut -d '"' -f4 | head -n1)
curl -L "$AQUA_URL" -o /tmp/aquatone.zip
unzip -q /tmp/aquatone.zip -d /tmp/aquatone
chmod +x /tmp/aquatone/aquatone
$SUDO mv /tmp/aquatone/aquatone /usr/local/bin/aquatone
rm -rf /tmp/aquatone*

# 🧪 Actualizar templates de nuclei
if command -v nuclei >/dev/null 2>&1; then
    echo "[*] Actualizando templates de nuclei..."
    nuclei -update-templates
fi

echo "[✓] Setup completo."
