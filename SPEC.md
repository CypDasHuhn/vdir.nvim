# vdir.nvim — Plugin Specification & Test Plan

This document describes what vdir.nvim is, what it must do, and every behavior
that needs to be verified. It is the basis for generating unit and integration
tests.

The CLI counterpart is specified in `~/repos/vdir-cli/SPEC.md`.

---

## What is vdir.nvim?

vdir.nvim is a Neovim plugin that provides a visual panel for the vdir virtual
directory system. It is a **thin UI wrapper** — it owns no data, no query logic,
and no storage. Everything goes through the vdir CLI.

The panel renders as a neo-tree source: a sidebar tree you can navigate,
expand, and interact with using keyboard shortcuts. Opening a file from the
panel opens it in the editor. Creating, deleting, or renaming items calls the
CLI and refreshes the tree.

### What is vdir? (brief)

vdir is a virtual filesystem organizer. You build a named, navigable tree of:
- **Folders** — pure organizational containers (no disk counterpart)
- **Queries** — saved searches that run shell commands and emit file paths
- **References** — named aliases to real files or directories on disk

The tree is stored in `.vdir.json` in your project directory. A marker (your
current position in the tree) is stored in `.vdir-marker`.

---

## CLI output contract

The plugin depends on the output format of `vdir ls -lr`. This is the interface
between the CLI and the plugin; both sides must agree on it.

### `vdir ls -lr` output format

One line per item, depth encoded as leading spaces (2 per level):

| Prefix | Format | Meaning |
|--------|--------|---------|
| `d` | `d <name>/ (<N> items)` | Folder with N direct children |
| `q` | `q <name> (<N> suppliers)` | Query with N suppliers |
| `r` | `r <name> -> <target> [f]` | Reference to a file |
| `r` | `r <name> -> <target> [d]` | Reference to a directory |
| `f` | `f <path>` | Query result (child of a query line) |

Example:
```
d Projects/ (2 items)
  d Work/ (0 items)
  q todos (1 suppliers)
    f /home/user/work/main.rs
    f /home/user/work/lib.rs
r dotfiles -> /home/user/.dotfiles [d]
```

The plugin reads this output and constructs the tree. The format must never
change without updating both sides.

---

## Activation

- `:Vdir` toggles the vdir panel (a neo-tree source named `vdir`).
- Default keymap: `<leader>q` → `<cmd>Vdir<cr>`.
- When opened, the panel binds to the current working directory.

**Tests:**
- [ ] `:Vdir` opens the panel when it is closed
- [ ] `:Vdir` closes the panel when it is open
- [ ] Panel binds to the cwd at the moment it is opened, not a cached path

---

## Initialization

When the panel is opened in a directory that has no `.vdir.json`:

1. Show a prompt: "No vdir found here. Create one?"
2. **"Yes"** → run `vdir init` in that directory, then load the (empty) tree.
3. **"No"** → display a message in the panel, do nothing else.

**Tests:**
- [ ] Opening panel in a directory without `.vdir.json` shows the prompt
- [ ] Choosing "Yes" creates `.vdir.json` and the tree renders (empty root)
- [ ] Choosing "No" shows an informational message in the panel
- [ ] Choosing "No" does NOT create `.vdir.json`
- [ ] Opening panel in a directory WITH `.vdir.json` skips the prompt entirely

---

## Tree rendering

The plugin calls `vdir ls -lr` and parses the output into neo-tree nodes.
Indentation (2 spaces per level) determines the parent–child relationship.

### Node types

| CLI prefix | Neo-tree node type | Expandable | `extra.item_type` |
|------------|--------------------|------------|-------------------|
| `d` | `directory` | yes | `"folder"` |
| `q` | `directory` | yes | `"query"` |
| `r` | `file` or `directory` | no | `"reference"` |
| `f` (under `q`) | `file` | no | n/a (`is_query_result = true`) |
| root | `directory` | yes | `"root"` |

### Node paths

- **Folder**: virtual path inside `.vdir/` subdirectory, based on marker path
- **Query**: same virtual path scheme as folders
- **Reference**: the real filesystem path the reference points to
- **Query result**: the real filesystem path emitted by the command

