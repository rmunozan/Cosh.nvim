
# Cosh.nvim

Cosh is a plugin for sharing nicely formatted code snippets in Markdown. It lets you copy files, buffers, highlighted selections, directory contents, or directory trees directly into your clipboard. It works well for team chats, documentation, or posting on Reddit and GitHub.

## 🚀 Quickstart 

Install with LazyVim:

```lua
{
    "rmunozan/cosh.nvim",
},
```

Install with Packer
```lua
use "rmunozan/cosh.nvim"
```

## 🧙‍♂️ Commands

Use `:Cosh` followed by an action and optional path:

```vim
:Cosh file [path]
:Cosh buffer [path]
:Cosh selection
:Cosh dir [path]
:Cosh tree [path]
```

If `[path]` is omitted for `file`, `buffer`, or `dir`, Cosh uses the current file or directory.

**Sample usage:**

```vim
:Cosh file            " copies current file
:Cosh file init.lua   " copies init.lua
:Cosh buffer          " copies current buffer
:Cosh selection       " copies highlighted visual content
:Cosh dir             " copies files in current directory
:Cosh tree            " copies tree of current directory
```

## ⚙️ Configuration

Cosh can be customized in your Neovim setup:

```lua
config = function()
    require("cosh").setup({ allow, ignore })
end
```

### Allowed extensions (`allow`)

Map file extensions to Markdown languages. Cosh copies only files with extensions in this list, preventing unexpected files from being shared.

```lua
allow = {
    [".js"] = "javascript",
    [".ts"] = "typescript",
}
```

### Ignore patterns (`ignore`)

Sample ignore configuration:

```lua
ignore = {
    ".log",
    "node_modules/",
    "/dist/",
    "README.md",
}
```

Exclude files or directories with these patterns:

- **`.ext`** — ignore all files ending with the extension.
- **`dirname/`** — ignore directories by name anywhere.
- **`/dirname/`** — ignore only the root-level directory.
- **`filename.ext`** — ignore specific files by name.

## 📂 Supported Languages

Cosh supports many languages by default. See the full list in `lua/cosh/allowed_exts.lua`.

## 📌 Default Ignores

Common ignore patterns (version control, build folders, etc.) are in `lua/cosh/ignore_patterns.lua`.

## 🤝 Feedback & Collaboration

I welcome any feedback, ideas, or requests. Open to collaborate!