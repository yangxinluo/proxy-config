# Clash for Windows 多模式代理脚本

> **English:** [README.en.md](README.en.md)

面向 **Git Bash**、**WSL2**、**PowerShell**、**cmd** 及 **仅 Git** 模式的统一代理管理工具，配合本地 HTTP/SOCKS 代理使用。

## 概述

本目录 (`proxy-config`) 提供一套轻量级脚本，用于在开发环境中按需开启或关闭代理。支持四种使用模式：完整代理（环境变量 + Git）、仅 Git 代理、以及对应 Shell 下的关闭与状态查询。

安装脚本会自动检测当前目录，**无需硬编码路径**。

## 代理客户端兼容性

> **Clash for Windows (CFW) 已停止维护。** 本工具不绑定特定客户端，只要提供标准 **HTTP + SOCKS** 本地代理即可使用，例如：
>
> - [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev)
> - [Mihomo / Clash Meta](https://github.com/MetaCubeX/mihomo)
> - 其他兼容 Clash 端口的 HTTP/SOCKS 代理

默认端口为 HTTP `7890`、SOCKS `7891`（与常见 Clash 配置一致）。若端口不同，请编辑 `config.env`。

### 前置条件

1. 代理客户端已运行，并开启系统代理或手动配置端口。
2. **仅 WSL2**：在代理客户端中开启 **Allow LAN（允许局域网连接）**，以便 WSL 访问 Windows 主机上的代理。

## PowerShell 配置文件说明

Windows 上存在 **两套独立的 PowerShell**，各自有独立的 `$PROFILE` 路径：

| Shell | 典型 `$PROFILE` 路径 |
|-------|----------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ (`pwsh`) | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**推荐：** 在 **Windows PowerShell 5.1** 中运行 `.\install.ps1`（默认终端 / cmd 调用 `powershell.exe` 时使用）。安装脚本会**同时**向上述两个 profile 路径写入 hook（若目录不存在则创建），确保无论您使用哪种 PowerShell 都能加载 `proxy` 命令。

## Git 全局配置警告

`proxy on`（完整模式）及 `proxy on --git-only` / `proxy on -GitOnly` 在 `GIT_USE_HTTP=1`（默认）时会修改 **`git config --global`** 的 `http.proxy` 与 `https.proxy`。这会影响本机所有 Git 仓库的出站 HTTP/HTTPS 流量。使用 `proxy off` 可清除这些设置。

## 健康检查说明

`proxy status` 在检测到 `curl` 时，会通过当前 HTTP 代理请求：

```
http://www.gstatic.com/generate_204
```

用于验证代理连通性。该请求发往 Google 静态资源端点，**不会**上传本仓库或本地文件内容。若不希望访问外网 URL，可跳过 `proxy status` 或在不安装 `curl` 的环境中运行（将跳过此项检测）。详见 [SECURITY.md](SECURITY.md)。

## 目录结构

```
proxy-config/
├── LICENSE                 # MIT License
├── CHANGELOG.md
├── SECURITY.md
├── config.env              # 端口、NO_PROXY、可选 HOST 覆盖
├── bin/
│   ├── proxy               # Bash CLI（Git Bash / WSL2）
│   ├── proxy.ps1           # PowerShell CLI
│   └── proxy.cmd           # cmd.exe 包装器
├── lib/                    # Bash 共享库
│   ├── detect-host.sh      # 平台与主机检测
│   ├── git-proxy.sh        # Git 代理配置
│   └── proxy-core.sh       # 核心 on/off/status 逻辑
├── hooks/                  # Shell 配置文件片段（由安装脚本写入）
│   ├── bashrc.snippet      # Git Bash
│   ├── profile.snippet     # WSL2
│   └── powershell-profile.snippet
├── install.ps1             # Windows 安装脚本（推荐）
├── uninstall.ps1           # Windows 卸载脚本
├── install.sh              # Git Bash / WSL 安装脚本（可选）
├── uninstall.sh            # Git Bash / WSL 卸载脚本（可选）
├── README.md               # 中文文档（本文件）
└── README.en.md            # English documentation
```

## 四种使用模式

| 模式 | Shell | 命令 | 效果 |
|------|-------|------|------|
| 完整代理 (Bash) | Git Bash / WSL2 | `proxy on` | 设置环境变量 + Git 代理 |
| 仅 Git (Bash) | Git Bash / WSL2 | `proxy on --git-only` | 仅配置 Git 代理 |
| 完整代理 (PS) | PowerShell | `proxy on` | 设置环境变量 + Git 代理 |
| 仅 Git (PS) | PowerShell | `proxy on -GitOnly` | 仅配置 Git 代理 |

关闭代理：`proxy off`（或 `proxy off --git-only` / `proxy off -GitOnly`）。

## 安装

在 `proxy-config` 目录下运行安装脚本（路径可为任意位置）：

```powershell
cd path\to\proxy-config
.\install.ps1
```

安装脚本会：

1. 设置用户环境变量 `CLASH_PROXY_ROOT` 为当前目录
2. 将 `bin` 目录加入用户 **PATH**
3. 在 **Windows PowerShell 5.1 与 pwsh 的 `$PROFILE`**、Git Bash `~/.bashrc`、WSL `~/.bashrc`（若检测到 WSL）中写入带标记的 hook 片段

安装时会打印实际修改的路径（PATH 条目、`CLASH_PROXY_ROOT`、各 profile 与 bashrc 路径）。

选项：

```powershell
.\install.ps1 -WhatIf      # 预览，不修改
.\install.ps1 -Force       # 跳过确认
.\install.ps1 -SkipGitBash # 跳过 Git Bash hook
.\install.ps1 -SkipWsl     # 跳过 WSL hook
```

**Git Bash / WSL** 也可使用 bash 安装脚本：

```bash
cd /path/to/proxy-config
./install.sh
```

### 安装后验证

**打开新的终端窗口**，然后：

```powershell
proxy status
proxy on
proxy off
proxy on -GitOnly
```

```bash
proxy status
proxy on --git-only
```

cmd.exe 中同样可用 `proxy on`、`proxy status` 等（通过 `proxy.cmd`）。

## 卸载

```powershell
cd path\to\proxy-config
.\uninstall.ps1
```

或 Git Bash / WSL：

```bash
./uninstall.sh
```

卸载会移除 PATH 条目、各 Shell 中的 hook 片段，以及 `CLASH_PROXY_ROOT` 用户环境变量。可重复运行，安全幂等。卸载脚本会检查 **所有** PowerShell profile 路径，不会删除仅含 hook 的空 profile 文件（保留空文件或换行）。

### 卸载后验证

打开**新终端**，确认以下内容已清除：

```powershell
# proxy 命令应不可用（或不在本项目的 bin 路径中）
Get-Command proxy -ErrorAction SilentlyContinue

# 用户环境变量应已移除
[Environment]::GetEnvironmentVariable('CLASH_PROXY_ROOT', 'User')

# Git 全局代理应已清除（若曾启用过 proxy on）
git config --global --get http.proxy
git config --global --get https.proxy
```

```bash
# Bash / WSL
command -v proxy
echo "$CLASH_PROXY_ROOT"
git config --global --get http.proxy
```

若 `Get-Command proxy` 仍返回路径，请关闭所有旧终端窗口后重试。

## 命令参考

### Bash（Git Bash / WSL2）

```bash
proxy on
proxy on --git-only
proxy off
proxy off --git-only
proxy status
```

### PowerShell / cmd

```powershell
proxy on
proxy on -GitOnly
proxy off
proxy off -GitOnly
proxy status
```

## 配置说明（config.env）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| HTTP_PORT | 7890 | HTTP 代理端口 |
| SOCKS_PORT | 7891 | SOCKS 代理端口 |
| NO_PROXY | localhost, 私有网段 | 不走代理的地址列表 |
| HOST | （自动检测） | 强制指定 Clash 主机（WSL2 通常为 Windows IP） |
| GIT_USE_HTTP | 1 | 开启代理时是否配置 git http/https 代理 |
| STATE_DIR | ~/.local/state/clash-proxy | 持久化当前模式 |

### 主机检测规则

- **Git Bash / PowerShell**：`127.0.0.1`
- **WSL2**：读取 `/etc/resolv.conf` 的 nameserver，回退到默认网关
- **手动覆盖**：在 `config.env` 中设置 `HOST`

## 故障排除

### WSL2 无法连接代理

- 在代理客户端中开启 **Allow LAN**。
- 运行 `proxy status`，确认主机为 Windows IP（而非 `127.0.0.1`）。
- 若自动检测失败，在 `config.env` 中手动设置 `HOST` 为 Windows IP。

### `proxy: command not found`

- 确认已运行 `install.ps1`，并**打开新终端**使 PATH 生效。
- 检查 `echo $env:CLASH_PROXY_ROOT`（PowerShell）或 `echo $CLASH_PROXY_ROOT`（Bash）。
- 手动重新加载：`source ~/.bashrc` 或重启 PowerShell。

### Git 仍然很慢或失败

- 若仅需 Git 走代理，使用 `proxy on --git-only`。
- 检查 `git config --global --get http.proxy`。

### 健康检查失败

- 确认代理客户端正在运行，且端口与 `config.env` 一致。
- 检查防火墙是否允许本地 `7890`/`7891` 端口连接。
- 健康检查会访问 `http://www.gstatic.com/generate_204`；离线或阻断外网时可能显示 unreachable。

## 状态文件

启用代理后，模式保存在 `~/.local/state/clash-proxy/state`，内容为 `mode=full` 或 `mode=git-only`。执行 `proxy off` 后清除。

## 许可证

本项目采用 [MIT License](LICENSE) 发布。
