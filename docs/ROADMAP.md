# proxy-config 后续开发计划

本文档基于 v1.1.0 代码库分析整理，用于指导后续功能开发与优化排期。

## 一、项目现状概览

`proxy-config` 是一个跨平台 Clash 代理开关 CLI，支持 **Git Bash / WSL2 / PowerShell / cmd**。

### 已实现能力

| 能力 | 说明 |
|------|------|
| 核心命令 | `proxy on` / `proxy off` / `proxy status` |
| 作用域 | 会话级（默认）与全局级（`-g` / `--global` / `-Global`） |
| Git 模式 | `--git-only` / `-GitOnly` 仅配置 Git 代理 |
| 持久化 | User 环境变量、WSL `~/.bashrc` 标记块、`git config --global`、状态文件 |
| 主机探测 | Git Bash 使用 `127.0.0.1`；WSL2 使用 resolv.conf / 默认网关 |
| 安装/卸载 | 幂等标记块安装（`install.ps1` / `install.sh` / `uninstall.*`） |
| 健康检查 | 经 HTTP 代理访问 `http://www.gstatic.com/generate_204` |

### 代码结构

```
proxy-config/
├── bin/          # 各平台 CLI 入口
├── lib/          # Bash 共享逻辑（detect-host, proxy-core, persist-env, git-proxy, proxy-invoke）
├── hooks/        # Shell profile 安装片段
├── config.env    # 端口、NO_PROXY、HOST 等配置
├── install.*     # 安装脚本
└── uninstall.*   # 卸载脚本
```

### 架构评价

- 职责分离清晰：Bash 侧通过 `proxy-invoke.sh` 可 source，会话环境变量可正确保留
- PowerShell 侧自包含实现，与 Bash 行为基本对齐
- cmd 通过 `proxy-session.cmd` 实现会话级代理，全局模式委派给 PowerShell

### 主要短板

- **无自动化测试**
- **cmd 分支 status 行为不正确**
- **配置校验与安全加固不足**
- **可配置性与扩展命令有限**

---

## 二、问题与优化项（按优先级）

### P0 — 正确性缺陷

#### 1. cmd 下 `proxy status` 不准确

**现状：** `bin/proxy.cmd` 将 `status` 委派给 `proxy.ps1`。PowerShell 子进程读取的是**自身进程**的环境变量，无法看到 `proxy-session.cmd` 通过 `set` 写入 cmd 会话的变量。

**影响：** 在 cmd 中执行 `proxy on` 后再 `proxy status`，会显示 `session env: off`，产生误导。

**方案：** 新增 `bin/proxy-session-status.cmd`，在 cmd 会话内直接回显 `%HTTP_PROXY%` 等变量；必要时再拼接 PowerShell 侧的 git-global 检查。

---

#### 2. 各平台默认配置值不一致

**现状：**

- `config.env` 中 `NO_PROXY` 包含完整 CIDR 列表
- `proxy-session.cmd` 回退默认值为 `localhost,127.0.0.1`
- `proxy.ps1` 的 `Read-ClashProxyConfig` 默认 hashtable 同样为精简值

**影响：** 未正确读取 `config.env` 时，各 shell 的 bypass 列表行为不一致。

**方案：** 抽取统一的默认配置常量，或在各入口统一从 `config.env` 读取，避免硬编码回退值分叉。

---

#### 3. `git-only` 模式仅支持 HTTP 代理

**现状：** `git_proxy_on` / `Set-GitProxy` 只写入 `http.proxy` / `https.proxy`。

**影响：** 纯 SOCKS 环境（无 HTTP 端口）下 git-only 模式不可用。

**方案：** 支持 `GIT_PROXY_SCHEME` 配置项，允许写入 `socks5://` 等 scheme。

---

### P1 — 安全加固

#### 4. PowerShell 命令字符串注入风险

**现状：** `lib/persist-env.sh` 中 `_persist_env_powershell_set` 将配置值直接内插进：

```bash
powershell.exe -NoProfile -Command \
    "[Environment]::SetEnvironmentVariable('${key}', '${value}', 'User')"
```

**影响：** 若 `config.env` 的 host/port 含引号或特殊字符，可能造成命令注入。

**方案：**

- 改用参数化传值（`-EncodedCommand` 或临时脚本文件）
- 对 host/port 做严格白名单校验（host：`[A-Za-z0-9.:_-]`，port：纯数字）

---

#### 5. 配置值缺乏校验

**现状：** 端口、host 未做合法性检查，错误配置会静默产生无效 URL。

**方案：** 在 Bash（`proxy-invoke.sh`）与 PowerShell（`Read-ClashProxyConfig`）中增加统一的配置校验逻辑，启动时即报错退出。

---

### P2 — 功能增强

#### 6. 补充基础子命令

