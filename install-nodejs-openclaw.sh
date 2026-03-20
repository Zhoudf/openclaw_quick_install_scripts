#!/bin/bash

# ============================================================
# Ubuntu 24.04 自动安装脚本 (Node.js + OpenClaw)
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 此脚本在 WSL Ubuntu 内部运行，自动安装：
# 1. 系统更新
# 2. Node.js 24 LTS (使用国内/官方源)
# 3. OpenClaw
# ============================================================

echo ""
echo "============================================================"
echo "  Ubuntu 24.04 自动配置脚本 - Node.js + OpenClaw"
echo "============================================================"
echo ""

# 检查是否在 WSL 环境中运行
if [ ! -f /etc/wsl.conf ]; then
    echo "[错误] 此脚本必须在 WSL Ubuntu 内部运行！"
    echo ""
    echo "使用方法："
    echo "1. 首先启动 Ubuntu: wsl -d Ubuntu-24.04"
    echo "2. 然后运行：bash install-nodejs-openclaw.sh"
    echo ""
    read -p "按回车键退出"
    exit 1
fi

echo "[√] 检测到 WSL 环境"
echo ""

# 询问是否继续
read -p "是否继续安装 Node.js 和 OpenClaw？(Y/N): " CONFIRM
if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "y" ]; then
    echo "[信息] 安装已取消"
    read -p "按回车键退出"
    exit 0
fi

# 选择安装源
echo ""
echo "============================================================"
echo "  选择安装源"
echo "============================================================"
echo ""
echo "请选择软件源配置："
echo "  1. 国内镜像源 (推荐中国大陆用户)"
echo "     - Node.js: 使用 NodeSource 官方源 (需科学上网)"
echo "     - npm: 使用淘宝镜像"
echo "  2. 官方源 (推荐海外用户)"
echo "     - Node.js: NodeSource 官方源"
echo "     - npm: npm 官方源"
echo ""
read -p "请选择 (1/2, 默认=1): " INSTALL_SOURCE_CHOICE

# 默认使用国内镜像（npm 用淘宝，NodeSource 用官方）
INSTALL_SOURCE_CHOICE=${INSTALL_SOURCE_CHOICE:-1}

if [ "$INSTALL_SOURCE_CHOICE" = "2" ]; then
    NODE_SETUP_URL="https://deb.nodesource.com/setup_24.x"
    NPM_REGISTRY="https://registry.npmjs.org"
    echo "[信息] 已选择：官方源"
else
    NODE_SETUP_URL="https://deb.nodesource.com/setup_24.x"
    NPM_REGISTRY="https://registry.npmmirror.com"
    echo "[信息] 已选择：混合模式"
    echo "[提示] Node.js 从 NodeSource 安装，npm 包从淘宝镜像下载"
fi
echo ""

# 选择是否更新系统依赖
echo "============================================================"
echo "  系统依赖配置"
echo "============================================================"
echo ""
echo "是否更新系统并安装基础依赖？(curl, git, build-essential)"
echo "  1. 是，更新并安装依赖 (首次安装推荐)"
echo "  2. 否，跳过此步骤 (已安装过可跳过)"
echo ""
read -p "请选择 (1/2, 默认=1): " UPDATE_SYSTEM_CHOICE

# 默认执行系统更新
UPDATE_SYSTEM_CHOICE=${UPDATE_SYSTEM_CHOICE:-1}

if [ "$UPDATE_SYSTEM_CHOICE" = "2" ]; then
    echo "[信息] 跳过系统更新"
else
    echo "[信息] 正在更新系统并安装依赖..."
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl git build-essential
    echo "[√] 系统更新完成"
fi
echo ""

# 步骤 1: 安装 Node.js 24 LTS
echo "------------------------------------------------------------"
echo "[步骤 1/2] 安装 Node.js 24 LTS..."
echo "------------------------------------------------------------"
echo ""
echo "请选择 Node.js 安装方式："
echo "  1. 使用 NodeSource 源安装 (系统级，推荐)"
echo "  2. 使用 fnm 安装 (用户级，可切换版本)"
echo ""
read -p "请选择 (1/2, 默认=1): " NODE_INSTALL_METHOD

