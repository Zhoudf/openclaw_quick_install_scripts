#!/bin/bash
# ============================================================
# OpenClaw 全自动配置脚本（增强版 - 修复环境变量）
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash post-install-auto.sh
#
# 此脚本自动完成所有配置，适合：
# - CI/CD 自动化
# - 批量部署
# - 无人值守安装
# - 自动修复环境变量问题
# - 自动修复 Control UI 问题
#
# 参考 Issue:
# - https://github.com/openclaw/openclaw/issues/4855
# - https://github.com/openclaw/openclaw/issues/14416
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 全自动配置（增强版）"
echo "============================================================"
echo ""

# 0. 检查和修复环境变量
echo "[1/8] 检查和修复环境变量..."

# 检查 npm 是否安装
if ! command -v npm &> /dev/null; then
    echo "[×] npm 未安装，退出"
    exit 1
fi

NPM_VERSION=$(npm --version)
echo "[√] npm: $NPM_VERSION"

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "[×] Node.js 未安装，退出"
    exit 1
fi

NODE_VERSION=$(node --version)
echo "[√] Node.js: $NODE_VERSION"

# 获取 npm 全局路径
NPM_GLOBAL_BIN=$(npm config get prefix)/bin
echo "[信息] npm 全局路径：$NPM_GLOBAL_BIN"

# 检查路径是否已在 PATH 中
if [[ ":$PATH:" != *":$NPM_GLOBAL_BIN:"* ]]; then
    echo "[信息] npm 全局路径不在 PATH 中，正在添加..."
    
    # 添加到 ~/.bashrc
    if ! grep -q "npm-global" ~/.bashrc 2>/dev/null && ! grep -q "$NPM_GLOBAL_BIN" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# NPM Global Packages" >> ~/.bashrc
        echo "export PATH=\"$NPM_GLOBAL_BIN:\$PATH\"" >> ~/.bashrc
        echo "[√] 已添加到 ~/.bashrc"
    else
        echo "[√] ~/.bashrc 中已有 npm 配置"
    fi
    
    # 立即生效
    export PATH="$NPM_GLOBAL_BIN:$PATH"
    echo "[√] 环境变量已立即生效"
else
    echo "[√] npm 全局路径已在 PATH 中"
fi

# 刷新 hash
hash -r
echo "[√] 环境变量已刷新"
echo ""

# 1. 验证 OpenClaw 安装
echo "[2/8] 验证 OpenClaw 安装..."

# 检查 openclaw 命令
if ! command -v openclaw &> /dev/null; then
    echo "[×] openclaw 命令未找到"
    echo "[提示] 尝试重新安装..."
    
    # 尝试重新安装
    npm install -g openclaw@latest
    
    if command -v openclaw &> /dev/null; then
        echo "[√] OpenClaw 安装成功"
    else
        echo "[×] OpenClaw 安装失败"
        echo "[提示] 请手动运行：npm install -g openclaw@latest"
        exit 1
    fi
fi

OPENCLAW_VERSION=$(openclaw --version 2>&1 | head -1)
echo "[√] $OPENCLAW_VERSION"
echo ""

# 2. 安装 Daemon 服务
echo "[3/8] 安装 Daemon 服务..."
openclaw onboard --install-daemon --yes 2>/dev/null || {
    echo "[提示] Daemon 可能已安装或需要手动配置"
}
echo "[√] 完成"
echo ""

# 2.5 检查并安装飞书插件
echo "[3.5/8] 检查并安装飞书插件..."
CONFIG_DIR="$HOME/.openclaw"
EXTENSIONS_DIR="$CONFIG_DIR/extensions/feishu"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

# 检测飞书插件是否存在
if [ -d "$EXTENSIONS_DIR" ]; then
    echo "[提示] 检测到飞书插件已安装"
    echo "[信息] 备份旧版本插件..."
    # 移动插件目录到备份位置
    BACKUP_DIR="$CONFIG_DIR/extensions/feishu.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$EXTENSIONS_DIR" "$BACKUP_DIR"
    echo "[√] 旧版本已备份到：$BACKUP_DIR"
    echo ""
    echo "[信息] 正在安装最新版飞书插件..."
    openclaw plugins install @openclaw/feishu
    if [ $? -eq 0 ]; then
        echo "[√] 飞书插件已更新到最新版本"
    else
        echo "[提示] 插件安装失败，可稍后手动安装"
    fi
