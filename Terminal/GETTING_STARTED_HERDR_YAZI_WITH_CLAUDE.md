# Getting Started: Herdr + Yazi + Claude Code

A workflow guide for using Herdr as your terminal workspace manager, Yazi as your file navigator, and Claude Code in worktree mode to watch changes live.

## Quick Install

```bash
bash ~/Downloads/install_brew_herdr_yazi_lazygit_nvim.sh
```

This installs everything: Herdr, Yazi, Neovim (LazyVim), lazygit, delta, and tmux.

---

## 1. Launching Herdr

Start Herdr from any terminal:

```bash
herdr
```

This creates (or attaches to) a persistent session. Your workspace survives terminal closes.

### Named sessions

```bash
herdr --session myproject
```

### Detach and reattach

- Detach: `Ctrl+b` then `q`
- Reattach: just run `herdr` again

---

## 2. Herdr Pane Management

All Herdr commands start with the prefix key `Ctrl+b`.

| Action | Keys |
|--------|------|
| Split vertical | `Ctrl+b` then `v` |
| Split horizontal | `Ctrl+b` then `-` |
| Focus left pane | `Ctrl+b` then `h` |
| Focus down pane | `Ctrl+b` then `j` |
| Focus up pane | `Ctrl+b` then `k` |
| Focus right pane | `Ctrl+b` then `l` |
| Cycle panes | `Ctrl+b` then `Tab` |
| Close pane | `Ctrl+b` then `x` |
| Zoom/fullscreen pane | `Ctrl+b` then `z` |
| Resize mode | `Ctrl+b` then `r` |
| Toggle sidebar | `Ctrl+b` then `b` |

### Tabs

| Action | Keys |
|--------|------|
| New tab | `Ctrl+b` then `c` |
| Next tab | `Ctrl+b` then `n` |
| Previous tab | `Ctrl+b` then `p` |
| Switch to tab N | `Ctrl+b` then `1-9` |
| Rename tab | `Ctrl+b` then `Shift+t` |
| Close tab | `Ctrl+b` then `Shift+x` |

### Workspaces

| Action | Keys |
|--------|------|
| Workspace picker | `Ctrl+b` then `w` |
| New workspace | `Ctrl+b` then `Shift+n` |
| Rename workspace | `Ctrl+b` then `Shift+w` |
| Close workspace | `Ctrl+b` then `Shift+d` |
| New worktree | `Ctrl+b` then `Shift+g` |

### Help

Press `Ctrl+b` then `?` to see all keybindings.

---

## 3. Recommended Layout

Set up a three-pane layout for active development:

```
+-------------------+------------------+
|                   |                  |
|   Claude Code     |   Yazi / Editor  |
|   (worktree)      |                  |
|                   |                  |
+-------------------+------------------+
```

1. Start Herdr: `herdr`
2. In the first pane, launch Claude in worktree mode (see section 5)
3. Split vertical: `Ctrl+b` then `v`
4. In the second pane, launch Yazi: `yazi`

---

## 4. Using Yazi

Launch Yazi in any pane:

```bash
yazi
```

### Navigation

| Action | Keys |
|--------|------|
| Move up/down | `k` / `j` |
| Enter directory | `l` or `Enter` |
| Go up a directory | `h` |
| Go to top/bottom | `g g` / `G` |
| Search files | `/` |
| Toggle hidden files | `.` |
| Quit | `q` |

### Git Integration (custom keybindings)

| Action | Keys |
|--------|------|
| Open lazygit | `g i` |
| Show git changed files | `g c` |
| Full-screen git diff for file | `g d` |

The preview pane automatically shows inline diffs (via delta) for any file with uncommitted changes.

### File Operations

| Action | Keys |
|--------|------|
| Open file in $EDITOR | `Enter` |
| Copy file(s) | `y` |
| Cut file(s) | `x` |
| Paste | `p` |
| Delete | `d` |
| Rename | `r` |
| Create file | `a` (type name, Enter) |
| Create directory | `a` (type name/, Enter) |
| Select/deselect | `Space` |
| Select all | `Ctrl+a` |

### Opening Files in Neovim

When you press `Enter` on a file, Yazi opens it in `$EDITOR` (nvim). After editing, exit nvim to return to Yazi.

---

## 5. Claude Code in Worktree Mode

Run Claude Code with the `-w` flag to use git worktree isolation. This lets Claude make changes on a separate branch without disrupting your working tree:

```bash
claude -w
```

Claude will:
- Create a temporary git worktree
- Make all changes there (invisible to your main checkout)
- You can review changes in Yazi or lazygit before merging

### Watching Claude's changes live

In your Yazi pane, navigate to the worktree directory that Claude creates. The git-peek preview will show diffs as Claude writes code. Use `g c` to see which files Claude has modified.

### Typical workflow

1. Pane 1: `claude -w` -- give Claude a task
2. Pane 2: `yazi` -- browse the worktree, watch diffs appear in preview
3. Use `g i` in Yazi to open lazygit and review/stage/commit changes
4. When satisfied, merge the worktree branch into your main branch

---

## 6. Neovim (LazyVim) Quick Reference

When you open a file from Yazi, it launches in Neovim with LazyVim.

### Essential shortcuts

| Action | Keys |
|--------|------|
| Save file | `Space` then `w` (or `:w`) |
| Quit | `Space` then `q` (or `:q`) |
| File explorer | `Space` then `e` |
| Find file | `Space` then `f f` |
| Search in files (grep) | `Space` then `s g` |
| Buffer list | `Space` then `,` |
| Close buffer | `Space` then `b d` |
| Split vertical | `Space` then `\|` |
| Split horizontal | `Space` then `-` |
| Terminal | `Space` then `f t` |

### Getting help

| Action | Keys |
|--------|------|
| Show all keybindings | `Space` then `s k` |
| Which-key popup (wait) | Press `Space` and wait |
| Command palette | `Space` then `:` |
| LazyVim dashboard | `Space` then `l` |

The which-key popup is your best friend -- press `Space` and pause for 300ms to see all available leader-key commands grouped by category.

### Movement basics

| Action | Keys |
|--------|------|
| Word forward/back | `w` / `b` |
| Start/end of line | `0` / `$` |
| Go to line N | `N G` |
| Go to definition | `g d` |
| Go back | `Ctrl+o` |
| Find references | `g r` |

---

## 7. Putting It All Together

```bash
# Start your workspace
herdr --session dev

# Pane 1: Claude doing work in a worktree
claude -w

# Ctrl+b, v to split

# Pane 2: Navigate and watch changes
yazi

# Inside Yazi:
#   g c  -> see what Claude changed
#   g d  -> see the diff
#   g i  -> open lazygit to review/commit
#   Enter -> open file in nvim to edit
```

### Tips

- Use `Ctrl+b` then `z` to zoom any pane to fullscreen (toggle)
- Use `Ctrl+b` then `?` if you forget a Herdr keybinding
- In Yazi, the preview pane auto-shows diffs -- no action needed
- In nvim, press `Space` and wait to discover commands via which-key
- Herdr sessions persist -- close your terminal and `herdr` picks up where you left off
