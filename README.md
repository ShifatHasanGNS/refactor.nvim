# 🔧 refactor.nvim

**The most intuitive and powerful find & replace plugin for Neovim**

Transform your refactoring workflow with smart 4-letter flags, beautiful UX, and rock-solid reliability. Whether you're renaming a single variable or refactoring across your entire codebase, refactor.nvim makes it effortless and safe.

<!-- ![Demo](https://via.placeholder.com/800x400/1a1b26/7aa2f7?text=refactor.nvim+Demo) -->

---

## 📚 Table of Contents

- [✨ Features](#-features)
- [🚀 Installation](#-installation)
- [⚡ Quick Start](#-quick-start)
- [🎯 Flag System](#-flag-system)
- [📖 Usage Examples](#-usage-examples)
- [⚙️ Configuration](#️-configuration)
- [🎮 Commands](#-commands)
- [🔍 Advanced Usage](#-advanced-usage)
- [❓ FAQ](#-faq)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Features

- 🎯 **4-Letter Magic Flags** - `cWrp`, `CWRp` - Intuitive combinations control everything
- 🔧 **Dual Mode Operations** - Work on current buffer or entire quickfix list
- 🎨 **Smart Case Preservation** - Maintains your code's existing case patterns
- 🛡️ **Safe Whole-Word Matching** - Prevents accidental partial replacements
- 🎭 **Beautiful Interface** - Emoji-powered prompts with real-time feedback
- ⚡ **Regex Support** - Full Neovim regex power when you need it
- 🚀 **Zero Configuration** - Works perfectly out of the box

---

## 🚀 Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "shifathasangns/refactor.nvim",
    config = function()
        require("refactor").setup()
    end,
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "shifathasangns/refactor.nvim",
    config = function()
        require("refactor").setup()
    end
}
```

### With [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'shifathasangns/refactor.nvim'
```

---

## ⚡ Quick Start

1. **Current Buffer**: Press `<leader>r`
2. **Quickfix List**: Press `<leader>rq`
3. **Visual Selection**: Select text, then `<leader>r`

**Example Workflow:**

```
<leader>r
Flags: cWrp
Find: userId
Replace: accountId
```

---

## 🎯 Flag System

The heart of refactor.nvim is its **4-letter flag system**:

```
Format: [C/c][W/w][R/r][P/p]
```

| Position | Flag      | Description                                      |
| -------- | --------- | ------------------------------------------------ |
| **1**    | `C` / `c` | **Case** - Sensitive / Insensitive               |
| **2**    | `W` / `w` | **Word** - Whole word / Partial match            |
| **3**    | `R` / `r` | **Regex** - Enabled / Literal text               |
| **4**    | `P` / `p` | **Preserve** - Case preservation / Exact replace |

### 🏆 Popular Combinations

| Flag   | Description                           | Perfect For                                  |
| ------ | ------------------------------------- | -------------------------------------------- |
| `cWrp` | Case insensitive, whole word, literal | **Most common** - Safe variable renaming     |
| `CWrp` | Case sensitive, whole word, literal   | **Precise** - Strict language refactoring    |
| `cWRp` | Case insensitive, whole word, regex   | **Advanced** - Pattern-based transformations |
| `CWRP` | All features enabled                  | **Maximum control** - Complex refactoring    |

---

## 📖 Usage Examples

### Simple Variable Rename

```
Flags: cWrp
Find: userId
Replace: accountId
Result: userId → accountId (but not userIdList)
```

### Function to Async Conversion

```
Flags: cWRp
Find: function (\w+)
Replace: async function $1
Result: function getData() → async function getData()
```

### Smart Case Preservation

```
Flags: cWrP
Find: api
Replace: service
Results:
  API → SERVICE
  Api → Service
  api → service
```

### Multi-file Refactoring

```bash
# 1. Populate quickfix with search results
:grep "oldFunction" **/*.js

# 2. Refactor across all matches
<leader>rq
Flags: cWrp
Find: oldFunction
Replace: newFunction
```

---

## ⚙️ Configuration

### Basic Setup

```lua
require("refactor").setup()
```

### Custom Configuration

```lua
require("refactor").setup({
    -- Custom keymap (default: "<leader>r")
    keymap = "<leader>R",
})
```

### Manual API Usage

```lua
local refactor = require("refactor")

-- Direct function calls
refactor.refactor_buffer()     -- Current buffer
refactor.refactor_quickfix()   -- Quickfix list
```

---

## 🎮 Commands

| Command                 | Description                | Equivalent   |
| ----------------------- | -------------------------- | ------------ |
| `:Refactor`             | Refactor in current buffer | `<leader>r`  |
| `:RefactorQF`           | Refactor in quickfix list  | `<leader>rq` |
| `:checkhealth refactor` | Plugin health check        | -            |

---

## 🔍 Advanced Usage

### Working with Quickfix Lists

**1. Search and Populate**

```vim
:grep "pattern" **/*.lua
:vimgrep /pattern/j **/*.js
```

**2. Refactor Across Results**

```
<leader>rq
Flags: cWRp
Find: old_pattern
Replace: new_pattern
```

### Visual Selection Workflow

1. **Select text** you want to find (visual mode)
2. **Press** `<leader>r`
3. **See selected text** in notification
4. **Enter flags and replacement**

### Complex Regex Examples

**Swap Function Arguments:**

```
Flags: cWRp
Find: (\w+)\((\w+), (\w+)\)
Replace: $1($3, $2)
```

**Add Type Annotations:**

```
Flags: cWRp
Find: function (\w+)\((.*)\)
Replace: function $1($2): void
```

---

## ❓ FAQ

**Q: What's the difference between `c` and `C`?**  
A: `c` = case insensitive (matches `API`, `api`, `Api`), `C` = case sensitive (matches only exact case)

**Q: When should I use `W` vs `w`?**  
A: `W` = whole words only (safe for variables), `w` = partial matches (good for strings/comments)

**Q: Can I use without the flag system?**  
A: The flags are required - they prevent accidental replacements and make operations predictable

**Q: Does it work with all file types?**  
A: Yes! It works with any text in Neovim, regardless of file type

**Q: How do I refactor across my entire project?**  
A: Use `:grep` or similar to populate quickfix, then `<leader>rq` to refactor across all matches

---

## 🤝 Contributing

We love contributions! Here's how to help:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin amazing-feature`
5. **Open** a Pull Request

### Development Setup

```bash
git clone https://github.com/shifathasangns/refactor.nvim
cd refactor.nvim
# Test locally by symlinking to your Neovim config
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for developers who refactor**

[⭐ Star this repo](https://github.com/shifathasangns/refactor.nvim) • [🐛 Report Issues](https://github.com/shifathasangns/refactor.nvim/issues) • [💡 Discussions](https://github.com/shifathasangns/refactor.nvim/discussions)

**Transform your workflow. Refactor with confidence.**

</div>
