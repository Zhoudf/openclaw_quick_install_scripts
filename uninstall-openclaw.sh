#!/bin/bash
# ============================================================
# Ubuntu 24.04 OpenClaw + Node.js 完全卸载脚本
# ============================================================
# 作者：AI 大玩家 Eddie
# 微信：dev_eddie
# ============================================================
# 此脚本在 WSL Ubuntu 内部运行，用于完全卸载 OpenClaw 和 Node.js
# ============================================================

echo ""
echo "============================================================"
echo "  OpenClaw + Node.js 完全卸载脚本"
echo "============================================================"
echo ""

# 检查是否在 WSL 环境中运行
if [ ! -f /etc/wsl.conf ]; then
    echo "[错误] 此脚本必须在 WSL Ubuntu 内部运行！"
    echo ""
    echo "使用方法："
    echo "1. 首先启动 Ubuntu: wsl -d Ubuntu-24.04"
    echo "2. 然后运行：bash uninstall-openclaw.sh"
    echo ""
    read -p "按回车键退出"
    exit 1
fi

echo "[√] 检测到 WSL 环境"
echo ""

# 询问卸载范围
echo "------------------------------------------------------------"
echo "[信息] 请选择卸载范围："
echo "------------------------------------------------------------"
echo "1. 仅卸载 OpenClaw（保留 Node.js，可重新安装 OpenClaw）"
echo "2. 完全卸载 OpenClaw + Node.js（推荐，如果要彻底清理）"
echo ""

read -p "请选择 (1/2，默认=2): " UNINSTALL_CHOICE

if [ "$UNINSTALL_CHOICE" = "1" ]; then
    FULL_UNINSTALL=false
    echo "[信息] 将仅卸载 OpenClaw，保留 Node.js"
else
    FULL_UNINSTALL=true
    echo "[信息] 将完全卸载 OpenClaw 和 Node.js"
fi
echo ""

# 询问是否继续
if [ "$FULL_UNINSTALL" = true ]; then
    read -p "是否继续完全卸载？(Y/N): " CONFIRM
else
    read -p "是否继续卸载 OpenClaw？(Y/N): " CONFIRM
fi

if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "y" ]; then
    echo "[信息] 卸载已取消"
    read -p "按回车键退出"
    exit 0
fi

echo ""
echo "------------------------------------------------------------"
echo "[步骤 1/5] 停止 OpenClaw 服务..."
echo "------------------------------------------------------------"

# 停止并禁用 systemd 服务（如果存在）
if command -v systemctl &> /dev/null; then
    systemctl --user stop openclaw 2>/dev/null && echo "[√] 已停止 openclaw 服务"
    systemctl --user disable openclaw 2>/dev/null && echo "[√] 已禁用 openclaw 服务"
else
    echo "[信息] 未检测到 systemd，跳过服务停止"
fi

# 停止 pm2 进程（如果使用）
if command -v pm2 &> /dev/null; then
    pm2 stop openclaw 2>/dev/null
    pm2 delete openclaw 2>/dev/null
    echo "[√] 已停止 pm2 进程"
fi

echo ""
echo "------------------------------------------------------------"
echo "[步骤 2/5] 卸载 OpenClaw npm 包..."
echo "------------------------------------------------------------"

# 卸载全局 openclaw 包
npm uninstall -g openclaw 2>/dev/null
if [ $? -eq 0 ]; then
    echo "[√] OpenClaw 已从全局 npm 包中卸载"
else
    echo "[警告] 卸载可能失败，尝试强制卸载..."
    npm uninstall -g openclaw --force
fi

# 清理 npm 缓存
read -p "是否清理 npm 缓存？(推荐，Y/N): " CLEAN_CACHE
if [ "$CLEAN_CACHE" = "Y" ] || [ "$CLEAN_CACHE" = "y" ]; then
    npm cache clean --force
    echo "[√] npm 缓存已清理"
fi

