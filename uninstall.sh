#!/usr/bin/env bash
set -e

# ========================================================
#       VPS Proxy Uninstaller (Gost & Tinyproxy)
# ========================================================

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (use: sudo ./uninstall.sh)"
    exit 1
fi

echo "=========================================================="
echo "          VPS Proxy Uninstallation                        "
echo "=========================================================="
read -p "Are you sure you want to completely remove the proxy? (y/N): " CONFIRM
CONFIRM=${CONFIRM:-N}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "[1/3] Stopping and disabling services..."
systemctl stop gost 2>/dev/null || true
systemctl disable gost 2>/dev/null || true
systemctl stop tinyproxy 2>/dev/null || true
systemctl disable tinyproxy 2>/dev/null || true

rm -f /etc/systemd/system/gost.service
systemctl daemon-reload

echo "[2/3] Removing binary, configs and certificates..."
rm -f /usr/local/bin/gost
rm -rf /etc/gost /etc/tinyproxy /var/log/tinyproxy

if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    ufw delete allow 18080/tcp 2>/dev/null || true
    ufw delete allow 18443/tcp 2>/dev/null || true
fi

echo "[3/3] Purging leftover packages..."
apt-get purge -y tinyproxy 2>/dev/null || true
apt-get autoremove -y

echo ""
echo "=========================================================="
echo " Proxy has been completely removed from this server."
echo "=========================================================="
