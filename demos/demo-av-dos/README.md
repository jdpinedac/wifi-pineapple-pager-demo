# Demo AV DoS — BICSI-CALA 2026

Demo en vivo (~55 segundos) mostrando **Denegación de Servicio a un flujo de audio/video** usando el WiFi Pineapple Pager. El Pager ejecuta deauth cíclico (on/off) contra una red AV simulada. El iPad muestra un dashboard "AV System Monitor" que se congela y recupera dramáticamente con cada ciclo.

## Estructura

```
docs/demo-av-dos/
├── payloads/
│   └── 1_av_dos_attack/
│       └── payload.sh              ← Payload principal (recon/access_point)
├── stream/
│   ├── dashboard.html              ← Dashboard "AV System Monitor" (self-contained)
│   └── start_server.sh             ← Lanza Python3 HTTP server en laptop
└── README.md
```

## Ruta on-device (SD card del Pager)

```
/mmc/root/payloads/recon/access_point/av_dos_attack/    → payload 1
```

## Hardware Setup (WRT54GL)

| Parámetro | Valor |
|---|---|
| SSID | `AV-Stream` |
| Canal | 11 (evita conflicto con canal 6 de demo 1) |
| Seguridad | WPA2-PSK (`avstream2026`) |
| DHCP | Habilitado, rango `192.168.1.100–150` |
| Laptop | Conectado al WRT54GL vía **Ethernet** (puerto LAN) |
| iPad | Conectado al WiFi `AV-Stream`, Safari abierto en dashboard URL |

> **NOTA CRÍTICA:** La laptop DEBE conectarse por **Ethernet**, no por WiFi. El deauth broadcast desconectaría también al laptop si estuviera en WiFi, matando el servidor HTTP y el dashboard.

> **¿Por qué WPA2?** Usar WPA2 (no red abierta) es deliberado — demuestra que el cifrado WPA2 **no protege contra deauth** porque los management frames 802.11 no están cifrados. Solo WPA3 con Protected Management Frames (PMF/802.11w) mitiga este ataque.

## Secuencia de ejecución

| Paso | Acción | Lo que se ve |
|---|---|---|
| 0 | Laptop: ejecutar `start_server.sh` | Terminal muestra URL del dashboard |
| 1 | iPad: abrir `http://<laptop-ip>:8080/dashboard.html` en Safari | Dashboard con barras SMPTE, estado CONECTADO |
| 2 | Pager: Recon muestra `AV-Stream` → seleccionar → ejecutar payload | Pager muestra info del AP target |
| 3 | Confirmar ataque en el diálogo | LED rojo, deauth comienza |
| 4 | ~2-3s | iPad pierde WiFi → dashboard muestra **SEÑAL PERDIDA** con estática |
| 5 | 10s después | LED verde → deauth se detiene → ciclo de recuperación |
| 6 | ~3-5s | iPad reconecta WiFi → dashboard muestra flash **CONECTADO** |
| 7 | Se repiten ciclos 2 y 3 | Audiencia ve el patrón on/off en vivo |
| 8 | Fin del último ciclo | LED blanco → ALERT en Pager con resumen |

## Timeline (~55s)

```
t=0s      Confirmar ataque en Pager
t=0s      LED ROJO → Ciclo 1 ATAQUE (deauth sostenido)
t=2-3s    iPad pierde WiFi → dashboard muestra "SEÑAL PERDIDA"
t=10s     LED VERDE → Ciclo 1 RECUPERACIÓN
t=12-15s  iPad reconecta → dashboard muestra "CONECTADO"
t=20s     LED ROJO → Ciclo 2 ATAQUE
t=30s     LED VERDE → Ciclo 2 RECUPERACIÓN
t=40s     LED ROJO → Ciclo 3 ATAQUE (último)
t=50s     LED BLANCO → Demo completado, ALERT con resumen
```

## Checklist Pre-Demo

- [ ] Configurar WRT54GL: SSID `AV-Stream`, canal 11, WPA2-PSK `avstream2026`
- [ ] Conectar laptop al WRT54GL por **Ethernet** (puerto LAN)
- [ ] Ejecutar `start_server.sh` en la laptop
- [ ] Verificar dashboard en browser local: barras SMPTE animadas, métricas funcionando
- [ ] Conectar iPad al WiFi `AV-Stream`
- [ ] Abrir `http://<laptop-ip>:8080/dashboard.html` en Safari del iPad
- [ ] Verificar que dashboard muestra "CONECTADO" en el iPad
- [ ] Copiar payload al Pager: `scp payload.sh root@172.16.42.1:/mmc/root/payloads/recon/access_point/av_dos_attack/`
- [ ] Test rápido: toggle Airplane Mode en iPad → verificar overlay aparece en <2s

## Plan B

Si el iPad no reconecta durante la ventana de recuperación:

1. **Aumentar RECOVERY_DURATION:** Editar `payload.sh` y cambiar `RECOVERY_DURATION=10` a `15` o `20`.
2. **Reconexión manual:** En el iPad, ir a Settings → Wi-Fi y tocar `AV-Stream`.
3. **Dashboard no responde:** Recargar la página en Safari (pull-down to refresh).
4. **Servidor caído:** Verificar que la laptop sigue conectada por Ethernet, reiniciar `start_server.sh`.

## Calibración

- Si el iPad tarda >10s en reconectar, aumentar `RECOVERY_DURATION` a 15s
- Si el deauth no es efectivo, aumentar `BURST_COUNT` a 50 o reducir `BURST_INTERVAL` a 0.05
- Si los ciclos son muy rápidos para la audiencia, aumentar `ATTACK_DURATION` a 15s

## Cleanup Post-Demo

Mínimo — solo detener el servidor:

```bash
# En la laptop: Ctrl+C en la terminal de start_server.sh
```

No hay estado persistente que limpiar. El payload no modifica configuración del Pager ni del router.

## Notas técnicas

- El **deauth es broadcast** (`FF:FF:FF:FF:FF:FF`) — desconecta a todos los clientes del AP, no requiere conocer MACs individuales.
- El dashboard detecta pérdida de conexión haciendo `fetch()` cada 500ms al servidor HTTP en la laptop. Cuando el iPad pierde WiFi, el fetch falla con TypeError → 2 fallos consecutivos (1s) → overlay "SEÑAL PERDIDA".
- La diferencia con el demo Evil Twin: aquí el deauth es **sostenido por tiempo** (no por conteo fijo), impidiendo que el iPad reconecte durante la ventana de ataque. El efecto visual es dramático: congelamiento total → recuperación → congelamiento.
- Las barras SMPTE en el canvas son un test pattern broadcast clásico — refuerzan la narrativa AV del demo.
- El archivo `dashboard.html` es completamente autocontenido (sin dependencias externas), compatible con Safari en iPad.
