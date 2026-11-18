# Remote HTTP Proxy (US Egress for Antigravity & VS Code)

An automated HTTP/HTTPS proxy setup designed to provide a clean US-based egress connection for apps requiring a US location—such as **Google Antigravity**, **VS Code**, and AI extension APIs—directly via `"http.proxy"`.

---

## 📍 1. DigitalOcean Droplet Preparation

### Recommended Region:
Create your droplet in **New York (`nyc3`)**. It provides US geo-location with the lowest transatlantic latency from Iran (~160–190ms).

### Check IP Reachability Before Setup:
1. Go to [check-host.net](https://check-host.net) and enter your droplet's public IP.
2. Run **Ping** and **TCP Port (22)** checks.
3. Verify that Iranian ISP nodes (MCI, Irancell, Mokhaberat, Shatel) show `OK`.
4. *If blocked*: In the DigitalOcean console, go to **Networking** > **Reserved IPs**, attach a new Reserved IP, and delete the blocked one until you get a clean IP.

---

## 🚀 2. Deploy on VPS (1-Command)

SSH into your clean Ubuntu 22.04 / 24.04 droplet as `root`:

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/remote-http-proxy.git
cd remote-http-proxy
chmod +x setup.sh uninstall.sh
sudo ./setup.sh
```

### The script will:
- Ask for a port (default: `18080`) and username (default: `devproxy`).
- Prompt for a password or auto-generate a secure random password.
- Remove destination port restrictions (`ConnectPort`), enabling arbitrary API connections.
- Automatically configure UFW firewall rules.
- Run a self-test loopback verification.
- Output your proxy URL and the exact JSON snippet for Antigravity & VS Code.

---

## ⚙️ 3. Configure Antigravity / VS Code

Open `settings.json` (`Ctrl + Shift + P` -> **Preferences: Open User Settings (JSON)**) and add:

```json
{
  "http.proxy": "http://username:password@YOUR_VPS_IP:18080",
  "http.proxySupport": "on",
  "http.proxyStrictSSL": false
}
```

---

## 🧪 4. Verify from Your Local PC (PowerShell)

Before opening your IDE, test connectivity from PowerShell:

```powershell
# 1. Test TCP reachability
Test-NetConnection -ComputerName YOUR_VPS_IP -Port 18080

# 2. Test proxy authentication and verify US IP detection
curl.exe -x "http://username:password@YOUR_VPS_IP:18080" https://ipinfo.io/json
```

Expected output:
```json
{
  "ip": "YOUR_VPS_IP",
  "city": "New York",
  "region": "New York",
  "country": "US",
  ...
}
```

---

## 💻 5. Optional Terminal & Git Config

### PowerShell Terminal Session:
```powershell
$env:HTTP_PROXY="http://username:password@YOUR_VPS_IP:18080"
$env:HTTPS_PROXY="http://username:password@YOUR_VPS_IP:18080"
```

### Git CLI:
```bash
git config --global http.proxy http://username:password@YOUR_VPS_IP:18080
git config --global https.proxy http://username:password@YOUR_VPS_IP:18080
```

---

## 🗑️ 6. Uninstallation

To cleanly purge Tinyproxy and reset firewall rules on your VPS:

```bash
sudo ./uninstall.sh
```