# 如果选择完全卸载，删除 Node.js 和 nvm
echo ""
if [ "$FULL_UNINSTALL" = true ]; then
    echo "------------------------------------------------------------"
    echo "[步骤 3/5] 卸载 Node.js 和 nvm ..."
    echo "------------------------------------------------------------"
    
    # 检查是否安装了 nvm
    if [ -d "$HOME/.nvm" ]; then
        echo "[信息] 检测到 nvm (Node Version Manager) 目录"
        read -p "是否也卸载 nvm？(Y/N): " REMOVE_NVM
        
        if [ "$REMOVE_NVM" = "Y" ] || [ "$REMOVE_NVM" = "y" ]; then
            # 尝试卸载 nvm 管理的 Node.js 版本
            if [ -s "$HOME/.nvm/nvm.sh" ]; then
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
                nvm use --delete-prefix 2>/dev/null || true
                nvm alias default 'system' 2>/dev/null || true
                nvm unload 2>/dev/null || true
            fi
            
            # 删除 nvm 目录
            rm -rf "$HOME/.nvm"
            echo "[√] 已删除 nvm 目录"
            
            # 从 bashrc 中移除 nvm 配置
            if grep -q "NVM_DIR" ~/.bashrc; then
                # 创建备份（如果还没有）
                if [ ! -f ~/.bashrc.backup.nvm ]; then
                    cp ~/.bashrc ~/.bashrc.backup.nvm
                    echo "[√] 已创建 ~/.bashrc 备份：~/.bashrc.backup.nvm"
                fi
                
                # 移除 nvm 相关行
                sed -i '/export NVM_DIR/d' ~/.bashrc
                sed -i '/\[ -s "\$NVM_DIR\/nvm.sh" \]/d' ~/.bashrc
                sed -i '/\[ -s "\$NVM_DIR\/bash_completion/d' ~/.bashrc
                
                echo "[√] 已从 ~/.bashrc 中移除 nvm 配置"
            fi
            
            echo "[√] nvm 已卸载"
        else
            echo "[信息] 保留 nvm"
        fi
    else
        echo "[信息] 未检测到 nvm"
    fi
    
    # 检查并卸载 apt 安装的 Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo "[信息] 当前 Node.js 版本：$NODE_VERSION"
        
        # 检查是否通过 apt 安装
        if dpkg -l | grep -q nodejs; then
            # 卸载 Node.js
            sudo apt remove -y nodejs
            sudo apt autoremove -y
            
            # 移除 NodeSource 源（如果存在）
            if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
                sudo rm /etc/apt/sources.list.d/nodesource.list
                echo "[√] 已移除 NodeSource 源"
            fi
            
            echo "[√] Node.js (apt) 已卸载"
        else
            echo "[信息] Node.js 可能通过 nvm 安装，apt 未安装 Node.js"
        fi
    else
        echo "[信息] Node.js 未检测到（可能已通过 nvm 卸载）"
    fi
    
    # 清理 npm 全局包目录
    if [ -d ~/.npm-global ]; then
        rm -rf ~/.npm-global
        echo "[√] 已删除 npm 全局包目录"
    fi
else
    echo "[信息] 保留 Node.js，跳过卸载"
fi

echo ""
echo "------------------------------------------------------------"
echo "[步骤 4/5] 清理配置文件和数据..."
echo "------------------------------------------------------------"

# 列出可能存在的配置目录
OPENCLAW_DIRS=(
    "$HOME/.openclaw"
    "$HOME/.config/openclaw"
    "$HOME/.local/share/openclaw"
)

FOUND_DIRS=()
for dir in "${OPENCLAW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        FOUND_DIRS+=("$dir")
    fi
done

