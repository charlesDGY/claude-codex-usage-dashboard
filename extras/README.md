# extras

**Language**: [中文](#中文) · [English](#english)

Optional companion scripts that are useful alongside the dashboard but not
part of the core service.

---

## English

### `statusline_v2.sh`

Replaces the default Claude Code statusline with a richer one that appends
ccusage cost / burn-rate / context % info. **Async-cached**, so each prompt
tick stays under 100 ms even though ccusage itself takes ~14 s cold.

#### Install

```bash
mkdir -p ~/.claude/scripts
cp statusline_v2.sh ~/.claude/scripts/statusline_v2.sh
chmod +x ~/.claude/scripts/statusline_v2.sh
```

Edit `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/statusline_v2.sh"
  }
}
```

If you have a previous `statusline.sh`, back it up first:

```bash
cp ~/.claude/scripts/statusline.sh ~/.claude/scripts/statusline.sh.bak
```

#### What it shows

```
[opus] my-project (main) | in:7.78M out:70.4K | 💰 $14.91 block (3h 50m left) | 🔥 $27.39/hr | 🧠 15%
```

- in/out token totals from the current Claude Code transcript
- ccusage 5h-block cost + remaining time + burn rate + context window %

#### How the async cache works

ccusage statusline cold-start is ~14 s (it scans every Claude session file).
This script caches the cost suffix at `~/.cache/claude-statusline/ccusage_suffix`
with a 30 s TTL. Each prompt tick:

1. Reads the cache file (instant, <50 ms)
2. If cache > 30 s old, spawns a background process to refresh it
3. Returns immediately — next prompt tick will see the refreshed value

Result: statusline always renders in < 100 ms.

#### Uninstall

Restore your original `~/.claude/settings.json` `statusLine.command`.

---

## 中文

### `statusline_v2.sh`

替换 Claude Code 默认状态栏，把 ccusage 的成本 / 烧速 / context% 信息追加到末尾。
**异步缓存**，所以每次 prompt 显示都 < 100ms（虽然 ccusage 本身冷启动要 ~14 秒）。

#### 安装

```bash
mkdir -p ~/.claude/scripts
cp statusline_v2.sh ~/.claude/scripts/statusline_v2.sh
chmod +x ~/.claude/scripts/statusline_v2.sh
```

编辑 `~/.claude/settings.json`：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/scripts/statusline_v2.sh"
  }
}
```

如果你已经有 `statusline.sh`，先备份：

```bash
cp ~/.claude/scripts/statusline.sh ~/.claude/scripts/statusline.sh.bak
```

#### 显示效果

```
[opus] 我的项目 (main) | in:7.78M out:70.4K | 💰 $14.91 block (3h 50m left) | 🔥 $27.39/hr | 🧠 15%
```

- 当前 Claude Code 会话的 in/out token 总量
- ccusage 给出的 5h 块累计成本 + 剩余时间 + 烧速 + context window 占用%

#### 异步缓存怎么工作

ccusage statusline 的冷启动要 ~14 秒（它要扫每个 Claude session 文件）。
这个脚本把成本部分缓存到 `~/.cache/claude-statusline/ccusage_suffix`，TTL 30 秒。
每次 prompt 触发：

1. 读 cache 文件（瞬间，<50ms）
2. 如果 cache > 30 秒，spawn 一个后台进程刷新它
3. 立即返回 — 下一次 prompt 触发就会看到新值

结果：状态栏永远在 < 100ms 内渲染完成。

#### 卸载

把 `~/.claude/settings.json` 的 `statusLine.command` 改回原值。
