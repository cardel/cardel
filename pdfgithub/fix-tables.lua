-- fix-tables.lua
function Table(el)
	local colspecs = el.colspecs
	local needs_fix = false

	-- Revisamos si hay columnas con ancho 0 (automáticas/c/l/r)
	for i, spec in ipairs(colspecs) do
		if spec[2] == nil or spec[2] == 0 then
			needs_fix = true
			break
		end
	end

	if needs_fix then
		local n = #colspecs
		for i = 1, n do
			-- Asignamos un ancho equitativo (1 / número de columnas)
			-- Esto fuerza a Pandoc a usar p{...} en LaTeX
			el.colspecs[i][2] = 1.0 / n
		end
	end
	return el
end
