return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server",
        "lua-language-server",
        "stylua",
        "shellcheck",
        "shfmt",
      },
    },
  },
}

