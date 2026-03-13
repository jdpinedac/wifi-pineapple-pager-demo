#!/bin/bash
# Lanza servidor HTTP para el dashboard AV en el iPad
# Ejecutar desde la laptop conectada por Ethernet al WRT54GL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8080

# Obtener IP local
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="<tu-ip>"
fi

echo ""
echo "=== AV System Monitor — Servidor ==="
echo ""
echo "  Sirviendo desde: $SCRIPT_DIR"
echo "  Puerto: $PORT"
echo ""
echo "  Abrir en el iPad:"
echo "    http://${LOCAL_IP}:${PORT}/dashboard.html"
echo ""
echo "  Ctrl+C para detener"
echo ""

cd "$SCRIPT_DIR"
python3 -m http.server "$PORT" --bind 0.0.0.0
