#!/bin/bash

# ============================================================
# OpenClaw 飞书（Feishu）渠道配置脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash setup-feishu.sh
#
# 功能：
# - 配置飞书 App ID 和 App Secret 到 OpenClaw
# - 自动重启 Gateway 服务
# - 验证配置状态
#
# 前置条件：
# - 已安装 OpenClaw
# - 已安装飞书插件：openclaw plugins install @openclaw/feishu
#
# 飞书开放平台配置步骤：
# 1. 访问 https://open.feishu.cn/ 创建企业应用
# 2. 在"凭证与基础信息"中获取 App ID 和 App Secret
# 3. 在"事件订阅"中配置请求地址（由 openclaw feishu webhook 命令获取）
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 飞书（Feishu）渠道配置"
echo "============================================================"
echo ""

# 检查 OpenClaw 是否安装
if ! command -v openclaw &> /dev/null; then
    echo "[×] openclaw 命令未找到"
    echo "[提示] 请先安装：npm install -g openclaw@latest"
    exit 1
fi

# 检查 Python3 是否可用
HAS_PYTHON=false
if command -v python3 &> /dev/null; then
    HAS_PYTHON=true
fi

# 检查配置目录
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "[信息] 配置目录不存在，正在创建..."
    mkdir -p "$CONFIG_DIR"
fi

echo "配置目录：$CONFIG_DIR"
echo ""

# ============================================================
# 1. 输入飞书应用凭证
# ============================================================
echo "============================================================"
echo "  步骤 1: 输入飞书应用凭证"
echo "============================================================"
echo ""
echo "[提示] 获取 App ID 和 App Secret:"
echo "1. 访问飞书开放平台：https://open.feishu.cn/"
echo "2. 进入"管理后台" -> "应用开发""
echo "3. 创建企业应用或选择已有应用"
echo "4. 在"凭证与基础信息"中获取 App ID 和 App Secret"
echo ""

read -p "请输入 App ID: " FEISHU_APP_ID

if [ -z "$FEISHU_APP_ID" ]; then
    echo "[×] App ID 不能为空"
    exit 1
fi

read -p "请输入 App Secret: " FEISHU_APP_SECRET

if [ -z "$FEISHU_APP_SECRET" ]; then
    echo "[×] App Secret 不能为空"
    exit 1
fi

echo ""
echo "[√] 已输入 App ID: $FEISHU_APP_ID"
echo ""

# ============================================================
# 2. 更新配置文件
# ============================================================
echo "============================================================"
echo "  步骤 2: 更新配置文件"
echo "============================================================"
echo ""

# 备份现有配置
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.feishu.$(date +%Y%m%d_%H%M%S)"
    echo "[√] 配置已备份：$CONFIG_FILE.backup.feishu.*"
fi

# 使用 Python 更新配置
if [ "$HAS_PYTHON" = true ]; then
    python3 << PYEOF
import json
import os
from datetime import datetime

config_file = "$CONFIG_FILE"
config_dir = "$CONFIG_DIR"
app_id = "$FEISHU_APP_ID"
app_secret = "$FEISHU_APP_SECRET"

# 确保 agents/main/agent 目录存在
agent_dir = os.path.join(config_dir, "agents", "main", "agent")
os.makedirs(agent_dir, exist_ok=True)

# 读取现有配置
try:
    with open(config_file, "r") as f:
        config = json.load(f)
except:
    config = {
        "meta": {},
        "gateway": {}
    }

