#!/bin/bash
# ============================================================
# OpenClaw WSL 服务安装脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 支持 systemd、init.d 和 .bashrc 三种启动方式
# ============================================================

echo ""
echo "============================================================"
echo "  OpenClaw WSL 服务配置"
echo "============================================================"
echo ""

# 0. 检查 WSL 环境
echo "[检查] 环境..."
if [ ! -f /etc/wsl.conf ]; then
    echo "[错误] 此脚本必须在 WSL 内部运行"
    exit 1
fi

# 检查 OpenClaw 是否已安装
if ! command -v openclaw &> /dev/null; then
    echo "[错误] openclaw 命令未找到"
    echo "[提示] 请先运行：bash post-install-auto.sh"
    exit 1
fi
echo "[√] OpenClaw 已安装"

# 获取配置
NPM_GLOBAL_BIN=$(npm config get prefix)/bin
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
LOG_DIR="/var/log/openclaw"

echo "[√] npm 路径：$NPM_GLOBAL_BIN"
echo ""

# 1. 检查 systemd 是否可用
echo "[1/3] 检查启动方式..."
SYSTEMD_AVAILABLE=false
if [ -d /run/systemd/system ]; then
    SYSTEMD_AVAILABLE=true
    echo "[√] systemd 可用 - 将使用 systemd 服务"
else
    echo "[信息] systemd 不可用"

    # 检查是否可以通过配置启用 systemd
    if [ ! -f /etc/wsl.conf ] || ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
        echo "[信息] WSL 未启用 systemd"
        echo ""
        read -p "是否配置 WSL 启用 systemd？(Y/N): " ENABLE_SYSTEMD
        if [ "$ENABLE_SYSTEMD" = "Y" ] || [ "$ENABLE_SYSTEMD" = "y" ]; then
            echo "[boot]" | sudo tee -a /etc/wsl.conf > /dev/null
            echo "systemd=true" | sudo tee -a /etc/wsl.conf > /dev/null
            echo "[√] 已配置 systemd"
            echo ""
            echo "[重要] 请重启 WSL 后重新运行此脚本："
            echo "  1. 在 Windows PowerShell (管理员) 运行：wsl --shutdown"
            echo "  2. 重新启动 Ubuntu"
            echo "  3. 重新运行：bash install-openclaw-service.sh"
            echo ""
            exit 0
        fi
    fi

    echo "[信息] 将使用 .bashrc 方式启动"
fi
echo ""

# 2. 创建日志目录和启动脚本
echo "[2/3] 创建启动脚本..."
sudo mkdir -p "$LOG_DIR"
sudo chown "$(whoami)": "$(whoami)" "$LOG_DIR"

STARTUP_SCRIPT="$CONFIG_DIR/startup.sh"
cat > "$STARTUP_SCRIPT" << 'STARTUP_EOF'
#!/bin/bash
# OpenClaw 启动脚本

# 设置 PATH - 确保能找到 openclaw 命令
export PATH="$HOME/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export NODE_ENV=production
export HOME="$HOME"

# 切换到用户目录
cd "$HOME"

# 检查是否已有进程运行
if pgrep -f "openclaw gateway" > /dev/null; then
    echo "OpenClaw 已在运行"
    exit 0
fi

# 启动 OpenClaw Gateway
echo "启动 OpenClaw Gateway..."
nohup openclaw gateway --allow-unconfigured >> /var/log/openclaw/openclaw.log 2>&1 &
OPENCLAW_PID=$!
echo $OPENCLAW_PID > /run/openclaw.pid
echo "OpenClaw 已启动 (PID: $OPENCLAW_PID)"
STARTUP_EOF

chmod +x "$STARTUP_SCRIPT"
echo "[√] 启动脚本：$STARTUP_SCRIPT"
echo ""

# 3. 配置启动方式
echo "[3/3] 配置自动启动..."

if [ "$SYSTEMD_AVAILABLE" = true ]; then
    # systemd 方式
    echo "[模式] systemd 服务"

    SERVICE_FILE="/etc/systemd/system/openclaw.service"

    # 创建 systemd 服务文件
    # 使用 Type=simple 直接运行 openclaw 命令，这样 systemd 能正确跟踪进程
    sudo cat > "$SERVICE_FILE" << EOF
[Unit]
Description=OpenClaw Gateway Service
Documentation=https://docs.openclaw.ai
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$HOME
ExecStart=$NPM_GLOBAL_BIN/openclaw gateway --allow-unconfigured
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

Environment="PATH=$NPM_GLOBAL_BIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="NODE_ENV=production"
Environment="HOME=$HOME"

LimitNOFILE=65536
Nice=5

