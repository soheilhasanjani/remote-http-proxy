#!/usr/bin/env bash
set -e

# ========================================================
#       VPS HTTP Proxy Uninstaller
# ========================================================

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (use: sudo ./uninstall.sh)"
    exit 1
fi

echo "=========================================================="
echo "          VPS HTTP Proxy Uninstallation                   "
echo "=========================================================="
read -p "Are you sure you want to completely remove the proxy? (y/N): " CONFIRM
CONFIRM=${CONFIRM:-N}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "[1/3] Stopping and disabling Tinyproxy service..."
systemctl stop tinyproxy 2>/dev/null || true
systemctl disable tinyproxy 2>/dev/null || true

# Close firewall port if stored
if [ -f /etc/tinyproxy/.proxy_port ]; then
    SAVED_PORT=$(cat /etc/tinyproxy/.proxy_port)
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        echo "Removing UFW rule for port ${SAVED_PORT}..."
        ufw delete allow ${SAVED_PORT}/tcp 2>/dev/null || true
    fi
fi

echo "[2/3] Purging Tinyproxy and configuration files..."
apt-get purge -y tinyproxy
rm -rf /etc/tinyproxy /var/log/tinyproxy

echo "[3/3] Cleaning up unused packages..."
apt-get autoremove -y

echo ""
echo "=========================================================="
echo " Tinyproxy has been completely removed from this server."
echo "=========================================================="
