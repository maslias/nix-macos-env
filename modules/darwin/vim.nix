{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.vim ];

  environment.etc."vimrc".text = ''
    " Minimal shared Vim setup for editing config files and scripts.
    set number
    set relativenumber

    set expandtab
    set tabstop=2
    set shiftwidth=2
    set softtabstop=2
    set autoindent
    set smartindent

    set nowrap
    set scrolloff=5

    set ignorecase
    set smartcase
    set incsearch
    set hlsearch

    set ruler
    set showcmd

    syntax on
    filetype plugin indent on
  '';
}
