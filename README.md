# vdir.nvim

Neo-tree source for `vdir`.

The plugin is a thin UI wrapper around `vdir-cli`. It does not own query
storage or execution logic anymore. `vdir` remains the source of truth for the
virtual tree, marker state, supplier scopes, and shell execution.

## AI DISCLOSURE

This current branch is 100% AI generated.
I yet didnt write a lua plugin myself, but im wanting to learn it yet.
But since i need the utility now, i generated it.

Once this disclaimer isnt here anymore, this means i have rewritten in myself.

## Requirements

- [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- `vdir` or `vdir_cli` in `PATH`

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

If your CLI binary is not available as `vdir` or `vdir_cli`, set:

```lua
vim.g.vdir_cli_cmd = "path/to/vdir"
```

## Behavior

- The tree is loaded from `vdir ls -lr`
- Folder, query, rename, and delete actions call `vdir` commands directly
- Query editing is command and shell agnostic:
  - `cmd`
  - `scope`
  - `shell_program`
  - `shell_execute_arg`

The plugin does not interpret query syntax. It only sends raw command strings to
`vdir`.

## Keybindings

| Key | Action |
|-----|--------|
| `a` | Add item (folder if name ends with `/`, otherwise query) |
| `A` | Add folder |
| `d` | Delete folder/query |
| `r` | Rename folder/query |
| `e` | Edit query |

## Current limits

- The edit UI currently targets the default supplier only
- Queries that use only named suppliers or multiple supplier-specific configs
  are not editable from the plugin yet
- Query result nodes are read-only
