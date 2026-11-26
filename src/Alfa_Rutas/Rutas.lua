-- Alfa - Rutas: las acciones de tus rutas propias (seguir una, agregarle un
-- objeto) y el comando /alfa rutas. toxic3000 / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local P, I, G = M.Plan, M.Indice, M.Guias

local type, ipairs, tostring = type, ipairs, tostring
local format = string.format

---------------------------------------------------------------------------
-- Seguir una ruta: plan (si falta) -> pasos -> guía del motor -> pestaña
---------------------------------------------------------------------------

function M.Seguir(r, silencioso)
	if not r then return end
	if #r.tramos == 0 then return M.Aviso(L["Tu ruta no tiene tramos todavía"], L["Agrégale uno en la página Ruta."], { icono = "ic-aviso", tono = "aviso" }) end
	local function compilarCon(plan)
		P.Compilar(r, plan, function(def, motivo, avisos)
			if not def then
				return M.Aviso(L["No armé tu ruta"], motivo == "vacio" and L["Quedó sin pasos: agrega tramos o recalcula."] or I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
			end
			local ok = G.Instalar(def)
			if not ok then return M.Aviso(L["No armé tu ruta"], L["No pude abrir la guía. Prueba en un momento; si sigue, cuéntanos con /alfa reportar."], { icono = "ic-aviso", tono = "aviso" }) end
			local p = M.Personaje()
			local previo = p.progreso[r.id]
			p.activa = r.id
			p.progreso[r.id] = { firma = M.Firma(r), inicio = previo and previo.inicio or (time and time() or 0),
				nivel = previo and previo.nivel or I.Jugador().level }
			for k, a in ipairs(avisos or {}) do
				if k > 3 then break end
				M.Aviso(L["Ojo con tu ruta"], a, { icono = "ic-info", tono = "aviso" })
			end
			M.Avisar("SEGUIR", r.id)
			if silencioso then
				if G.Abierta(def.id) then M.Aviso(L["Tu ruta se actualizó"], r.nombre, { icono = "ic-ruta" }) end
				return
			end
			local i, por = G.Abrir(def.id)
			if i then
				M.Aviso(L["Ruta en marcha"], format(L["%s: sigue la flecha."], r.nombre), { lobo = "aullando" })
			elseif por == "tabs" then
				M.EnCurso.AvisoLleno(L["Es el máximo a la vez. Quita una que ya no uses y vuelve a abrir tu ruta."])
			end
		end)
	end
	local plan = P.De(r)
	if plan then return compilarCon(plan) end
	M.Aviso(L["Alfa está armando tu ruta…"], L["Elige solo misiones que ya puedes tomar."], { icono = "ic-ruta" })
	P.Armar(r, function(nuevo, motivo)
		if nuevo then compilarCon(nuevo) else M.Aviso(L["No armé tu ruta"], I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" }) end
	end)
end

-- Un objeto a tu ruta (desde la Enciclopedia): un tramo Objeto en la ruta en
-- marcha, o en la que editas, o en una nueva. Si sigues esa ruta, tu guía se
-- actualiza sola. -> true
function M.AgregarObjeto(itemId)
	itemId = tonumber(itemId)
	if not itemId then return false end
	local p = M.Personaje()
	local r = M.RutaActiva() or M.RutaEditada() or M.NuevaRuta(L["Mi ruta"], {})
	-- Un tramo de profesión sin material lo toma si es un material.
	local t = M.NuevoTramo({ rama = "objeto", item = itemId, cantidad = 1 })
	if I.LineaDe(itemId) then t = M.NuevoTramo({ rama = "prof", item = itemId, cantidad = 20 }) end
	r.tramos[#r.tramos + 1] = t
	p.editando = r.id
	M.Cambio(r)
	M.Aviso(L["Agregado a tu ruta"], format(L["%s, tramo %d de %s."], M.NombreObjeto(itemId), #r.tramos, r.nombre), {
		icono = "ic-ruta", accion = { texto = L["Ver mi ruta"], alClic = function() N.Abrir(M.ID) end } })
	if p.activa == r.id and p.guias[r.id] then M.Seguir(r, true) end
	return true
end

---------------------------------------------------------------------------
-- /alfa rutas [liberar | entregar | recoger | asistente | guias | seguir]
---------------------------------------------------------------------------

local function ayuda()
	A.Print(L["Comandos de Ruta:"])
	A.Print("  /alfa rutas  \194\183  " .. L["abre la página Ruta"])
	A.Print("  /alfa rutas liberar  \194\183  " .. L["arma el plan para cerrar tus misiones"])
	A.Print("  /alfa rutas entregar  \194\183  " .. L["solo las listas para entregar"])
	A.Print("  /alfa rutas recoger  \194\183  " .. L["toma las mejores misiones de cerca"])
	A.Print("  /alfa rutas asistente  \194\183  " .. L["¿qué quieres hacer?"])
	A.Print("  /alfa rutas guias  \194\183  " .. L["la biblioteca de guías"])
	A.Print("  /alfa rutas seguir  \194\183  " .. L["sigue (o actualiza) tu ruta"])
	A.Print("  /alfa rutas historial  \194\183  " .. L["tus guías terminadas, con fecha y tiempo"])
	A.Print("  /alfa rutas nivel  \194\183  " .. L["salta a la parte de tu guía que va con tu nivel"])
end

A.RegisterCommand("rutas", function(resto)
	local sub = (type(resto) == "string" and resto:match("^%s*(%S+)") or ""):lower()
	if sub == "" or sub == "ruta" then
		N.Abrir(M.ID)
	elseif sub == "liberar" or sub == "cerrar" then
		M.Cerrar.Ahora()
	elseif sub == "entregar" then
		M.EntregarListas()
	elseif sub == "recoger" then
		M.Recoger.Ahora()
	elseif sub == "asistente" then
		M.Asistente.Abrir()
	elseif sub == "guias" or sub == "guías" then
		M.Biblioteca.Abrir()
	elseif sub == "seguir" then
		M.Seguir(M.RutaActiva() or M.RutaEditada())
	elseif sub == "historial" or sub == "terminadas" then -- 1.4.0 (32)
		M.Historial.Abrir()
	elseif sub == "minivel" or sub == "nivel" then -- 1.4.0 (26)
		if not M.MiNivel.Saltar() then N.Imprimir(L["Tu guía no va atrás de tu nivel."]) end
	else
		ayuda()
	end
end, L["Tu ruta, tus misiones y tus guías (/alfa rutas ayuda)."])
