return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.explorer = opts.picker.sources.explorer or {}

      local function extract_known_vim_open_error(err)
        local msg = tostring(err or "Unknown Snacks error")
        local candidates = {
          { pattern = "Vim%b():E325:", code = "E325" },
          { plain = "Vim:E325:", code = "E325" },
          { pattern = "Vim%b():E37:", code = "E37" },
          { plain = "Vim:E37:", code = "E37" },
          { pattern = "Vim%b():E162:", code = "E162" },
          { plain = "Vim:E162:", code = "E162" },
        }

        local start_idx, code
        for _, candidate in ipairs(candidates) do
          local idx = candidate.plain and msg:find(candidate.plain, 1, true) or msg:find(candidate.pattern)
          if idx and (not start_idx or idx < start_idx) then
            start_idx = idx
            code = candidate.code
          end
        end

        if not start_idx then
          return false
        end

        local has_exec2_wrapper = msg:find("nvim_exec2()", 1, true) ~= nil
        local direct_vim_error = msg:sub(1, start_idx - 1):match("^%s*$") ~= nil
        if not (has_exec2_wrapper or direct_vim_error) then
          return false
        end

        return true, msg:sub(start_idx):gsub("\n+$", ""), code
      end

      local function append_guidance(detail, code)
        if code == "E325" then
          return detail
            .. "\n检测到 swap 文件冲突；请先 :recover，或删除对应 .swp 文件后再重试。"
        elseif code == "E37" or code == "E162" then
          return detail
            .. "\n当前缓冲区有未保存修改；请先 :w / :wa 保存，再从 explorer 打开文件。"
        end
        return detail
      end

      local original_confirm = opts.picker.sources.explorer.confirm
      if type(original_confirm) ~= "function" then
        original_confirm = require("snacks.explorer.actions").actions.confirm
      end

      opts.picker.sources.explorer.confirm = function(...)
        local result = table.pack(pcall(original_confirm, ...))
        if result[1] then
          return table.unpack(result, 2, result.n)
        end

        local handled, detail, code = extract_known_vim_open_error(result[2])
        if handled then
          vim.notify(append_guidance(detail, code), vim.log.levels.ERROR, { title = "Snacks Explorer" })
          return nil
        end

        error(result[2], 0)
      end
    end,
  },
}
