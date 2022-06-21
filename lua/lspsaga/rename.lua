local util,api = vim.lsp.util,vim.api
local window = require('lspsaga.window')
local config = require('lspsaga').config_values
local libs = require('lspsaga.libs')

local unique_name = 'textDocument-rename'
local pos = {}

local get_prompt_prefix = function()
  return config.rename_prompt_prefix..' '
end

local close_rename_win = function()
  if vim.fn.mode() == 'i' then
    vim.cmd [[stopinsert]]
  end
  local has,winid = pcall(api.nvim_win_get_var,0,unique_name)
  if has then
    window.nvim_close_valid_window(winid)
  end
  api.nvim_win_set_cursor(0,{pos[1],pos[2] + 1})
end

local apply_action_keys = function(bufnr)
  local quit_key = config.rename_action_quit
  local rhs_of_quit = [[<cmd>lua require('lspsaga.rename').close_rename_win()<CR>]]
  local opts = {nowait = true,silent = true,noremap = true}

  api.nvim_buf_set_keymap(bufnr,'i',quit_key,rhs_of_quit,opts)
  api.nvim_buf_set_keymap(bufnr,'n',quit_key,rhs_of_quit,opts)
end

local lsp_rename = function()
  local active,msg = libs.check_lsp_active()
  if not active then vim.notify(msg) return end
  local current_buf = api.nvim_get_current_buf()
  local current_win = api.nvim_get_current_win()
  pos = api.nvim_win_get_cursor(current_win)

  local opts = {
    height = 1,
    width = 30,
  }

  local content_opts = {
    contents = {},
    filetype = '',
    enter = true,
    highlight = 'LspSagaRenameBorder'
  }

  local bufnr,winid = window.create_win_with_border(content_opts,opts)
  local saga_rename_prompt_prefix = api.nvim_create_namespace('lspsaga_rename_prompt_prefix')
  api.nvim_win_set_option(winid,'scrolloff',0)
  api.nvim_win_set_option(winid,'sidescrolloff',0)
  api.nvim_buf_set_option(bufnr,'modifiable',true)
  local prompt_prefix = get_prompt_prefix()
  api.nvim_buf_set_option(bufnr,'buftype','prompt')
  vim.fn.prompt_setprompt(bufnr, prompt_prefix)
  api.nvim_buf_add_highlight(bufnr, saga_rename_prompt_prefix, 'LspSagaRenamePromptPrefix', 0, 0, #prompt_prefix)
  local options = {
    bufnr = current_buf
  }
  vim.fn.prompt_setcallback(bufnr,function(new_name)
    close_rename_win()
    api.nvim_win_set_cursor(current_win,pos)
    vim.lsp.buf.rename(new_name,options)
    api.nvim_win_set_cursor(current_win,{pos[1],pos[2]+1})
    pos = {}
  end)

  vim.cmd [[startinsert!]]
  api.nvim_win_set_var(0,unique_name,winid)
  api.nvim_create_autocmd('QuitPre',{
    buffer = bufnr,
    once = true,
    nested = true,
    callback = function()
      require('lspsaga.rename').close_rename_win()
    end
  })
  apply_action_keys(bufnr)
end

return {
  lsp_rename = lsp_rename,
  close_rename_win = close_rename_win,
}