| 命令 | 用途 |
|------|------|
| `proxy help` / `-h` / `--help` | 用法说明 |
| `proxy version` / `--version` | 版本号（与 CHANGELOG 对齐） |
| `proxy toggle` | 在 on/off 间切换 |
| `proxy status --json` | 机器可读输出，便于脚本/状态栏集成 |

---

#### 7. 多代理 Profile 支持

**场景：** 工作网络与家庭网络使用不同 Clash 端口或 host。

**方案：** 支持 `config.d/work.env`、`config.d/home.env`，通过 `proxy on --profile work` 切换。

---

#### 8. 可配置健康检查 URL

**现状：** 健康检查硬编码 `http://www.gstatic.com/generate_204`。

**方案：** 增加 `HEALTH_CHECK_URL` 配置项；置空时跳过健康检查（避免出网或内网环境误报）。

---

#### 9. 联动其他开发工具代理（可选开关）

在 `config.env` 中增加可选开关，一键设置/清除：

| 工具 | 配置项示例 |
|------|-----------|
| npm | `NPM_USE_PROXY=1` |
| pip | `PIP_USE_PROXY=1` |
| docker | `DOCKER_USE_PROXY=1` |
| apt | `APT_USE_PROXY=1` |

---

#### 10. WSL2 mirrored networking 探测

**现状：** WSL2 始终通过 resolv.conf / 默认网关推断 Windows 主机 IP。

**背景：** 新版 Windows 的 WSL mirrored 网络模式下，`127.0.0.1` 可直接访问宿主机 Clash。

**方案：** 探测 mirrored 模式时优先使用 `127.0.0.1`，减少错误 host 推断。

---

#### 11. Clash 端口连通性检测

**现状：** `proxy status` 仅通过 HTTP 请求判断代理是否可用。

**方案：** 增加对 `HTTP_PORT` 的 TCP 连通性检测，区分「代理已配置」与「Clash 未运行」。

---

### P3 — 工程化与开发者体验

#### 12. 自动化测试（当前完全缺失）

| 平台 | 框架 | 覆盖范围 |
|------|------|----------|
| Bash | `bats-core` | `detect-host.sh`、`proxy-core.sh` 的 on/off/status/flag 解析 |
| PowerShell | `Pester` | `proxy.ps1` 各命令分支 |
| 隔离 | mock | `git config`、`powershell.exe`、网络调用 |

---

#### 13. CI（GitHub Actions）

建议流水线包含：

- `shellcheck` 静态检查所有 `.sh`
- `PSScriptAnalyzer` 检查 `.ps1`
- Linux 跑 bats、Windows 跑 Pester
- CHANGELOG / 版本号一致性检查

---

#### 14. 输出本地化与颜色统一

**现状：** CLI 输出为英文；README 为中英双语。

**方案：** 支持 `CLASH_PROXY_LANG=zh|en`，或至少统一各平台输出术语与格式。

---

#### 15. 卸载时可选清理残留全局代理

**现状：** README 已说明 `uninstall.ps1` 不会自动清除 `proxy on -g` 留下的 User env / WSL bashrc 块。

**方案：** 增加 `uninstall.ps1 -PurgeProxyEnv`，一并清理持久化代理配置。

---

## 三、里程碑排期

| 版本 | 主题 | 包含项 |
|------|------|--------|
| **v1.1.1** | 修复 | #1 cmd status、#2 默认值统一、#4 注入加固、#5 配置校验 |
| **v1.2.0** | 测试基座 | #12 bats + Pester、#13 CI、#3 git SOCKS 支持 |
| **v1.3.0** | 体验 | #6 help/version/toggle/json、#8 健康检查 URL、#11 端口探测 |
| **v1.4.0** | 场景扩展 | #7 多 Profile、#9 工具联动、#10 WSL mirrored、#15 卸载清理 |

---

## 四、优先实施建议

以下三项投入小、收益高，建议优先落地：

1. **修复 cmd `proxy status`**（#1）— 影响用户信任度，改动范围小
2. **PowerShell 注入加固 + 配置校验**（#4、#5）— 安全与健壮性，成本低
3. **搭建 shellcheck + PSScriptAnalyzer CI**（#13）— 立即拦截后续回归

---

## 五、不在当前范围内的事项

以下需求暂不纳入近期计划，待核心稳定性达标后再评估：

- GUI / 系统托盘集成
- 自动检测并启动 Clash 进程
- 订阅规则管理
- 与 Clash Verge / Mihomo 控制 API 深度集成（切换节点、规则模式等）

---

## 六、文档维护

- 每完成一个里程碑，更新本文件对应条目的状态
- 版本发布时同步更新 `CHANGELOG.md`
- 重大行为变更需在 README 中注明迁移说明

---

*最后更新：2026-07-01（基于 v1.1.0 代码分析）*
