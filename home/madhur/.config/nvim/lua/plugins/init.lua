-- This file can be loaded by calling `lua require('plugins')` from your init.vim

return require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
   use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    } 

end)
