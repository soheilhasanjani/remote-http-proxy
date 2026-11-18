# Remote HTTP/HTTPS Proxy (Dual-Mode)

A lightweight dual-mode proxy:
1. **Port 18080 (Plain HTTP)**: Direct plug-and-play for **Antigravity**, **VS Code**, and developer CLI tools.
2. **Port 18443 (Encrypted HTTPS with TLS)**: Bypasses DPI inspection for **YouTube**, Google Chrome, Edge, and web browsing.

---

## 🚀 Setup on VPS

SSH into your Ubuntu droplet as `root`:

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/remote-http-proxy.git
cd remote-http-proxy
chmod +x setup.sh uninstall.sh
sudo ./setup.sh
```

---

## 🛠️ Configuration

### 1. Antigravity & VS Code (`settings.json`)
Use Port `18080`:
```json
{
  "http.proxy": "http://USERNAME:PASSWORD@YOUR_VPS_IP:18080",
  "http.proxySupport": "on",
  "http.proxyStrictSSL": false
}
```

---

### 2. Browser & YouTube (ZeroOmega / SwitchyOmega)
Use Port `18443` (Encrypted HTTPS):
1. **Protocol**: `HTTPS`
2. **Server**: `YOUR_VPS_IP`
3. **Port**: `18443`
4. **Auth**: Username & Password

#### Trust Certificate in Windows (Run once in PowerShell on your PC):
```powershell
scp root@YOUR_VPS_IP:/etc/gost/proxy.crt . ; Import-Certificate -FilePath .\proxy.crt -CertStoreLocation Cert:\CurrentUser\Root
```

---

## 🗑️ Uninstallation

To cleanly wipe the proxy and reset firewall:
```bash
sudo ./uninstall.sh
```
