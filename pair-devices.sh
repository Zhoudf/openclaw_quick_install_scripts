#!/bin/bash
# ============================================================
# OpenClaw 设备配对脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 用法：
#   bash pair-devices.sh
#
# 此脚本处理设备配对请求，包括：
# - 清除旧的配对设备
# - 批准待配对的设备
# - 后台监控并自动批准新设备
#
# 参考 Issue:
# - https://github.com/openclaw/openclaw/issues/4855
# - https://github.com/openclaw/openclaw/issues/14416
# ============================================================

set -e

echo ""
echo "============================================================"
echo "  OpenClaw 设备配对"
echo "============================================================"
echo ""

# 自动批准设备配对请求（Token 认证需要）
echo "[信息] 处理设备配对..."
sleep 3  # 等待服务完全启动

if command -v openclaw &> /dev/null; then
    # 清除旧的配对设备（避免冲突）
    echo "[信息] 清除旧的配对设备..."
    openclaw devices clear 2>/dev/null || true

    # 检查是否有待配对的设备
    PENDING=$(openclaw devices list 2>/dev/null | grep -c "Pending" || true)
    PENDING=${PENDING:-0}
    if [ "$PENDING" -gt 0 ] 2>/dev/null; then
        echo "[信息] 发现 $PENDING 个待配对设备，正在批准..."
        openclaw devices approve --latest 2>/dev/null && echo "[√] 设备配对已批准" || echo "[提示] 配对可能需要手动确认"
    fi

    # 持续监控并自动批准新设备（后台运行）
    echo "[信息] 启动设备配对监控..."
    (
        for i in {1..10}; do
            sleep 5
            PENDING_COUNT=$(openclaw devices list 2>/dev/null | grep -c "Pending" || true)
            PENDING_COUNT=${PENDING_COUNT:-0}
            if [ "$PENDING_COUNT" -gt 0 ] 2>/dev/null; then
                openclaw devices approve --latest 2>/dev/null || true
            fi
        done
    ) &
    echo "[√] 设备配对监控已启动（后台运行 50 秒）"
else
    echo "[×] openclaw 命令未找到"
    exit 1
fi

echo ""
echo "============================================================"
echo "  设备配对完成！"
echo "============================================================"
echo ""
echo "[提示] 设备配对监控将在后台运行 50 秒"
echo "[提示] 新设备将自动批准"
echo ""
