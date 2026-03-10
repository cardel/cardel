-- break-code.lua
-- Pandoc Lua filter: permite line-break en texto monospace (backticks)
-- dentro de tablas PDF. Inserta \allowbreak despues de . / - _ : @
-- para que URLs largas como `grafana-data-stack.dev.confirmeza.com.co`
-- se quiebren correctamente en celdas de longtable.

function Code(elem)
	if FORMAT:match("latex") then
		local text = elem.text
		-- Escapar caracteres especiales de LaTeX
		text = text:gsub("%%", "\\%%")
		text = text:gsub("#", "\\#")
		text = text:gsub("&", "\\&")
		text = text:gsub("{", "\\{")
		text = text:gsub("}", "\\}")
		text = text:gsub("~", "\\textasciitilde{}")
		text = text:gsub("%^", "\\textasciicircum{}")
		text = text:gsub("_", "\\_")
		text = text:gsub("%$", "\\$")
		-- Insertar \allowbreak despues de puntos de quiebre seguros
		-- NO incluir _ (ya escapado como \_ que LaTeX quiebra solo)
		text = text:gsub("([%.%/%-%:@])", "%1\\allowbreak{}")
		return pandoc.RawInline("latex", "\\texttt{" .. text .. "}")
	end
	return elem
end
