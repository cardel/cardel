--Configurarion scala

local M = {}

M.adapter = {
  type = "executable",
  command = "metals",
  args = {""}
}

M.config = {
  {
    type = "scala",
    request = "launch",
    name = "Launch file",
    mainClass = "${file}",
  },
}

return M
