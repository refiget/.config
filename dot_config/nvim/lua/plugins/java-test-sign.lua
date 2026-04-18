return {
  {
    "nvim-lua/plenary.nvim",
    ft = "java",
    config = function()
      local test_sign_name = "JavaTestRunSign"
      local main_sign_name = "JavaMainRunSign"
      local sign_group = "JavaRunSignGroup"

      for _, sign_name in ipairs({ test_sign_name, main_sign_name }) do
        vim.fn.sign_define(sign_name, {
          text = "",
          texthl = "DiagnosticSignHint",
          linehl = "",
          numhl = "",
        })
      end
      vim.api.nvim_set_hl(0, "DiagnosticSignHint", { fg = "#a6e3a1" })

      local function is_main_method_line(line)
        return line:match("public%s+static%s+void%s+main%s*%(")
          or line:match("static%s+public%s+void%s+main%s*%(")
      end

      local function collect_test_method_lines_treesitter(bufnr)
        local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
        if not ok_parser or not parser then
          return nil
        end

        local query_parse = vim.treesitter.query and vim.treesitter.query.parse
        if type(query_parse) == "table" and type(getmetatable(query_parse) and getmetatable(query_parse).__call) == "function" then
          query_parse = function(lang, q)
            return vim.treesitter.query.parse(lang, q)
          end
        end
        if type(query_parse) ~= "function" then
          return nil
        end

        local ok_query, query = pcall(
          query_parse,
          "java",
          [[
            (method_declaration
              (modifiers (marker_annotation name: (identifier) @ann))
              name: (identifier) @method_name) @method
          ]]
        )
        if not ok_query or not query then
          return nil
        end

        local ok_tree, trees = pcall(parser.parse, parser)
        if not ok_tree or not trees or not trees[1] then
          return nil
        end

        local root = trees[1]:root()
        local result = {}

        for _, match in query:iter_matches(root, bufnr, 0, -1) do
          local ann_nodes = match[1]
          local method_name_nodes = match[2]

          if ann_nodes and method_name_nodes then
            local has_test_ann = false
            for _, ann in ipairs(ann_nodes) do
              local ann_text = vim.treesitter.get_node_text(ann, bufnr)
              if ann_text == "Test" then
                has_test_ann = true
                break
              end
            end

            if has_test_ann then
              local method_name = method_name_nodes[1]
              if method_name then
                local row = select(1, method_name:range())
                result[row + 1] = true
              end
            end
          end
        end

        return result
      end

      local function collect_test_method_lines_fallback(lines)
        local result = {}
        local pending_test = false
        local in_block_comment = false

        local function line_has_test_annotation(line)
          return line:match("^%s*@Test%s*$") or line:match("^%s*@Test%f[%W]")
        end

        local function update_block_comment_state(line, state)
          local i = 1
          while i <= #line do
            local two = line:sub(i, i + 1)
            if not state and two == "/*" then
              state = true
              i = i + 2
            elseif state and two == "*/" then
              state = false
              i = i + 2
            else
              i = i + 1
            end
          end
          return state
        end

        local function is_method_declaration_line(line)
          local s = line:gsub("^%s+", "")
          if s:match("^[@%w_].*=.*;$") then
            return false
          end
          return s:match("^[%w_<>,%[%]%s]+%s+[%w_]+%s*%b()%s*[{;]?") ~= nil
        end

        for i, raw in ipairs(lines) do
          local line = raw or ""
          local currently_in_block = in_block_comment

          if not currently_in_block and line_has_test_annotation(line) then
            pending_test = true
          elseif pending_test then
            local trimmed = line:match("^%s*(.-)%s*$") or ""
            local skip = trimmed == "" or trimmed:match("^@") ~= nil or currently_in_block or trimmed:match("^//") ~= nil

            if not skip and is_method_declaration_line(line) then
              result[i] = true
              pending_test = false
            end
          end

          in_block_comment = update_block_comment_state(line, in_block_comment)
        end

        return result
      end

      local function refresh_java_run_signs(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        if vim.bo[bufnr].filetype ~= "java" then
          return
        end

        vim.fn.sign_unplace(sign_group, { buffer = bufnr })

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local test_lines = collect_test_method_lines_treesitter(bufnr) or collect_test_method_lines_fallback(lines)
        local id = 1

        for i, line in ipairs(lines) do
          if test_lines[i] then
            vim.fn.sign_place(id, sign_group, test_sign_name, bufnr, { lnum = i, priority = 10 })
            id = id + 1
          end

          if is_main_method_line(line) then
            vim.fn.sign_place(id, sign_group, main_sign_name, bufnr, { lnum = i, priority = 10 })
            id = id + 1
          end
        end
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
        group = vim.api.nvim_create_augroup("JavaRunSignAutocmd", { clear = true }),
        pattern = "*.java",
        callback = function(args)
          refresh_java_run_signs(args.buf)
        end,
      })

      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "java" then
          refresh_java_run_signs(b)
        end
      end
    end,
  },
}
