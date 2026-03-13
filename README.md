# WiFi Pineapple Pager — BICSI-CALA 2026 Demos

[![ShellCheck](https://github.com/jdpinedac/wifi-pineapple-pager-demo/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/jdpinedac/wifi-pineapple-pager-demo/actions/workflows/shellcheck.yml)
[![HTML Validate](https://github.com/jdpinedac/wifi-pineapple-pager-demo/actions/workflows/html-validate.yml/badge.svg)](https://github.com/jdpinedac/wifi-pineapple-pager-demo/actions/workflows/html-validate.yml)
[![Release](https://img.shields.io/github/v/release/jdpinedac/wifi-pineapple-pager-demo)](https://github.com/jdpinedac/wifi-pineapple-pager-demo/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Demos en vivo para la conferencia [BICSI-CALA 2026](https://www.bicsicala.org/) que muestran ataques Wi-Fi sobre redes AV simuladas usando el [Hak5 WiFi Pineapple Pager](https://hak5.org/products/wifi-pineapple-pager).

> **Disclaimer:** Este material es exclusivamente para fines educativos y de demostración en un entorno controlado. No utilizar contra redes sin autorización explícita.

## Demos

| Demo | Descripcion | Duración |
|---|---|---|
| [AV Evil Twin](demos/demo-av-evil-twin/) | Clona un SSID AV, desautentica clientes y sirve un portal cautivo que captura credenciales | ~60s |
| [AV DoS](demos/demo-av-dos/) | Deauth cíclico contra un stream AV — el iPad muestra congelamiento y recuperación en vivo | ~55s |

## Hardware

- **Hak5 WiFi Pineapple Pager** — ejecuta los payloads (deauth, evil twin)
- **Linksys WRT54GL** — router víctima con SSID de red AV simulada
- **Laptop Linux Mint** — servidor HTTP para dashboards (conectada por Ethernet)
- **iPad Pro** — dispositivo víctima que muestra el impacto visual

## Estructura del repositorio

```
demos/
├── demo-av-evil-twin/              # Demo 1: Evil Twin + Portal Cautivo
│   ├── payloads/
│   │   ├── 1_setup_portal/         # Setup pre-demo (requiere internet)
│   │   ├── 2_deauth_and_twin/      # Deauth + clonación SSID
│   │   └── 3_credential_alert/     # Alerta al capturar credenciales
│   ├── portal/                     # Portal cautivo (PHP)
│   └── README.md
└── demo-av-dos/                    # Demo 2: DoS de Stream AV
    ├── payloads/
    │   └── 1_av_dos_attack/        # Deauth cíclico por tiempo
    ├── stream/                     # Dashboard + servidor HTTP
    └── README.md
```

## Despliegue de payloads

Los payloads son scripts bash que se copian al Pineapple Pager via SCP:

```bash
scp payload.sh root@172.16.42.1:/mmc/root/payloads/<category>/<payload_name>/
```

Consultar el `README.md` de cada demo para rutas específicas y configuración del hardware.

## Requisitos

- WiFi Pineapple Pager con firmware actualizado
- Router Wi-Fi (WRT54GL o similar) para la red víctima
- Python 3 en la laptop (para `http.server`)
- `scp` / `ssh` para transferir payloads al Pager

## Licencia

[MIT](LICENSE)
