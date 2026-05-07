{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;

    extraPackages = with pkgs; [
      # Native LSP servers and format/lint tools, all supplied by Nix for offline use.
      bash-language-server
      shellcheck
      shfmt

      yaml-language-server
      yamlfmt
      yamllint

      taplo

      vscode-langservers-extracted

      pyright
      ruff

      # fzf-lua helpers.
      fd
      fzf
      ripgrep
    ];

    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: with p; [
        bash
        json
        lua
        markdown
        nix
        python
        toml
        vim
        vimdoc
        yaml
      ]))
      SchemaStore-nvim
      mini-nvim
      fzf-lua
    ];

    initLua = ''
      --------------------------------------------------------------------------------------------------
      -- Shared minimal Neovim setup. Offline-safe: plugins, parsers, LSPs and tools come from Nix.
      --------------------------------------------------------------------------------------------------
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.signcolumn = "yes"
      vim.opt.cursorline = true
      vim.opt.list = true
      vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

      vim.opt.expandtab = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.softtabstop = 2
      vim.opt.autoindent = true
      vim.opt.smartindent = true

      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.incsearch = true
      vim.opt.hlsearch = true

      vim.opt.wrap = false
      vim.opt.breakindent = true
      vim.opt.scrolloff = 5
      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.termguicolors = true
      vim.opt.updatetime = 300
      vim.opt.timeoutlen = 500
      vim.opt.completeopt = { "menuone", "noselect", "popup" }

      local undodir = vim.fn.stdpath("state") .. "/undo"
      vim.fn.mkdir(undodir, "p")
      vim.opt.swapfile = false
      vim.opt.backup = false
      vim.opt.writebackup = false
      vim.opt.undofile = true
      vim.opt.undodir = undodir

      local augroup = vim.api.nvim_create_augroup("SharedConfig", { clear = true })

      vim.api.nvim_create_autocmd("TextYankPost", {
        group = augroup,
        desc = "Highlight yanked text",
        callback = function()
          vim.highlight.on_yank()
        end,
      })

      vim.api.nvim_create_autocmd("BufReadPost", {
        group = augroup,
        desc = "Restore last cursor position",
        callback = function()
          if vim.o.diff then return end
          local mark = vim.api.nvim_buf_get_mark(0, '"')
          local line_count = vim.api.nvim_buf_line_count(0)
          if mark[1] > 0 and mark[1] <= line_count then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = { "markdown", "text", "gitcommit" },
        desc = "Wrap prose-like filetypes",
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
        end,
      })

      --------------------------------------------------------------------------------------------------
      -- Treesitter: parsers are installed through Nix, never downloaded by Neovim.
      --------------------------------------------------------------------------------------------------
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("SharedTreeSitter", { clear = true }),
        desc = "Start Treesitter highlighting when a Nix-provided parser exists",
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if pcall(vim.treesitter.language.add, lang) then
            pcall(vim.treesitter.start, args.buf, lang)
          end
        end,
      })

      --------------------------------------------------------------------------------------------------
      -- Plugins
      --------------------------------------------------------------------------------------------------
      require("mini.statusline").setup()
      require("mini.bracketed").setup()

      local miniclue = require("mini.clue")
      miniclue.setup({
        triggers = {
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
          { mode = "n", keys = "<C-w>" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
        },
        clues = {
          miniclue.gen_clues.builtin_completion(),
          miniclue.gen_clues.g(),
          miniclue.gen_clues.marks(),
          miniclue.gen_clues.registers(),
          miniclue.gen_clues.windows(),
          miniclue.gen_clues.z(),

          { mode = "n", keys = "<Leader>f", desc = "+find/format" },
          { mode = "n", keys = "<Leader>r", desc = "+rename/references" },
          { mode = "n", keys = "<Leader>c", desc = "+code" },
        },
        window = {
          delay = 400,
          config = { width = "auto", border = "rounded" },
        },
      })

      require("fzf-lua").setup({
        winopts = { border = "rounded" },
        files = {
          fd_opts = "--color=never --type f --hidden --follow --exclude .git",
        },
        grep = {
          rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!/.git/*'",
        },
      })

      --------------------------------------------------------------------------------------------------
      -- Diagnostics
      --------------------------------------------------------------------------------------------------
      vim.diagnostic.config({
        virtual_text = { prefix = "●", spacing = 4 },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true },
      })

      --------------------------------------------------------------------------------------------------
      -- Native LSP and native Neovim completion
      --------------------------------------------------------------------------------------------------
      local schemastore = require("schemastore")

      vim.lsp.config("bashls", {
        cmd = { "bash-language-server", "start" },
        filetypes = { "bash", "sh", "zsh" },
        root_markers = { ".git" },
        settings = {
          bashIde = {
            shellcheckPath = "shellcheck",
          },
        },
      })

      vim.lsp.config("yamlls", {
        cmd = { "yaml-language-server", "--stdio" },
        filetypes = { "yaml", "yaml.docker-compose" },
        root_markers = { ".git" },
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" },
            schemas = schemastore.yaml.schemas(),
            validate = true,
          },
        },
      })

      vim.lsp.config("taplo", {
        cmd = { "taplo", "lsp", "stdio" },
        filetypes = { "toml" },
        root_markers = { ".taplo.toml", "taplo.toml", ".git" },
      })

      vim.lsp.config("jsonls", {
        cmd = { "vscode-json-language-server", "--stdio" },
        filetypes = { "json", "jsonc" },
        root_markers = { ".git" },
        settings = {
          json = {
            schemas = schemastore.json.schemas(),
            validate = { enable = true },
          },
        },
      })

      vim.lsp.config("pyright", {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        cmd = { "ruff", "server" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
      })

      vim.lsp.enable({ "bashls", "yamlls", "taplo", "jsonls", "pyright", "ruff" })

      local function format_with_command(cmd)
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local input = table.concat(lines, "\n") .. "\n"
        local result = vim.system(cmd, { text = true, stdin = input }):wait()
        if result.code ~= 0 then
          vim.notify((result.stderr ~= "" and result.stderr or "Formatter failed"), vim.log.levels.ERROR)
          return
        end
        local view = vim.fn.winsaveview()
        local output = vim.split(result.stdout:gsub("\n$", ""), "\n", { plain = true })
        vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
        vim.fn.winrestview(view)
      end

      local function format_buffer()
        local ft = vim.bo.filetype
        if ft == "sh" or ft == "bash" or ft == "zsh" then
          format_with_command({ "shfmt", "-i", "2", "-ci", "-sr" })
          return
        end
        if ft == "yaml" or ft == "yaml.docker-compose" then
          format_with_command({ "yamlfmt", "-in" })
          return
        end
        vim.lsp.buf.format({ async = true, timeout_ms = 3000 })
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = augroup,
        desc = "LSP keymaps and native completion",
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local bufnr = args.buf

          if client and client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
          end

          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          map("n", "gd", vim.lsp.buf.definition, "LSP: go to definition")
          map("n", "gD", vim.lsp.buf.declaration, "LSP: go to declaration")
          map("n", "gr", vim.lsp.buf.references, "LSP: references")
          map("n", "gi", vim.lsp.buf.implementation, "LSP: implementation")
          map("n", "K", vim.lsp.buf.hover, "LSP: hover")
          map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: rename")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
          map("n", "<leader>f", format_buffer, "Format buffer")
        end,
      })

      --------------------------------------------------------------------------------------------------
      -- Shared keymaps
      --------------------------------------------------------------------------------------------------
      vim.keymap.set("n", "<leader>w", "<cmd>update<cr>", { desc = "Save buffer" })
      vim.keymap.set("n", "<leader>x", "<cmd>quit<cr>", { desc = "Quit" })
      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
      vim.keymap.set("i", "<C-Space>", "<C-x><C-o>", { desc = "Trigger completion" })

      -- Selection helpers: move selected lines and keep visual selection after indenting.
      vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
      vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })
      vim.keymap.set("v", "H", "<gv", { desc = "Indent selection left", silent = true })
      vim.keymap.set("v", "L", ">gv", { desc = "Indent selection right", silent = true })
      vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines without moving cursor" })

      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })
      vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to location list" })

      local fzf = require("fzf-lua")
      vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
      vim.keymap.set("n", "<leader>fh", fzf.help_tags, { desc = "Find help" })
      vim.keymap.set("n", "<leader>fk", fzf.keymaps, { desc = "Find keymaps" })
      vim.keymap.set("n", "<leader>fd", fzf.diagnostics_document, { desc = "Document diagnostics" })
      vim.keymap.set("n", "<leader>fs", fzf.lsp_document_symbols, { desc = "Document symbols" })
      vim.keymap.set("n", "<leader>fr", fzf.lsp_references, { desc = "LSP references" })
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
