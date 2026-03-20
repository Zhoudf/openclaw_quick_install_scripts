#!/bin/bash
# ============================================================
# OpenClaw 重启脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash restart-openclaw.sh
#
# 此脚本用于重启 OpenClaw Gateway 服务
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 重启脚本"
echo "============================================================"
echo ""

# 1. 停止现有服务
echo "[1/4] 停止现有服务..."
# 使用更精确的匹配，只杀死 gateway 进程，避免杀死脚本本身
pkill -f "openclaw gateway" 2>/dev/null && echo "[√] 已停止 OpenClaw Gateway 进程" || echo "[提示] 没有找到运行中的 Gateway 进程"
sleep 2

# 检查是否还有其他 openclaw 相关进程（排除脚本本身）
OTHER_PROCS=$(pgrep -a "openclaw" 2>/dev/null | grep -v "restart-openclaw.sh" | grep -v "post-install-auto.sh" || echo "")
if [ -n "$OTHER_PROCS" ]; then
    echo "[提示] 发现其他 OpenClaw 进程，正在停止..."
    pgrep -f "openclaw" 2>/dev/null | while read pid; do
        FULL_CMD=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
        # 排除脚本本身
        if ! echo "$FULL_CMD" | grep -q "restart-openclaw.sh\|post-install-auto.sh\|update-openclaw.sh"; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    sleep 2
fi

# 2. 检查配置文件
echo "[2/4] 检查配置文件..."
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[×] 配置文件不存在：$CONFIG_FILE"
    echo "[提示] 请先运行 post-install-auto.sh 进行初始化配置"
    exit 1
fi

echo "[√] 配置文件存在：$CONFIG_FILE"

# 读取 Token
TOKEN=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')
echo "[信息] Gateway Token: $TOKEN"

# 3. 启动 Gateway 服务
echo "[3/4] 启动 Gateway 服务..."
nohup openclaw gateway --allow-unconfigured --bind lan --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
echo "[√] Gateway 服务已启动（后台运行）"

# 4. 等待服务启动并验证
echo "[4/4] 等待服务启动..."
MAX_WAIT=30
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if command -v ss &> /dev/null; then
        PORT_STATUS=$(ss -tlnp 2>/dev/null | grep 18789 || echo "")
    elif command -v netstat &> /dev/null; then
        PORT_STATUS=$(netstat -tlnp 2>/dev/null | grep 18789 || echo "")
    else
        PORT_STATUS=""
    fi

    if [ -n "$PORT_STATUS" ]; then
        echo "[√] 服务已启动，端口 18789 正在监听"
        break
    fi

    echo "   等待中... ($WAITED/$MAX_WAIT 秒)"
    sleep 3
    WAITED=$((WAITED + 3))
done

if [ -z "$PORT_STATUS" ]; then
    echo "[×] 服务在 ${MAX_WAIT}秒内未启动"
    echo "[日志] tail -f /tmp/openclaw-gateway.log"
    exit 1
fi

echo ""
echo "============================================================"
echo "  重启完成！"
echo "============================================================"
echo ""
echo "[访问地址]"
echo "- Control UI: http://localhost:18789/"
echo "- Windows 访问：http://<WSL-IP>:18789/"
echo ""
echo "[网关认证]"
echo "- Token: $TOKEN"
echo "- Token 文件：$CONFIG_DIR/gateway.token"
echo ""
echo "[日志]"
echo "- tail -f /tmp/openclaw-gateway.log"
echo ""