else
    echo "[信息] 未检测到飞书插件，正在安装..."
    openclaw plugins install @openclaw/feishu
    if [ $? -eq 0 ]; then
        echo "[√] 飞书插件安装成功"
    else
        echo "[提示] 插件安装失败，可稍后手动安装"
    fi
fi
echo ""

# 3. 检查并修复 Control UI
echo "[5/8] 检查并修复 Control UI..."
OPENCLAW_DIR=$(npm root -g)/openclaw
UI_INDEX="$OPENCLAW_DIR/dist/control-ui/index.html"

if [ -f "$UI_INDEX" ]; then
    echo "[√] Control UI 文件已存在"

    # 停止现有服务
    if command -v pkill &> /dev/null; then
        pkill -f "openclaw" 2>/dev/null || true
    elif command -v killall &> /dev/null; then
        killall openclaw 2>/dev/null || true
    else
        # 使用 pgrep + kill 或直接跳过
        if command -v pgrep &> /dev/null; then
            for pid in $(pgrep -f "openclaw" 2>/dev/null); do
                kill "$pid" 2>/dev/null || true
            done
        else
            echo "[提示] 未找到进程管理命令，跳过停止服务"
        fi
    fi

    # 创建/检查配置文件
    CONFIG_DIR="$HOME/.openclaw"
    CONFIG_FILE="$CONFIG_DIR/openclaw.json"
    mkdir -p "$CONFIG_DIR"

    # 生成随机 token
    TOKEN=$(openssl rand -hex 20 2>/dev/null || echo "openclaw_$(date +%s | md5sum | head -c 40)")

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "[信息] 创建配置文件..."
        cat > "$CONFIG_FILE" << EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "enabled": true
    },
    "auth": {
      "mode": "token",
      "token": "$TOKEN"
    }
  }
}
EOF
        echo "[√] 配置文件已创建"
        echo "[信息] 生成随机 Token: $TOKEN"
    else
        # 检查配置文件中是否已设置 gateway.mode
        if ! grep -q '"mode"' "$CONFIG_FILE" 2>/dev/null; then
            echo "[信息] 配置文件中没有 mode 设置，正在添加..."
            # 备份原配置
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
            # 使用 jq 添加 mode 设置，如果没有 jq 则用 sed
            if command -v jq &> /dev/null; then
                jq --arg token "$TOKEN" '.gateway.mode = "local" | .gateway.bind = "lan" | .gateway.auth = {"mode": "token", "token": $token}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            else
                # 使用 sed 在 gateway 对象后添加 mode
                sed -i 's/"gateway": {/"gateway": {\n    "mode": "local",\n    "bind": "lan",\n    "auth": {\n      "mode": "token",\n      "token": "'$TOKEN'"\n    }/' "$CONFIG_FILE"
            fi
            echo "[√] 已添加 gateway.mode=local、bind=lan 和 auth 设置"
        elif ! grep -q '"bind"' "$CONFIG_FILE" 2>/dev/null; then
            echo "[信息] 配置文件中没有 bind 设置，正在添加..."
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
            if command -v jq &> /dev/null; then
                jq --arg token "$TOKEN" '.gateway.bind = "lan" | .gateway.auth = {"mode": "token", "token": $token}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            else
                sed -i 's/"mode": "local"/"mode": "local",\n    "bind": "lan",\n    "auth": {\n      "mode": "token",\n      "token": "'$TOKEN'"\n    }/' "$CONFIG_FILE"
            fi
            echo "[√] 已添加 gateway.bind=lan 和 auth 设置"
        elif ! grep -q '"auth"' "$CONFIG_FILE" 2>/dev/null; then
            echo "[信息] 配置文件中没有 auth 设置，正在添加..."
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
            if command -v jq &> /dev/null; then
                jq --arg token "$TOKEN" '.gateway.auth = {"mode": "token", "token": $token}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            else
                sed -i 's/"bind": "lan"/"bind": "lan",\n    "auth": {\n      "mode": "token",\n      "token": "'$TOKEN'"\n    }/' "$CONFIG_FILE"
            fi
            echo "[√] 已添加 auth 设置"
        fi

        # 读取现有 token
        TOKEN=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')
    fi

    # 保存 token 到文件
    echo "$TOKEN" > "$CONFIG_DIR/gateway.token"
    echo "[信息] Token 已保存到：$CONFIG_DIR/gateway.token"

    # 添加 plugins.allow 配置（允许飞书插件加载）
    if command -v jq &> /dev/null; then
        jq '.plugins = {"allow": ["@openclaw/feishu"]}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null && \
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE" && \
        echo "[√] 已添加 plugins.allow 配置" || echo "[提示] 插件配置跳过"
    fi

    # 停止现有服务
    if command -v pkill &> /dev/null; then
        pkill -f "openclaw" 2>/dev/null || true
    elif command -v killall &> /dev/null; then
        killall openclaw 2>/dev/null || true
    else
        # 使用 pgrep + kill 或直接跳过
        if command -v pgrep &> /dev/null; then
            for pid in $(pgrep -f "openclaw" 2>/dev/null); do
                kill "$pid" 2>/dev/null || true
            done
        else
            echo "[提示] 未找到进程管理命令，跳过停止服务"
        fi
    fi
    sleep 2

    # 重启服务，使用 --allow-unconfigured 参数确保服务能启动
    # 使用 --bind lan 允许从 Windows 主机访问（WSL2 场景）
    echo "[信息] 启动 Gateway 服务..."
    nohup openclaw gateway --allow-unconfigured --bind lan --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
    echo "[√] Control UI 已就绪"
