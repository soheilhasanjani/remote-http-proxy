#!/usr/bin/env bash
set -e

# ========================================================
#       VPS HTTP Proxy Setup (Tinyproxy for US Egress)
# ========================================================

# Check root privilege
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (use: sudo ./setup.sh)"
    exit 1
fi

DEFAULT_PORT="18080"
DEFAULT_USER="devproxy"

echo "=========================================================="
echo "    Automated HTTP Proxy Setup (Antigravity & VS Code)    "
echo "=========================================================="

# 1. Prompt for port
read -p "Enter proxy port [Default: ${DEFAULT_PORT}]: " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-$DEFAULT_PORT}

# 2. Prompt for username
read -p "Enter username [Default: ${DEFAULT_USER}]: " PROXY_USER
PROXY_USER=${PROXY_USER:-$DEFAULT_USER}

# 3. Prompt for password (or auto-generate)
AUTO_PASS=$(head -c 12 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)
read -p "Enter password [Press Enter to auto-generate: ${AUTO_PASS}]: " PROXY_PASS
PROXY_PASS=${PROXY_PASS:-$AUTO_PASS}

echo ""
echo "[1/5] Updating packages and installing Tinyproxy..."
apt-get update -y
apt-get install -y tinyproxy curl ufw

echo "[2/5] Configuring proxy rules..."
CONF_FILE="/etc/tinyproxy/tinyproxy.conf"

# Backup default config if not already backed up
if [ ! -f "${CONF_FILE}.bak" ]; then
    cp "$CONF_FILE" "${CONF_FILE}.bak"
fi

# Reset config from backup
cp "${CONF_FILE}.bak" "$CONF_FILE"

# Set Port
sed -i "s/^Port .*/Port ${PROXY_PORT}/" "$CONF_FILE"

# Allow connections from any IP (default is 127.0.0.1 only)
sed -i 's/^Allow /#Allow /' "$CONF_FILE"

# Allow CONNECT method to any destination port (critical for arbitrary API & dev ports)
sed -i 's/^ConnectPort /#ConnectPort /' "$CONF_FILE"

# Clean any existing BasicAuth lines and add credentials
sed -i '/^BasicAuth /d' "$CONF_FILE"
echo "BasicAuth ${PROXY_USER} ${PROXY_PASS}" >> "$CONF_FILE"

# Save port for uninstaller
echo "${PROXY_PORT}" > /etc/tinyproxy/.proxy_port

echo "[3/5] Configuring firewall rules for port ${PROXY_PORT}..."
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    ufw allow ${PROXY_PORT}/tcp
    echo "UFW rule added for port ${PROXY_PORT}."
fi

echo "[4/5] Starting Tinyproxy service..."
systemctl restart tinyproxy
systemctl enable tinyproxy

echo "[5/5] Performing self-test verification..."
sleep 2
TEST_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -x "http://${PROXY_USER}:${PROXY_PASS}@127.0.0.1:${PROXY_PORT}" --connect-timeout 5 https://www.google.com || echo "000")

if [ "$TEST_HTTP_CODE" = "200" ]; then
    echo " Self-test passed: Tinyproxy is accepting and routing connections."
else
    echo " Warning: Local self-test returned HTTP status code ${TEST_HTTP_CODE}. Service may still be initializing."
fi

# Fetch IP and Location Info
IP_INFO=$(curl -s --connect-timeout 5 https://ipinfo.io/json || true)
PUBLIC_IP=$(echo "$IP_INFO" | grep -oP '"ip":\s*"\K[^"]+' || curl -s4 https://api.ipify.org || echo "YOUR_VPS_IP")
COUNTRY=$(echo "$IP_INFO" | grep -oP '"country":\s*"\K[^"]+' || echo "Unknown")
CITY=$(echo "$IP_INFO" | grep -oP '"city":\s*"\K[^"]+' || echo "Unknown")

PROXY_URL="http://${PROXY_USER}:${PROXY_PASS}@${PUBLIC_IP}:${PROXY_PORT}"

echo ""
echo "=========================================================="
echo "              Proxy Setup Complete!                       "
echo "=========================================================="
echo "  Egress Location : ${CITY}, ${COUNTRY} (Detected)"
echo "  Proxy URL       : ${PROXY_URL}"
echo ""
echo "Add this to your Antigravity / VS Code 'settings.json':"
echo "----------------------------------------------------------"
cat <<EOF
"http.proxy": "${PROXY_URL}",
"http.proxySupport": "on",
"http.proxyStrictSSL": false
EOF
echo "----------------------------------------------------------"
echo ""
echo "To test from your PC (PowerShell):"
echo "  curl.exe -x \"${PROXY_URL}\" https://ipinfo.io/json"
echo "=========================================================="
