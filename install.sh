#!/bin/bash
# =====================================================
# Rust Dedicated Server — Исправленный One-Click Installer
# =====================================================

set -euo pipefail

echo -e "\033[1;32m╔══════════════════════════════════════════════════════════════╗"
echo -e "║     Rust Dedicated Server — Установка в 1 клик (FIXED)       ║"
echo -e "║                  Ubuntu 22.04 / 24.04                        ║"
echo -e "╚══════════════════════════════════════════════════════════════╝\033[0m"

# ===================== ИНТЕРАКТИВНЫЕ НАСТРОЙКИ =====================
read -rp "Название сервера [Мой Rust Сервер]: " SERVER_NAME < /dev/tty
SERVER_NAME=${SERVER_NAME:-"Мой Rust Сервер"}

read -rp "RCON пароль (Enter = сгенерировать): " RCON_PASSWORD < /dev/tty
if [[ -z "$RCON_PASSWORD" ]]; then
    RCON_PASSWORD=$(openssl rand -hex 16)
    echo -e "\033[1;33m✅ Сгенерирован RCON-пароль: $RCON_PASSWORD\033[0m (сохрани его!)"
fi

read -rp "Seed карты (Enter = случайный): " SERVER_SEED < /dev/tty
if [[ -z "$SERVER_SEED" ]]; then
    SERVER_SEED=$((RANDOM * RANDOM % 2147483647))
    echo -e "\033[1;33m✅ Сгенерирован seed: $SERVER_SEED\033[0m"
fi

read -rp "Размер мира [4000]: " WORLD_SIZE < /dev/tty
WORLD_SIZE=${WORLD_SIZE:-4000}

read -rp "Максимум игроков [100]: " MAX_PLAYERS < /dev/tty
MAX_PLAYERS=${MAX_PLAYERS:-100}

echo -e "\n\033[1;34mНачинаем установку...\033[0m"

# ===================== ЗАВИСИМОСТИ =====================
echo "→ Обновление системы и установка пакетов..."
sudo apt update && sudo apt full-upgrade -y
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y steamcmd lib32gcc-s1 lib32stdc++6 curl wget htop jq net-tools cron ufw openssl screen

# ===================== rcon-cli (исправленное скачивание) =====================
echo "→ Установка rcon-cli..."
# Пробуем скачать напрямую, если не выйдет (таймаут 10 сек) - качаем через зеркало
if ! wget --timeout=10 --tries=2 https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz -O /tmp/rcon.tar.gz; then
    echo -e "\033[1;33m⚠️ Ошибка прямого скачивания. Пробуем через зеркало ghproxy...\033[0m"
    wget --timeout=15 --tries=3 https://ghproxy.net/https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-amd64_linux.tar.gz -O /tmp/rcon.tar.gz
fi

sudo tar -xzf /tmp/rcon.tar.gz -C /usr/local/bin --strip-components=1
sudo chmod +x /usr/local/bin/rcon
rm -f /tmp/rcon.tar.gz
echo "✅ rcon-cli установлен!"

# ===================== УСТАНОВКА СЕРВЕРА =====================
mkdir -p ~/rustserver/{logs,scripts,backups}
cd ~/rustserver

echo "→ Скачивание Rust Dedicated Server (2–5 минут)..."
steamcmd +login anonymous +force_install_dir ~/rustserver +app_update 258550 validate +quit

# ===================== config.env =====================
cat > config.env << EOF
SERVER_NAME="$SERVER_NAME"
RCON_PASSWORD="$RCON_PASSWORD"
SERVER_SEED=$SERVER_SEED
WORLD_SIZE=$WORLD_SIZE
MAX_PLAYERS=$MAX_PLAYERS
SERVER_IDENTITY="main"
TICKRATE=30
SAVE_INTERVAL=300
PUBLIC_IP=\$(curl -s ifconfig.me || echo "0.0.0.0")
EOF

# ===================== start.sh =====================
cat > start.sh << 'EOL'
#!/bin/bash
set -euo pipefail
source config.env

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d_%H-%M-%S).log"
ln -sf "$(basename "$LOG_FILE")" "$LOG_DIR/latest.log"

# Steam SDK fix
mkdir -p ~/.steam/sdk64
ln -sf ~/.steam/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so 2>/dev/null || true
export LD_LIBRARY_PATH="$HOME/.steam/sdk64:${LD_LIBRARY_PATH:-}"
export SteamAppId=252490