else
    echo "[提示] Control UI 文件不存在，跳过修复"
fi
echo ""

# 4. 等待服务启动
echo "[6/8] 等待服务启动..."

# 轮询检查服务是否启动，最多等待 600 秒
MAX_WAIT=600
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
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ -z "$PORT_STATUS" ]; then
    echo "[警告] 服务在 ${MAX_WAIT}秒内未启动，请检查日志"
    echo "[日志] tail -f /tmp/openclaw-gateway.log"
fi
echo ""

# 5. 检查服务状态和 UI 可访问性
echo "[7/8] 检查服务状态..."
echo ""

echo "--- Gateway 状态 ---"
openclaw status 2>&1 | head -10 || echo "[提示] 服务可能正在启动"

echo ""
echo "--- 健康检查 ---"
openclaw health 2>&1 | head -10 || echo "[提示] 服务可能正在启动"

echo ""
echo "--- Control UI 状态 ---"

# 检查端口
if command -v ss &> /dev/null; then
    PORT_STATUS=$(ss -tlnp | grep 18789 || echo "")
elif command -v netstat &> /dev/null; then
    PORT_STATUS=$(netstat -tlnp | grep 18789 || echo "")
else
    PORT_STATUS=""
fi

if [ -n "$PORT_STATUS" ]; then
    echo "[√] 端口 18789 正在监听"
    
    # 使用 curl 测试 UI 可访问性
    if command -v curl &> /dev/null; then
        echo "[信息] 测试 Control UI 访问..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/ 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "[√] Control UI 可访问！"
            echo "[√] UI 测试通过"
        elif [ "$HTTP_CODE" = "404" ]; then
            echo "[提示] Control UI 返回 404（官方已知 bug）"
            echo "[提示] UI 文件存在但路由检测有问题"
            echo "[参考] https://github.com/openclaw/openclaw/issues/4855"
        else
            echo "[提示] Control UI 返回 HTTP $HTTP_CODE"
            echo "[提示] 服务可能还未完全启动"
        fi
    else
        echo "[提示] 未安装 curl，跳过 UI 测试"
    fi
