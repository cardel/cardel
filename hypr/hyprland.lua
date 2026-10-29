-- Configuracion de Hyprland. Formato Lua, obligado desde 0.57.0, que elimino
-- el parser de hyprland.conf.
--
-- Traducida de los diez archivos .conf que habia antes. Un modulo por archivo
-- viejo y en el mismo orden, para que la correspondencia sea directa:
--
--   hyprvars.conf     -> hyprvars.lua
--   hyprdevices.conf  -> hyprdevices.lua
--   hyprstart.conf    -> hyprstart.lua
--   hyprsettings.conf -> hyprsettings.lua
--   hyprules.conf     -> hyprules.lua
--   hyprbinds.conf    -> hyprbinds.lua
--   hyprance.conf     -> hyprance.lua
--   user_configs/overrides.conf -> overrides.lua
--   user_configs/local.conf     -> maquina.lua
--
-- El orden importa: lo de abajo gana sobre lo de arriba, igual que con los
-- source del .conf. hyprlayouts.conf no entra porque estaba vacio.

require("hyprvars")
require("hyprdevices")
require("hyprstart")
require("hyprsettings")
require("hyprules")
require("hyprbinds")
require("hyprance")
require("overrides")
