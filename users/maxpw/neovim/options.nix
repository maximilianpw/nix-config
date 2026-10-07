# Declarative editor options, applied by Nixvim before lua/config runs.
# Behavior that is not a plain assignment stays in lua/config/options.lua.
{
  luaLoader.enable = true;

  globals = {
    # Must be set before any mapping is defined.
    mapleader = " ";
    maplocalleader = " ";
    have_nerd_font = true;
  };

  opts = {
    number = true;
    relativenumber = true;
    mouse = "a";
    showmode = false;

    breakindent = true;
    undofile = true;
    ignorecase = true;
    smartcase = true;

    signcolumn = "yes";
    updatetime = 250;
    timeoutlen = 300;
    splitright = true;
    splitbelow = true;
    list = true;
    inccommand = "split";
    cursorline = true;
    scrolloff = 10;
    confirm = true;

    tabstop = 2;
    shiftwidth = 2;
    expandtab = true;
    listchars = {
      tab = "» ";
      trail = "·";
      nbsp = "␣";
    };

    termguicolors = true;

    # Completion menu for blink.cmp
    completeopt = "menu,menuone,noselect";
    pumheight = 15;

    virtualedit = "block";
    fillchars = {
      fold = "⸱";
      foldopen = "▾";
      foldclose = "▸";
      foldsep = " ";
      diff = "╱";
      eob = " ";
    };
    smoothscroll = true;
    foldlevel = 99;
    foldmethod = "expr";
    foldexpr = "v:lua.vim.treesitter.foldexpr()";
    foldtext = "";

    hlsearch = true;
    incsearch = true;

    wildmode = "longest:full,full";
    wildignore = ["*.o" "*.obj" ".git" "node_modules" "*.pyc"];
  };
}