else
    echo "[提示] 端口 18789 未在监听，服务可能正在启动"
fi

echo ""

# 6. 最终验证
echo "[7/8] 最终验证..."
echo ""

# 验证 openclaw 命令
if command -v openclaw &> /dev/null; then
    echo "[√] openclaw 命令可用"
    echo "    路径：$(which openclaw)"
else
    echo "[×] openclaw 命令不可用"
    echo "[提示] 请手动运行以下命令："
    echo "  export PATH=\"$NPM_GLOBAL_BIN:\$PATH\""
    echo "  echo 'export PATH=\"$NPM_GLOBAL_BIN:\$PATH\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
fi

# 验证环境变量
echo ""
echo "--- 环境变量检查 ---"
echo "PATH 中的 npm 路径："
echo "$PATH" | tr ':' '\n' | grep npm || echo "[提示] npm 路径不在 PATH 中"

# 配置 WSL2 端口转发（Windows 访问必需）
echo ""
echo "============================================================"
echo "  WSL2 端口转发配置（从 Windows 访问必需）"
echo "============================================================"

# 检查是否在 WSL 环境中
if [ -f /etc/wsl.conf ]; then
    echo "[信息] 检测到 WSL 环境"

    # 获取 WSL IP 地址
    WSL_IP=$(hostname -I | awk '{print $1}')
    echo "[信息] WSL IP 地址：$WSL_IP"
    echo ""

    # 尝试自动配置端口转发
    echo "[信息] 尝试自动配置端口转发..."
    SETUP_SCRIPT="$(dirname "$0")/setup-portforward.sh"
    if [ -f "$SETUP_SCRIPT" ]; then
        echo "[信息] 运行端口转发配置脚本..."
        bash "$SETUP_SCRIPT"
    else
        echo "[提示] 端口转发脚本未找到，请手动配置"
    fi

    echo ""
    echo "[手动配置方法]"
    echo "如果自动配置失败，请在 Windows PowerShell (管理员) 中运行："
    echo ""
    echo "  netsh interface portproxy add v4tov4 listenport=18789 listenaddress=0.0.0.0 connectport=18789 connectaddress=$WSL_IP"
    echo "  netsh advfirewall firewall add rule name=\"WSL Gateway\" dir=in action=allow protocol=TCP localport=18789"
    echo ""
else
    echo "[信息] 非 WSL 环境，跳过端口转发配置"
fi
echo ""

echo ""
echo "============================================================"
echo "  配置完成！"
echo "============================================================"
echo ""
echo "[完成] OpenClaw 已配置完成"
echo ""
echo "[访问地址]"
echo "- Control UI: http://localhost:18789/"
echo "- Windows 访问：配置端口转发后使用相同地址"
echo ""
echo "[网关认证]"
echo "- 认证模式：Token 认证"
echo "- Gateway Token: $TOKEN"
echo "- Token 已保存到：$CONFIG_DIR/gateway.token"
echo "- 在 Control UI 页面输入 Token 即可连接"
echo ""
echo "[常用命令]"
echo "- openclaw --help       查看帮助"
echo "- openclaw models list  查看可用模型"
echo "- openclaw models set   设置默认模型"
echo "- openclaw status       检查服务状态"
echo "- openclaw health       健康检查"
echo "- openclaw doctor       运行诊断"
echo "- openclaw channels list 查看已配置的渠道"
echo ""
echo "[飞书插件]"
echo "- 插件已自动安装到：$CONFIG_DIR/extensions/feishu"
echo "- 旧版本已备份到：$CONFIG_DIR/extensions/feishu.backup.*"
echo "- 配置凭证请运行：bash setup-feishu.sh"
echo "- 或在 Control UI 中配置 App ID 和 App Secret"
echo ""
echo "[日志文件]"
echo "- Gateway 日志：/tmp/openclaw-gateway.log"
echo "- 查看日志：tail -f /tmp/openclaw-gateway.log"
echo ""

read -p "按回车键退出"
