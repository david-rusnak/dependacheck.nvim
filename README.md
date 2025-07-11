# dependacheck.nvim

A Neovim plugin that automatically checks for Cargo.toml dependency updates and displays them inline.

## Features

- **Automatic dependency checking** - Monitors your `Cargo.toml` files and checks for updates
- **Inline annotations** - Shows available updates as virtual text next to dependency lines
- **Asynchronous operations** - Non-blocking API calls to crates.io
- **Smart version comparison** - Only shows updates when newer versions are actually available
- **Comprehensive parsing** - Supports all dependency sections and formats

## Installation

### Prerequisites

This plugin requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for HTTP requests.

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "david-rusnak/dependacheck.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  ft = "toml",
  config = function()
    require("dependacheck").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "david-rusnak/dependacheck.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  ft = "toml",
  config = function()
    require("dependacheck").setup()
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'david-rusnak/dependacheck.nvim'
```

Then add to your init.lua:

```lua
require("dependacheck").setup()
```

## Usage

### Automatic Checking

The plugin automatically checks for dependency updates when you:

- Open a `Cargo.toml` file
- Save a `Cargo.toml` file

Updates are displayed as virtual text at the end of dependency lines:

```toml
[dependencies]
serde = "1.0.180"          # <� 1.0.195
tokio = { version = "1.32" } # <� 1.35.1
```

### Manual Checking

You can manually trigger dependency checking with the `:Dependacheck` command:

```vim
:Dependacheck
```

### Supported Dependency Sections

The plugin checks dependencies in all standard Cargo.toml sections:

- `[dependencies]`
- `[dev-dependencies]`
- `[build-dependencies]`
- `[workspace.dependencies]`

### Supported Dependency Formats

Both simple and table formats are supported:

```toml
# Simple format
serde = "1.0.180"

# Table format
tokio = { version = "1.32", features = ["full"] }
clap = { version = "4.0", default-features = false }
```

### Basic Setup

```lua
require("dependacheck").setup()
```

## How It Works

1. **File Detection**: The plugin monitors `Cargo.toml` files using Neovim's autocmd system
2. **Dependency Parsing**: Parses the TOML content to extract crate names and versions
3. **API Requests**: Makes asynchronous requests to `crates.io/api/v1/crates/{crate}`
4. **Version Comparison**: Compares current versions with latest available versions
5. **Visual Display**: Shows updates as virtual text using Neovim's extmark API

## Requirements

- Neovim 0.8+ (for extmark API)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Internet connection (for crates.io API access)

## License

MIT License

```

```
