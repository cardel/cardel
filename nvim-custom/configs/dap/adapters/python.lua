--adapter for Python
--Pendiente https://raw.githubusercontent.com/mfussenegger/nvim-dap-python/master/lua/dap-python.lua
local M = {}

M.adapter = {
  type = "executable",
  command = "/bin/python",
  args = {"-m", "debugpy.adapter"},
}

M.config = {
  {
    type = "python",
    request = "launch",
    name = "Launch file",
    program = "${file}",
    pythonPath = function()
      return vim.fn.input("Path to python interpreter: ", vim.fn.getcwd() .. "/venv/bin/python", "file")
    end,
  },
}


return M