[Install]
WantedBy=multi-user.target
EOF

    # 启用服务
    echo "[信息] 重新加载 systemd 配置..."
    sudo systemctl daemon-reload
    echo "[信息] 启用 openclaw 服务..."
    sudo systemctl enable openclaw.service
    echo "[信息] 启动 openclaw 服务..."
    sudo systemctl start openclaw.service

    echo "[√] systemd 服务已创建"
    echo "[√] 服务已启用"

    # 检查状态
    sleep 5
    SERVICE_STATUS=$(sudo systemctl is-active openclaw.service 2>/dev/null || echo "unknown")
    echo "[信息] 服务状态：$SERVICE_STATUS"

    if [ "$SERVICE_STATUS" != "active" ]; then
        echo "[警告] 服务未正常启动，查看日志："
        sudo journalctl -u openclaw.service --no-pager -n 20
    fi

else
    # .bashrc 方式
    echo "[模式] .bashrc 自启动"

    # 检查是否已配置
    if grep -q "openclaw.*startup" ~/.bashrc 2>/dev/null; then
        echo "[√] .bashrc 中已有 OpenClaw 配置"
    else
        # 添加到 .bashrc
        cat >> ~/.bashrc << 'BASHRC_EOF'

# OpenClaw 自动启动
if [ -f "$HOME/.openclaw/startup.sh" ]; then
    # 延迟启动，避免阻塞 shell
    (sleep 2 && bash "$HOME/.openclaw/startup.sh" &) >/dev/null 2>&1 &
fi
BASHRC_EOF
        echo "[√] 已添加到 .bashrc"
    fi

    # 同时配置 init.d（如果可用）
    if [ -d /etc/init.d ]; then
        INIT_SCRIPT="/etc/init.d/openclaw"
        sudo cat > "$INIT_SCRIPT" << INIT_EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          openclaw
# Required-Start:    \$remote_fs \$syslog \$network
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: OpenClaw Gateway Service
# Description:       OpenClaw Gateway Service
### END INIT INFO

case "\$1" in
    start)
        su - $USER -c "bash $STARTUP_SCRIPT"
        ;;
    stop)
        pkill -f "openclaw gateway" || true
        ;;
    restart)
        \$0 stop
        sleep 2
        \$0 start
        ;;
    status)
        if pgrep -f "openclaw gateway" > /dev/null; then
            echo "OpenClaw is running"
        else
            echo "OpenClaw is not running"
        fi
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
exit 0
INIT_EOF

        sudo chmod +x "$INIT_SCRIPT"

        # 尝试启用 init.d 服务
        if command -v update-rc.d &> /dev/null; then
            sudo update-rc.d openclaw defaults 2>/dev/null && echo "[√] init.d 服务已启用" || echo "[信息] init.d 配置跳过"
        fi
    fi

    echo "[√] .bashrc 自启动已配置"
fi

echo ""

# 启动服务
echo "[启动] 启动 OpenClaw 服务..."
if [ "$SYSTEMD_AVAILABLE" = true ]; then
    # systemd 模式下由 systemctl 管理服务
    sudo systemctl restart openclaw.service
    sleep 5
else
    # 手动启动
    pkill -f "openclaw gateway" 2>/dev/null || true
    sleep 2
    bash "$STARTUP_SCRIPT"
    sleep 5
fi

# 验证
echo ""
echo "[验证] 检查服务状态..."
if pgrep -f "openclaw gateway" > /dev/null; then
    echo "[√] OpenClaw 服务正在运行"
    ss -tlnp | grep 18789 && echo "[√] 端口 18789 正在监听"
else
    echo "[警告] OpenClaw 服务未运行"
    echo "[提示] 查看日志：tail -f /var/log/openclaw/openclaw.log"
fi
echo ""

# 完成
echo "============================================================"
echo "  服务配置完成！"
echo "============================================================"
echo ""
echo "[启动方式]"
if [ "$SYSTEMD_AVAILABLE" = true ]; then
    echo "- systemd 服务"
    echo ""
    echo "[常用命令]"
    echo "- sudo systemctl status openclaw   # 查看状态"
    echo "- sudo systemctl start openclaw    # 启动"
    echo "- sudo systemctl stop openclaw     # 停止"
    echo "- sudo systemctl restart openclaw  # 重启"
    echo "- sudo journalctl -u openclaw -f   # 查看日志"
else
    echo "- .bashrc 自启动（登录 shell 时启动）"
    echo "- init.d 脚本（如果支持）"
    echo ""
    echo "[常用命令]"
    echo "- bash ~/.openclaw/startup.sh      # 手动启动"
    echo "- pkill -f 'openclaw gateway'      # 停止"
    echo "- pgrep -f 'openclaw gateway'      # 检查状态"
    echo "- tail -f /var/log/openclaw/openclaw.log"
fi
echo ""
echo "[日志]"
echo "- 日志文件：/var/log/openclaw/openclaw.log"
echo ""
echo "[注意]"
if [ "$SYSTEMD_AVAILABLE" != true ]; then
    echo "- 当前 WSL 未启用 systemd，使用 .bashrc 方式启动"
    echo "- 需要登录 WSL 才会自动启动服务"
    echo "- 如需开机自动启动，请在 Windows 配置任务计划程序"
fi
echo ""

read -p "按回车键退出"
