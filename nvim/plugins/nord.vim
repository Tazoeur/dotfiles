Plug 'arcticicestudio/nord-vim'

augroup NordOverrides
    autocmd!
    " autocmd ColorScheme dracula highlight DraculaBoundary guibg=none
    autocmd User PlugLoaded ++nested colorscheme nord
augroup end