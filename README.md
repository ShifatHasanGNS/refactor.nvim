# 🔧 refactor.nvim

<!-- **The most intuitive and powerful find & replace plugin for Neovim**

Transform your refactoring workflow with smart 4-letter flags, beautiful UX, and rock-solid reliability. Whether you're renaming a single variable or refactoring across your entire codebase, refactor.nvim makes it effortless and safe.

![Demo](https://via.placeholder.com/800x400/1a1b26/7aa2f7?text=refactor.nvim+Demo)

## ✨ Features

- 🎯 **4-Letter Magic Flags** - `cWrp`, `CWRp` - Intuitive combinations control everything
- 🔧 **Dual Mode Operations** - Work on current buffer or entire quickfix list
- 🎨 **Smart Case Preservation** - Maintains your code's existing case patterns
- 🛡️ **Safe Whole-Word Matching** - Prevents accidental partial replacements
- 🎭 **Beautiful Interface** - Emoji-powered prompts with real-time feedback
- ⚡ **Regex Support** - Full Neovim regex power when you need it
- 🚀 **Zero Configuration** - Works perfectly out of the box

## 🚀 Quick Start

### Installation

#### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "shifathasangns/refactor.nvim",
    config = function()
        require("refactor").setup()
    end,
}
```

#### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "shifathasangns/refactor.nvim",
    config = function()
        require("refactor").setup()
    end
}
```

### Basic Usage

1. **Current Buffer**: Press `<leader>r`
2. **Quickfix List**: Press `<leader>rq`
3. **Visual Selection**: Select text, then `<leader>r`

## 🎯 Flag System

The heart of refactor.nvim is its **4-letter flag system** - each position controls a specific behavior:

```
Position:  1    2    3    4
Format:   [C/c][W/w][R/r][P/p]
Example:   c    W    r    p
```

| Position | Flag      | Meaning                                          |
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

## 📖 Examples

### Simple Variable Rename

```
Flags: cWrp
Find: userId
Replace: accountId
```

Safely renames `userId` → `accountId` without touching `userIdList` or `isUserId`.

### Function to Async Conversion

```
Flags: cWRp
Find: function (\w+)
Replace: async function $1
```

Transforms `function getData()` → `async function getData()` across your project.

### Smart Case Preservation

```
Flags: cWrP
Find: api
Replace: service
```

- `API` → `SERVICE`
- `Api` → `Service`
- `api` → `service`

## ⚙️ Configuration

```lua
require("refactor").setup({
    -- Custom keymap (default: "<leader>r")
    keymap = "<leader>R",

    -- Additional options coming soon...
})
```

## 🎮 Commands

| Command       | Description                     |
| ------------- | ------------------------------- |
| `:Refactor`   | Open refactor in current buffer |
| `:RefactorQF` | Open refactor for quickfix list |

## 🛠️ Advanced Usage

### Working with Quickfix Lists

1. **Populate quickfix** with your search results:

   ```vim
   :grep "function.*getData" **/*.js
   ```

2. **Mass refactor** across all matches:
   ```
   <leader>rq
   Flags: cWRp
   Find: function (\w+)
   Replace: async function $1
   ```

### Visual Selection Workflow

1. **Select text** you want to find
2. **Press** `<leader>r`
3. **Confirmation** shows selected text
4. **Enter replacement** and flags

## 🔍 Why refactor.nvim?

| Traditional Approach  | refactor.nvim               |
| --------------------- | --------------------------- |
| `:s/old/new/gc`       | `cWrp` + intuitive prompts  |
| Remember regex syntax | Smart 4-letter flags        |
| Risk partial matches  | Safe whole-word default     |
| Manual case handling  | Automatic case preservation |
| Command-line only     | Beautiful visual feedback   |

## 🤝 Contributing

We love contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built for the amazing Neovim community
- Inspired by modern refactoring tools
- Designed for developer happiness

---

<div align="center">

**Made with ❤️ for developers who refactor**

[⭐ Star this repo](https://github.com/shifathasangns/refactor.nvim) • [🐛 Report Issues](https://github.com/shifathasangns/refactor.nvim/issues) • [💡 Feature Requests](https://github.com/shifathasangns/refactor.nvim/discussions)

</div> -->
