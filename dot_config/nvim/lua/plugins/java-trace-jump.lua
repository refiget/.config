return {
  {
    "nvim-lua/plenary.nvim",
    event = "VeryLazy",
    init = function()
      local function get_src_roots(project_root)
        local roots = {}
        local classpath = project_root .. "/.classpath"
        if vim.fn.filereadable(classpath) == 1 then
          local lines = vim.fn.readfile(classpath)
          for _, l in ipairs(lines) do
            local kind = l:match('kind="([^"]+)"')
            local path = l:match('path="([^"]+)"')
            if kind == "src" and path and path ~= "" then
              table.insert(roots, project_root .. "/" .. path)
            end
          end
        end

        if #roots == 0 then
          table.insert(roots, project_root .. "/src")
          table.insert(roots, project_root .. "/tests")
        end
        return roots
      end

      local function parse_stack_line(line)
        -- Example: at game2048logic.Model.atLeastOneMoveExists(Model.java:144)
        local class_fqn, lineno = line:match("at%s+([%w_%.%$]+)%.[%w_%$<>]+%([^:]+:(%d+)%)")
        if not class_fqn then
          return nil
        end
        class_fqn = class_fqn:gsub("%$.*$", "") -- inner classes -> outer source file
        local rel = class_fqn:gsub("%.", "/") .. ".java"
        return rel, tonumber(lineno)
      end

      local function java_trace_jump()
        local line = vim.api.nvim_get_current_line()
        local rel, lineno = parse_stack_line(line)
        if not rel or not lineno then
          vim.notify("No Java stack trace target found on current line", vim.log.levels.WARN)
          return
        end

        local project_root = vim.fn.getcwd()
        local roots = get_src_roots(project_root)

        local target = nil
        for _, root in ipairs(roots) do
          local p = root .. "/" .. rel
          if vim.fn.filereadable(p) == 1 then
            target = p
            break
          end
        end

        if not target then
          -- fallback: basename search in project
          local base = rel:match("([^/]+)$")
          local found = vim.fn.glob(project_root .. "/**/" .. base, false, true)
          if type(found) == "table" and #found > 0 then
            target = found[1]
          end
        end

        if not target then
          vim.notify("Target source not found for " .. rel, vim.log.levels.ERROR)
          return
        end

        -- Open target directly in a NEW tab (avoid temporary [No Name] tab)
        vim.cmd("tabedit " .. vim.fn.fnameescape(target))
        local max_line = vim.api.nvim_buf_line_count(0)
        local row = math.max(1, math.min(lineno, max_line))
        pcall(vim.api.nvim_win_set_cursor, 0, { row, 0 })
        vim.cmd("normal! zz")
      end

      vim.api.nvim_create_user_command("JavaTraceJump", java_trace_jump, {
        desc = "Jump from Java stacktrace line to source",
      })

      vim.keymap.set("n", "<leader>gj", java_trace_jump, {
        desc = "Java stacktrace jump",
        silent = true,
      })
    end,
  },
}
