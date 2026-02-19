# vdir.nvim

Virtual directories for Neovim. Create custom folder structures based on grep patterns.

## Disclosure

This project was largely written by AI.
I'm not going to pretend it isn't.

## Features

- Define virtual folders and queries in `.vdir.toml`
- Pattern matching with live preview
- Nested folder support
- Neo-tree integration

## Installation

```lua
{
  "CypDasHuhn/vdir.nvim",
  dependencies = {
    "nvim-neo-tree/neo-tree.nvim",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>q", "<cmd>Vdir<cr>", desc = "Toggle Vdir" },
  },
}
```

## Keybindings

| Key | Action |
|-----|--------|
| `a` | Add item (folder if ends with `/`, otherwise query) |
| `A` | Add folder |
| `d` | Delete folder/query |
| `r` | Rename folder/query |
| `e` | Edit query (opens editor) |

### Query Editor

| Key | Action |
|-----|--------|
| `Tab` | Next field |
| `Shift-Tab` | Previous field |
| `Ctrl-r` | Toggle regex mode |
| `Enter` | Save |
| `Esc` | Cancel |

## Configuration

Creates `.vdir.toml` in your project root:

```toml
[[folder]]
name = "Code Quality"

[[folder.query]]
name = "TODOs"
pattern = "TODO, FIXME"
glob = "**/*.lua"

[[folder.query]]
name = "Debug"
pattern = "print, console.log"
regex = true
```

## Requirements

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep)
