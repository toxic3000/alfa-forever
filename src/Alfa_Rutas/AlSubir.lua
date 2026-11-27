-- Alfa - Rutas: las misiones que se abren al subir de nivel (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Al subir de nivel, el juego abre misiones nuevas que antes no te daban, y
-- no lo dice. Si no vas siguiendo una guía (la guía ya te lleva a las suyas),
-- Alfa te lo cuenta una vez: «Nivel 12: misiones nuevas», con «Ver cuáles».
-- La ventana trae las que se abren justo con tu nivel, la más cerca primero
-- (su zona y el tiempo de camino), y un clic pone la flecha en quien la da.
-- Si el Codex ya está leído, el aviso dice cuántas hay (y no sale si no hay
-- ninguna); si no, se lee con tu clic en «Ver cuáles» (nunca en combate).
--
--   Su.Lista(nivel, fn(lista | nil, motivo))   { { id, titulo, nivel, zona, segundos, dador } }, la más cerca primero
--   Su.Abrir(nivel)                           la ventana (sin nivel: el tuyo)
--   Su.AlSubir(nivel)                         el aviso (lo llama PLAYER_LEVEL_UP)
-- Ajuste: rutas.nuevasNivel (de fábrica, sí). Comando: /alfa rutas nuevas.

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Su = {}
M.AlSubir = Su

A.RegisterDefaults(M.ID, { nuevasNivel = true })

local type, ipairs, tonumber, pcall = type, ipairs, tonumber, pcall
local format = string.format

local MAX = 12

local function I() return M.Indice end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function miNivel() return tonumber(UnitLevel and UnitLevel("player")) or 1 end

-- ¿Vas siguiendo una guía que aún no terminas?
local function enGuia()
	local E = A.Engine
	local ok, g = pcall(function() return E and E.GetGuide and E.GetGuide() end)
	if not (ok and g) then return false end
	return not (M.GuiaTerminada and M.GuiaTerminada())
end

local function armar(ix, nivel)
	local Ix = I()
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	local out = {}
	for _, e in ipairs(ix.lista or {}) do
		if (e.min or 1) == nivel and not Ix.EnRegistro(e.id) then
			local okD, si = pcall(Ix.Disponible, e, {}, nivel)
			if okD and si then
				local okP, dador = pcall(Ix.Puntos, e, desde)
				if okP and dador then
					out[#out + 1] = { id = e.id, titulo = M.TituloMision(e.id), nivel = e.lvl, zona = M.Zona(dador.map),
						segundos = desde and Ix.Viaje(desde, dador) or nil, dador = dador }
				end
			end
		end
	end
	table.sort(out, function(a, b)
		local sa, sb = a.segundos or 1e9, b.segundos or 1e9
		if sa ~= sb then return sa < sb end
		return (a.titulo or "") < (b.titulo or "")
	end)
	while #out > MAX do out[#out] = nil end
	return out
end

function Su.Lista(nivel, fn)
	nivel = tonumber(nivel) or miNivel()
	local Ix = I()
	if not Ix then return fn(nil, "missing") end
	if enCombate() and not Ix.Listo() then return fn(nil, "combat") end
	Ix.Pedir(function(ix, motivo)
		if not ix then return fn(nil, motivo) end
		local ok, lista = pcall(armar, ix, nivel)
		fn(ok and lista or {}, nil)
	end)
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local ventana

local function tomar(d)
	local Ir = M.IrMision
	local p = d.dador
	if not (Ir and p) then return end
	local nombre = p.name or L["Quien da la misión"]
	if Ir.Viajar({ map = p.map, x = p.x, y = p.y, f = p.f, z = p.z }, nombre, L["Tomar misión"]) then
		M.Empezar()
		M.Aviso(L["Llévame"], format(L["Vamos con %s a tomar %s."], nombre, M.Citar(d.titulo)), { icono = "ic-flecha" })
	end
end

local function armarVentana()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasNuevasNivel", titulo = L["Misiones nuevas"], icono = "ic-misiones", ancho = 440, alto = 460,
		vacio = { lobo = "atento", titulo = L["Nada nuevo cerca"], texto = L["Con este nivel no se abre ninguna misión cerca de ti. «Recoger misiones» busca las mejores que ya puedes tomar."] },
		boton = { texto = L["Recoger misiones"], alClic = function() if M.Recoger then M.Recoger.Ahora() end end },
		crear = function(fila)
			fila.Icono = K.Icono(fila, "ic-misiones", 14, "acento")
			fila.Icono:SetPoint("LEFT", fila, "LEFT", 10, 0)
			fila.Texto = K.Texto(fila, "cuerpo", "texto")
			fila.Texto:SetPoint("LEFT", fila, "LEFT", 32, 0)
			fila.Extra = K.Texto(fila, "pequeno", "textoTenue")
			fila.Extra:SetPoint("RIGHT", fila, "RIGHT", -10, 0)
			fila.Extra:SetJustifyH("RIGHT")
			fila.Texto:SetPoint("RIGHT", fila.Extra, "LEFT", -8, 0)
		end,
		pintar = function(fila, d)
			K.Escribir(fila.Texto, d.nivel and format(L["%s (nivel %d)"], d.titulo, d.nivel) or d.titulo)
			local lejos = d.segundos and ("\226\137\136 " .. M.Minutos(d.segundos)) or ""
			K.Escribir(fila.Extra, d.zona and (lejos ~= "" and (d.zona .. " \194\183 " .. lejos) or d.zona) or lejos)
		end,
		alClic = function(d) tomar(d) end,
	})
