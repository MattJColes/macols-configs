#!/usr/bin/env bash
set -euo pipefail

echo ""
echo "=============================="
echo " [1/7] Homebrew"
echo "=============================="

if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."

    # Install prerequisites on Linux
    if [[ "$(uname)" == "Linux" ]]; then
        if command -v apt-get &>/dev/null; then
            echo "  Installing build dependencies (apt)..."
            sudo apt-get update -y
            sudo apt-get install -y build-essential procps curl file git
        elif command -v dnf &>/dev/null; then
            echo "  Installing build dependencies (dnf)..."
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y procps-ng file git
        elif command -v yum &>/dev/null; then
            echo "  Installing build dependencies (yum)..."
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y procps-ng curl file git
        fi
    fi

    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew already installed."
fi

# Ensure brew is on PATH for the rest of the script
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

echo ""
echo "=============================="
echo " [2/7] Installing packages"
echo "=============================="

echo "Installing neovim, yazi, lazygit, delta, and tmux..."
brew install neovim yazi lazygit git-delta tmux

# herdr is Amazon-internal — skip on non-Amazon systems
if brew tap | grep -q amazon 2>/dev/null || brew search herdr 2>/dev/null | grep -q herdr; then
    echo "Installing herdr..."
    brew install herdr
else
    echo "  Skipping herdr (not available outside Amazon)."
fi

echo ""
echo "=============================="
echo " [3/7] LazyVim setup"
echo "=============================="

if [[ ! -d "$HOME/.config/nvim" ]]; then
    echo "Cloning LazyVim starter..."
    git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
    echo "LazyVim installed."
else
    echo "Neovim config already exists, skipping LazyVim install."
fi

echo "  Writing git and theme plugins..."
mkdir -p "$HOME/.config/nvim/lua/plugins"
cat > "$HOME/.config/nvim/lua/plugins/git.lua" << 'EOF'
return {
  { "Shatur/neovim-ayu" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ayu-dark",
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      current_line_blame = true,
    },
  },

  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" } },
}
EOF

echo ""
echo "=============================="
echo " [4/7] Verifying installations"
echo "=============================="

yazi --version
ya --version
lazygit --version
delta --version
nvim --version | head -1

echo ""
echo "=============================="
echo " [5/7] Installing Yazi plugins"
echo "=============================="

ya pkg add yazi-rs/plugins:git || true
ya pkg add yazi-rs/plugins:vcs-files || true
ya pkg install --discard || true

echo ""
echo "=============================="
echo " [6/7] Writing Yazi config"
echo "=============================="

YAZI_CONFIG="$HOME/.config/yazi"
mkdir -p "$YAZI_CONFIG/plugins/git-peek.yazi"
mkdir -p "$YAZI_CONFIG/plugins/git-diff.yazi"
mkdir -p "$YAZI_CONFIG/plugins/lazygit.yazi"

echo "  Writing yazi.toml..."
cat > "$YAZI_CONFIG/yazi.toml" << 'EOF'
[[plugin.prepend_previewers]]
url  = "*"
run  = "git-peek"

[[plugin.prepend_fetchers]]
id    = "git"
url   = "*"
run   = "git"
group = "git"

[[plugin.prepend_fetchers]]
id    = "git"
url   = "*/"
run   = "git"
group = "git"

[mgr]
show_hidden = true

[manager]
show_git = true
linemode = "git"

[opener]
edit = [
	{ run = 'nvim "$@"', block = true, desc = "nvim" },
]

[git]
modified = { fg = "yellow", bold = true }
untracked = { fg = "cyan" }
staged    = { fg = "green" }
renamed   = { fg = "magenta" }
deleted   = { fg = "red" }
EOF

echo "  Writing keymap.toml..."
cat > "$YAZI_CONFIG/keymap.toml" << 'EOF'
[[mgr.prepend_keymap]]
on   = [ "g", "i" ]
run  = "plugin lazygit"
desc = "run lazygit"

[[mgr.prepend_keymap]]
on   = [ "g", "c" ]
run  = "plugin vcs-files"
desc = "Show Git file changes"

[[mgr.prepend_keymap]]
on   = [ "g", "d" ]
run  = "plugin git-diff"
desc = "Show inline git diff for selected file"
EOF

echo "  Writing init.lua..."
cat > "$YAZI_CONFIG/init.lua" << 'EOF'
require("git"):setup {
	order = 1500,
}
EOF

