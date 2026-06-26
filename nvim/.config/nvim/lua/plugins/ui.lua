return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = false,
      on_colors = function(colors)
        local palette = vim.g.lumina_matugen
        if not palette then
          return
        end
        colors.bg = palette.bg
        colors.bg_dark = palette.bg_dark
        colors.fg = palette.fg
        colors.blue = palette.primary
        colors.cyan = palette.info
        colors.purple = palette.accent
        colors.red = palette.error
        colors.yellow = palette.warning
        colors.green = palette.secondary
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
