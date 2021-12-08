"-------------------------------------------------------------------------------
" General settings
"-------------------------------------------------------------------------------

set cc=80
set confirm
"set expandtab
set hidden
set hlsearch
set ignorecase
set ignorecase
set list
set listchars=tab:▸\ ,trail:·
set mouse=a
set nocompatible
set number
set relativenumber
set scrolloff=8
set shiftwidth=4
set showmatch
set sidescrolloff=8
set signcolumn=yes:2
set smartcase
set softtabstop=-1 " When negative, the value of shiftwidth is used.
set tabstop=4
set spell
set splitright
set termguicolors
set clipboard=unnamedplus
set title
set wildmode=longest:full,full
set encoding=UTF-8

filetype plugin indent on
syntax on

"--------------------------------------------------------------------------
" Key maps
"--------------------------------------------------------------------------

let mapleader = "\<space>"

nmap <leader>k :nohlsearch<CR>

nmap <leader>ve :edit ~/.config/nvim/init.vim<cr>
nmap <leader>vr :source ~/.config/nvim/init.vim<cr>

" Allow gf to open non-existent files
map gf :edit <cfile><cr>

" Reselect visual selection after indenting
vnoremap < <gv
vnoremap > >gv

nmap <leader>Q :bufdo bdelete<cr>

" Maintain the cursor position when yanking a visual selection
" http://ddrscott.github.io/blog/2016/yank-without-jank/
vnoremap y myy`y
vnoremap Y myY`y

" Open the current file in the default program
nmap <leader>x :!xdg-open %<cr><cr>


"-------------------------------------------------------------------------------
" Plugins
"-------------------------------------------------------------------------------

" Automatically install vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin(data_dir . '/plugins')

source ~/.config/nvim/plugins/airline.vim
source ~/.config/nvim/plugins/heritage.vim
source ~/.config/nvim/plugins/coc.vim
source ~/.config/nvim/plugins/commentary.vim
source ~/.config/nvim/plugins/fugitive.vim
source ~/.config/nvim/plugins/floaterm.vim
source ~/.config/nvim/plugins/lastplace.vim
source ~/.config/nvim/plugins/fzf.vim
source ~/.config/nvim/plugins/nord.vim
source ~/.config/nvim/plugins/sayonara.vim
" source ~/.config/nvim/plugins/polyglot.vim
source ~/.config/nvim/plugins/surround.vim
source ~/.config/nvim/plugins/peekaboo.vim
source ~/.config/nvim/plugins/exchange.vim
source ~/.config/nvim/plugins/nerdtree.vim

call plug#end()

doautocmd User PlugLoaded
