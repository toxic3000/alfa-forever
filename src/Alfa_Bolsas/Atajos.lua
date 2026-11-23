-- Alfa - Bolsas: atajos a lo nuevo y a tus mejoras (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7 (tercera vuelta). Dentro de la búsqueda de tus bolsas, a la derecha,
-- dos píldoras chiquitas que solo salen cuando hay algo:
--   * «3 nuevos»: lo que acabas de recoger (lo que ya brilla). Un clic busca
--     «nuevo» y lo deja resaltado, lo demás se atenúa.
--   * «1 mejora»: el equipo de tus bolsas que es mejor que lo que llevas (la
--     flecha verde). Un clic busca «mejora».
-- Otro clic en la misma píldora (o la X de la búsqueda) lo quita. Con la
-- búsqueda escrita, o si no caben, no salen. Solo en tus bolsas en vivo (no
-- en la foto de otro personaje ni en el banco). Ajuste: bolsas.atajos.
-- La búsqueda ya entendía «nuevo» y «mejora» (Objetos.lua): esto la pone a
-- un clic.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ESP = K.ESP
local Aj = {}
M.Atajos = Aj

local format, max = string.format, math.max

-- Lo que necesita a la vista la búsqueda (su lupa y su texto de ayuda) antes de las píldoras.
local MIN_BUSQUEDA = 56

local function pildora(f, clave, tono, icono)
	local p = K.Insignia(f.Busca, "", tono, { icono = icono })
	p:EnableMouse(true)
	p:SetFrameLevel(f.Busca:GetFrameLevel() + 5)
	p.alfaClave = clave
	p:SetScript("OnMouseUp", function(self, boton)
		if boton ~= "LeftButton" then return end
		Aj.Elegir(f, self.alfaClave)
	end)
	K.ConInfo(p, function(self)
		if self.alfaClave == "nuevo" then
			return L["Lo nuevo"], L["Resalta lo que acabas de conseguir. Otro clic lo quita."]
		end
		return L["Tus mejoras"], L["Resalta el equipo de tus bolsas que es mejor que el tuyo. Otro clic lo quita."]
	end)
	p:Hide()
	return p
end

-- Un clic: busca esa palabra (o la quita si ya estaba).
function Aj.Elegir(f, clave)
	if not (f and f.Busca) then return end
	local palabra = clave == "nuevo" and L["nuevo"] or L["mejora"]
	if f.Busca:Texto() == palabra then
		f.Busca:SetTexto("", true)
		M.Ventana.Buscar(f, "")
	else
		f.Busca:SetTexto(palabra, true)
		M.Ventana.Buscar(f, palabra)
	end
end

-- Desde la franja de Ventana.lua, ya acomodada la búsqueda. activo: tus bolsas en vivo.
function Aj.Pintar(f, activo)
	if not (f and f.Busca) then return end
	if not f.alfaAtajos then
		f.alfaAtajos = { nuevo = pildora(f, "nuevo", "acento", "ic-estrella"), mejora = pildora(f, "mejora", "exito", "ic-nivel") }
	end
	local p = f.alfaAtajos
	local nuevos, mejoras = tonumber(f.alfaNuevos) or 0, tonumber(f.alfaMejoras) or 0
	local texto = f.Busca:Texto()
	local escrita = texto ~= "" and texto ~= L["nuevo"] and texto ~= L["mejora"]
	local quiere = activo and M.Get("atajos") ~= false and not escrita
	local wN = quiere and nuevos > 0 and p.nuevo:Set(N.Plural(nuevos, L["%d nuevo"], L["%d nuevos"]), "acento", "ic-estrella") or 0
	local wM = quiere and mejoras > 0 and p.mejora:Set(N.Plural(mejoras, L["%d mejora"], L["%d mejoras"]), "exito", "ic-nivel") or 0
	-- ¿Caben? El campo empieza a 32 px y la X de borrar ocupa los últimos 30.
	local ancho = K.num(f.Busca:GetWidth(), 0)
	local libre = ancho - 32 - 30 - MIN_BUSQUEDA
	local x = -30
	for _, par in ipairs({ { p.mejora, wM, "mejora" }, { p.nuevo, wN, "nuevo" } }) do
		local pil, w = par[1], par[2]
		if w and w > 0 and libre >= w then
			pil:ClearAllPoints()
			pil:SetPoint("RIGHT", f.Busca, "RIGHT", x, 0)
			-- La que está buscando se ve elegida (más llena).
			pil:SetAlpha(texto == "" and 1 or (texto == (par[3] == "nuevo" and L["nuevo"] or L["mejora"]) and 1 or 0.55))
			pil:Show()
			x = x - w - ESP.xs
			libre = libre - w - ESP.xs
		else
			pil:Hide()
		end
	end
	-- Con una píldora elegida, el «3 coinciden» de la búsqueda sobra (la píldora ya lo dice).
	if texto == L["nuevo"] or texto == L["mejora"] then
		if (texto == L["nuevo"] and p.nuevo:IsShown()) or (texto == L["mejora"] and p.mejora:IsShown()) then f.Coinciden:Hide() end
	end
end
