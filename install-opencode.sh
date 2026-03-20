#!/bin/bash

# ============================================================
# OpenCode CLI 安装脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash install-opencode.sh
#
# 功能：
# - 检查系统依赖（Node.js, npm）
# - 使用 npm 安装 OpenCode CLI
# - 验证安装
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenCode CLI 安装"
echo "============================================================"
echo ""

# ============================================================
# 1. 检查系统依赖
# ============================================================
echo "============================================================"
echo "  步骤 1: 检查系统依赖"
echo "============================================================"
echo ""

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "[×] Node.js 未安装"
    echo "[提示] 请先安装 Node.js:"
    echo "  - Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "  - macOS: brew install node"
    echo "  - Windows: 访问 https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v)
echo "[√] Node.js 已安装：$NODE_VERSION"

# 检查 npm
if ! command -v npm &> /dev/null; then
    echo "[×] npm 未安装"
    echo "[提示] 请安装 npm（通常与 Node.js 一起安装）"
    exit 1
fi

NPM_VERSION=$(npm -v)
echo "[√] npm 已安装：$NPM_VERSION"

echo ""

# ============================================================
# 2. 安装 OpenCode CLI
# ============================================================
echo "============================================================"
echo "  步骤 2: 安装 OpenCode CLI"
echo "============================================================"
echo ""

echo "[信息] 使用 npm 安装最新版 (opencode-ai)..."
npm install -g opencode-ai 2>&1 || {
    echo "[警告] 安装失败，可能是权限问题"
    echo "[提示] 尝试使用以下命令："
    echo "  sudo npm install -g opencode-ai --unsafe-perm"
    exit 1
}

# 验证安装
echo ""
echo "[信息] 验证安装..."
if command -v opencode-ai &> /dev/null; then
    OPENCODE_VERSION=$(opencode-ai --version 2>&1 || echo "未知")
    echo "[√] OpenCode CLI 已安装：$OPENCODE_VERSION"
else
    echo "[×] opencode-ai 命令未找到"
    echo "[提示] 请检查 npm 全局路径是否在 PATH 中"
    echo "[提示] 通常路径为：~/.npm-global/bin 或 /usr/local/bin"
    exit 1
fi

echo ""

# ============================================================
# 3. 配置目录
# ============================================================
echo "============================================================"
echo "  步骤 3: 配置目录"
echo "============================================================"
echo ""

CONFIG_DIR="$HOME/.opencode"

if [ -d "$CONFIG_DIR" ]; then
    echo "[提示] 配置目录已存在：$CONFIG_DIR"
else
    echo "[信息] 创建配置目录..."
    mkdir -p "$CONFIG_DIR"
    echo "[√] 配置目录已创建：$CONFIG_DIR"
fi

echo ""

# ============================================================
# 完成
# ============================================================
echo "============================================================"
echo "  安装完成！"
echo "============================================================"
echo ""

echo "[完成] OpenCode CLI 安装完成"
echo ""
echo "[安装路径] $(which opencode-ai)"
echo "[配置目录] $CONFIG_DIR"
echo ""
echo "[常用命令]"
echo "- opencode-ai --help      查看帮助"
echo "- opencode-ai --version   查看版本"
echo "- opencode-ai <command>   执行命令"
echo ""
echo "[下一步]"
echo "1. 运行 'opencode-ai --help' 查看可用命令"
echo "2. 开始使用 OpenCode CLI 进行开发！"
echo ""

read -p "按回车键退出"