if [ ${#FOUND_DIRS[@]} -gt 0 ]; then
    echo "[信息] 发现以下 OpenClaw 配置目录："
    for dir in "${FOUND_DIRS[@]}"; do
        echo "  - $dir"
    done
    echo ""
    read -p "是否删除这些配置目录？(警告：这将删除所有配置和数据，Y/N): " DELETE_CONFIG
    if [ "$DELETE_CONFIG" = "Y" ] || [ "$DELETE_CONFIG" = "y" ]; then
        for dir in "${FOUND_DIRS[@]}"; do
            rm -rf "$dir"
            echo "[√] 已删除：$dir"
        done
    else
        echo "[信息] 保留配置目录"
    fi
else
    echo "[信息] 未发现 OpenClaw 配置目录"
fi

# 清理 bashrc 中的 npm-global 配置（如果用户选择）
echo ""
if grep -q "npm-global" ~/.bashrc; then
    read -p "是否从 ~/.bashrc 中移除 npm-global PATH 配置？(Y/N): " REMOVE_PATH
    if [ "$REMOVE_PATH" = "Y" ] || [ "$REMOVE_PATH" = "y" ]; then
        # 创建备份
        cp ~/.bashrc ~/.bashrc.backup.openclaw
        echo "[√] 已创建 ~/.bashrc 备份：~/.bashrc.backup.openclaw"
        
        # 移除相关行
        sed -i '/# NPM Global Packages/d' ~/.bashrc
        sed -i '/export PATH="\$HOME\/.npm-global\/bin:\$PATH"/d' ~/.bashrc
        sed -i '/^$/N;/^\n$/d' ~/.bashrc
        
        echo "[√] 已从 ~/.bashrc 中移除 npm-global 配置"
    fi
fi

# 如果完全卸载，移除 Node.js 相关的 PATH 配置
if [ "$FULL_UNINSTALL" = true ]; then
    if grep -q "/.npm-global" ~/.bashrc; then
        # 如果之前没有备份，创建备份
        if [ ! -f ~/.bashrc.backup.openclaw ]; then
            cp ~/.bashrc ~/.bashrc.backup.openclaw
            echo "[√] 已创建 ~/.bashrc 备份：~/.bashrc.backup.openclaw"
        fi
    fi
fi

echo ""
echo "------------------------------------------------------------"
echo "[步骤 5/5] 刷新环境变量..."
echo "------------------------------------------------------------"

# 刷新 hash 缓存
hash -r

# 重新加载 bashrc
source ~/.bashrc

echo "[√] 环境变量已刷新"

echo ""
echo "============================================================"
echo "  卸载完成！"
echo "============================================================"
echo ""

if [ "$FULL_UNINSTALL" = true ]; then
    echo "[完成] OpenClaw 和 Node.js 已成功完全卸载"
else
    echo "[完成] OpenClaw 已成功卸载（Node.js 已保留）"
fi

echo ""
echo "[验证卸载]"
echo "- 运行：which openclaw    (应该无输出或显示未找到)"
echo "- 运行：openclaw --version (应该显示 command not found)"

if [ "$FULL_UNINSTALL" = true ]; then
    echo "- 运行：node --version   (应该显示 command not found)"
    echo "- 运行：npm --version    (应该显示 command not found)"
    echo "- 检查：ls ~/.nvm        (应该显示 No such file or directory)"
    
    # 检查 nvm 备份
    if [ -f ~/.bashrc.backup.nvm ]; then
        echo ""
        echo "[提示] 发现 nvm 配置备份：~/.bashrc.backup.nvm"
        echo "       如果要恢复 nvm，可以从备份中恢复配置"
    fi
fi

echo ""
echo "[保留的文件]"
if [ ${#FOUND_DIRS[@]} -gt 0 ] && [ "$DELETE_CONFIG" != "Y" ] && [ "$DELETE_CONFIG" != "y" ]; then
    echo "- 配置文件保留在以上列出的目录中"
fi
if [ -f ~/.bashrc.backup.openclaw ]; then
    echo "- ~/.bashrc 备份：~/.bashrc.backup.openclaw"
fi
echo ""

if [ "$FULL_UNINSTALL" = true ]; then
    echo "[重新安装]"
    echo "- 重新安装 Node.js + OpenClaw: bash install-nodejs-openclaw.sh"
    echo "- 或手动安装 Node.js: curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -"
    echo "- 或使用 nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
else
    echo "[重新安装 OpenClaw]"
    echo "- bash install-nodejs-openclaw.sh"
    echo "- 或手动安装：npm install -g openclaw@latest"
fi
echo ""

read -p "按回车键退出"
