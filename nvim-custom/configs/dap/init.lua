local dap = require("dap")

-- ui
require("custom.configs.dap.ui")

-- debuggers
local lldb = require("custom.configs.dap.adapters.lldb")
local python = require("custom.configs.dap.adapters.python")
local scala = require("custom.configs.dap.adapters.scala")
dap.adapters.lldb = lldb.adapter
dap.adapters.python = python.adapter
dap.adapters.scala = scala.adapter

dap.configurations.c = lldb.config
dap.configurations.cpp = lldb.config
dap.configurations.rust = lldb.config

dap.configurations.python = python.config
dap.configurations.scala = scala.config
