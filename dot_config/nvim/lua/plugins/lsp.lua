return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonInstallAll", "InstallApp" },
    opts = function(_, opts)
      local common = require("lsp.common")
      opts.ensure_installed = common.mason_ensure_installed()
    end,
    config = function(_, opts)
      require("mason").setup(opts)

      vim.api.nvim_create_user_command("InstallApp", function()
        local set = {}
        for _, tool in ipairs((opts.ensure_installed or {})) do
          set[tool] = true
        end

        local ok_map, mappings = pcall(require, "mason-lspconfig.mappings")
        if ok_map then
          local lsp_to_pkg = mappings.get_mason_map().lspconfig_to_package or {}
          local servers = require("lsp.common").base_servers()
          require("lsp.python").setup(servers)
          require("lsp.java").setup(servers)
          for name, _ in pairs(servers) do
            local pkg = lsp_to_pkg[name]
            if pkg then
              set[pkg] = true
            end
          end
        end

        local list = {}
        for pkg, _ in pairs(set) do
          table.insert(list, pkg)
        end
        table.sort(list)

        if #list == 0 then
          vim.notify("No Mason packages to install", vim.log.levels.INFO)
          return
        end

        local cmd = "MasonInstall " .. table.concat(list, " ")
        vim.notify("Running: :" .. cmd, vim.log.levels.INFO)
        vim.cmd(cmd)
        vim.schedule(function()
          pcall(vim.cmd, "Mason")
        end)
      end, { desc = "Install all mason-managed tools from current config" })

      vim.api.nvim_create_user_command("MasonInstallAll", function()
        vim.cmd("InstallApp")
      end, { desc = "Alias: install all missing Mason tools" })
    end,
  },
}
