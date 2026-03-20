#!/bin/bash

# ============================================================
# OpenClaw API Key 配置脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash setup-apikey.sh
#
# 功能：
# - 支持 Nvidia 和 iflow.cn 两个端点
# - 配置 API Key 到 OpenClaw 配置文件
# - 列举可用模型供用户选择（常用模型在前）
# - 设置选中的模型为主模型
# - 重启 OpenClaw 服务和网关
#
# 支持端点：
# - Nvidia: https://integrate.api.nvidia.com/v1
# - iflow.cn: https://apis.iflow.cn/v1
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw API Key 配置"
echo "============================================================"
echo ""

# 检查 OpenClaw 是否安装
if ! command -v openclaw &> /dev/null; then
    echo "[×] openclaw 命令未找到"
    echo "[提示] 请先安装：npm install -g openclaw@latest"
    exit 1
fi

# 检查 curl 和 python3 是否安装
if ! command -v curl &> /dev/null; then
    echo "[×] curl 未安装，请先安装：sudo apt-get install curl"
    exit 1
fi

HAS_PYTHON=false
if command -v python3 &> /dev/null; then
    HAS_PYTHON=true
fi

# 检查 OpenClaw 配置目录
CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "[信息] 配置目录不存在，正在创建..."
    mkdir -p "$CONFIG_DIR"
fi

echo "配置目录：$CONFIG_DIR"
echo ""

# ============================================================
# 1. 选择端点
# ============================================================
echo "============================================================"
echo "  步骤 1: 选择 API 端点"
echo "============================================================"
echo ""
echo "可用端点:"
echo "  1. Nvidia (https://integrate.api.nvidia.com/v1)"
echo "  2. iflow.cn (https://apis.iflow.cn/v1)"
echo ""

while true; do
    read -p "请选择端点 (1-2): " ENDPOINT_CHOICE
    case $ENDPOINT_CHOICE in
        1)
            PROVIDER_NAME="nvidia"
            API_BASE_URL="https://integrate.api.nvidia.com/v1"
            API_KEY_NAME="NVIDIA_API_KEY"
            PROVIDER_DISPLAY="Nvidia"
            WEBSITE_URL="https://build.nvidia.com/"
            break
            ;;
        2)
            PROVIDER_NAME="iflow"
            API_BASE_URL="https://apis.iflow.cn/v1"
            API_KEY_NAME="IFLOW_API_KEY"
            PROVIDER_DISPLAY="iflow.cn"
            WEBSITE_URL="https://apis.iflow.cn/"
            break
            ;;
        *)
            echo "[×] 无效选择，请输入 1 或 2"
            ;;
    esac
done

echo ""
echo "[√] 已选择：$PROVIDER_DISPLAY ($API_BASE_URL)"
echo ""

# ============================================================
# 2. 配置 API Key
# ============================================================
echo "============================================================"
echo "  步骤 2: 配置 $PROVIDER_DISPLAY API Key"
echo "============================================================"
echo ""

echo "[提示] 获取 API Key:"
echo "1. 访问：$WEBSITE_URL"
echo "2. 登录/注册账号"
echo "3. 获取 API Key"
echo ""

read -p "输入 API Key: " API_KEY

if [ -z "$API_KEY" ]; then
    echo "[×] API Key 不能为空"
    exit 1
fi

echo "[信息] 保存 API Key 到配置文件..."

# 备份现有配置
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[√] 配置已备份"
fi

# ============================================================
# 3. 获取并列出模型供用户选择
# ============================================================
echo ""
echo "============================================================"
echo "  步骤 3: 选择主模型"
echo "============================================================"
echo ""

echo "[信息] 正在获取 $PROVIDER_DISPLAY 可用模型列表..."

# 使用 curl 获取模型列表
MODELS_RESPONSE=$(curl -s --max-time 30 \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    "$API_BASE_URL/models" 2>/dev/null || echo "")

if [ -z "$MODELS_RESPONSE" ]; then
    echo "[×] 无法获取模型列表，可能是 API Key 无效或网络问题"
    exit 1
fi