NODE_INSTALL_METHOD=${NODE_INSTALL_METHOD:-1}

if [ "$NODE_INSTALL_METHOD" = "2" ]; then
    # 使用 fnm 安装 Node.js
    echo "[信息] 正在安装 fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash

    export FNM_DIR="$HOME/.fnm"
    export PATH="$HOME/.fnm:$PATH"
    source ~/.bashrc

    echo "[信息] 正在安装 Node.js 24..."
    fnm install 24
    fnm use 24
    fnm default 24

    # 配置 npm 源
    npm config set registry "$NPM_REGISTRY"
else
    # 使用 NodeSource 安装
    echo "[信息] 正在配置 NodeSource 源..."

    # 检查是否已安装旧版本 Node.js
    if command -v node &> /dev/null; then
        CURRENT_NODE=$(node --version)
        echo "[提示] 检测到已安装 Node.js $CURRENT_NODE"
        read -p "是否覆盖安装 Node.js 24？(Y/N, 默认=Y): " OVERWRITE_NODE
        OVERWRITE_NODE=${OVERWRITE_NODE:-Y}
        if [ "$OVERWRITE_NODE" = "Y" ] || [ "$OVERWRITE_NODE" = "y" ]; then
            echo "[信息] 正在卸载旧版本 Node.js..."
            sudo apt remove -y nodejs npm 2>/dev/null || true
            sudo apt autoremove -y 2>/dev/null || true
        fi
    fi

    # 下载并运行 NodeSource 安装脚本
    curl -fsSL "$NODE_SETUP_URL" | sudo -E bash -

    # 安装 Node.js
    sudo apt-get install -y nodejs

    # 配置 npm 源
    npm config set registry "$NPM_REGISTRY"
fi

echo "[√] Node.js 24 安装完成"
echo "Node 版本："
node --version
echo "NPM 版本："
npm --version
echo ""

# 步骤 2: 安装 OpenClaw
echo "------------------------------------------------------------"
echo "[步骤 2/2] 安装 OpenClaw..."
echo "------------------------------------------------------------"
echo ""
echo "请选择 OpenClaw 安装方式："
echo "  1. 正常安装 (推荐，使用官方 npm 源)"
echo "  2. 使用备用源安装 (如果方式 1 失败)"
echo "  3. 跳过 Git 依赖安装 (忽略 libsignal-node 错误)"
echo ""
read -p "请选择 (1/2/3, 默认=1): " OPENCLAW_INSTALL_CHOICE

OPENCLAW_INSTALL_CHOICE=${OPENCLAW_INSTALL_CHOICE:-1}

# 配置 npm 全局安装到用户目录（避免权限问题）
NPM_GLOBAL_DIR="$HOME/.npm-global"
mkdir -p "$NPM_GLOBAL_DIR"
npm config set prefix "$NPM_GLOBAL_DIR"

# 配置 npm 源
npm config set registry "$NPM_REGISTRY"
echo "[信息] npm 源已配置：$NPM_REGISTRY"

# 添加到 PATH（如果还没有）
# 同时配置 ~/.bashrc 和 ~/.profile 确保在所有 shell 会话中生效
if ! grep -q "npm-global" ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# NPM Global Packages' >> ~/.bashrc
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi

if ! grep -q "npm-global" ~/.profile 2>/dev/null; then
    echo '' >> ~/.profile
    echo '# NPM Global Packages' >> ~/.profile
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
fi

# 立即导出 PATH 变量，让当前会话也能使用
export PATH="$NPM_GLOBAL_DIR/bin:$PATH"

echo "[信息] npm 全局包安装路径：$NPM_GLOBAL_DIR"
echo ""

