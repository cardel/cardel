-- mason-bootstrap.lua -- instala de golpe todo lo que mason deberia tener.
--
-- Lo ejecuta install.sh:  nvim --headless -c "luafile .../mason-bootstrap.lua" -c qa
--
-- Por que existe: mason instala bajo demanda. Las herramientas de
-- mason.ensure_installed llegan cuando se carga mason.nvim (de forma asincrona,
-- asi que un arranque headless se muere antes), los adaptadores de depuracion
-- cuando se carga nvim-dap, y los servidores LSP recien al abrir un archivo de
-- ese tipo. En una maquina nueva eso significa que los fallos de instalacion
-- aparecen de a uno, semanas despues, la primera vez que se abre un .java.
--
-- Este script calcula la lista completa a partir de la configuracion --no de
-- una lista escrita a mano, que se desincronizaria-- y la instala de una sola
-- vez, en un solo punto donde los errores se ven juntos.

require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig" } })

local registry = require("mason-registry")

-- En una maquina nueva el registro todavia no esta en disco y has_package diria
-- que no existe nada. refresh() sin callback es sincrono.
registry.refresh()

local lsp_to_pkg = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package

-- mason marca un paquete como instalado escribiendo su recibo. Preguntarle a
-- registry es poco fiable justo despues de instalar --el estado en memoria se
-- actualiza por evento y todavia no ha llegado--, y eso daba falsos fallos.
local function installed_on_disk(pkg)
  local dir = vim.fn.stdpath("data") .. "/mason/packages/" .. pkg
  return vim.uv.fs_stat(dir .. "/mason-receipt.json") ~= nil
end

local wanted, seen, skipped = {}, {}, {}

local function add(pkg)
  if pkg and not seen[pkg] then
    seen[pkg] = true
    if not registry.has_package(pkg) then
      table.insert(skipped, pkg .. " (no esta en el registro de mason)")
    elseif not installed_on_disk(pkg) then
      table.insert(wanted, pkg)
    end
  end
end

-- 1) Herramientas de mason.ensure_installed: las de LazyVim (stylua, shfmt) mas
--    las que anaden los extras y lua/plugins/*.lua.
for _, tool in ipairs(LazyVim.opts("mason.nvim").ensure_installed or {}) do
  add(tool)
end

-- 2) Adaptadores de depuracion. Van en una tabla aparte, la de
--    mason-nvim-dap.nvim, no en la de mason.nvim.
for _, tool in ipairs(LazyVim.opts("mason-nvim-dap.nvim").ensure_installed or {}) do
  add(tool)
end

-- 3) Servidores LSP. Se saltan los que la propia configuracion desactiva: el
--    extra de Python, por ejemplo, declara pyright, basedpyright, ruff y
--    ruff_lsp pero deja enabled = false en los que no eligio.
for name, cfg in pairs(LazyVim.opts("nvim-lspconfig").servers or {}) do
  if name ~= "*" and not (type(cfg) == "table" and cfg.enabled == false) then
    local pkg = lsp_to_pkg[name]
    if pkg then
      add(pkg)
    else
      -- racket_langserver va por raco, metals por coursier. No es error.
      table.insert(skipped, name .. " (no lo empaqueta mason)")
    end
  end
end

if #skipped > 0 then
  print("fuera de mason, se instalan aparte: " .. table.concat(skipped, ", "))
end

if #wanted == 0 then
  print("mason ya tiene todo lo que pide la configuracion")
  return
end

table.sort(wanted)
print("instalando " .. #wanted .. " paquetes: " .. table.concat(wanted, " "))

-- En modo headless MasonInstall bloquea hasta terminar. Se instalan de a uno
-- para que un fallo aislado --por ejemplo un servidor que se compila desde el
-- fuente y no encuentra su toolchain-- no impida instalar el resto.
for _, pkg in ipairs(wanted) do
  pcall(vim.cmd, "MasonInstall " .. pkg)
end

local failed = {}
for _, pkg in ipairs(wanted) do
  if not installed_on_disk(pkg) then
    table.insert(failed, pkg)
  end
end

if #failed > 0 then
  print("FALLARON: " .. table.concat(failed, ", "))
  print("suele ser una dependencia del sistema que falta (node, python, java,")
  print("cargo, rebar3...). Ver :Mason para el detalle.")
else
  print("mason completo: " .. #wanted .. " paquetes instalados")
end
