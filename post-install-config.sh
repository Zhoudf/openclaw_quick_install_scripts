#!/bin/bash

# ============================================================
# OpenClaw 安装后自动配置脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：bash post-install-config.sh
# ============================================================

echo ""
echo "============================================================"
echo "  OpenClaw 安装后配置"
echo "============================================================"
echo ""

# 步骤 1: 刷新环境变量
echo "[步骤 1/4] 刷新环境变量..."
. ~/.bashrc 2>/dev/null || true
export PATH="$HOME/.npm-global/bin:$PATH" 2>/dev/null || true
hash -r
echo "[√] 环境变量已刷新"
echo ""

# 步骤 2: 验证 OpenClaw 安装
echo "[步骤 2/4] 验证 OpenClaw 安装..."
if command -v openclaw &> /dev/null; then
    echo "[√] OpenClaw 已安装"
    echo "版本信息："
    openclaw --version 2>&1 | head -3
else
    echo "[×] OpenClaw 未找到，请检查安装"
    echo ""
    echo "[提示] 请运行：bash install-nodejs-openclaw.sh 重新安装"
    echo ""
    read -p "按回车键退出"
    exit 1
fi
echo ""

# 步骤 3: 询问是否运行新手引导
echo "============================================================"
echo "  新手引导配置"
echo "============================================================"
echo ""
echo "新手引导会帮你配置："
echo "- API Key（模型提供商）"
echo "- Daemon 服务"
echo "- 其他设置"
echo ""
echo "如果你已经有 API Key，可以选择自动配置"
echo "如果需要手动选择配置项，建议选择手动引导"
echo ""

read -p "是否运行新手引导？(Y/N): " RUN_ONBOARD

if [ "$RUN_ONBOARD" = "Y" ] || [ "$RUN_ONBOARD" = "y" ]; then
    echo ""
    echo "[信息] 启动新手引导..."
    echo ""
    
    # 检查是否使用自动模式
    read -p "是否使用自动模式安装 Daemon？(Y/N): " AUTO_DAEMON
    
    if [ "$AUTO_DAEMON" = "Y" ] || [ "$AUTO_DAEMON" = "y" ]; then
        echo "[信息] 自动安装 Daemon..."
        openclaw onboard --install-daemon
    else
        echo "[信息] 启动交互式引导..."
        openclaw onboard
    fi
else
    echo "[信息] 跳过新手引导"
    echo "[提示] 之后可以手动运行：openclaw onboard"
fi

echo ""

# 步骤 4: 验证服务状态
echo "============================================================"
echo "  服务状态检查"
echo "============================================================"
echo ""

echo "[信息] 检查 Gateway 状态..."
openclaw status 2>&1 | head -20 || echo "[提示] 服务可能未启动"

echo ""
echo "[信息] 运行健康检查..."
openclaw doctor 2>&1 | head -20 || echo "[提示] 服务可能未启动"

echo ""

# 完成
echo "============================================================"
echo "  配置完成！"
echo "============================================================"
echo ""
echo "[完成] OpenClaw 已配置完成"
echo ""
echo "[下一步操作]"
echo "1. 如果还没有配置 API Key，运行：openclaw onboard"
echo "2. 打开仪表板：openclaw dashboard"
echo "3. 开始使用 OpenClaw！"
echo ""
echo "[常用命令]"
echo "- openclaw --help       查看帮助"
echo "- openclaw status       检查服务状态"
echo "- openclaw health       健康检查"
echo "- openclaw doctor       运行诊断"
echo "- openclaw dashboard    打开仪表板"
echo ""

read -p "按回车键退出"