# 检查是否返回错误
if echo "$MODELS_RESPONSE" | grep -q '"message"'; then
    ERROR_MSG=$(echo "$MODELS_RESPONSE" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')
    if [ -n "$ERROR_MSG" ]; then
        echo "[×] API 返回错误：$ERROR_MSG"
        exit 1
    fi
fi

# 提取模型 ID 列表
MODELS_RAW=$(echo "$MODELS_RESPONSE" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"id"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' | sort -u)

if [ -z "$MODELS_RAW" ]; then
    echo "[×] 模型列表为空"
    exit 1
fi

echo "[√] 成功获取模型列表"
echo ""

# 将模型列表转换为数组
ALL_MODELS=()
while IFS= read -r model; do
    if [ -n "$model" ]; then
        ALL_MODELS+=("$model")
    fi
done <<< "$MODELS_RAW"

# 优先显示常用模型系列
PRIORITY_FOUND=()
OTHER_MODELS=()

for model in "${ALL_MODELS[@]}"; do
    IS_PRIORITY=false

    # 优先显示 Kimi, Minimax, DeepSeek, Qwen, GLM, Llama, Nemotron, Mistral, Gemma, Phi 等
    if [[ "$model" == *"kimi"* ]] || [[ "$model" == *"minimax"* ]] || \
       [[ "$model" == *"deepseek"* ]] || [[ "$model" == *"qwen"* ]] || \
       [[ "$model" == *"glm"* ]] || [[ "$model" == *"llama"* ]] || \
       [[ "$model" == *"nemotron"* ]] || [[ "$model" == *"mistral"* ]] || \
       [[ "$model" == *"gemma"* ]] || [[ "$model" == *"mixtral"* ]] || \
       [[ "$model" == *"phi"* ]] || [[ "$model" == *"cosmos"* ]] || \
       [[ "$model" == *"granite"* ]] || [[ "$model" == *"doubao"* ]] || \
       [[ "$model" == *"seed"* ]] || [[ "$model" == *"baichuan"* ]] || \
       [[ "$model" == *"yi"* ]] || [[ "$model" == *"internlm"* ]]; then
        IS_PRIORITY=true
    fi

    if [ "$IS_PRIORITY" = true ]; then
        PRIORITY_FOUND+=("$model")
    else
        OTHER_MODELS+=("$model")
    fi
done

# 合并列表
SORTED_MODELS=("${PRIORITY_FOUND[@]}" "${OTHER_MODELS[@]}")

# 设置默认模型（0 号选项）
if [ "$PROVIDER_NAME" = "nvidia" ]; then
    DEFAULT_MODEL="moonshotai/kimi-k2-instruct"
elif [ "$PROVIDER_NAME" = "iflow" ]; then
    DEFAULT_MODEL="qwen3-235b-a22b-instruct"
fi

# 显示模型列表
echo "可用模型（常用模型已前置）:"
echo "------------------------------------------------------------"
echo "  0. [默认] $DEFAULT_MODEL"

MODEL_NUM=${#SORTED_MODELS[@]}

if [ "$MODEL_NUM" -eq 0 ]; then
    echo "[×] 未找到可用模型"
    exit 1
fi

for i in "${!SORTED_MODELS[@]}"; do
    printf "  %2d. %s\n" "$((i + 1))" "${SORTED_MODELS[$i]}"
done

echo "------------------------------------------------------------"
echo ""

# 用户选择模型
while true; do
    read -p "请选择主模型 (输入编号 0-$MODEL_NUM, 0=默认): " MODEL_CHOICE

    if [[ "$MODEL_CHOICE" = "0" ]]; then
        SELECTED_MODEL="$DEFAULT_MODEL"
        break
    elif [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] && [ "$MODEL_CHOICE" -ge 1 ] && [ "$MODEL_CHOICE" -le "$MODEL_NUM" ]; then
        SELECTED_MODEL="${SORTED_MODELS[$((MODEL_CHOICE - 1))]}"
        break
    else
        echo "[×] 无效选择，请输入 0-$MODEL_NUM 之间的数字"
    fi
done

echo ""
echo "[√] 已选择模型：$SELECTED_MODEL"
echo ""

# ============================================================
# 4. 更新配置文件
# ============================================================
echo "============================================================"
echo "  步骤 4: 更新配置文件"
echo "============================================================"
echo ""

# 使用 Python 来构建和更新配置（如果可用）
if [ "$HAS_PYTHON" = true ]; then
    python3 << PYEOF
import json
import os
from datetime import datetime

config_file = "$CONFIG_FILE"
agent_dir = "$CONFIG_DIR/agents/main/agent"
provider_name = "$PROVIDER_NAME"
api_key_name = "$API_KEY_NAME"
api_base_url = "$API_BASE_URL"
selected_model = "$SELECTED_MODEL"
models_raw = """$MODELS_RAW"""
api_key = "$API_KEY"

# 确保 agent 目录存在
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

# 更新 meta
config["meta"]["lastTouchedVersion"] = "2026.3.17"
config["meta"]["lastTouchedAt"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
# 移除旧格式的版本字段（如果存在）
if "version" in config:
    del config["version"]

# 更新 env (保留现有 env 设置)
if "env" not in config:
    config["env"] = {}
config["env"][api_key_name] = api_key

# 更新 models.providers
if "models" not in config:
    config["models"] = {}
if "providers" not in config["models"]:
    config["models"]["providers"] = {}

# 构建 models 数组（从 API 获取的模型列表）
models_list = []

# 优先添加常用模型
for model_id in models_raw.strip().split('\n'):
    model_id = model_id.strip()
    if model_id:
        # 生成友好的名称
        name = model_id.split('/')[-1].replace('-instruct', '').replace('-distill', '').title()
        models_list.append({"id": model_id, "name": name})

config["models"]["providers"][provider_name] = {
    "baseUrl": api_base_url,
    "api": "openai-completions",
    "models": models_list
}

# 更新 agents.defaults.model
if "agents" not in config:
    config["agents"] = {}
if "defaults" not in config["agents"]:
    config["agents"]["defaults"] = {
        "compaction": {"mode": "safeguard"}
    }

config["agents"]["defaults"]["model"] = {
    "primary": f"{provider_name}/{selected_model}"
}

# 保留现有 models 配置，只更新当前 provider 的模型
if "models" not in config["agents"]["defaults"]:
    config["agents"]["defaults"]["models"] = {}
config["agents"]["defaults"]["models"][f"{provider_name}/{selected_model}"] = {}

# 保留并更新 gateway 配置
if "gateway" not in config:
    config["gateway"] = {}

# 确保 gateway 基本配置存在
config["gateway"].setdefault("mode", "local")
config["gateway"].setdefault("bind", "lan")

# 配置 controlUi（添加 allowedOrigins）
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
# 保留现有 token（如果存在）
if "token" not in config["gateway"]["auth"]:
    import secrets
    config["gateway"]["auth"]["token"] = secrets.token_hex(20)

# 保存配置
with open(config_file, "w") as f:
    json.dump(config, f, indent=2)

print("[√] 配置文件已更新")
print(f"[√] 主模型设置为：{provider_name}/{selected_model}")

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

# 移除旧格式（如果存在 env 字段）
if "env" in auth_profiles:
    del auth_profiles["env"]
if "meta" in auth_profiles:
    del auth_profiles["meta"]

# 确保 version 字段存在
auth_profiles["version"] = 1

# 添加/更新 provider 的 API Key (使用 api_key 格式)
profile_key = f"{provider_name}:default"
auth_profiles["profiles"][profile_key] = {
    "type": "api_key",
    "provider": provider_name,
    "key": api_key
}

# 更新 usageStats
if profile_key not in auth_profiles["usageStats"]:
    auth_profiles["usageStats"][profile_key] = {}
auth_profiles["usageStats"][profile_key]["lastUsed"] = int(datetime.utcnow().timestamp() * 1000)
auth_profiles["usageStats"][profile_key]["errorCount"] = 0

# 保存 auth-profiles.json
with open(auth_profiles_file, "w") as f:
    json.dump(auth_profiles, f, indent=2)

print("[√] auth-profiles.json 已更新")
PYEOF
else
    # 备用方法：使用 Python（如果可用）或有限的 sed 更新
    # 注意：备用方法功能有限，建议安装 Python3 以获得完整功能

    # 尝试使用 python3（即使没有 pip 安装 openclaw）
    if command -v python3 &> /dev/null; then
        python3 << PYEOF
import json
import os
from datetime import datetime

config_file = "$CONFIG_FILE"
agent_dir = "$CONFIG_DIR/agents/main/agent"
provider_name = "$PROVIDER_NAME"
api_key_name = "$API_KEY_NAME"
api_base_url = "$API_BASE_URL"
selected_model = "$SELECTED_MODEL"
api_key = "$API_KEY"

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

# 更新 meta
config["meta"]["lastTouchedVersion"] = "2026.3.17"
config["meta"]["lastTouchedAt"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")

# 更新 env
if "env" not in config:
    config["env"] = {}
config["env"][api_key_name] = api_key

# 更新 models.providers（保留其他 provider）
if "models" not in config:
    config["models"] = {}
if "providers" not in config["models"]:
    config["models"]["providers"] = {}

config["models"]["providers"][provider_name] = {
    "baseUrl": api_base_url,
    "api": "openai-completions",
    "models": [{"id": selected_model, "name": selected_model.split('/')[-1]}]
}

# 更新 agents.defaults.model
if "agents" not in config:
    config["agents"] = {}
if "defaults" not in config["agents"]:
    config["agents"]["defaults"] = {"compaction": {"mode": "safeguard"}}

config["agents"]["defaults"]["model"] = {"primary": f"{provider_name}/{selected_model}"}

# 保留现有 models，只更新当前 provider
if "models" not in config["agents"]["defaults"]:
    config["agents"]["defaults"]["models"] = {}
config["agents"]["defaults"]["models"][f"{provider_name}/{selected_model}"] = {}

# 更新 gateway
config["gateway"].setdefault("mode", "local")
config["gateway"].setdefault("bind", "lan")
config["gateway"]["controlUi"] = {
    "enabled": True,
    "allowedOrigins": ["http://localhost:18789", "http://127.0.0.1:18789"]
}
config["gateway"]["auth"] = config["gateway"].get("auth", {})
config["gateway"]["auth"]["mode"] = "token"
if "token" not in config["gateway"]["auth"]:
    import secrets
    config["gateway"]["auth"]["token"] = secrets.token_hex(20)

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)

print("[√] 配置文件已更新")

# 更新 auth-profiles.json
auth_profiles_file = os.path.join(agent_dir, "auth-profiles.json")
try:
    with open(auth_profiles_file, "r") as f:
        auth_profiles = json.load(f)
except:
    auth_profiles = {"version": 1, "profiles": {}, "usageStats": {}}

# 清理旧格式
if "env" in auth_profiles:
    del auth_profiles["env"]
if "meta" in auth_profiles:
    del auth_profiles["meta"]

auth_profiles["version"] = 1

profile_key = f"{provider_name}:default"
auth_profiles["profiles"][profile_key] = {
    "type": "api_key",
    "provider": provider_name,
    "key": api_key
}

if profile_key not in auth_profiles["usageStats"]:
    auth_profiles["usageStats"][profile_key] = {}
auth_profiles["usageStats"][profile_key]["lastUsed"] = int(datetime.utcnow().timestamp() * 1000)
auth_profiles["usageStats"][profile_key]["errorCount"] = 0

with open(auth_profiles_file, "w") as f:
    json.dump(auth_profiles, f, indent=2)

print("[√] auth-profiles.json 已更新")
PYEOF
    else
        echo "[警告] Python3 不可用，只能进行有限更新"
        echo "[建议] 请安装 Python3: apt-get install python3"

        # 最基本的 sed 更新（只更新 primary model）
        if [ -f "$CONFIG_FILE" ]; then
            sed -i "s/\"primary\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"primary\": \"$PROVIDER_NAME\/$SELECTED_MODEL\"/" "$CONFIG_FILE"
            echo "[√] 已更新主模型配置（有限更新）"
        else
            echo "[×] 配置文件不存在且无法创建"
            exit 1
        fi
    fi
fi

echo ""

# ============================================================
# 5. 重启 OpenClaw 服务和网关
# ============================================================
echo "============================================================"
echo "  步骤 5: 重启 OpenClaw 服务"
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

# 使用 nohup 启动网关
nohup openclaw gateway --allow-unconfigured --bind lan --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
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
# 6. 验证配置
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
echo "--- 模型状态 ---"
openclaw models 2>&1 | head -20 || echo "[提示] 服务可能正在启动"

echo ""

# 获取 gateway token
GATEWAY_TOKEN=""
if [ -f "$CONFIG_DIR/gateway.token" ]; then
    GATEWAY_TOKEN=$(cat "$CONFIG_DIR/gateway.token" 2>/dev/null)
elif [ -f "$CONFIG_FILE" ]; then
    GATEWAY_TOKEN=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')
fi

# ============================================================
# 完成
# ============================================================
echo "============================================================"
echo "  配置完成！"
echo "============================================================"
echo ""

echo "[完成] $PROVIDER_DISPLAY API Key 已配置完成"
echo ""
echo "[主模型] $PROVIDER_NAME/$SELECTED_MODEL"
echo ""
echo "[访问地址]"
echo "- Control UI: http://localhost:18789/"
echo ""
if [ -n "$GATEWAY_TOKEN" ]; then
    echo "[Gateway Token] $GATEWAY_TOKEN"
    echo "[Token 文件] $CONFIG_DIR/gateway.token"
fi
echo ""
echo "[常用命令]"
echo "- openclaw models list  查看可用模型"
echo "- openclaw models set   切换主模型"
echo "- openclaw status       检查服务状态"
echo "- openclaw health       健康检查"
echo ""
echo "[日志文件]"
echo "- Gateway 日志：/tmp/openclaw-gateway.log"
echo "- 查看日志：tail -f /tmp/openclaw-gateway.log"
echo ""
echo "[故障排除]"
echo "如果遇到 'missing scope: operator.read' 错误："
echo "1. 确认 gateway.auth.mode 设置为 'token'"
echo "2. 确认 controlUi.allowedOrigins 包含 localhost:18789"
echo "3. 运行 'openclaw doctor --fix' 修复配置"
echo "4. 重启网关：pkill -f openclaw && openclaw gateway --allow-unconfigured --bind lan --port 18789"
echo ""
echo "如果聊天无响应："
echo "1. 检查模型是否正确配置：openclaw models"
echo "2. 确认 API Key 有效：curl -H \"Authorization: Bearer \$API_KEY\" https://apis.iflow.cn/v1/models"
echo "3. 查看日志中是否有请求记录：grep 'chat' /tmp/openclaw-gateway.log"
echo ""

read -p "按回车键退出"
