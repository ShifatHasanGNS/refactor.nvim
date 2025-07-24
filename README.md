# `refactor.nvim`

**`refactor.nvim`** is a NeoVim plugin written in Lua that enhances your editing experience with advanced find and replace capabilities. Whether you need to refactor text in the current buffer or across multiple files via the quickfix list, this plugin offers a flexible and user-friendly solution with support for various matching options.

![refactor-nvim-baby](./image/refactor-nvim-baby.png)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Health Check](#health-check)
- [Author](#author)
- [License](#license)

---

## Features

- Perform find and replace operations in the current file/buffer
- Extend replacements across the quickfix list
- Toggle case-sensitive or case-insensitive searches
- Match whole words or partial text
- Optionally use regular expressions for complex patterns
- Optionally preserve case during replacements
- Cancel operations easily with ESC
- Receive clear, informative notifications

---

## Installation

`refactor.nvim` requires [NeoVim](https://neovim.io/) 0.7 or later. You can install it using your preferred package manager.

### Using [Lazy](https://github.com/folke/lazy.nvim)

Add the following to your `Lazy` configuration:

```lua
{
  "ShifatHasanGNS/refactor.nvim",
  config = function()
    require("refactor").setup()
  end
}
```

### Using [Packer](https://github.com/wbthomason/packer.nvim)

Add the following to your `Packer` configuration:

```lua
use {
  "ShifatHasanGNS/refactor.nvim",
  config = function()
    require("refactor").setup()
  end
}
```

### Using [Vim-Plug](https://github.com/junegunn/vim-plug)

Add the following to your `vimrc`:

```viml
Plug 'ShifatHasanGNS/refactor.nvim'
```

Then, in your NeoVim configuration (e.g., `init.lua`):

```lua
require("refactor").setup()
```

---

## Usage

It provides two primary commands to initiate refactoring:

- `:RefactorB` - Refactor in the current buffer
- `:RefactorQ` - Refactor across the quickfix list

Default key mappings are also available (using `<leader>r` as the base):

- `<leader>rb` - Refactor in the current buffer
- `<leader>rq` - Refactor in the quickfix list

### How It Works

When you run a refactor command, the plugin guides you through these steps:

1. **Flags**: Enter optional flags (e.g., `cw` for case-sensitive and whole-word). Press Enter to use defaults. Available flags:
   - `c` - Case-sensitive
   - `w` - Whole-word
   - `r` - Regular expression
   - `p` - Preserve case
2. **Find String**: Enter the text or pattern to search for.
3. **Replace String**: Enter the replacement text.
4. **Confirmation**: Type `y` to proceed or `n` to cancel.

Press `ESC` at any prompt to cancel the operation. Notifications will keep you informed throughout the process. To cencel operations just after initiating, you have to press `ESC` twice.

### Example

To replace all occurrences of "Yisra'el" with "Filastin" in the current buffer, case-sensitive and whole-word only:

- Run `:RefactorB` or `<leader>rb`
- Enter flags: `cw`
- Find: `Yisra'el`
- Replace: `Filastin`
- Confirm: `y`

---

## Configuration

Customize the plugin by passing options to the `setup` function. For example, to set default flags:

```lua
-- For Example
require("refactor").setup({
  -- Case-sensitive and whole-word by default
  default_flags = "cw"
})
```

The `default_flags` option accepts any combination of `c`, `w`, `r`, and `p`. Leave it empty (`""`) for default behavior (case-insensitive, partial-match, literal-text, normal-case).

## Health Check

Ensure the plugin is working correctly by running:

```
:checkhealth refactor
```

This command verifies the NeoVim version and plugin loading status.

---

## Author

Developed by [**Md. Shifat Hasan**](https://github.com/ShifatHasanGNS)

_**Contact**_

[Facebook](https://www.facebook.com/ShifatHasanGNS/)
&emsp;
[Instagram](https://www.instagram.com/ShifatHasanGNS/)
&emsp;
[Linkedin](https://www.linkedin.com/in/md-shifat-hasan-8179402b4/)
&emsp;
[X](https://x.com/ShifatHasanGNS)

## License

`refactor.nvim` is distributed under the [MIT License](./LICENSE).
