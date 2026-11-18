#!/usr/bin/env bash
set -e

# ==============================================================================
#   Dual-Mode Proxy Setup: Plain HTTP (for IDEs) + Encrypted HTTPS (for Browser)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (use: sudo ./setup.sh)"
    exit 1
fi

HTTP_PORT="18080"
HTTPS_PORT="18443"
DEFAULT_USER="soheilhm"

echo "=========================================================="
echo "    VPS Dual Proxy Setup (Antigravity/IDEs + Browser)     "
echo "=========================================================="

# 1. Credentials
read -p "Enter username [Default: ${DEFAULT_USER}]: " PROXY_USER
PROXY_USER=${PROXY_USER:-$DEFAULT_USER}

AUTO_PASS=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 14)
read -p "Enter password (alphanumeric only) [Default: ${AUTO_PASS}]: " PROXY_PASS
PROXY_PASS=${PROXY_PASS:-$AUTO_PASS}
PROXY_PASS=$(echo "$PROXY_PASS" | tr -dc 'a-zA-Z0-9')

# 2. Get Public IP
PUBLIC_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://icanhazip.com || echo "YOUR_VPS_IP")

echo ""
echo "[1/5] Stopping old services and installing dependencies..."
systemctl stop tinyproxy 2>/dev/null || true
systemctl disable tinyproxy 2>/dev/null || true

apt-get update -y
apt-get install -y curl openssl gzip ufw

echo "[2/5] Installing Gost binary..."
GOST_VERSION="2.11.5"
GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-amd64-${GOST_VERSION}.gz"

curl -fsSL "$GOST_URL" -o /tmp/gost.gz
gzip -d -f /tmp/gost.gz
mv /tmp/gost /usr/local/bin/gost
chmod +x /usr/local/bin/gost

echo "[3/5] Generating TLS Certificate for IP: ${PUBLIC_IP}..."
mkdir -p /etc/gost

cat <<EOF > /etc/gost/openssl.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${PUBLIC_IP}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = ${PUBLIC_IP}
EOF

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/gost/proxy.key \
  -out /etc/gost/proxy.crt \
  -config /etc/gost/openssl.cnf

chmod 644 /etc/gost/proxy.crt
chmod 600 /etc/gost/proxy.key

echo "[4/5] Creating Systemd Service..."
cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=Gost Dual HTTP/HTTPS Proxy
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/gost -L http://${PROXY_USER}:${PROXY_PASS}@:${HTTP_PORT} -L https://${PROXY_USER}:${PROXY_PASS}@:${HTTPS_PORT}?cert=/etc/gost/proxy.crt&key=/etc/gost/proxy.key
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gost
systemctl restart gost

echo "[5/5] Configuring firewall..."
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    ufw allow ${HTTP_PORT}/tcp
    ufw allow ${HTTPS_PORT}/tcp
fi

sleep 2
systemctl is-active --quiet gost && echo " Service is running smoothly!" || echo " Service starting..."

echo ""
echo "=========================================================="
echo "                   Setup Completed!                       "
echo "=========================================================="
echo ""
echo " 1. FOR ANTIGRAVITY & VS CODE (Port ${HTTP_PORT}):"
echo "----------------------------------------------------------"
echo "\"http.proxy\": \"http://${PROXY_USER}:${PROXY_PASS}@${PUBLIC_IP}:${HTTP_PORT}\","
echo "\"http.proxySupport\": \"on\","
echo "\"http.proxyStrictSSL\": false"
echo ""
echo " 2. FOR BROWSER & YOUTUBE (Port ${HTTPS_PORT} - TLS Encrypted):"
echo "----------------------------------------------------------"
echo "  Protocol : HTTPS"
echo "  Server   : ${PUBLIC_IP}"
echo "  Port     : ${HTTPS_PORT}"
echo "  Username : ${PROXY_USER}"
echo "  Password : ${PROXY_PASS}"
echo ""
echo " 3. TO TRUST THE TLS CERTIFICATE IN WINDOWS (Run in PC PowerShell):"
echo "----------------------------------------------------------"
echo "scp root@${PUBLIC_IP}:/etc/gost/proxy.crt . ; Import-Certificate -FilePath .\\proxy.crt -CertStoreLocation Cert:\\CurrentUser\\Root"
echo "=========================================================="
