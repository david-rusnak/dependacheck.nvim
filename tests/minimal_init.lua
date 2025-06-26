-- Minimal init file for running tests
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

-- Add current project to runtimepath
local current_dir = vim.fn.getcwd()
vim.cmd([[set runtimepath+=]] .. current_dir)

-- Install plenary.nvim if not already installed
local install_path = "/tmp/nvim/site/pack/packer/start/plenary.nvim"
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  vim.fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/nvim-lua/plenary.nvim",
    install_path,
  })
end
vim.cmd([[runtime plugin/plenary.vim]])

-- Set up test environment
vim.o.swapfile = false
vim.bo.swapfile = false