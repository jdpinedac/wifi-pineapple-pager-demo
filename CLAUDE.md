# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

This is a demo project for the BICSI-CALA 2026 conference, showcasing the [Hak5 WiFi Pineapple Pager](https://hak5.org/products/wifi-pineapple-pager). The demos live under `demos/` — each subdirectory is a self-contained demo with its own payloads, supporting files, and README.

## Payload Deployment

There are no build steps. Payloads are bash scripts that run **directly on the WiFi Pineapple Pager device**. To deploy a payload, copy the `payload.sh` file into the appropriate directory on the device:

```
/mmc/root/payloads/<category>/<payload_name>/payload.sh
```

## Payload Architecture

Payloads are organized into three trigger types on the device:

- **`alerts/`** — Event-triggered by the device (handshake_captured, deauth_flood_detected, pineapple_auth_captured, pineapple_client_connected)
- **`user/`** — User-initiated from the pager menu, organized by function (general, reconnaissance, remote_access, evil_portal, interception, exfiltration, games, virtual_pager, examples, prank)
- **`recon/`** — Recon context payloads (access_point, client)

Each payload lives in its own subdirectory as `payload.sh`. Supporting files (config, README, HTML, etc.) go in the same directory.

## Writing Payloads

Payloads are `#!/bin/bash` scripts mixing standard bash with **DuckyScript™ commands** (always ALL_CAPS).

### Required header format

```bash
#!/bin/bash
# Title: Example Payload
# Description: What this does
# Author: YourName
# Version: 1.0
# Category: general
```

### DuckyScript UI commands

| Command | Usage |
|---|---|
| `LOG [color] "msg"` | Log output. Colors: `red`, `green`, `blue`, `yellow` |
| `ALERT "msg"` | Push an alert notification |
| `PROMPT "msg"` | Block until any button pressed |
| `ERROR_DIALOG "msg"` | Show error dialog |
| `CONFIRMATION_DIALOG "prompt"` | Yes/No dialog — returns via `$?` or `$DUCKYSCRIPT_USER_CONFIRMED`/`$DUCKYSCRIPT_USER_DENIED` |
| `START_SPINNER "msg"` | Start spinner; captures ID for stop |
| `STOP_SPINNER $id` | Stop a running spinner |
| `WAIT_FOR_INPUT` | Block until any button; returns button name |
| `WAIT_FOR_BUTTON_PRESS UP\|DOWN\|A\|B` | Wait for specific button |
| `IP_PICKER "label" "default"` | IP address input dialog |
| `MAC_PICKER "label" "default"` | MAC address input dialog |
| `TEXT_PICKER "label" "default"` | Text input dialog |
| `NUMBER_PICKER "label" default` | Number input dialog |

### Dialog return value constants

Check `$?` or capture stdout. Use these environment variables for branching:

- `$DUCKYSCRIPT_CANCELLED` — user cancelled
- `$DUCKYSCRIPT_REJECTED` — dialog rejected
- `$DUCKYSCRIPT_ERROR` — error
- `$DUCKYSCRIPT_USER_CONFIRMED` — confirmed (yes)
- `$DUCKYSCRIPT_USER_DENIED` — denied (no)

### Alert payload variables (alerts/ category only)

Alert payloads receive context via environment variables, e.g.:
- `$_ALERT_HANDSHAKE_SUMMARY`, `$_ALERT_HANDSHAKE_AP_MAC_ADDRESS`, `$_ALERT_HANDSHAKE_PCAP_PATH`
- `$_ALERT_HANDSHAKE_TYPE` (`eapol` | `pmkid`), `$_ALERT_HANDSHAKE_CRACKABLE`

### Key device paths

- `/mmc/root/payloads/` — on-device payload root
- `/mmc/usr/bin/` — installed binaries (e.g. `sshpass`)
- `/pineapple/ui` — virtual pager web UI
- `/rom/pineapple/ui` — read-only backup of UI

## Contribution conventions

- Use `-` or `_` instead of spaces in directory/file names
- Place configurable values in named variables at the top of the payload
- Use `example.com` as a placeholder for any hosted resource URLs
- Do not hardcode API keys, passwords, or personal endpoints — use placeholder comments
- Staged code must be included in the payload directory, not linked externally
