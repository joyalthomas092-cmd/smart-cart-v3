#!/bin/bash
# SmartCart v3 — Pi 5 Kiosk Setup (X11 + LXDE/Openbox, surf kiosk shell)
set -e

echo "╔══════════════════════════════════════╗"
echo "║   SmartCart v3.0 — Pi Setup          ║"
echo "║   FastAPI + HTMX + SSE + surf kiosk  ║"
echo "╚══════════════════════════════════════╝"

cd "$(dirname "$0")"
PROJECT_DIR=$(pwd)
USER_NAME=$(whoami)

# 1. System packages — surf is the suckless WebKit X11 kiosk browser. No Chromium.
echo "[1/7] Installing system packages..."
sudo apt update
sudo apt install -y curl python3-venv unclutter surf

# 2. uv (fast Python package manager)
echo "[2/7] Installing uv..."
if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# 3. Python deps
echo "[3/7] Installing Python dependencies via uv..."
uv sync

# 4. Vendor HTMX + SSE extension locally
echo "[4/7] Vendoring HTMX..."
mkdir -p static/js
[ -f static/js/htmx.min.js ]        || curl -fsSL https://unpkg.com/htmx.org@2.0.3/dist/htmx.min.js -o static/js/htmx.min.js
[ -f static/js/sse.js ]             || curl -fsSL https://unpkg.com/htmx-ext-sse@2.2.2/sse.js -o static/js/sse.js
[ -f static/js/simple-keyboard.js ] || curl -fsSL https://cdn.jsdelivr.net/npm/simple-keyboard@latest/build/index.js -o static/js/simple-keyboard.js
[ -f static/css/simple-keyboard.css ] || curl -fsSL https://cdn.jsdelivr.net/npm/simple-keyboard@latest/build/css/index.css -o static/css/simple-keyboard.css

# 5. systemd service for the FastAPI server (port 8001 to coexist with ElectroMart on 8000)
echo "[5/7] Setting up systemd service..."
sudo tee /etc/systemd/system/smartcart.service > /dev/null <<EOF
[Unit]
Description=SmartCart v3 FastAPI Server
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$PROJECT_DIR
ExecStart=$HOME/.local/bin/uv run uvicorn app.main:app --host 127.0.0.1 --port 8001
Restart=always
RestartSec=3
MemoryMax=384M
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable smartcart
sudo systemctl restart smartcart

# 6. Kiosk launcher script + XDG autostart entry + Desktop icon
echo "[6/7] Configuring kiosk launcher and autostart..."
cat > "$PROJECT_DIR/launch_kiosk.sh" <<'EOF'
#!/bin/bash
# SmartCart kiosk launcher — wait for server, then surf fullscreen
URL="http://127.0.0.1:8001"

for _ in $(seq 1 60); do
    curl -sf -o /dev/null "$URL/login" && break
    sleep 0.5
done

exec surf -F "$URL"
EOF
chmod +x "$PROJECT_DIR/launch_kiosk.sh"

mkdir -p ~/.config/autostart
cat > ~/.config/autostart/smartcart.desktop <<EOF
[Desktop Entry]
Type=Application
Name=SmartCart Kiosk
Comment=Auto-launch SmartCart in fullscreen surf
Exec=$PROJECT_DIR/launch_kiosk.sh
X-GNOME-Autostart-enabled=true
Terminal=false
EOF

mkdir -p ~/Desktop
cat > ~/Desktop/SmartCart.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=SmartCart v3
Comment=Launch SmartCart kiosk
Exec=$PROJECT_DIR/launch_kiosk.sh
Icon=applications-internet
Terminal=false
Type=Application
Categories=Utility;Application;
EOF
chmod +x ~/Desktop/SmartCart.desktop

# 7. Openbox keybindings — Ctrl+Alt+Q kills surf, Ctrl+Alt+S relaunches
echo "[7/7] Adding Openbox keybindings..."
mkdir -p ~/.config/openbox
[ -f ~/.config/openbox/rpd-rc.xml ] || cp /etc/xdg/openbox/rpd-rc.xml ~/.config/openbox/rpd-rc.xml

if ! grep -q 'pkill -x surf' ~/.config/openbox/rpd-rc.xml; then
    python3 - <<PY
import re
p = "/home/$USER_NAME/.config/openbox/rpd-rc.xml"
s = open(p).read()
inject = '''    <!-- SmartCart panic-close: Ctrl+Alt+Q kills surf -->
    <keybind key="C-A-q">
      <action name="Execute"><command>pkill -x surf</command></action>
    </keybind>
    <!-- SmartCart relaunch: Ctrl+Alt+S reopens the kiosk -->
    <keybind key="C-A-s">
      <action name="Execute"><command>$PROJECT_DIR/launch_kiosk.sh</command></action>
    </keybind>
'''
s = re.sub(r'(<chainQuitKey>[^<]*</chainQuitKey>\s*\n)', r'\1' + inject, s, count=1)
open(p, 'w').write(s)
PY
fi

openbox --reconfigure 2>/dev/null || true

echo ""
echo "✅ Setup complete."
echo ""
echo "   Server:     http://127.0.0.1:8001  (smartcart.service, auto-starts at boot)"
echo "   Kiosk:      surf -F http://127.0.0.1:8001  (auto-launches at login)"
echo "   Manual:     ~/smart-cart-v3/launch_kiosk.sh  or double-click Desktop icon"
echo "   Login:      admin / 1234"
echo ""
echo "   Keybindings (Openbox):"
echo "     Ctrl+Alt+Q   close kiosk (test mode)"
echo "     Ctrl+Alt+S   relaunch kiosk"
echo "     Ctrl+Q       (built-in surf shortcut, also closes the window)"
echo ""
echo "   Reboot to enter kiosk mode:  sudo reboot"
