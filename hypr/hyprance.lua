-- Apariencia. Antes hyprance.conf.
--
-- Los colores salen del fondo de pantalla. Antes eran diecisiete variables de
-- configuracion que hyprcolors.sh rellenaba con `hyprctl keyword`; eso ya no
-- existe, asi que aqui se lee el archivo que genera pywal. Al cambiar de fondo,
-- refresh.sh (SUPER+SHIFT+R) recarga y los colores siguen al fondo nuevo.

---- Paleta ----

-- ~/.cache/wal/colors trae dieciseis lineas "#rrggbb", de la 0 a la 15.
-- Devuelve la paleta completa en el formato que entiende Hyprland, 0xaarrggbb.
local function paleta()
    local p = {}
    local f = io.open(os.getenv("HOME") .. "/.cache/wal/colors", "r")
    if not f then return p end
    for linea in f:lines() do
        local hex = linea:gsub("^#", "")
        p[#p] = "0xff" .. hex          -- p[0] es color0
        p[#p + 1] = nil                -- no dejar huecos que confundan a #p
    end
    f:close()
    return p
end

-- Modo grabacion: sin animaciones, sin blur, sin sombra y sin wobble. Para
-- grabar clase con OBS, que la captura salga limpia y la GPU no se caliente de
-- adorno. Lo alterna modo-grabacion.sh, que escribe este archivo y recarga.
local function grabando()
    local ruta = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/modo-grabacion"
    local f = io.open(ruta, "r")
    if not f then return false end
    f:close()
    return true
end

local adornos = not grabando()

local c = paleta()
-- Si pywal no ha corrido todavia, un gris que no canta.
local function color(i, respaldo)
    return c[i] or respaldo
end

-- Para la sombra hace falta el mismo color con transparencia, no opaco.
local function con_alfa(hex, alfa)
    return "0x" .. alfa .. hex:sub(5)
end

local fondo      = color(0,  "0xff0b090a")
local acento     = color(4,  "0xffccaa68")
local acento_dos = color(6,  "0xff4652c1")
local apagado    = color(8,  "0xff363737")

---- General ----

hl.config({
    general = {
        -- Antes esto estaba en overrides.lua con todo en cero, y con cero
        -- espacio el redondeo de las esquinas no se ve. Un margen pequeño
        -- separa las ventanas sin desperdiciar pantalla en un portatil de 15".
        gaps_in  = 4,
        gaps_out = 8,

        -- 3 y no 2: con 2 el degradado casi no se ve.
        border_size = 3,

        col = {
            -- Degradado entre dos colores del fondo de pantalla, en diagonal.
            -- Hyprland 0.57 acepta la forma { colors = {...}, angle = n }.
            active_border   = { colors = { acento, acento_dos }, angle = 45 },
            inactive_border = apagado,
        },

        -- Redimensionar arrastrando el borde o el espacio entre ventanas.
        resize_on_border = true,

        layout = "master",
        allow_tearing = false,
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        -- La ventana con el foco, opaca; las de atras, un pelo atenuadas. Es
        -- una pista de donde esta el foco que no estorba al proyectar.
        active_opacity   = 1.0,
        inactive_opacity = adornos and 0.96 or 1.0,
        dim_inactive     = adornos,
        dim_strength     = 0.08,

        shadow = {
            enabled      = adornos,
            range        = 20,
            render_power = 3,
            offset       = "0 4",
            color        = con_alfa(fondo, "99"),
        },

        blur = {
            enabled = adornos,
            size    = 6,
            passes  = 3,

            -- 0.57 cambio el blur a once variantes con nombre: haze, acrylic,
            -- prism, water, aurora, drops, heat_shimmer, fluid_jar, ripple,
            -- frost y kawase. "frost" es vidrio helado, sobrio y legible por
            -- encima; cada una tiene sus propios parametros bajo
            -- decoration.blur.<variante>.
            variant = "frost",

            noise             = 0.02,
            new_optimizations = true,
            popups            = true,
            ignore_opacity    = true,
        },

        -- Novedad de 0.57: la ventana se deforma al moverla, como una tela.
        -- Es lo mas llamativo que trae. Si marea o cuesta GPU, enabled = false
        -- y se queda todo lo demas.
        wobble = {
            enabled   = adornos,
            intensity = 0.6,
            mass      = 0.9,
            stiffness = 600,
            damping   = 22,
        },
    },

    animations = {
        enabled = adornos,
    },
})

---- Animaciones ----

-- Las curvas y resortes que 0.57 trae de fabrica. Antes habia un solo bezier
-- hecho a mano; los resortes se sienten mas naturales al mover ventanas.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
