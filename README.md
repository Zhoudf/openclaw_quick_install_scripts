# OpenClaw 快速安装脚本

> OpenClaw 自动化安装与配置工具集

## 📖 参照文档

**详细配置文档**：[OpenClaw 配置指南](https://icnc5d4v520o.feishu.cn/docx/S6CBdDmNQoQeBixPhsbcR3d8nob?from=from_copylink)

---

## ⚠️ 当前状态

**仅支持 Windows 平台** - 当前只开发了 `win_script` 目录下的 Windows 版本脚本。

Linux 部分可以参照 wsl 部分

Mac 版本计划中，敬请期待。

---

## 📁 目录结构

```
openclaw_quick_install_scripts/
├── win_script/                      # Windows 平台脚本（已完成）
│   ├── install-wsl.bat              # 安装 WSL + Ubuntu 24.04
│   ├── uninstall-wsl.bat            # 卸载 WSL
│   ├── install-nodejs-openclaw.sh   # 安装 Node.js + OpenClaw
│   ├── install-opencode.sh          # 安装 OpenCode CLI
│   ├── install-openclaw-service.sh  # 配置 OpenClaw 系统服务
│   ├── install-feishu-plugin.sh     # 安装飞书插件
│   ├── post-install-auto.sh         # 全自动配置（一键完成）
│   ├── post-install-config.sh       # 手动配置向导
│   ├── setup-apikey.sh              # 配置 API Key 和模型
│   ├── setup-feishu.sh              # 配置飞书凭证
│   ├── restart-openclaw.sh          # 重启 OpenClaw 服务
│   ├── update-openclaw.sh           # 更新 OpenClaw
│   ├── uninstall-openclaw.sh        # 卸载 OpenClaw
│   └── pair-devices.sh              # 设备配对管理
├── README.md
└── LICENSE
```

---

## 🚀 快速开始（Windows）

### 1. 安装 WSL + Ubuntu

```cmd
cd win_script
install-wsl.bat
```

**功能：**
- 启用 WSL 功能
- 安装 WSL 2
- 安装 Ubuntu 24.04 LTS

### 2. 安装 Node.js + OpenClaw

在 WSL 中运行：

```bash
wsl -d Ubuntu-24.04
bash install-nodejs-openclaw.sh
```

**功能：**
- 安装 Node.js 24 LTS
- 安装 OpenClaw CLI
- 配置 npm 源和 PATH

### 3. 全自动配置

```bash
bash post-install-auto.sh
```

**功能：**
- 安装 Daemon 服务
- 安装飞书插件
- 配置 Control UI
- 启动 Gateway 服务

---

## 📝 脚本说明

### 安装类脚本

| 脚本 | 功能 | 运行环境 |
|------|------|----------|
| `install-wsl.bat` | 安装 WSL + Ubuntu 24.04 | Windows PowerShell (管理员) |
| `install-nodejs-openclaw.sh` | 安装 Node.js + OpenClaw | WSL Ubuntu |
| `install-opencode.sh` | 安装 OpenCode CLI | WSL Ubuntu |
| `install-openclaw-service.sh` | 配置 OpenClaw 系统服务 | WSL Ubuntu |
| `install-feishu-plugin.sh` | 安装飞书插件 | WSL Ubuntu |

### 配置类脚本

| 脚本 | 功能 | 运行环境 |
|------|------|----------|
| `post-install-auto.sh` | 全自动配置（一键完成所有配置） | WSL Ubuntu |
| `post-install-config.sh` | 手动配置向导 | WSL Ubuntu |
| `setup-apikey.sh` | 配置 API Key 和模型提供商 | WSL Ubuntu |
| `setup-feishu.sh` | 配置飞书 App ID 和 Secret | WSL Ubuntu |

### 管理类脚本

| 脚本 | 功能 | 运行环境 |
|------|------|----------|
| `restart-openclaw.sh` | 重启 OpenClaw 服务 | WSL Ubuntu |
| `update-openclaw.sh` | 更新 OpenClaw 到最新版 | WSL Ubuntu |
| `uninstall-openclaw.sh` | 卸载 OpenClaw | WSL Ubuntu |
| `uninstall-wsl.bat` | 卸载 WSL | Windows PowerShell |
| `pair-devices.sh` | 设备配对管理 | WSL Ubuntu |

---

## 💡 推荐用法

### 全新安装（推荐）

```cmd
# 1. Windows 端安装 WSL
install-wsl.bat

# 2. 进入 WSL
wsl -d Ubuntu-24.04

# 3. 安装 Node.js 和 OpenClaw
bash install-nodejs-openclaw.sh

# 4. 全自动配置
bash post-install-auto.sh
```

### 单独配置飞书

```bash
# 安装飞书插件
bash install-feishu-plugin.sh

# 配置飞书凭证
bash setup-feishu.sh
```

---

## 🔧 常用命令

```bash
# 查看 OpenClaw 状态
openclaw status

# 查看健康检查
openclaw health

# 查看已安装插件
openclaw plugins list

# 查看已配置渠道
openclaw channels list

# 重启服务
bash restart-openclaw.sh
```

---

## ⚠️ 注意事项

1. **管理员权限** - `install-wsl.bat` 需要以管理员身份运行
2. **网络环境** - 部分脚本支持选择国内镜像源
3. **首次启动** - Ubuntu 首次启动需要设置用户名和密码
4. **端口转发** - WSL2 已自动配置端口转发，Windows 可直接访问 Control UI

---

## 📄 License

MIT License - 详见 [LICENSE](LICENSE)

---

## 👤 作者

**Eddie**
- 微信：dev_eddie
- 邮箱：15961658715@163.com

---

## 🙋 问题反馈

如有问题，请通过以下方式联系：
- 微信：dev_eddie
- GitHub Issues
