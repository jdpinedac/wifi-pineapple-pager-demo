# Demo AV Evil Twin — BICSI-CALA 2026

Demo en vivo (~60 segundos) mostrando **Evil Twin + Portal Cautivo** sobre una red AV simulada. El Pager desautentica a la víctima, activa un Evil Twin con el mismo SSID, y sirve un portal que imita un login de sistema AV (Crestron DM-NVX). Las credenciales capturadas aparecen en pantalla.

## Estructura

```
docs/demo-av-evil-twin/
├── portal/
│   └── index.php                      ← Portal AV (login form + credential capture)
├── payloads/
│   ├── 1_setup_portal/
│   │   ├── payload.sh                 ← Pre-charla setup (requiere internet)
│   │   └── whitelist_monitor.sh       ← Monitor de whitelist IP
│   ├── 2_deauth_and_twin/
│   │   └── payload.sh                 ← Deauth + Evil Twin (recon/access_point)
│   └── 3_credential_alert/
│       └── payload.sh                 ← Alerta al conectar víctima (pineapple_client_connected)
└── README.md
```

## Rutas on-device (SD card del Pager)

```
/mmc/root/payloads/user/interception/av_demo_setup/    → payload 1
/mmc/root/payloads/recon/access_point/av_evil_twin/    → payload 2
/mmc/root/payloads/alerts/pineapple_client_connected/av_credential_alert/ → payload 3
```

## Hardware Setup (WRT54GL)

| Parámetro | Valor |
|---|---|
| SSID | `AV-Control` |
| Canal | 6 (fijo) |
| Seguridad | Ninguna (red abierta) |
| DHCP | Habilitado, rango `192.168.1.100–150` |
| Ubicación | Lejos del escenario (señal débil) |

**Dispositivo víctima:** tablet/laptop con Auto-Join ON y MAC randomization OFF, pre-conectado a `AV-Control`.

## Secuencia de ejecución

| Paso | Acción | Lo que se ve |
|---|---|---|
| 0 | Recon muestra `AV-Control` con 1 cliente | AP visible en pantalla |
| 1 | Seleccionar `AV-Control` → ejecutar payload 2 | Pager muestra info del objetivo |
| 2 | Confirmar en el diálogo | LED rojo, deauth en progreso |
| 3 | ~10 segundos | Tablet víctima pierde conexión |
| 4 | Auto | Tablet reconecta al Evil Twin del Pager |
| 5 | Auto | Browser muestra portal "AV Control Network Login" |
| 6 | Voluntario ingresa usuario/contraseña | Spinner "Verificando credenciales..." |
| 7 | Auto (alert payload) | Pager vibra, LED verde, ALERT con credenciales |

## Checklist Pre-Demo

- [ ] Correr `1_setup_portal/payload.sh` (con internet activo en el Pager)
- [ ] Verificar portal en `http://172.16.52.1/` desde dispositivo de prueba
- [ ] Hacer submit de prueba → confirmar escritura en credentials.log
- [ ] Limpiar estado de demo anterior:
  ```bash
  echo -n > /root/loot/av_demo/credentials.log
  rm -f /tmp/av_demo_whitelist.txt /tmp/av_demo_processed.txt
  ```
- [ ] Configurar WRT54GL: SSID `AV-Control`, canal 6, abierto
- [ ] Conectar víctima al WRT54GL, desactivar MAC randomization
- [ ] Cargar `3_credential_alert` en slot `pineapple_client_connected`
- [ ] Desconectar Pager de internet (modo cliente OFF)

## Plan B (si la víctima no reconecta)

Si el timeout de 120s se cumple sin credenciales:

1. **Reconexión manual:** En la tablet víctima, ir a Settings → Wi-Fi y seleccionar `AV-Control` manualmente.
2. **Portal no aparece:** Abrir el browser y navegar a `http://neverssl.com` o cualquier sitio HTTP — el DNS hijack redirigirá al portal.
3. **Mostrar resultado manualmente:** Si el voluntario ya ingresó credenciales pero el payload no las mostró, verificar directamente:
   ```bash
   cat /root/loot/av_demo/credentials.log
   ```

## Cleanup Post-Demo

Ejecutar desde SSH o terminal del Pager para restaurar estado limpio:

```bash
# Detener procesos de la demo
[ -f /tmp/av_demo-dns.pid ] && kill "$(cat /tmp/av_demo-dns.pid)" 2>/dev/null
[ -f /tmp/av_demo-whitelist.pid ] && kill "$(cat /tmp/av_demo-whitelist.pid)" 2>/dev/null

# Restaurar nginx config original
[ -f /etc/nginx/nginx.conf.av_demo.bak ] && cp /etc/nginx/nginx.conf.av_demo.bak /etc/nginx/nginx.conf
/etc/init.d/nginx restart 2>/dev/null

# Eliminar reglas de firewall AVDemo
while uci show firewall 2>/dev/null | grep -q "AVDemo"; do
    idx=$(uci show firewall | grep "AVDemo" | head -1 | sed "s/.*\[\([0-9]*\)\].*/\1/")
    uci delete "firewall.@redirect[$idx]" 2>/dev/null || break
done
uci commit firewall
/etc/init.d/firewall restart

# Restaurar IPv6
sysctl -w net.ipv6.conf.br-lan.disable_ipv6=0 2>/dev/null

# Limpiar archivos temporales
rm -f /tmp/av_demo_whitelist.txt /tmp/av_demo_processed.txt
rm -f /tmp/av_demo-dns.pid /tmp/av_demo-whitelist.pid
```

## Notas técnicas

- El **deauth es broadcast** (`FF:FF:FF:FF:FF:FF`) para no depender del MAC del cliente (que podría estar randomizado).
- El portal **no requiere romper handshake** — la red AV-Control es abierta, el ataque es puramente social.
- El `whitelist_monitor.sh` aplica reglas `nftables` en memoria para dar internet al cliente tras capturar credenciales.
- Las credenciales se almacenan en `/root/loot/av_demo/credentials.log`. El monitor crea backups timestamped en el mismo directorio sin truncar el archivo original (los payloads 2 y 3 dependen de este archivo para detectar credenciales).
- El payload 3 (`credential_alert`) filtra por SSID `AV-Control` para evitar falsos positivos con otros clientes conectados al Pineapple.
- Tras el submit del portal, la víctima es redirigida a `google.com` una vez que el whitelist monitor habilita su acceso a internet.
