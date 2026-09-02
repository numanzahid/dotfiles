-- Optional Kitty graphics / snacks.nvim image (LazyVim).
-- Enable: ./scripts/kitty-image-support-install-update.sh

local flag = vim.fn.expand("~/.config/dotfiles/image-support.enabled")
if vim.fn.filereadable(flag) ~= 1 then
  return {}
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        doc = {
          enabled = true,
          inline = true,
          float = true,
        },
      },
    },
  },
}