### Tests:
- [ ] Folders render as expandable directory nodes
- [ ] Queries render as expandable directory nodes with `is_query = true`
- [ ] References pointing to files render as file nodes
- [ ] References pointing to directories render as directory nodes
- [ ] Query results render as file nodes under their query node
- [ ] Nested folders render at correct depth (2 spaces per level = 1 depth)
- [ ] An empty vdir (no children) renders root with no child nodes
- [ ] Hidden items (names starting with `.`) are not shown (ls is called without `-a`)
- [ ] A query with no results shows no child nodes (or a placeholder)

---

## Navigation

Opening items with Enter follows the node type:

| Node type | Enter behavior |
|-----------|----------------|
| Folder | Toggle expand/collapse |
| Query | Toggle expand/collapse |
| Reference (file) | Open the target file in the editor |
| Reference (directory) | Open the target directory (netrw or similar) |
| Query result | Open the file in the editor |

Most default neo-tree keys are disabled. The active key set is exactly:
`a`, `A`, `d`, `r`, `e` (plus standard neo-tree navigation).

**Tests:**
- [ ] Enter on a folder toggles expand/collapse
- [ ] Enter on a query toggles expand/collapse
- [ ] Enter on a file reference opens the file in the editor
- [ ] Enter on a directory reference opens a directory view
- [ ] Enter on a query result opens the file in the editor
- [ ] Default neo-tree keys that are disabled (`c`, `m`, `p`, `y`, etc.) do nothing

---

## `a` — Add item

Prompts for a name at the cursor position.

- If the name **ends with `/`**: creates a folder via `vdir mkdir <name>`
- Otherwise: opens the query editor and creates a query via `vdir mkq`

The cursor must be on a **folder** or the **root** node. Any other position is
an error.

After success: tree refreshes, success notification shown.

**Tests:**
- [ ] `a` on root, entering `myfolder/` → creates folder at root
- [ ] `a` on a folder node, entering `sub/` → creates subfolder inside that folder
- [ ] `a` on root, entering `myquery` → opens query editor
- [ ] `a` on a query node → error notification, nothing happens
- [ ] `a` on a reference node → error notification, nothing happens
- [ ] `a` on a query result node → error notification, nothing happens
- [ ] Pressing Esc or submitting an empty name → cancels, nothing changes
- [ ] After successful folder creation, tree refreshes and new folder is visible
- [ ] After successful query creation, tree refreshes and new query is visible

---

## `A` — Add folder (explicit)

Same as `a` but always creates a folder, no trailing-slash disambiguation.

**Tests:**
- [ ] `A` on root prompts for a name and creates a folder
- [ ] `A` on a folder node creates a subfolder
- [ ] `A` on a query node → error notification
- [ ] `A` on a reference node → error notification
- [ ] Empty name → cancels, nothing changes

---

## `d` — Delete

Deletes the item at the cursor.

- Calls `vdir rm --force <name>` (bypasses interactive confirmation).
- Root cannot be deleted.
- Query results are read-only and cannot be deleted.
- After success: tree refreshes.

**Tests:**
- [ ] `d` on a folder removes it from the tree (including all children)
- [ ] `d` on a query removes it
- [ ] `d` on a reference removes it
- [ ] `d` on the root node → error notification, nothing changes
- [ ] `d` on a query result node → error notification, nothing changes
- [ ] After successful deletion, tree refreshes and item is gone

---

## `r` — Rename

Prompts for a new name, pre-filled with the item's current name.
Calls `vdir mv <name> <new_name>`.

- Root cannot be renamed.
- Query results cannot be renamed.
- Submitting the same name or an empty name cancels without change.

**Tests:**
- [ ] `r` pre-fills the input prompt with the current item name
- [ ] Entering a different name renames the item
- [ ] Entering an empty name → cancels, no CLI call made
- [ ] Entering the same name as current → cancels, no CLI call made
- [ ] `r` on root → error notification
- [ ] `r` on a query result → error notification
- [ ] After successful rename, tree refreshes showing the new name

---

## `e` — Edit query

Opens the query editor for the selected query.

**Conditions for opening:**
- Cursor must be on a **query** node (not folder, reference, or result).
- The query must have zero or one supplier, and if one, it must be `_default`.
- If the query has multiple named suppliers: error notification, editor does not open.

**On save:** the old query is deleted and recreated with the new compiler/args,
preserving the query name and position.

**On cancel:** no change to the query.

