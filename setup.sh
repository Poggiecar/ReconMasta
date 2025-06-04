#!/usr/bin/env bash
set -e

# Use sudo if not running as root
SUDO=""
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
fi

# Basic packages
PACKAGES=(git curl jq whois dnsrecon unzip)

echo "[*] Updating package lists"
$SUDO apt-get update -y

echo "[*] Installing packages: ${PACKAGES[*]}"
$SUDO apt-get install -y "${PACKAGES[@]}"

# Install Go-based tools
GO_TOOLS=(
    github.com/projectdiscovery/subfinder/v2/cmd/subfinder
    github.com/tomnomnom/assetfinder
    github.com/owasp-amass/amass/v4/... 
    github.com/projectdiscovery/httpx/cmd/httpx
    github.com/projectdiscovery/nuclei/v3/cmd/nuclei
    github.com/tomnomnom/anew
)

echo "[*] Installing Go tools"
for tool in "${GO_TOOLS[@]}"; do
    echo "    - $tool"
    go install "$tool@latest"
 done

# Install findomain (binary release)
echo "[*] Installing findomain"
FIND_URL=$(curl -s https://api.github.com/repos/findomain/findomain/releases/latest \
    | grep browser_download_url \
    | grep 'findomain-linux.zip' \
    | cut -d '"' -f4)

curl -L "$FIND_URL" -o /tmp/findomain.zip
unzip -q /tmp/findomain.zip -d /tmp/findomain
chmod +x /tmp/findomain/findomain
$SUDO mv /tmp/findomain/findomain /usr/local/bin/findomain
rm -rf /tmp/findomain /tmp/findomain.zip

# Install aquatone (binary release)
echo "[*] Installing aquatone"
AQUA_URL=$(curl -s https://api.github.com/repos/michenriksen/aquatone/releases/latest \
    | grep browser_download_url \
    | grep linux_amd64 \
    | head -n 1 \
    | cut -d '"' -f4)

curl -L "$AQUA_URL" -o /tmp/aquatone.zip
unzip -q /tmp/aquatone.zip -d /tmp/aquatone
chmod +x /tmp/aquatone/aquatone
$SUDO mv /tmp/aquatone/aquatone /usr/local/bin/aquatone
rm -rf /tmp/aquatone /tmp/aquatone.zip

# Update nuclei templates
if command -v nuclei >/dev/null 2>&1; then
    echo "[*] Updating nuclei templates"
    nuclei -update-templates
fi

echo "[+] Setup complete"


