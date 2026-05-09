{ pkgs, ... }:

{
  home.packages = [ pkgs.vim ];

  # Avoid ~/.vimrc. Vim reads this environment variable during startup.
  home.sessionVariables = {
    VIMINIT = "source $HOME/.config/vim/vimrc";
  };

  xdg.configFile."vim/vimrc".text = ''
    " Vim configuration managed by Home Manager.
    " Local changes should be made in home/vim.nix.

    " Runtime files do not belong in ~/.config. Keep viminfo in XDG_STATE_HOME.
    let s:vim_state_dir = empty($XDG_STATE_HOME) ? expand('~/.local/state/vim') : $XDG_STATE_HOME . '/vim'
    call mkdir(s:vim_state_dir, 'p')
    execute 'set viminfo+=n' . fnameescape(s:vim_state_dir . '/viminfo')

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