**Tests:**
- [ ] `e` on a folder → error notification
- [ ] `e` on a reference → error notification
- [ ] `e` on a query result → error notification
- [ ] `e` on an empty query (no suppliers) → opens editor with blank state
- [ ] `e` on a compiler-based query → opens editor pre-filled with compiler and args
- [ ] `e` on a query with only `_default` supplier → opens editor with that supplier's data
- [ ] `e` on a query with multiple named suppliers → error notification
- [ ] Saving from editor → old query deleted, new query created with same name
- [ ] Saving from editor → tree refreshes
- [ ] Cancelling editor (Esc or `q`) → query is unchanged

---

## Query editor UI

A floating modal with three stacked panels:

### Panels

1. **Compiler** (read-only) — shows the currently selected compiler name and
   its index: `Compiler [2/5]`. Changed with `<C-n>` / `<C-p>`.
2. **Arguments** (editable) — a single-line text field for compiler arguments.
3. **Preview** (read-only) — shows the shell commands the compiler would
   generate for the current compiler + args. Updates with 300ms debounce.

### Keys (active in all panels)

| Key | Action |
|-----|--------|
| `<CR>` | Save and close |
| `<C-s>` | Save and close |
| `<Esc>` | Cancel and close |
| `q` (normal mode) | Cancel and close |
| `<Tab>` | Move focus to next panel (compiler → args → compiler) |
| `<S-Tab>` | Move focus to previous panel |
| `<C-n>` | Select next compiler (wraps) |
| `<C-p>` | Select previous compiler (wraps) |

### Behavior

- Opens with focus on the Arguments panel in insert mode.
- Compiler panel is never editable (modifiable = false).
- Preview panel is never editable.
- Preview shows `(select a compiler)` when no compiler is selected.
- Preview shows `(compiler test failed)` when the compiler command fails.
- Preview shows `(no output)` when the compiler returns nothing.
- The preview border title shows the count of generated shell commands.

### Tests:
- [ ] If no compilers are registered → error notification, editor does not open
- [ ] Compiler panel shows the selected compiler name
- [ ] Compiler panel border shows `[N/total]` index
- [ ] `<C-n>` moves to the next compiler; wraps from last to first
- [ ] `<C-p>` moves to the previous compiler; wraps from first to last
- [ ] Changing compiler triggers a preview update (after debounce)
- [ ] Typing in Arguments triggers a preview update (after debounce)
- [ ] Preview updates reflect the correct compiler + args combination
- [ ] Preview shows `(select a compiler)` when compiler field is empty
- [ ] Preview shows `(compiler test failed)` on CLI error
- [ ] `<CR>` from compiler panel saves
- [ ] `<CR>` from args panel saves
- [ ] `<C-s>` from either panel saves
- [ ] `<Esc>` from either panel cancels without saving
- [ ] `q` in normal mode cancels without saving
- [ ] `<Tab>` cycles focus: compiler → args → compiler
- [ ] `<S-Tab>` cycles focus in reverse
- [ ] Args panel opens in insert mode
- [ ] Saving with no compiler selected → error notification, editor stays open

---

## CLI integration

### Binary resolution

The plugin looks for the CLI binary in this order:
1. `vim.g.vdir_cli_cmd` if set
2. `vdir` in PATH
3. `vdir_cli` in PATH

### Marker management

All mutations run at a specific vdir marker position (the parent folder of the
item being created/modified). The plugin:
1. Saves the current marker by calling `vdir pwd`
2. Sets the marker to the target folder via `vdir cd <marker>`
3. Runs the mutation command
4. Restores the previous marker via `vdir cd <saved>`

### Error handling

- CLI exits non-zero → show the stderr output as an error notification
- Binary not found → show a clear error notification (not a Lua stack trace)
- After any successful mutation → call `vdir ls -lr` and re-render the tree

### Tests:
- [ ] `vim.g.vdir_cli_cmd` overrides the default binary lookup
- [ ] `vdir` in PATH is found automatically
- [ ] `vdir_cli` in PATH is found as a fallback
- [ ] Binary not in PATH → clear error notification
- [ ] CLI exits non-zero → error notification showing the error text
- [ ] All mutation commands run at the correct marker (parent of target item)
- [ ] After every successful command, the tree is refreshed via `ls -lr`
- [ ] Marker is restored after every command (success or failure)
