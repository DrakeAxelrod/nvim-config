
return {
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    }
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function()
      local ts = require("nvim-treesitter.configs")
      return {
        ensure_installed = { "all" }, --"all", -- one of "all" or a list of languages
        sync_install = true, -- install languages synchronously (only applied to `ensure_installed`)
        auto_install = true,
        ignore_install = { "" }, -- List of parsers to ignore installing
        highlight = {
          -- use_languagetree = true,
          enable = true, -- false will disable the whole extension
          -- disable = { "css", "html" }, -- list of language that will be disabled
          disable = function(lang, buf)
            if vim.tbl_contains({ "latex" }, lang) then
              return true
            end

            local max_filesize = 1024 * 1024
            local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
              -- local ok, illuminate = pcall(require, "illuminate")
              -- if ok then
              --   illuminate.pause_buf()
              -- end

              vim.schedule(function()
                vim.api.nvim_buf_call(buf, function()
                  vim.cmd "setlocal noswapfile noundofile"

                  if vim.tbl_contains({ "json" }, lang) then
                    vim.cmd "NoMatchParen"
                    vim.cmd "syntax off"
                    vim.cmd "syntax clear"
                    vim.cmd "setlocal nocursorline nolist bufhidden=unload"

                    vim.api.nvim_create_autocmd({ "BufDelete" }, {
                      callback = function()
                        vim.cmd "DoMatchParen"
                        vim.cmd "syntax on"
                      end,
                      buffer = buf,
                    })
                  end
                end)
              end)

              vim.notify({
                text = "File larger than 1MB, turned off treesitter for this buffer"
              })
              return true
            end
          end,
          additional_vim_regex_highlighting = true,
        },
        -- incremental selection
        incremental_selection = {
          enable = true,
          keymaps = {
            -- init_selection = mapping.plugin.nvim_treesitter.init_selection,
            -- node_incremental = mapping.plugin.nvim_treesitter.node_incremental,
            -- node_decremental = mapping.plugin.nvim_treesitter.node_decremental,
            -- scope_incremental = mapping.plugin.nvim_treesitter.scope_incremental
          }
        },
        indent = {
          enable = {
            "javascriptreact",
          },
          disable = { "css", "yaml" },
        },
        playground = {
          enable = true,
          disable = {},
          updatetime = 25,
          persist_queries = false,
          keybindings = {
            toggle_query_editor = "o",
            toggle_hl_groups = "i",
            toggle_injected_languages = "t",
            toggle_anonymous_nodes = "a",
            toggle_language_display = "I",
            focus_language = "f",
            unfocus_language = "F",
            update = "R",
            goto_node = "<cr>",
            show_help = "?",
          },
        },
        autopairs = {
          enable = true,
        },
        autotag = {
          enable = true,
          disable = { "xml" },
        },
        rainbow = {
          enable = true,
          extended_mode = false, -- Highlight also non-parentheses delimiters, boolean or table: lang -> boolean
          -- colors = {
          --   c.white,
          --   c.yellow,
          --   c.magenta,
          --   c.cyan,
          --   c.blue,
          --   c.green,
          -- },
          disable = { "html" },
        },
        context_commentstring = {
          enable = true,
          config = {
            -- Languages that have a single comment style
            typescript = "// %s",
            css = "/* %s */",
            scss = "/* %s */",
            html = "<!-- %s -->",
            svelte = "<!-- %s -->",
            vue = "<!-- %s -->",
            json = "",
            javascriptreact = {
              style_element = "{/*%s*/}",
            },
          },
        },
        textobjects = {
          swap = {
            enable = false,
            -- swap_next = textobj_swap_keymaps,
          },
          -- move = textobj_move_keymaps,
          select = {
            enable = false,
            -- keymaps = textobj_sel_keymaps,
          },
        },
        textsubjects = {
          enable = false,
          keymaps = {
            ["."] = "textsubjects-smart",
            [";"] = "textsubjects-big" },
        },
      }
    end
  },
  {
    "NvChad/nvim-colorizer.lua",
    opts = {
      filetypes = { "*" },
      user_default_options = {
        RGB = true, -- #RGB hex codes
        RRGGBB = true, -- #RRGGBB hex codes
        names = false, -- "Name" codes like Blue or blue
        RRGGBBAA = false, -- #RRGGBBAA hex codes
        AARRGGBB = false, -- 0xAARRGGBB hex codes
        rgb_fn = false, -- CSS rgb() and rgba() functions
        hsl_fn = false, -- CSS hsl() and hsla() functions
        css = false, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
        css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
        -- Available modes for `mode`: foreground, background,  virtualtext
        mode = "background", -- Set the display mode.
        -- Available methods are false / true / "normal" / "lsp" / "both"
        -- True is same as normal
        tailwind = false, -- Enable tailwind colors
        -- parsers can contain values used in |user_default_options|
        sass = { enable = false, parsers = { "css" }, }, -- Enable sass colors
        virtualtext = "■",
      },
      -- all the sub-options of filetypes apply to buftypes
      buftypes = {},
    }
  },
}
