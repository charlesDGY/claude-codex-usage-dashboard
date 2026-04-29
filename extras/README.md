# extras

Optional companion scripts that are useful alongside the dashboard but not
part of the core service.

## `statusline_v2.sh`

Replaces the default Claude Code statusline with a richer one that appends
ccusage cost / burn-rate / context % info. **Async-cached**, so each prompt
tick stays under 100 ms even though ccusage itself takes ~14 s cold.

### Install

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

### What it shows

```
[opus] my-project (main) | in:7.78M out:70.4K | 💰 $14.91 block (3h 50m left) | 🔥 $27.39/hr | 🧠 15%
```

- in/out token totals from the current Claude Code transcript
- ccusage 5h-block cost + remaining time + burn rate + context window %

### How the async cache works

ccusage statusline cold-start is ~14 s (it scans every Claude session file).
This script caches the cost suffix at `~/.cache/claude-statusline/ccusage_suffix`
with a 30 s TTL. Each prompt tick:

1. Reads the cache file (instant, <50 ms)
2. If cache > 30 s old, spawns a background process to refresh it
3. Returns immediately — next prompt tick will see the refreshed value

Result: statusline always renders in < 100 ms.

### Uninstall

Restore your original `~/.claude/settings.json` `statusLine.command`.