end

function Su.Abrir(nivel)
	nivel = tonumber(nivel) or miNivel()
	Su.Lista(nivel, function(lista, motivo)
		if not lista then
			M.Aviso(L["Misiones nuevas"], I() and I().TextoMotivo(motivo) or motivo, { icono = "ic-aviso", tono = "aviso" })
			return
		end
		if not ventana then armarVentana() end
		ventana:Boton(#lista == 0 and L["Recoger misiones"] or nil)
		ventana:Llenar(lista, format(L["Nivel %d: misiones nuevas"], nivel), M.Plural(#lista, L["%d misión"], L["%d misiones"]),
			#lista > 0 and L["Se abren con tu nivel. Haz clic en una y la flecha te lleva con quien la da."] or nil)
	end)
	return true
end

function Su.Ventana() return ventana end

---------------------------------------------------------------------------
-- El aviso al subir
---------------------------------------------------------------------------

function Su.AlSubir(nivel)
	nivel = tonumber(nivel) or miNivel()
	if A.Get(M.ID .. ".nuevasNivel") == false or enGuia() then return false end
	local Ix = I()
	local function decir(n)
		local texto = n and format(L["Se abren %s cerca de ti. ¿Te enseño cuáles?"], M.Plural(n, L["%d misión"], L["%d misiones"]))
			or L["Con tu nivel se abren misiones nuevas. ¿Te enseño cuáles tienes cerca?"]
		M.Aviso(format(L["Nivel %d: misiones nuevas"], nivel), texto, { icono = "ic-misiones", prioridad = 3, caduca = 300,
			acciones = { { texto = L["Ver cuáles"], alClic = function() Su.Abrir(nivel) end } } })
	end
	-- Con el índice ya armado se sabe cuántas: ninguna, ningún aviso.
	if Ix and Ix.Listo() then
		local ok, lista = pcall(armar, Ix.Listo(), nivel)
		if ok and #lista == 0 then return false end
		decir(ok and #lista or nil)
	else
		decir(nil)
	end
	return true
end

local function alSubir(_, nivel)
	if N.FueraDeCombate then N.FueraDeCombate("rutas.alSubir", function() Su.AlSubir(nivel) end) else Su.AlSubir(nivel) end
end
A.RegisterEvent("PLAYER_LEVEL_UP", (N.TrasNivel or function(_, f) return f end)("rutas.alSubir", alSubir))