echo "  Writing lazygit plugin..."
rm -f "$YAZI_CONFIG/plugins/lazygit.yazi/main.lua"
cat > "$YAZI_CONFIG/plugins/lazygit.yazi/main.lua" << 'EOF'
local function entry()
	ya.emit("shell", { "lazygit", block = true, orphan = true })
end

return { entry = entry }
EOF

echo "  Writing git-diff plugin..."
cat > "$YAZI_CONFIG/plugins/git-diff.yazi/main.lua" << 'EOF'
local selected = ya.sync(function()
	local h = cx.active.current.hovered
	if h then
		return tostring(h.url)
	end
end)

local function entry()
	local path = selected()
	if not path then return end

	ya.emit("shell", {
		'git diff HEAD -- "$0" | delta --paging=always',
		path,
		block = true,
		orphan = true,
	})
end

return { entry = entry }
EOF

echo "  Writing git-peek plugin..."
cat > "$YAZI_CONFIG/plugins/git-peek.yazi/main.lua" << 'EOF'
local M = {}

function M:peek(job)
	local path = tostring(job.file.path)

	local diff, err = Command("git"):arg({ "diff", "HEAD", "--", path }):output()
	if not diff or not diff.stdout or #diff.stdout == 0 then
		diff = Command("git"):arg({ "diff", "--", path }):output()
	end
	if not diff or not diff.stdout or #diff.stdout == 0 then
		return require("code"):peek(job)
	end

	local child = Command("sh")
		:arg({ "-c", "delta --width=" .. job.area.w })
		:stdin(Command.PIPED)
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:spawn()

	local text
	if child then
		child:write_all(diff.stdout)
		child:flush()
		local output = child:wait_with_output()
		if output and output.stdout and #output.stdout > 0 then
			text = output.stdout
		else
			text = diff.stdout
		end
	else
		text = diff.stdout
	end

	local opt = { ansi = true, tab_size = rt.preview.tab_size, wrap = rt.preview.wrap, width = job.area.w }
	local limit = job.area.h
	local i, lines = 0, {}

	for line in text:gmatch("[^\n]*\n?") do
		if #line > 0 then
			local wrapped = ui.lines(line, opt)
			local from = math.max(1, job.skip - i + 1)
			local to = math.min(#wrapped, job.skip + limit - i)

			i = i + #wrapped
			for j = from, to do
				lines[#lines + 1] = wrapped[j]
			end

			if i >= job.skip + limit then break end
		end
	end

	if job.skip > 0 and i < job.skip + limit then
		ya.emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		ya.preview_widget(job, ui.Text(lines):area(job.area))
	end
end

function M:seek(job) require("code"):seek(job) end

return M
EOF

echo "  Done."

echo ""
echo "=============================="
echo " [7/7] Shell configuration"
echo "=============================="

BREW_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
EDITOR_LINE='export EDITOR="nvim"'

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
        if ! grep -qF 'linuxbrew' "$rc" && ! grep -qF '/opt/homebrew' "$rc"; then
            echo "" >> "$rc"
            if [[ -f /opt/homebrew/bin/brew ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$rc"
            else
                echo "$BREW_LINE" >> "$rc"
            fi
            echo "  Added brew shellenv to $rc"
        else
            echo "  brew shellenv already in $rc"
        fi

        if ! grep -qF 'export EDITOR="nvim"' "$rc"; then
            echo "" >> "$rc"
            echo "$EDITOR_LINE" >> "$rc"
            echo "  Added EDITOR=nvim to $rc"
        else
            echo "  EDITOR=nvim already set in $rc"
        fi
    fi
done

# Configure tmux mouse support
if ! grep -qF "set -g mouse on" "$HOME/.tmux.conf" 2>/dev/null; then
    echo "set -g mouse on" >> "$HOME/.tmux.conf"
    echo "  Added mouse support to ~/.tmux.conf"
else
    echo "  tmux mouse already enabled in ~/.tmux.conf"
fi

echo ""
echo "=============================="
echo " Complete!"
echo "=============================="
echo ""
echo "Keybindings:"
echo "  gi  - Open lazygit"
echo "  gc  - Show git changed files"
echo "  gd  - Full-screen git diff for hovered file"
echo ""
echo "Preview pane automatically shows inline diffs for modified files."
echo ""
echo "Next steps:"
echo "  source ~/.zshrc   (or ~/.bashrc)"
echo "  yazi"