echo "[$(date '+%H:%M:%S')] Запуск сервера: $SERVER_NAME" | tee -a "$LOG_FILE"

exec "$BASE_DIR/RustDedicated" -batchmode -nographics -logFile "$LOG_FILE" \
    +server.ip 0.0.0.0 +server.port 28015 \
    +server.queryport 28017 \
    +rcon.ip 0.0.0.0 +rcon.port 28016 +rcon.password "$RCON_PASSWORD" +rcon.web 1 \
    +server.hostname "$SERVER_NAME" +server.identity "$SERVER_IDENTITY" \
    +server.seed $SERVER_SEED +server.level "Procedural Map" \
    +server.worldsize $WORLD_SIZE +server.maxplayers $MAX_PLAYERS \
    +server.tickrate $TICKRATE +server.saveinterval $SAVE_INTERVAL \
    +app.publicip $PUBLIC_IP 2>&1 | tee -a "$LOG_FILE"
EOL
chmod +x start.sh

# ===================== СКРИПТЫ УПРАВЛЕНИЯ =====================
mkdir -p scripts

cat > scripts/update.sh << 'EOL'
#!/bin/bash
echo -e "\033[1;33m=== ОБНОВЛЕНИЕ СЕРВЕРА ===\033[0m"
sudo systemctl stop rustserver
cd ~/rustserver && steamcmd +login anonymous +force_install_dir ~/rustserver +app_update 258550 validate +quit
sudo systemctl start rustserver
echo "Обновление завершено!"
EOL

cat > scripts/wipe.sh << 'EOL'
#!/bin/bash
read -p "ВНИМАНИЕ! Полный вайп сервера? (y/N): " confirm < /dev/tty
if [[ $confirm =~ ^[Yy]$ ]]; then
    sudo systemctl stop rustserver
    tar -czf ~/rustserver/backups/backup_$(date +%Y%m%d_%H%M).tar.gz server/main/ 2>/dev/null || true
    rm -rf server/main/*
    NEW_SEED=$((RANDOM * RANDOM % 2147483647))
    sed -i "s/SERVER_SEED=.*/SERVER_SEED=$NEW_SEED/" config.env
    echo "Новый seed: $NEW_SEED"
    sudo systemctl start rustserver
    echo "Вайп завершён!"
fi
EOL

cat > scripts/rcon.sh << 'EOL'
#!/bin/bash
source ~/rustserver/config.env
rcon -a 127.0.0.1:28016 -p "$RCON_PASSWORD" "$@"
EOL

cat > scripts/scheduled_restart.sh << 'EOL'
#!/bin/bash
source ~/rustserver/config.env
rcon -a 127.0.0.1:28016 -p "$RCON_PASSWORD" "say 🔴 Перезагрузка сервера через 10 минут!"
sleep 600
sudo systemctl restart rustserver
EOL

chmod +x scripts/*.sh

# ===================== SYSTEMD + ФАЙРВОЛ =====================
sudo tee /etc/systemd/system/rustserver.service > /dev/null << EOF
[Unit]
Description=Rust Dedicated Server
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$HOME/rustserver
ExecStart=$HOME/rustserver/start.sh
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

sudo ufw allow 28015/udp
sudo ufw allow 28016/tcp
sudo ufw allow 28017/udp
sudo ufw allow 28082/tcp
sudo ufw --force enable 2>/dev/null || true

sudo systemctl daemon-reload
sudo systemctl enable --now rustserver

# ===================== ФИНАЛ =====================
echo -e "\n\033[1;32m╔══════════════════════════════════════════════════════════════╗"
echo -e "║               УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                   ║"
echo -e "╚══════════════════════════════════════════════════════════════╝\033[0m"
echo "Название: $SERVER_NAME"
echo "RCON:     $RCON_PASSWORD"
echo "Seed:     $SERVER_SEED"
echo ""
echo "Управление:"
echo "  systemctl status rustserver"
echo "  ~/rustserver/scripts/update.sh       # обновить"
echo "  ~/rustserver/scripts/wipe.sh         # вайп"
echo "  ~/rustserver/scripts/rcon.sh say Привет!"
echo "  tail -f ~/rustserver/logs/latest.log # логи"