-- https://github.com/hrsh7th/nvim-cmp
-- https://github.com/hrsh7th/cmp-nvim-lsp
-- https://github.com/hrsh7th/cmp-path
-- https://github.com/hrsh7th/cmp-buffer
return function(cmp)
  local M = {}
  M.methods = {}
  local icons = require("lib.icons")
  local under_compare = function(entry1, entry2)
    local _, entry1_under = entry1.completion_item.label:find "^_+"
    local _, entry2_under = entry2.completion_item.label:find "^_+"
    entry1_under = entry1_under or 0
    entry2_under = entry2_under or 0
    -- _ completions at the beginning come later
    return entry1_under < entry2_under
  end

  local luasnip_ok, luasnip = pcall(require, "luasnip")
  if luasnip_ok then
    require("luasnip.loaders.from_lua").lazy_load()
    require("luasnip.loaders.from_vscode").lazy_load {
      paths = {
        api.fs.join(vim.fn.stdpath("config") .. "/snippets"),
        api.fs.join(vim.fn.stdpath("data") .. "/site/pack/packer/opt/friendly-snippets/snippets"),
      },
    }
    require("luasnip.loaders.from_snipmate").lazy_load()
  end
  ---checks if the character preceding the cursor is a space character
  ---@return boolean true if it is a space character, false otherwise
  local check_backspace = function()
    local col = vim.fn.col "." - 1
    return col == 0 or vim.fn.getline("."):sub(col, col):match "%s"
  end
  M.methods.check_backspace = check_backspace

  ---wraps vim.fn.feedkeys while replacing key codes with escape codes
  ---Ex: feedkeys("<CR>", "n") becomes feedkeys("^M", "n")
  ---@param key string
  ---@param mode string
  local function feedkeys(key, mode)
    vim.fn.feedkeys(t(key), mode)
  end

  M.methods.feedkeys = feedkeys

  ---checks if emmet_ls is available and active in the buffer
  ---@return boolean true if available, false otherwise
  local is_emmet_active = function()
    local clients = vim.lsp.buf_get_clients()

    for _, client in pairs(clients) do
      if client.name == "emmet_ls" then
        return true
      end
    end
    return false
  end
  M.methods.is_emmet_active = is_emmet_active

  ---when inside a snippet, seeks to the nearest luasnip field if possible, and checks if it is jumpable
  ---@param dir number dir options 1 for forward, -1 for backward; defaults to 1
  ---@return boolean true if a jumpable luasnip field is found while inside a snippet
  local function jumpable(dir)
    dir = dir or 1
    if not luasnip_ok then
      return
    end

    local win_get_cursor = vim.api.nvim_win_get_cursor
    local get_current_buf = vim.api.nvim_get_current_buf

    local function inside_snippet()
      -- for outdated versions of luasnip
      if not luasnip.session.current_nodes then
        return false
      end

      local node = luasnip.session.current_nodes[get_current_buf()]
      if not node then
        return false
      end

      local snip_begin_pos, snip_end_pos = node.parent.snippet.mark:pos_begin_end()
      local pos = win_get_cursor(0)
      pos[1] = pos[1] - 1 -- LuaSnip is 0-based not 1-based like nvim for rows
      return pos[1] >= snip_begin_pos[1] and pos[1] <= snip_end_pos[1]
    end

    ---sets the current buffer's luasnip to the one nearest the cursor
    ---@return boolean true if a node is found, false otherwise
    local function seek_luasnip_cursor_node()
      -- for outdated versions of luasnip
      if not luasnip.session.current_nodes then
        return false
      end

      local pos = win_get_cursor(0)
      pos[1] = pos[1] - 1
      local node = luasnip.session.current_nodes[get_current_buf()]
      if not node then
        return false
      end

      local snippet = node.parent.snippet
      local exit_node = snippet.insert_nodes[0]

      -- exit early if we're past the exit node
      if exit_node then
        local exit_pos_end = exit_node.mark:pos_end()
        if (pos[1] > exit_pos_end[1]) or (pos[1] == exit_pos_end[1] and pos[2] > exit_pos_end[2]) then
          snippet:remove_from_jumplist()
          luasnip.session.current_nodes[get_current_buf()] = nil

          return false
        end
      end

      node = snippet.inner_first:jump_into(1, true)
      while node ~= nil and node.next ~= nil and node ~= snippet do
        local n_next = node.next
        local next_pos = n_next and n_next.mark:pos_begin()
        local candidate = n_next ~= snippet and next_pos and (pos[1] < next_pos[1])
            or (pos[1] == next_pos[1] and pos[2] < next_pos[2])

        -- Past unmarked exit node, exit early
        if n_next == nil or n_next == snippet.next then
          snippet:remove_from_jumplist()
          luasnip.session.current_nodes[get_current_buf()] = nil

          return false
        end

        if candidate then
          luasnip.session.current_nodes[get_current_buf()] = node
          return true
        end

        local ok
        ok, node = pcall(node.jump_from, node, 1, true) -- no_move until last stop
        if not ok then
          snippet:remove_from_jumplist()
          luasnip.session.current_nodes[get_current_buf()] = nil

          return false
        end
      end

      -- No candidate, but have an exit node
      if exit_node then
        -- to jump to the exit node, seek to snippet
        luasnip.session.current_nodes[get_current_buf()] = snippet
        return true
      end

      -- No exit node, exit from snippet
      snippet:remove_from_jumplist()
      luasnip.session.current_nodes[get_current_buf()] = nil
      return false
    end

    if dir == -1 then
      return inside_snippet() and luasnip.jumpable(-1)
    else
      return inside_snippet() and seek_luasnip_cursor_node() and luasnip.jumpable()
    end
  end

  M.methods.jumpable = jumpable


  local kind_icons = icons.kind

  cmp.setup {
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body) -- For `luasnip` users.
      end,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert {
      ["<C-k>"] = cmp.mapping.select_prev_item(),
      ["<C-j>"] = cmp.mapping.select_next_item(),
      ["<C-d>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expandable() then
          luasnip.expand()
        elseif jumpable(1) then
          luasnip.jump(1)
        elseif check_backspace() then
          fallback()
        elseif is_emmet_active() then
          return vim.fn["cmp#complete"]()
        else
          fallback()
        end
      end, {
        "i",
        "s",
      }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, {
        "i",
        "s",
      }),

      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-e>"] = cmp.mapping.abort(),
      ["<CR>"] = cmp.mapping(function(fallback)
        if cmp.visible() and cmp.confirm({
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        }) then
          if jumpable(1) then
            luasnip.jump(1)
          end
          return
        end

        if jumpable(1) then
          if not luasnip.jump(1) then
            fallback()
          end
        else
          fallback()
        end
      end),
    },
    formatting = {
      fields = { "kind", "abbr", "menu" },
      format = function(entry, vim_item)
        -- Kind icons
        vim_item.kind = ("%s"):format(kind_icons[vim_item.kind])
        -- NOTE: order matters
        vim_item.menu = ({
          nvim_lsp = "(lsp)",
          nvim_lua = "(nvim)",
          copilot = "(copilot)",
          ["lua-dev"] = "(ldev)",
          luasnip = "(snippet)",
          buffer = "(buffer)",
          path = "(path)",
        })[entry.source.name]
        return vim_item
      end,
    },
    sorting = {
      priority_weight = 2,
      comparators = {
        under_compare,
        cmp.config.compare.offset,
        cmp.config.compare.exact,
        cmp.config.compare.score,
        cmp.config.compare.length,
        cmp.config.compare.recently_used,
        cmp.config.compare.locality,
        cmp.config.compare.kind,
        cmp.config.compare.sort_text,
        cmp.config.compare.order
      }
    },
    sources = cmp.config.sources({
      { name = "copilot" },
      { name = "lua-dev" },
      { name = "nvim_lsp" },
      { name = "nvim_lua" },
      { name = "luasnip" },
      { name = "nvim_lsp_signature_help" },
      { name = "path"},
    }, {
      { name = 'buffer' },
    }),
    duplicates = {
      buffer = 1,
      path = 1,
      nvim_lsp = 0,
      luasnip = 1,
    },
    duplicates_default = 0,
    experimental = {
      ghost_text = false,
      native_menu = false,
    },
  }
end