# 配置 Git 使用 HTTPS 而不是 SSH（避免 Permission denied 错误）
git config --global url."https://github.com/".insteadOf ssh://git@github.com/ 2>/dev/null || true
echo "[信息] 已配置 Git 使用 HTTPS 访问 GitHub"
echo ""

# 尝试安装 OpenClaw（不需要 sudo）
echo "[信息] 正在安装 OpenClaw..."

if [ "$OPENCLAW_INSTALL_CHOICE" = "3" ]; then
    # 方式 3: 跳过 Git 依赖
    echo "[信息] 使用跳过 Git 依赖方式安装..."
    npm install -g openclaw@latest --ignore-scripts --legacy-peer-deps 2>/dev/null || \
    npm install -g openclaw@latest --ignore-scripts --force 2>/dev/null || \
    SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest --ignore-scripts
elif [ "$OPENCLAW_INSTALL_CHOICE" = "2" ]; then
    # 方式 2: 使用备用源
    echo "[信息] 使用备用方式安装..."
    npm install -g openclaw@latest --legacy-peer-deps 2>/dev/null || \
    npm install -g openclaw@latest --force 2>/dev/null || \
    SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest --legacy-peer-deps
else
    # 方式 1: 正常安装
    echo "[信息] 使用标准方式安装..."
    npm install -g openclaw@latest 2>/dev/null || \
    npm install -g openclaw@latest --legacy-peer-deps 2>/dev/null || \
    SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest --legacy-peer-deps
fi

if command -v openclaw &> /dev/null || command -v open-claw &> /dev/null; then
    echo "[√] OpenClaw 安装成功！"
else
    echo "[警告] OpenClaw 安装可能失败，请检查错误信息"
fi

# 刷新 hash 缓存，确保新安装的命令立即可用
hash -r

echo ""
echo "[验证] 检查 OpenClaw 安装..."
# 检查 openclaw 可执行文件是否存在
if [ -f "$NPM_GLOBAL_DIR/bin/openclaw" ]; then
    echo "[√] openclaw 可执行文件已创建：$NPM_GLOBAL_DIR/bin/openclaw"
    "$NPM_GLOBAL_DIR/bin/openclaw" --version
else
    echo "[警告] openclaw 可执行文件未找到，尝试使用 open-claw..."
    if [ -f "$NPM_GLOBAL_DIR/bin/open-claw" ]; then
        echo "[√] open-claw 可执行文件已创建：$NPM_GLOBAL_DIR/bin/open-claw"
        "$NPM_GLOBAL_DIR/bin/open-claw" --version
    else
        echo "[错误] 未找到 openclaw 可执行文件"
        echo "npm 全局包目录内容："
        ls -la "$NPM_GLOBAL_DIR/bin/" 2>/dev/null || echo "目录不存在"
    fi
fi
echo ""

# 完成
echo "============================================================"
echo "  安装完成！"
echo "============================================================"
echo ""
echo "[完成] Node.js 24 和 OpenClaw 已成功安装"
echo "[下一步操作]"
echo "1. 运行新手引导：openclaw onboard --install-daemon"
echo "2. 配置你的 API Key 和模型提供商"
echo "3. 开始使用 OpenClaw！"
echo ""
echo "[有用的命令]"
echo "- openclaw --version    查看 OpenClaw 版本"
echo "- openclaw doctor       运行健康检查"
echo "- openclaw --help       查看帮助"
echo ""
# 自动重新加载 bashrc，让 openclaw 命令立即生效
echo "[信息] 正在重新加载 shell 配置..."
source ~/.bashrc
hash -r

echo ""
echo "[测试] 验证 openclaw 命令..."
if command -v openclaw &> /dev/null; then
    echo "[√] openclaw 命令已可用！"
    openclaw --version
else
    echo "[警告] openclaw 命令仍未生效，请手动执行：source ~/.bashrc"
fi
echo ""

read -p "按回车键退出"
