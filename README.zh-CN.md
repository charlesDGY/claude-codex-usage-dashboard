# claude-codex-usage-dashboard

**Language**: 中文 · [English](README.md)


一个本地 web dashboard，把 **Claude Code (Anthropic)** 与 **Codex (OpenAI)**
两边的 token 用量统一在一个浏览器页面里查看：

- Anthropic 官方实时配额（5h / 7d 利用率 + 重置倒计时）
- Codex 官方实时配额（同上，外加按钮主动刷新）
- 5h 计费窗口 cost 估算（ccusage）+ 周用量自适应 budget bar
- 按工具 / subagent 类型 / 项目 / 模型分桶的 token 拆分
- 24 小时分钟级今日 vs 昨日趋势
- Top 20 单 turn 最贵 token 消耗
- RTK 节省总览（如果装了 [RTK 代理](https://github.com/yusukebe/rtk)）
- Codex 按天 / 按模型的 USD 估算（基于本地可改的定价表）

stdlib-only Python（除了 npx 依赖 ccusage 拉 Claude 价格）。

```
┌──────────────────────────────┬──────────────────────────────┐
│ ⚡ Anthropic 实时配额         │ ⚡ Codex 实时配额 [🔄 刷新]   │
│ 5h: 39%  7d: 69%             │ 5h: 27%  7d: 4%              │
│ 重置 3h2m / 2d0h             │ 重置 4h32m / 7d              │
└──────────────────────────────┴──────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│ 关键洞察                                                      │
│ ⚡ Anthropic 5h 39% · 7d 69% / Codex 5h 27% · 7d 4%          │
│ 🔥 Subagent 占 50% 总 token / 🛠️ Bash 占 67% 工具 token      │
│ 💾 cache 命中 97% 极佳 / ✂️ RTK 整体压缩 90.1%               │
└──────────────────────────────────────────────────────────────┘
... (其他面板)
```

---

## 数据来源（5 个独立 source，互相补充）

| 数据 | 来源 | 说明 |
|---|---|---|
| **Anthropic 5h / 7d 实时配额** | `https://api.anthropic.com/api/oauth/usage` | 直接调 OAuth 端点，权威实时数据 |
| **Codex 5h / 7d 实时配额** | `~/.codex/sessions/.../rollout-*.jsonl` 里的 `rate_limits` 字段 | OpenAI 服务端在每次 codex API 响应里返回；不调 REST，零额外消耗 |
| **Claude Code 详细 token 拆分** | `~/.claude/projects/**/*.jsonl` | 直接扫所有 session jsonl 文件，按 isSidechain / 工具 / 项目分桶 |
| **Cost 估算 + 5h 块** | `npx ccusage` (LiteLLM 价格库) | 主动调用 ccusage CLI，每次刷新跑 daily/blocks/session 三个命令 |
| **RTK 节省** | `~/.local/share/rtk/history.db` (SQLite) | 直接读 RTK proxy 的命令历史 |
| **Codex per-session token + cost** | `~/.codex/state_5.sqlite` (SQLite) + `~/.codex/sessions/...rollout-*.jsonl` | sqlite 给每 session 总 token，jsonl 给 input/cached/output 拆分用于成本计算 |

**关键设计决策**：

1. **不依赖任何长期跑的 daemon / hook** — 单进程多线程 Python，60s refresh loop。
2. **不修改任何外部状态**（settings.json / .env / shell rc 等都不动），只读。
3. **Codex 定价用本地可编辑 JSON 表** — OpenAI 没公开稳定的 codex 模型价目表，所以放 `codex_pricing.json` 让用户自己维护。
4. **绕过 Cloudflare** — `chatgpt.com` 域名对 curl 拦截，所以 Codex 配额数据不调 REST，改读本地 jsonl。

---

## 依赖

| 软件 | 用途 | 必需？ |
|---|---|---|
| Python 3.8+ | 运行 dashboard | ✅ |
| Node.js + npm | `npx ccusage@latest` 提供 Claude cost 估算 | ✅ (除非你不要 Claude cost) |
| `~/.claude/projects/` 目录有数据 | Claude Code 至少跑过 1 次 | 推荐（不然这部分空） |
| `~/.codex/` 目录有数据 | `codex login` + 至少跑过 1 次 codex | 推荐（不然 Codex 部分空） |
| `~/.local/share/rtk/history.db` | [RTK proxy](https://github.com/yusukebe/rtk) 装过且用过 | 可选（不然 RTK 板块空） |
| `codex` CLI 在 PATH | "🔄 立即刷新" 按钮可用 | 可选 |
| `curl` (`/usr/bin/curl`) | 调 Anthropic 配额端点 | ✅ |

---

## 快速开始

```bash
git clone https://github.com/charlesDGY/claude-codex-usage-dashboard.git ~/.cache/cc-dashboard
cd ~/.cache/cc-dashboard

# 启动（默认端口 36668，绑 0.0.0.0 局域网可达）
./bin/ccdash start
```

把 `bin/ccdash` 软链到 PATH 里方便日常用：

```bash
mkdir -p ~/.local/bin
ln -sf ~/.cache/cc-dashboard/bin/ccdash ~/.local/bin/ccdash
# 确保 ~/.local/bin 在 PATH 里 (常见在 ~/.bashrc / ~/.zshrc)
```

打开浏览器：

- 本机：`http://localhost:36668/`
- 局域网：`http://<你的服务器 IP>:36668/`
- SSH 转发（公网服务器推荐）：`ssh -L 36668:localhost:36668 user@server` 然后 `http://localhost:36668/`

---

## 命令

```bash
ccdash start      # 启动（如果已跑会跳过）
ccdash stop       # 停止
ccdash restart    # 重启
ccdash status     # 状态 + 关键指标 + URL
ccdash log        # 全部 server 日志
ccdash tail       # 实时 tail 日志
```

---

## 配置（env 变量）

| 变量 | 默认 | 说明 |
|---|---|---|
| `CC_DASHBOARD_PORT` | `36668` | 监听端口 |
| `CC_DASHBOARD_HOST` | `0.0.0.0` | 监听地址（要锁本地：`127.0.0.1`） |
| `CC_DASHBOARD_REFRESH` | `60` | 后台 refresh 间隔（秒） |
| `CC_DASHBOARD_CCUSAGE_TIMEOUT` | `60` | ccusage 单次调用超时（秒） |
| `CC_DASHBOARD_LOCAL_DAYS` | `14` | 本地 jsonl 扫描的回溯天数 |
| `CC_DASHBOARD_WEEKLY_BUDGET_USD` | `0`(自适应) | 周 budget 显示参考线（0 = 取过去 4 周最高 × 1.1） |
| `CC_DASHBOARD_CODEX_PROBE_MIN_INTERVAL_S` | `60` | "🔄 立即刷新"按钮的节流间隔 |
| `CC_DASHBOARD_LOG` | `<repo>/dashboard.log` | 日志文件路径 |
| `CC_DASHBOARD_PID` | `<repo>/dashboard.pid` | PID 文件路径 |

例：

```bash
CC_DASHBOARD_PORT=8088 CC_DASHBOARD_HOST=127.0.0.1 ccdash restart
```

---

## 在新服务器上适配（重点）

### Step 1：装依赖

```bash
# Python 3.8+ 通常自带；node 多数 distro 有
sudo apt install -y python3 nodejs npm  # 或 brew / yum / pacman 对应
node --version  # 检查 ≥ v18
python3 --version
```

### Step 2：登录 Claude Code（如果你想要 Anthropic 配额）

dashboard 读 `~/.claude/.credentials.json` 拿 OAuth token。这个文件在你跑过
Claude Code（`claude` CLI）并登录之后会自动出现。验证：

```bash
ls -la ~/.claude/.credentials.json
python3 -c "import json; d=json.load(open('$HOME/.claude/.credentials.json'))['claudeAiOauth']; print('subscription:', d.get('subscriptionType'), 'tier:', d.get('rateLimitTier'))"
# 期望: subscription: max / pro / team, tier: 某个值
```

如果文件不存在或 401 错误，回去跑一次 `claude` CLI 登录即可。

### Step 3：登录 Codex（如果你想要 OpenAI 配额）

```bash
# codex CLI（npm 包）
npm i -g @openai/codex
codex login
# 按提示选 "Sign in with ChatGPT" 走 device code 流程
codex login status  # 确认 "Logged in using ChatGPT"
ls -la ~/.codex/auth.json  # 应该存在
```

**重要**：dashboard 读的是 `~/.codex/sessions/*/rollout-*.jsonl` 里的 rate_limits
字段，**这只在 codex 真的调过一次 API 之后才会有**。所以登录后**至少跑一次 codex
exec**：

```bash
echo 'hi' | codex exec --skip-git-repo-check
# 这次调用会让 OpenAI 服务端返回当前 rate_limits，写到 jsonl
```

### Step 4：克隆 + 启动

```bash
git clone https://github.com/charlesDGY/claude-codex-usage-dashboard.git ~/.cache/cc-dashboard
cd ~/.cache/cc-dashboard
./bin/ccdash start
```

打开浏览器，等约 60 秒拿到第一次 refresh。

### Step 5：调价（可选）

`codex_pricing.json` 是我**估算**的 OpenAI codex 模型定价（2026-04 时点的猜测，
非权威）。如果你要更准确的数字，去 [OpenAI 定价页](https://openai.com/api/pricing/)
查实际价格然后改这个文件。dashboard 下次 refresh 自动重读。

```bash
vim ~/.cache/cc-dashboard/codex_pricing.json
```

格式：

```json
{
  "gpt-5.5":      {"input": 5.0, "cached_input": 0.5, "output": 20.0},
  "gpt-5.4-mini": {"input": 0.30, "cached_input": 0.03, "output": 1.20},
  "default":      {"input": 5.0, "cached_input": 0.5, "output": 20.0}
}
```

USD per 1M tokens。`cached_input` 是 prompt-cache 命中部分的折扣价（OpenAI 通常 1/10）。
`reasoning_output_tokens` 按 `output` 价计费。

### Step 6（可选）：Claude Code 状态栏增强

`extras/statusline_v2.sh` 是一个把 cost / 烧速 / context% 显示到 Claude Code
状态栏的脚本（不属于 dashboard，但同源数据）。安装：

```bash
cp extras/statusline_v2.sh ~/.claude/scripts/statusline_v2.sh
chmod +x ~/.claude/scripts/statusline_v2.sh

# 编辑 ~/.claude/settings.json，把 statusLine.command 改成 bash ~/.claude/scripts/statusline_v2.sh
```

详见 `extras/README.md`。

---

## 架构 / 数据流

```
                 ┌────────────────────────────────────┐
                 │  cc_dashboard.py (single Python)   │
                 │                                    │
   每 60s        │   ┌────────────────────────┐       │
   后台          │   │ refresh_loop (thread)  │       │
   refresh       │   └────┬───────────────────┘       │
                 │        │ 5 sources:                │
                 │        ├─→ run_ccusage daily/...   │
                 │        ├─→ scan_local()             │
                 │        ├─→ scan_rtk()               │
                 │        ├─→ scan_codex()             │
                 │        └─→ fetch_anthropic_usage()  │
                 │                 ↓                   │
                 │        _state (in-memory dict)      │
                 │                 ↓                   │
                 │   ┌────────────────────────┐       │
                 │   │ ThreadingHTTPServer    │       │
                 │   │  GET /     → HTML      │       │
                 │   │  GET /api/data → JSON  │       │
                 │   │  POST /api/codex_probe │       │
                 │   └────────────────────────┘       │
                 └────────────────────────────────────┘
                              ↑ 浏览器每 30s 拉
```

**数据流细节**：

1. **启动**: `cc_dashboard.py` fork 一个后台线程跑 `refresh_loop`，主线程跑 HTTP server
2. **refresh_loop**: 每 60s 重新跑 5 个数据源；任何一个失败不影响其他
3. **HTTP 处理**: 浏览器 GET `/api/data` 时直接返回 _state（已缓存），无新计算
4. **probe 按钮**: POST `/api/codex_probe` 触发后台跑一次 `codex exec`，写入新 jsonl，下次 refresh 自动读到新 rate_limits
5. **HTML 页面**: 一个静态字符串内嵌 vanilla JS，每 30s `fetch /api/data` 重渲染

线程模型：

- 1 主线程（HTTP server, ThreadingHTTPServer 处理并发请求）
- 1 后台 refresh 线程（持续运行）
- 偶尔的 probe 线程（按需 spawn）
- 数据 access 用 `_state_lock` 保护

---

## 安全 / 隐私

dashboard **只读**，不写任何外部状态。访问的文件：

| 路径 | 内容 | 我们做什么 |
|---|---|---|
| `~/.claude/.credentials.json` | Anthropic OAuth token | 读 access_token，发 Bearer 调 `api.anthropic.com/api/oauth/usage` |
| `~/.claude/projects/**/*.jsonl` | Claude Code 完整 session 历史 | 流式读 + 聚合统计，不外发 |
| `~/.codex/auth.json` | OpenAI OAuth token | **只读到内存**，不发任何网络（Codex 配额不靠 REST，靠读 jsonl） |
| `~/.codex/sessions/**/*.jsonl` | Codex session 历史 + 服务端返回的 rate_limits | 流式读 |
| `~/.codex/state_5.sqlite` | Codex 元数据库 | 只读模式打开 |
| `~/.local/share/rtk/history.db` | RTK 命令历史 | 只读模式打开 |

**网络请求**：

- `https://api.anthropic.com/api/oauth/usage` — 用 Anthropic OAuth Bearer token (60s 一次)
- `npx ccusage@latest ...` — Node.js 子进程，调用 LiteLLM 价格库（一次性下载缓存）
- POST `/api/codex_probe` 触发的 `codex exec` — 跑 codex CLI，发 OpenAI API（仅按钮触发，节流 60s）

**绑定**：默认 `0.0.0.0:36668`，**局域网内任何机器都能访问**。
如果是公网/不可信网络环境，强烈建议改 `CC_DASHBOARD_HOST=127.0.0.1` + SSH 隧道。

dashboard 完全不发任何遥测，不调任何外部 webhook。

---

## 卸载

```bash
ccdash stop
rm -rf ~/.cache/cc-dashboard            # 整个 repo
rm -f ~/.local/bin/ccdash               # 软链
# 还原 statusline (如果你装了 v2):
# 编辑 ~/.claude/settings.json 把 statusLine.command 改回原值
```

---

## 故障排查

### `ccdash status` 说 running 但浏览器打不开

```bash
ccdash log | tail -50  # 看错误
ss -lntp | grep 36668  # 端口被占？
```

### Anthropic 卡片显示"数据未读到 (token 失效?)"

```bash
# 检查 token 是否过期
python3 -c "import json,time; d=json.load(open('$HOME/.claude/.credentials.json'))['claudeAiOauth']; print('expires_at:', d.get('expiresAt'), 'now:', int(time.time()*1000))"
# 如果 expires_at < now，跑一次 claude CLI 自动续期
claude --help > /dev/null
```

### Codex 卡片显示"没找到 codex session 文件"

```bash
# Codex 还没跑过任何任务
codex login status  # 必须 "Logged in"
echo 'hi' | codex exec --skip-git-repo-check  # 跑一次产生 session jsonl
ls -la ~/.codex/sessions/*/*/*/rollout-*.jsonl 2>&1 | tail
```

### Codex 配额数据"几小时前的"

正常 — 这些数据只在 `codex exec` 调用后由服务端推送来。
点 dashboard 上的 **🔄 立即刷新** 按钮，会触发一次最小 codex 调用拉新数据，
30s 内 dashboard 自动反映。

如果你不想花配额做 probe，等系统下次自然跑 codex 即可（每次 codex 调用都会刷新）。

### ccusage 卡 / 慢 / 失败

```bash
# ccusage 第一次跑会下载 LiteLLM 价格库（几 MB），慢正常
node --version  # 必须 ≥ v18
npx -y ccusage@latest --version  # 测试 ccusage 是否能跑
```

### "本地扫"扫到很多旧文件，今日数据偏少

dashboard 默认扫 14 天回溯（`CC_DASHBOARD_LOCAL_DAYS=14`）。
如果你只想看今日 + 昨日：`CC_DASHBOARD_LOCAL_DAYS=2 ccdash restart`

### 端口冲突

```bash
CC_DASHBOARD_PORT=8088 ccdash restart
```

---

## 已知限制

1. **Codex 实时性**：5h/7d % 数据只在 codex 跑过之后刷新，本身就有几分钟延迟。Anthropic 那边是直接调 REST，真实时。
2. **Codex 价格估算不权威**：OpenAI 公开价目表对 GPT-5.x 系列变动较快，本 repo 内置的 `codex_pricing.json` 是 2026-04 时点的估算。
3. **不分账户**：如果你机器上多个 ChatGPT 账号交叉登录过 codex，会读到混合数据（按当前 `~/.codex/auth.json` 的 active 账号）。
4. **不区分 Claude 编排 vs Codex 全编排** 调用 codex 的来源 — 都计在 codex 一边。

---

## License

MIT (see `LICENSE`)

---

## 致谢

- [`ccusage`](https://github.com/ryoppippi/ccusage) — Claude Code 用量分析工具，本 dashboard 的 Claude cost 估算靠它。
- [`rtk`](https://github.com/yusukebe/rtk) — 本地命令代理（可选数据源）。
- 直接读 jsonl session 文件的思路源自对 Claude Code / Codex CLI 数据持久化策略的逆向。