# 更新 meta 信息
config["meta"]["lastTouchedVersion"] = "2026.3.18"
config["meta"]["lastTouchedAt"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

# 移除旧格式的版本字段
if "version" in config:
    del config["version"]

# 配置飞书渠道
if "channels" not in config:
    config["channels"] = {}

config["channels"]["feishu"] = {
    "appId": app_id,
    "appSecret": app_secret,
    "enabled": True
}

# 确保 gateway 配置存在
config["gateway"].setdefault("mode", "local")
config["gateway"].setdefault("bind", "lan")

# 配置 controlUi
if "controlUi" not in config["gateway"]:
    config["gateway"]["controlUi"] = {}
config["gateway"]["controlUi"]["enabled"] = True
config["gateway"]["controlUi"]["allowedOrigins"] = [
    "http://localhost:18789",
    "http://127.0.0.1:18789"
]

# 配置 auth
if "auth" not in config["gateway"]:
    config["gateway"]["auth"] = {}
config["gateway"]["auth"]["mode"] = "token"
if "token" not in config["gateway"]["auth"]:
    import secrets
    config["gateway"]["auth"]["token"] = secrets.token_hex(20)

# 保存配置
with open(config_file, "w") as f:
    json.dump(config, f, indent=2)

print("[√] 配置文件已更新")
print(f"[√] 飞书渠道已配置")
print(f"[√] App ID: {app_id}")

# 创建飞书渠道的 token 文件
token_file = os.path.join(config_dir, "feishu.token")
with open(token_file, "w") as f:
    f.write(f"App ID: {app_id}\n")
    f.write(f"App Secret: {app_secret}\n")
    f.write(f"配置时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

print(f"[√] 凭证已保存到：{token_file}")

# 更新 auth-profiles.json
auth_profiles_file = os.path.join(agent_dir, "auth-profiles.json")
try:
    with open(auth_profiles_file, "r") as f:
        auth_profiles = json.load(f)
except:
    auth_profiles = {
        "version": 1,
        "profiles": {},
        "usageStats": {}
    }

# 清理旧格式
if "env" in auth_profiles:
    del auth_profiles["env"]
if "meta" in auth_profiles:
    del auth_profiles["meta"]

auth_profiles["version"] = 1

# 添加飞书渠道凭证
auth_profiles["profiles"]["feishu:default"] = {
    "type": "app_credentials",
    "channel": "feishu",
    "appId": app_id,
    "appSecret": app_secret
}

# 更新使用统计
if "feishu:default" not in auth_profiles["usageStats"]:
    auth_profiles["usageStats"]["feishu:default"] = {}
auth_profiles["usageStats"]["feishu:default"]["lastUsed"] = int(datetime.utcnow().timestamp() * 1000)
auth_profiles["usageStats"]["feishu:default"]["errorCount"] = 0

# 保存 auth-profiles.json
with open(auth_profiles_file, "w") as f:
    json.dump(auth_profiles, f, indent=2)

print("[√] auth-profiles.json 已更新")
PYEOF
else
    echo "[警告] Python3 不可用，只能进行有限更新"
    echo "[建议] 请安装 Python3: apt-get install python3"
    exit 1
fi

echo ""

# ============================================================
# 3. 重启 Gateway 服务
# ============================================================
echo "============================================================"
echo "  步骤 3: 重启 Gateway 服务"
echo "============================================================"
echo ""

# 停止现有服务
echo "[信息] 停止现有服务..."
pkill -f "openclaw" 2>/dev/null || true
sleep 2
echo "[√] 服务已停止"
echo ""

# 重启网关服务
echo "[信息] 启动 Gateway 服务..."

# 检测 WSL 环境
if [ -f /etc/wsl.conf ]; then
    BIND_ADDR="lan"
    echo "[信息] WSL 环境，使用 --bind lan"
else
    BIND_ADDR="localhost"
    echo "[信息] 非 WSL 环境，使用 --bind localhost"
fi

nohup openclaw gateway --allow-unconfigured --bind "$BIND_ADDR" --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
GATEWAY_PID=$!
echo "[信息] Gateway 进程 ID: $GATEWAY_PID"

# 等待服务启动
echo ""
echo "[信息] 等待服务启动..."

MAX_WAIT=30
WAITED=0
SERVICE_STARTED=false

while [ $WAITED -lt $MAX_WAIT ]; do
    if command -v ss &> /dev/null; then
        PORT_STATUS=$(ss -tlnp 2>/dev/null | grep ":18789" || echo "")
    elif command -v netstat &> /dev/null; then
        PORT_STATUS=$(netstat -tlnp 2>/dev/null | grep ":18789" || echo "")
    else
        PORT_STATUS=""
    fi

    if [ -n "$PORT_STATUS" ]; then
        echo "[√] 服务已启动，端口 18789 正在监听"
        SERVICE_STARTED=true
        break
    fi

    echo "   等待中... ($WAITED/$MAX_WAIT 秒)"
    sleep 3
    WAITED=$((WAITED + 3))
done

if [ "$SERVICE_STARTED" = false ]; then
    echo "[警告] 服务在 ${MAX_WAIT}秒内未启动，请检查日志"
    echo "[日志] tail -f /tmp/openclaw-gateway.log"
fi

echo ""

# ============================================================
# 4. 获取 Webhook URL
# ============================================================
echo "============================================================"
echo "  步骤 4: 获取飞书 Webhook URL"
echo "============================================================"
echo ""

echo "[信息] 获取飞书 Webhook URL..."
echo ""
echo "请将以下 URL 配置到飞书开放平台的"事件订阅"中："
echo ""
echo "  请求地址（Request URL）:"
echo "  http://localhost:18789/api/channels/feishu/webhook"
echo ""
echo "  如果是 WSL 环境，Windows 访问地址为："
if [ -f /etc/wsl.conf ]; then
    WSL_IP=$(hostname -I | awk '{print $1}')
    echo "  http://$WSL_IP:18789/api/channels/feishu/webhook"
fi
echo ""

echo "[重要] 飞书开放平台配置步骤："
echo "1. 访问 https://open.feishu.cn/ 进入应用管理"
echo "2. 进入"事件订阅"菜单"
echo "3. 点击"添加事件"或"修改配置""
echo "4. 填入上方的 Request URL"
echo "5. 保存配置（飞书会发送验证请求）"
echo "6. 在"事件订阅"中勾选需要订阅的事件"
echo ""

# ============================================================
# 5. 验证配置
# ============================================================
echo "============================================================"
echo "  配置验证"
echo "============================================================"
echo ""

echo "--- 服务状态 ---"
openclaw status 2>&1 | head -10 || echo "[提示] 服务可能正在启动"

echo ""
echo "--- 健康检查 ---"
openclaw health 2>&1 | head -10 || echo "[提示] 服务可能正在启动"

echo ""
echo "--- 渠道状态 ---"
openclaw channels list 2>&1 | head -20 || echo "[提示] 服务可能正在启动"

# ============================================================
# 完成
# ============================================================
echo "============================================================"
echo "  配置完成！"
echo "============================================================"
echo ""

echo "[完成] 飞书渠道已配置完成"
echo ""
echo "[配置信息]"
echo "- App ID: $FEISHU_APP_ID"
echo "- 配置文件：$CONFIG_FILE"
echo "- 凭证文件：$CONFIG_DIR/feishu.token"
echo ""
echo "[访问地址]"
echo "- Control UI: http://localhost:18789/"
echo "- 飞书 Webhook: http://localhost:18789/api/channels/feishu/webhook"
echo ""
echo "[下一步操作]"
echo "1. 在飞书开放平台配置事件订阅 URL（见上方步骤 4）"
echo "2. 在 Control UI 中测试飞书消息"
echo "3. 在飞书中测试发送消息给机器人"
echo ""
echo "[常用命令]"
echo "- openclaw channels list     查看已配置的渠道"
echo "- openclaw channels status   查看渠道状态"
echo "- openclaw status            检查服务状态"
echo "- openclaw health            健康检查"
echo ""
echo "[日志文件]"
echo "- Gateway 日志：/tmp/openclaw-gateway.log"
echo "- 查看日志：tail -f /tmp/openclaw-gateway.log"
echo ""
echo "[故障排除]"
echo "如果飞书消息无响应："
echo "1. 确认事件订阅 URL 配置正确"
echo "2. 确认飞书应用已发布（可见范围包含测试用户）"
echo "3. 检查 Gateway 日志中是否有飞书请求记录"
echo "4. 运行 'openclaw doctor --fix' 修复配置"
echo ""

read -p "按回车键退出"
