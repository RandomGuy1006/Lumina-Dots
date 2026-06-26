vim.keymap.set("n", "<leader>tt", function()
  vim.cmd("terminal")
end, { desc = "Open terminal" })

vim.keymap.set("n", "<leader>fd", function()
  vim.cmd("cd " .. vim.fn.expand("~/lumina-dots"))
end, { desc = "Jump to lumina-dots" })
