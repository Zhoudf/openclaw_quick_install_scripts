#!/bin/bash

# ============================================================
# OpenClaw 飞书插件安装脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash install-feishu-plugin.sh
#
# 功能：
# - 安装飞书插件 @openclaw/feishu
# - 验证插件安装状态
# - 提示后续配置步骤
#
# 注意：
# - 此脚本仅安装插件，不配置凭证
# - 配置 App ID 和 App Secret 请运行：bash setup-feishu.sh
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 飞书插件安装"
echo "============================================================"
echo ""

# 检查 OpenClaw 是否安装
if ! command -v openclaw &> /dev/null; then
    echo "[×] openclaw 命令未找到"
    echo "[提示] 请先安装 OpenClaw："
    echo "       bash install-nodejs-openclaw.sh"
    exit 1
fi

OPENCLAW_VERSION=$(openclaw --version 2>&1 | head -1)
echo "[√] OpenClaw 已安装：$OPENCLAW_VERSION"
echo ""

# 检查是否已安装飞书插件
CONFIG_DIR="$HOME/.openclaw"
EXTENSIONS_DIR="$CONFIG_DIR/extensions/feishu"

if [ -d "$EXTENSIONS_DIR" ]; then
    echo "[提示] 检测到飞书插件已安装"
    echo ""
    read -p "是否重新安装？(Y/N): " REINSTALL
    if [ "$REINSTALL" != "Y" ] && [ "$REINSTALL" != "y" ]; then
        echo "[信息] 已跳过安装"
        echo ""
        echo "[提示] 配置飞书凭证请运行：bash setup-feishu.sh"
        exit 0
    else
        echo "[信息] 正在重新安装飞书插件..."
    fi
fi

echo "============================================================"
echo "  安装飞书插件"
echo "============================================================"
echo ""
echo "[信息] 正在下载并安装 @openclaw/feishu..."
echo ""

# 安装飞书插件
openclaw plugins install @openclaw/feishu

if [ $? -eq 0 ]; then
    echo ""
    echo "[√] 飞书插件安装成功"
else
    echo ""
    echo "[×] 飞书插件安装失败"
    echo "[提示] 请检查网络连接或手动安装："
    echo "       openclaw plugins install @openclaw/feishu"
    exit 1
fi

echo ""
echo "============================================================"
echo "  安装完成！"
echo "============================================================"
echo ""
echo "[完成] 飞书插件已安装到：$EXTENSIONS_DIR"
echo ""
echo "[下一步操作]"
echo "1. 配置飞书凭证：bash setup-feishu.sh"
echo "2. 或在 Control UI 中配置渠道"
echo ""
echo "[常用命令]"
echo "- openclaw channels list     查看已配置的渠道"
echo "- openclaw plugins list      查看已安装的插件"
echo "- openclaw status            检查服务状态"
echo ""
echo "[注意]"
echo "安装飞书插件后，首次启动 Gateway 可能会看到插件相关警告"
echo "这属于正常现象，配置凭证后会自动消失"
echo ""

read -p "按回车键退出"
