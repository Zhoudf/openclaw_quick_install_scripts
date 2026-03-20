#!/bin/bash
# ============================================================
# OpenClaw 更新脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash update-openclaw.sh
#
# 此脚本用于更新 OpenClaw 到最新版本
# 更新前自动停止服务，更新后自动重启服务
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 更新脚本"
echo "============================================================"
echo ""

# 1. 检查当前安装
echo "[1/6] 检查当前安装..."
if command -v openclaw &> /dev/null; then
    CURRENT_VERSION=$(openclaw --version 2>&1 | head -1)
    echo "[信息] 当前版本：$CURRENT_VERSION"
else
    echo "[信息] OpenClaw 未安装，将执行全新安装"
fi

# 获取当前安装的版本
INSTALLED_PATH=$(which openclaw 2>/dev/null || echo "")
if [ -n "$INSTALLED_PATH" ]; then
    echo "[信息] 安装路径：$INSTALLED_PATH"
fi
echo ""

# 2. 停止现有服务
echo "[2/6] 停止现有服务..."
# 先尝试优雅停止
pkill -f "openclaw gateway" 2>/dev/null && echo "[√] 已停止 OpenClaw Gateway 进程" || echo "[提示] 没有找到运行中的 Gateway 进程"
sleep 2

# 检查是否还有 openclaw 进程在运行（排除当前脚本）
# 使用 pgrep -a 查看进程，然后过滤掉脚本本身
OTHER_PROCS=$(pgrep -a "openclaw" 2>/dev/null | grep -v "update-openclaw.sh" | grep -v "restart-openclaw.sh" | grep -v "post-install-auto.sh" || echo "")
if [ -n "$OTHER_PROCS" ]; then
    echo "[提示] 发现其他 OpenClaw 进程:"
    echo "$OTHER_PROCS" | head -5
    # 只杀死 gateway 和 worker 进程，不杀死脚本
    pgrep -f "openclaw" 2>/dev/null | while read pid; do
        CMD=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
        if [ "$CMD" = "node" ] || [ "$CMD" = "openclaw" ]; then
            # 检查是否是脚本本身
            FULL_CMD=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
            if ! echo "$FULL_CMD" | grep -q "update-openclaw.sh\|restart-openclaw.sh\|post-install-auto.sh"; then
                kill "$pid" 2>/dev/null || true
                echo "[信息] 已停止进程 $pid"
            fi
        fi
    done
    sleep 2
fi

echo "[√] 服务已停止"
echo ""

# 3. 备份配置（如果需要）
echo "[3/6] 备份配置..."
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ -f "$CONFIG_FILE" ]; then
    # 备份配置文件
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[√] 配置文件已备份"
else
    echo "[提示] 未找到配置文件，跳过备份"
fi

# 备份 token 文件
if [ -f "$CONFIG_DIR/gateway.token" ]; then
    cp "$CONFIG_DIR/gateway.token" "$CONFIG_DIR/gateway.token.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[√] Token 文件已备份"
fi
echo ""

# 4. 更新 OpenClaw
echo "[4/6] 更新 OpenClaw..."
echo "[信息] 正在从 npm 获取最新版本..."

# 获取最新版本号
LATEST_VERSION=$(npm view openclaw version 2>/dev/null || echo "unknown")
echo "[信息] 最新 npm 版本：$LATEST_VERSION"

# 执行全局更新
echo "[信息] 正在更新 openclaw..."
npm install -g openclaw@latest

if command -v openclaw &> /dev/null; then
    NEW_VERSION=$(openclaw --version 2>&1 | head -1)
    echo "[√] 更新成功！新版本：$NEW_VERSION"
else
    echo "[×] OpenClaw 未安装成功"
    exit 1
fi
echo ""

# 5. 恢复配置（如果有）
echo "[5/6] 检查配置..."
if [ -f "$CONFIG_FILE" ]; then
    echo "[√] 配置文件存在"
else
    echo "[提示] 配置文件不存在，可能需要重新初始化"
fi

if [ -f "$CONFIG_DIR/gateway.token" ]; then
    TOKEN=$(cat "$CONFIG_DIR/gateway.token")
    echo "[√] Token 文件存在"
else
    TOKEN=""
    echo "[提示] Token 文件不存在"
fi
echo ""

# 6. 启动 Gateway 服务
echo "[6/6] 启动 Gateway 服务..."

# 检查是否在 WSL 环境
BIND_ADDR="lan"
if [ -f /etc/wsl.conf ]; then
    echo "[信息] WSL 环境，使用 --bind lan"
else
    echo "[信息] 非 WSL 环境，使用默认绑定"
    BIND_ADDR="localhost"
fi

nohup openclaw gateway --allow-unconfigured --bind "$BIND_ADDR" --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
echo "[√] Gateway 服务已启动（后台运行）"

# 等待服务启动
echo "[信息] 等待服务启动..."
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
echo "  更新完成！"
echo "============================================================"
echo ""
echo "[版本信息]"
if [ -n "$CURRENT_VERSION" ]; then
    echo "- 更新前：$CURRENT_VERSION"
fi
echo "- 更新后：$NEW_VERSION"
echo ""
echo "[访问地址]"
echo "- Control UI: http://localhost:18789/"
echo ""
echo "[网关认证]"
echo "- Token: $TOKEN"
echo "- Token 文件：$CONFIG_DIR/gateway.token"
echo ""
echo "[日志]"
echo "- tail -f /tmp/openclaw-gateway.log"
echo ""
echo "[提示]"
echo "- 如果更新后出现问题，可以恢复备份的配置文件"
echo "- 备份文件位于：$CONFIG_DIR/*.backup.*"
echo ""
