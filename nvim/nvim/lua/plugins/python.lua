-- Python: la raiz del proyecto y el entorno virtual
--
-- El extra lazyvim.plugins.extras.lang.python ya esta activo en lazyvim.json y
-- trae lo gordo: pyright + ruff, venv-selector, neotest-python y
-- nvim-dap-python (estos dos se despiertan con test.core y dap.core). Nada de
-- eso se repite aqui. Lo que falta es lo unico que ningun extra puede resolver
-- solo, porque depende de como esta ordenado ESTE disco.
--
-- Medido el 2026-10-08 con nvim 0.12.5, pyright y ruff de mason, sobre
-- ~/repositorios/work/videos/split_c32_4.py (que importa pydantic, whisper y
-- anthropic, los tres solo en su .venv):
--
--   root=/home/cardel/repositorios   pythonPath=nil
--   l101 [Pyright] Import "anthropic" could not be resolved
--
-- Dos fallos distintos en esa linea, y ninguno es culpa del extra.

-- ---------------------------------------------------------------------------
-- 1) La raiz se escapaba a ~/repositorios, la carpeta de TODOS los repos.
--
-- lspconfig declara para pyright (lsp/pyright.lua):
--
--   root_markers = { 'pyrightconfig.json', 'pyproject.toml', 'setup.py',
--                    'setup.cfg', 'requirements.txt', 'Pipfile', '.git' }
--
-- y en una lista plana **manda la prioridad, no la cercania**. Aqui hay un
-- ~/repositorios/requirements.txt de 33 bytes; work/videos cuelga del repo git
-- ~/repositorios/work, que esta un nivel MAS CERCA. Gano igualmente el
-- requirements.txt porque va antes en la lista. Resultado: la raiz del
-- proyecto eran los 52.739 archivos .py de ~/repositorios.
--
-- La correccion no es quitar ese archivo (es legitimo) sino ordenar por
-- niveles. `root_markers` acepta listas anidadas y cada sublista es un escalon
-- de prioridad (:h lsp-root_markers): se agota el primero antes de mirar el
-- segundo, y dentro de cada escalon si gana el mas cercano.
--
--   1. marcadores que declaran un proyecto Python de verdad. Van .venv y venv
--      con ellos: una carpeta con su propio entorno ES la raiz, y es lo que
--      hace que work/videos salga bien aunque no tenga pyproject.toml.
--   2. .git, que es el borde del repositorio.
--   3. requirements.txt, el ultimo. Sigue sirviendo para un proyecto suelto
--      sin git, pero ya no puede secuestrar nada desde arriba, porque para
--      llegar a el hay que haber descartado antes el .git del repo.
local MARCADORES = {
  { "pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "Pipfile", ".venv", "venv" },
  ".git",
  "requirements.txt",
}

-- ---------------------------------------------------------------------------
-- 2) pythonPath=nil: pyright usaba el Python del sistema.
--
-- Por eso `anthropic` salia sin resolver. Lo enganoso es que pydantic y
-- whisper NO se quejaban: estan en /usr/lib/python3.14/site-packages, o sea
-- que resolvian por casualidad. Con un solo import fallando de tres, esto se
-- lee como "falta instalar anthropic" y no como "pyright no mira el venv".
--
-- :VenvSelect (<leader>cv, de venv-selector) ya existia, pero hay que
-- acordarse de pulsarlo en cada proyecto y en cada arranque.
local function python_del_proyecto(desde)
  -- Un venv ya activado en la terminal manda sobre cualquier deduccion.
  local activo = vim.env.VIRTUAL_ENV
  if activo and activo ~= "" and vim.fn.executable(activo .. "/bin/python") == 1 then
    return activo .. "/bin/python"
  end

  -- Si no, se busca subiendo. Los mismos dos nombres que usa el resto de la
  -- configuracion; en este disco hay 3 proyectos con .venv y 3 con venv, asi
  -- que no se puede dar por hecho ninguno de los dos.
  --
  -- `desde` llega a veces como archivo (el buffer, desde dap-python) y a veces
  -- como directorio (la raiz del cliente LSP). Hay que distinguirlo: aplicar
  -- dirname a un directorio se salta un nivel, y precisamente el nivel que
  -- importa -- con root_dir = .../work/videos empezaba a mirar en .../work y
  -- el .venv de videos no lo veia nunca. Medido: pythonPath acababa en
  -- /usr/bin/python3, el ultimo recurso.
  local dir = vim.fn.isdirectory(desde) == 1 and desde or vim.fs.dirname(desde)
  local tope = vim.fs.root(desde, ".git") -- no salirse del repositorio
  while dir and dir ~= "" do
    for _, nombre in ipairs({ ".venv", "venv" }) do
      local candidato = dir .. "/" .. nombre .. "/bin/python"
      if vim.fn.executable(candidato) == 1 then
        return candidato
      end
    end
    if dir == tope or dir == vim.env.HOME then
      break
    end
    local padre = vim.fs.dirname(dir)
    if padre == dir then
      break
    end
    dir = padre
  end

  -- Sin venv, el del sistema. Es lo que ya hacia, solo que ahora a proposito.
  return vim.fn.exepath("python3")
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          root_markers = MARCADORES,

          -- Tiene que ser on_init y NO before_init, aunque before_init parezca
          -- el sitio natural. Medido: con before_init el `pythonPath` no
          -- llegaba nunca (`c.settings` del cliente vivo seguia sin el), porque
          -- el cliente copia config.settings al construirse y before_init corre
          -- despues, sobre una tabla que ya nadie mira. on_init recibe el
          -- cliente ya hecho, y ademas permite avisar al servidor del cambio,
          -- que es como se cambian los ajustes de un LSP en caliente.
          on_init = function(client)
            local python = python_del_proyecto(client.root_dir or vim.fn.getcwd())
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
              python = { pythonPath = python },
            })
            client:notify("workspace/didChangeConfiguration", { settings = client.settings })
          end,
        },

        -- ruff se lleva la misma raiz. Sin esto quedarian desalineados --
        -- pyright mirando work/videos y ruff ~/repositorios -- y los avisos de
        -- import de primera parte saldrian mal.
        ruff = { root_markers = MARCADORES },
      },
    },
  },

  -- -------------------------------------------------------------------------
  -- 3) El depurador y los tests heredan el arreglo, pero conviene atarlo.
  --
  -- nvim-dap-python ya busca el venv solo: su get_python_path mira
  -- $VIRTUAL_ENV, luego $CONDA_PREFIX, luego M.resolve_python, y si nada de
  -- eso hay recorre roots() -- que son el cwd del editor y **el root_dir de
  -- los clientes LSP**. O sea que con la raiz rota de arriba buscaba
  -- ~/repositorios/.venv, que no existe, y caia al Python del sistema.
  -- Arreglada la raiz ya acertaria; se declara resolve_python de todas formas
  -- para que no dependa de cual sea el cwd al abrir el editor.
  --
  -- El campo pythonPath de las configuraciones se rellena al LANZAR, no al
  -- cargar: leerlo antes da nil y parece que no hay nada configurado.
  {
    "mfussenegger/nvim-dap-python",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyLoad",
        group = vim.api.nvim_create_augroup("python-dap-venv", { clear = true }),
        callback = function(ev)
          if ev.data == "nvim-dap-python" then
            require("dap-python").resolve_python = function()
              return python_del_proyecto(vim.api.nvim_buf_get_name(0))
            end
          end
        end,
      })
    end,
  },

  -- neotest-python acepta en `python` una cadena o una funcion(root); se usa
  -- la funcion para que cada proyecto corra sus tests con su propio interprete.
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["neotest-python"] = {
          python = function(root)
            return python_del_proyecto(root)
          end,
        },
      },
    },
  },
}
