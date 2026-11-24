-- Alfa - Bolsas: el candado de objetos (toxic3000 / La Jauría). GPL-3.0. 1.3.8.
--
-- Pedido de Toxic: «¿Alguna manera de bloquear objetos para no borrarlos en
-- algún clic mal dado?». Un objeto con candado:
--   * no se borra: al soltarlo fuera de las bolsas el juego pide confirmar
--     (DELETE_ITEM_CONFIRM y su cuadro DELETE_ITEM / DELETE_GOOD_ITEM /
--     DELETE_QUEST_ITEM / DELETE_GOOD_QUEST_ITEM); Alfa lo regresa a su lugar
--     con ClearCursor (sin restricciones, GameCursorDocumentation) y el cuadro
--     se cierra solo (su OnUpdate lo esconde sin nada en el cursor). Por si
--     acaso, el cuadro dice «¡Este objeto tiene candado!» y su botón Aceptar
--     queda apagado hasta que se cierra. DeleteCursorItem (HasRestrictions)
--     nunca se llama.
--   * no se vende: con un comerciante abierto, sobre cada casilla con candado
--     va una capa propia (fuera de combate) que no deja el clic derecho
--     (vender) y sí deja tomarlo, moverlo y enlazarlo; también en las bolsas
--     del juego si Alfa no las reemplaza. Lo que se venda de todos modos (en
--     combate, otra ventana) se avisa con la pestaña «Recompra».
--   * nada de Alfa lo vende ni lo borra solo: Alfa.QoL.Marks.Protected (la
--     regla del motor para vender lo gris, la chatarra marcada y borrar para
--     hacer espacio, QoL/Vendor.lua y QoL/Space.lua) dice «protegido»; la
--     sugerencia de qué vender, «Separar», «Marcar para vender», «Acomodar» y
--     «Mandar a tu alt» (Comercio/Envios.lua) se lo saltan.
--   * al ponerlo en el comercio, el correo o la subasta, o al desencantarlo,
--     un aviso claro (sin impedir nada: eso lo protege el juego).
--
-- Poner y quitar: Alt+clic derecho sobre el objeto (en tus bolsas, las de
-- Alfa o las del juego) abre su menú: «Ponerle candado» / «Quitarle el
-- candado» y «En toda la cuenta». En combate cambia sin menú. Alt+clic
-- izquierdo sigue siendo la guía del objeto y Ctrl+Alt las marcas del motor.
--
-- Se guarda por objeto: por su número (itemID) o, si es único con enlace
-- (equipo con sufijo o número propio), por su enlace (itemID:sufijo:único,
-- sin el nivel ni la especialización, que cambian). Por personaje en
-- AlfaNucleoCharDB.candado.o y para toda la cuenta en AlfaNucleoDB.candado.o:
-- true = con candado, false = sin candado aunque el automático lo pondría.
--
-- Automático (ajuste bolsas.candadoAuto, prendido): lo épico y legendario, lo
-- de misiones, la piedra de hogar y lo de tus conjuntos de equipo.
-- Ajustes: bolsas.candado (todo), bolsas.candadoAuto, bolsas.candadoCuenta
-- (los candados nuevos van a toda la cuenta).
--
--   Cd.Tiene(id, link, o) -> bool, motivo ("tuyo" | "cuenta" | "epico" | "mision" | "hogar" | "conjunto")
--   Cd.TieneCasilla(bolsa, casilla) -> bool, motivo
--   Cd.Poner(id, link, si, o) ; Cd.EnCuenta(id, link, si) ; Cd.Cuantos()
--   Cd.Pintar(b, p, ent) (Botones.lua) ; Cd.Menu(id, link, ancla, o)
--   AlfaBolsas.TieneCandado(bolsa, casilla), AlfaBolsas.Candado(id, link),
--   AlfaBolsas.AvisarCandado(id, link, donde)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local type, pairs, ipairs, tonumber, tostring, format = type, pairs, ipairs, tonumber, tostring, string.format
local floor, max = math.floor, math.max

local Cd = {}
M.Candado = Cd

local PIEDRA_HOGAR = 6948
local DESENCANTAR = 13262
local ICONO = "ic-candado"
local BOLSAS = { 0, 1, 2, 3, 4, 5 }

local function encendido() return M.Get("candado") ~= false end
Cd.Encendido = encendido

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Lo guardado
---------------------------------------------------------------------------

local function lista(cuenta)
	local d = cuenta and N.Datos("candado") or N.DatosPersonaje("candado")
	if type(d.o) ~= "table" then d.o = {} end
	return d.o
end
Cd.Lista = lista

local version = 0
local porId -- id -> true: algún candado puesto a mano con ese número (cualquier enlace)

local function cambio()
	version = version + 1
	porId = nil
	local S = M.Sugerencias
	if S and S.Invalidar then S.Invalidar() end
	M.Avisar("CANDADO")
	M.Avisar("SUGERENCIAS")
	if M.Ventana and M.Ventana.RepintarTodo then M.Ventana.RepintarTodo() end
	if Cd.Juego then Cd.Juego() end
end

local function indice()
	if porId then return porId end
	porId = {}
	for _, cuenta in ipairs({ false, true }) do
		for k, v in pairs(lista(cuenta)) do
			if v == true then
				local id = tonumber(tostring(k):match("^(%d+)"))
				if id then porId[id] = true end
			end
		end
	end
	return porId
end

-- El objeto que dice el juego: -> calidad, clase, cuántos caben en un montón
local function infoJuego(id)
	local get = C_Item and C_Item.GetItemInfo
	if type(get) ~= "function" then return nil end
	local ok, nombre, _, q, _, _, _, _, apila, _, _, _, clase = pcall(get, id)
	if not ok or not M.Texto(nombre) then return nil end
	return M.Num(q), M.Num(clase), M.Num(apila)
end

-- La clave de un objeto: "id" o, si es único con enlace, "id:sufijo:único".
function Cd.Clave(id, link)
	id = tonumber(id)
	if not id then return nil end
	link = M.Texto(link)
	local cadena = link and link:match("item:([^|]+)")
	if cadena then
		local campos = {}
		for x in (cadena .. ":"):gmatch("([^:]*):") do campos[#campos + 1] = x end
		local suf, uni = campos[7] or "", campos[8] or ""
		if (suf ~= "" and suf ~= "0") or (uni ~= "" and uni ~= "0") then
			local _, _, apila = infoJuego(id)
			if not (apila and apila > 1) then
				return id .. ":" .. (suf ~= "" and suf or "0") .. ":" .. (uni ~= "" and uni or "0")
			end
		end
	end
	return tostring(id)
end

-- -> true | false | nil, y dónde ("tuyo" | "cuenta")
local function manual(k)
	if not k then return nil end
	local v = lista(false)[k]
	if v ~= nil then return v, "tuyo" end
	v = lista(true)[k]
	if v ~= nil then return v, "cuenta" end
	return nil
end

---------------------------------------------------------------------------
-- El automático
---------------------------------------------------------------------------

local conjuntos, conjuntosT = nil, -1
local function enConjunto(id)
	local ahora = GetTime and GetTime() or 0
	if not conjuntos or ahora - conjuntosT > 2 then
		conjuntos, conjuntosT = {}, ahora
		local Cj = M.Conjuntos
		if Cj and Cj.Lista and M.Get("conjuntos") ~= false then
			for _, c in ipairs(Cj.Lista()) do
				for _, pieza in pairs(c.p or {}) do
					local i = type(pieza) == "table" and tonumber(pieza.i)
					if i then conjuntos[i] = true end
				end
			end
		end
	end
	return conjuntos[id] == true
end

-- o (opcional): { q = calidad, clase = classID, mision = bool }
function Cd.Auto(id, o)
	if M.Get("candadoAuto") == false then return nil end
	id = tonumber(id)
	if not id then return nil end
	if id == PIEDRA_HOGAR then return "hogar" end
	if o and o.mision then return "mision" end
	local q, clase = o and o.q, o and o.clase
	if q == nil or clase == nil then
		local gq, gc = infoJuego(id)
		if q == nil then q = gq end
		if clase == nil then clase = gc end
	end
	if clase == 12 then return "mision" end
	if type(q) == "number" and q >= 4 then return "epico" end
	if enConjunto(id) then return "conjunto" end
	return nil
end

---------------------------------------------------------------------------
-- ¿Tiene candado?
---------------------------------------------------------------------------

function Cd.Tiene(id, link, o)
	if not encendido() then return false end
	id = M.Num(id)
	if not id then return false end
	local k = Cd.Clave(id, link)
	local v, donde = manual(k)
	local idk = tostring(id)
	if v == nil and k ~= idk then v, donde = manual(idk) end
	if v ~= nil then return v, v and donde or nil end
	local a = Cd.Auto(id, o)
	if a then return true, a end
	return false
end

-- Solo con el número (la regla del motor): protegido si cualquier objeto con
-- ese número lleva candado.
function Cd.ProtegeID(id)
	if not encendido() then return false end
	id = M.Num(id)
	if not id then return false end
	if indice()[id] then return true end
	if manual(tostring(id)) == false then return false end
	return Cd.Auto(id) ~= nil
end

local function misionDe(bolsa, casilla)
	local q = M.Llamar(M.CC.GetContainerItemQuestInfo, bolsa, casilla)
	if type(q) ~= "table" then return false end
	if M.Leer(q.isQuestItem) == true then return true end
	return (M.Num(q.questID) or 0) > 0
end

function Cd.TieneCasilla(bolsa, casilla)
	if not encendido() then return false end
	local info = M.Llamar(M.CC.GetContainerItemInfo, bolsa, casilla)
	if type(info) ~= "table" then return false end
	local id = M.Num(info.itemID)
	if not id then return false end
	return Cd.Tiene(id, M.Texto(info.hyperlink), { q = M.Num(info.quality), mision = misionDe(bolsa, casilla) })
end

-- Cuántos candados pusiste tú (personaje y cuenta).
function Cd.Cuantos()
	local n = 0
	for _, cuenta in ipairs({ false, true }) do
		for _, v in pairs(lista(cuenta)) do if v == true then n = n + 1 end end
	end
	return n
end

---------------------------------------------------------------------------
-- Poner y quitar
---------------------------------------------------------------------------

-- El nombre del objeto, sin enlace (los avisos y Lya lo dicen en texto).
local function nombreDe(id, link)
	link = M.Texto(link)
	local nombre = link and link:match("|h%[(.-)%]|h")
	if nombre and nombre ~= "" then return nombre end
	local get = C_Item and C_Item.GetItemInfo
	local ok, nombre = false, nil
	if type(get) == "function" then ok, nombre = pcall(get, id) end
	return (ok and M.Texto(nombre)) or (L["Objeto"] .. " " .. tostring(id))
end
Cd.Nombre = nombreDe

function Cd.TextoMotivo(m)
	if m == "epico" then return L["automático: épico o legendario"] end
	if m == "mision" then return L["automático: objeto de misión"] end
	if m == "hogar" then return L["automático: tu piedra de hogar"] end
	if m == "conjunto" then return L["automático: está en un conjunto tuyo"] end
	if m == "cuenta" then return L["en toda la cuenta"] end
	return nil
end

function Cd.Poner(id, link, si, o)
	id = M.Num(id)
	if not id then return false end
	local k = Cd.Clave(id, link)
	local idk = tostring(id)
	local antes = Cd.Tiene(id, link, o)
	if si then
		local destino = (lista(true)[k] == true or M.Get("candadoCuenta")) and true or false
		lista(false)[k], lista(true)[k] = nil, nil
		if lista(false)[idk] == false then lista(false)[idk] = nil end
		if lista(true)[idk] == false then lista(true)[idk] = nil end
		lista(destino)[k] = true
	else
		lista(false)[k], lista(true)[k] = nil, nil
		if lista(false)[idk] == true then lista(false)[idk] = nil end
		if lista(true)[idk] == true then lista(true)[idk] = nil end
		-- Lo que el automático pondría: «sin candado» a mano, por su número.
		if encendido() and Cd.Auto(id, o) then lista(M.Get("candadoCuenta") and true or false)[idk] = false end
	end
	cambio()
	local ahora = Cd.Tiene(id, link, o)
	if ahora ~= antes and K and K.Aviso then
		K.Aviso({ id = "candado.poner", pedido = true, icono = ICONO, tono = ahora and "exito" or "neutro", duracion = 5,
			titulo = ahora and L["Le pusiste candado"] or L["Le quitaste el candado"],
			texto = format(ahora and L["%s ya no se puede borrar ni vender por error."] or L["%s ya se puede vender y borrar."], nombreDe(id, link)) })
	end
	return ahora
end

-- Mueve el candado de este objeto entre tu personaje y toda la cuenta.
function Cd.EnCuenta(id, link, si)
	id = M.Num(id)
	if not id then return end
	local k = Cd.Clave(id, link)
	if lista(false)[k] ~= true and lista(true)[k] ~= true then
		k = tostring(id)
		if lista(false)[k] ~= true and lista(true)[k] ~= true then return end
	end
	lista(false)[k], lista(true)[k] = nil, nil
	lista(si and true or false)[k] = true
	cambio()
end

function Cd.Alternar(id, link, o)
	return Cd.Poner(id, link, not Cd.Tiene(id, link, o), o)
end

-- Quita todos los candados que pusiste en este personaje (y los de la cuenta con cuenta = true).
function Cd.QuitarTodos(cuenta)
	local d = N.DatosPersonaje("candado")
	d.o = {}
	if cuenta then N.Datos("candado").o = {} end
	cambio()
end

---------------------------------------------------------------------------
-- El menú del objeto (Alt+clic derecho)
---------------------------------------------------------------------------

local ancla
local function anclaEnCursor()
	if not ancla then
		ancla = CreateFrame("Frame", nil, UIParent)
		ancla:SetSize(1, 1)
	end
	local x, y = K.CursorEnUI() -- (1.3.8 revisión: con el escritorio movido, igual)
	ancla:ClearAllPoints()
	ancla:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	return ancla
end

function Cd.Menu(id, link, dueno, o)
	id = M.Num(id)
	if not id then return end
	if not encendido() then
		N.Imprimir(L["El candado de objetos está apagado (Bolsas > Candado de objetos)."])
		return
	end
	-- En combate, sin menú (el menú atrapa clics): cambia y ya.
	if enCombate() or not (K and K.Menu) then return Cd.Alternar(id, link, o) end
	local tiene, motivo = Cd.Tiene(id, link, o)
	local ops = { { valor = "alternar", texto = tiene and L["Quitarle el candado"] or L["Ponerle candado"], icono = ICONO } }
	local k = Cd.Clave(id, link)
	local cuenta = lista(true)[k] == true or lista(true)[tostring(id)] == true
	if tiene and (motivo == "tuyo" or motivo == "cuenta") then
		ops[#ops + 1] = { valor = "cuenta", texto = cuenta and L["Solo en este personaje"] or L["En toda la cuenta"], icono = "ic-personajes" }
	end
	K.Menu(dueno or anclaEnCursor(), ops, nil, function(v)
		if v == "alternar" then Cd.Alternar(id, link, o)
		elseif v == "cuenta" then Cd.EnCuenta(id, link, not cuenta) end
	end, 200)
end

-- Alt+clic derecho (solo Alt) sobre un objeto: Alfa.Hooks.ItemClick, el
-- seguidor de HandleModifiedItemClick (bolsas de Alfa y del juego).
local function soloAltDerecho()
	if not (IsAltKeyDown and IsAltKeyDown()) then return false end
	if IsShiftKeyDown and IsShiftKeyDown() then return false end
	if IsControlKeyDown and IsControlKeyDown() then return false end
	local boton = GetMouseButtonClicked and GetMouseButtonClicked()
	return boton == "RightButton"
end
Cd.SoloAltDerecho = soloAltDerecho

function Cd.AlClic(link, id)
	if not soloAltDerecho() then return false end
	id = M.Num(id) or M.ItemID(M.Texto(link))
	if not id then return false end
	Cd.Menu(id, link)
	return true
end

if A.Hooks and A.Hooks.ItemClick then
	A.Hooks.ItemClick("Alfa_Bolsas_Candado", function(link, id) M.Seguro(Cd.AlClic, link, id) end)
end

-- «Con candado» en el cuadro del objeto.
if A.Hooks and A.Hooks.ItemLines then
	A.Hooks.ItemLines("Alfa_Bolsas_Candado", function(tooltip, link, id)
		if not encendido() or not (tooltip and tooltip.AddLine) then return end
		local si, motivo = Cd.Tiene(id, link)
		if not si then return end
		local r, g, b = M.Color("warning", 1, 0.82, 0.3)
		local texto = "|T" .. K.Ruta(ICONO) .. ":0|t " .. L["Con candado"]
		local m = Cd.TextoMotivo(motivo)
		if m then texto = texto .. " (" .. m .. ")" end
		tooltip:AddLine(texto, r, g, b, true)
		local dr, dg, db = M.Color("textDim", 0.7, 0.7, 0.75)
		tooltip:AddLine(L["No se borra ni se vende por error. Alt+clic derecho para quitarlo."], dr, dg, db, true)
	end)
end

---------------------------------------------------------------------------
-- La regla del motor: lo protegido no se vende ni se borra solo
---------------------------------------------------------------------------

do
	local Q = A.QoL
	local Mk = Q and Q.Marks
	if type(Mk) == "table" and type(Mk.Protected) == "function" and not Mk.alfaCandado then
		local antes = Mk.Protected
		Mk.Protected = function(id)
			local ok, si = pcall(Cd.ProtegeID, id)
			if ok and si then return true end
			return antes(id)
		end
		Mk.alfaCandado = true
	end
end

---------------------------------------------------------------------------
-- Borrar: el cuadro del juego no deja
---------------------------------------------------------------------------

local CUADROS = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
Cd.CUADROS = CUADROS

-- Lo del cursor: -> id, enlace (solo objetos)
local function delCursor()
	local f = rawget(_G, "GetCursorInfo")
	if type(f) ~= "function" then return nil end
	local ok, que, id, link = pcall(f)
	if not ok or M.Texto(que) ~= "item" then return nil end
	return M.Num(id), M.Texto(link)
end

local apagados = setmetatable({}, { __mode = "k" }) -- cuadro -> su botón Aceptar, apagado por Alfa
local enganchados = setmetatable({}, { __mode = "k" }) -- cuadro -> true: ya lleva los ganchos de Alfa

local function pieza(d, metodo, ...)
	if type(d[metodo]) == "function" then
		local ok, x = pcall(d[metodo], d)
		if ok and x then return x end
	end
	for i = 1, select("#", ...) do
		local x = d[(select(i, ...))]
		if type(x) == "table" then return x end
	end
	return nil
end

local function devolverBoton(d)
	local b = apagados[d]
	apagados[d] = nil
	if b and b.Enable then pcall(b.Enable, b) end
end

local function cerrarCuadro(d)
	if not (type(d) == "table" and d.GetObjectType) then return end
	local b = pieza(d, "GetButton1", "button1", "Button1")
	if b and b.Disable then
		pcall(b.Disable, b)
		apagados[d] = b
		if not enganchados[d] and d.HookScript then
			-- (HookScript no toca el OnHide del juego; nada se escribe en su tabla.)
			enganchados[d] = true
			pcall(d.HookScript, d, "OnHide", function(self) devolverBoton(self) end)
			local caja = pieza(d, "GetEditBox", "editBox", "EditBox")
			if caja and caja.HookScript then
				pcall(caja.HookScript, caja, "OnTextChanged", function()
					local bb = apagados[d]
					if bb and bb.Disable then pcall(bb.Disable, bb) end
				end)
			end
			Cd.ganchos = (Cd.ganchos or 0) + 1
		end
	end
	local fs = pieza(d, "GetTextFontString", "text", "Text")
	if fs and fs.SetText then pcall(fs.SetText, fs, L["¡Este objeto tiene candado!"] .. "\n" .. L["No se puede borrar. Quítale el candado primero."]) end
end
Cd.CerrarCuadro = cerrarCuadro

local ultimoBorrar = 0
local function avisarBorrar(id, link)
	local ahora = GetTime and GetTime() or 0
	if ahora - ultimoBorrar < 0.5 then return end
	ultimoBorrar = ahora
	local texto = format(L["%s volvió a tus bolsas. Para borrarlo, quítale el candado con Alt+clic derecho."], nombreDe(id, link))
	Cd.ultimoAviso = texto
	if K and K.Aviso then
		K.Aviso({ id = "candado.borrar", pedido = true, importante = "siempre", icono = ICONO, tono = "aviso", duracion = 8,
			titulo = L["Tiene candado: no se puede borrar"], texto = texto })
	else
		N.Imprimir(texto)
	end
end

-- -> true si Alfa paró el borrado
function Cd.AlBorrar()
	if not encendido() then return false end
	local id, link = delCursor()
	if not id or not Cd.Tiene(id, link) then return false end
	local limpiar = rawget(_G, "ClearCursor")
	if type(limpiar) == "function" then pcall(limpiar) end
	-- El cuadro del juego, si ya salió: apagado (y se cierra solo sin el objeto en el cursor).
	local buscar = rawget(_G, "StaticPopup_FindVisible")
	if type(buscar) == "function" then
		for cual in pairs(CUADROS) do
			local ok, d = pcall(buscar, cual)
			if ok and d then cerrarCuadro(d) end
		end
	end
	Cd.parados = (Cd.parados or 0) + 1
	avisarBorrar(id, link)
	return true
end

A.RegisterEvent("DELETE_ITEM_CONFIRM", function() M.Seguro(Cd.AlBorrar) end)

-- El cuadro, al salir (por si llega antes que el evento a Alfa): si el
-- objeto del cursor tiene candado, apagado y el objeto de vuelta.
local enganchado = false
local function engancharCuadro()
	if enganchado then return end
	local f = rawget(_G, "StaticPopup_Show")
	if type(f) ~= "function" or not hooksecurefunc then return end
	enganchado = true
	hooksecurefunc("StaticPopup_Show", function(cual)
		if not (type(cual) == "string" and CUADROS[cual]) then return end
		M.Seguro(Cd.AlBorrar)
	end)
end
Cd.Enganchar = engancharCuadro
engancharCuadro()
A.OnLogin(engancharCuadro)

---------------------------------------------------------------------------
-- Vender: la capa sobre cada casilla con candado (comerciante abierto)
---------------------------------------------------------------------------

local comerciante = false
function Cd.Comerciante() return comerciante end

local capas = setmetatable({}, { __mode = "k" }) -- botón -> capa

local function avisarVenta(id, link)
	if K and K.Aviso then
		K.Aviso({ id = "candado.vender", pedido = true, icono = ICONO, tono = "aviso", duracion = 6,
			titulo = L["Tiene candado: no se vende"],
			texto = format(L["%s tiene candado. Si quieres venderlo, quítale el candado con Alt+clic derecho."], nombreDe(id, link)) })
	end
end

local function capaEntrar(self)
	if not (GameTooltip and self.alfaBolsa) then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if GameTooltip.SetBagItem then pcall(GameTooltip.SetBagItem, GameTooltip, self.alfaBolsa, self.alfaCasilla) end
	GameTooltip:Show()
end

local function capaSalir(self)
	if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function recoger(self)
	if enCombate() or not self.alfaBolsa then return end
	local f = M.CC.PickupContainerItem
	if type(f) == "function" then pcall(f, self.alfaBolsa, self.alfaCasilla) end
end

function Cd.ClicCapa(self, boton)
	local bolsa, casilla = self.alfaBolsa, self.alfaCasilla
	if not bolsa then return end
	local info = M.Llamar(M.CC.GetContainerItemInfo, bolsa, casilla)
	local id = type(info) == "table" and M.Num(info.itemID)
	local link = type(info) == "table" and M.Texto(info.hyperlink) or nil
	-- (1.3.8 revisión) Mayús+clic con el comerciante: separar el montón (con
	-- candado también se puede partir; solo no se vende).
	if boton == "LeftButton" and IsModifiedClick and IsModifiedClick("SPLITSTACK") then
		local n = type(info) == "table" and M.Num(info.stackCount) or nil
		local abrir = rawget(_G, "OpenStackSplitFrame")
		if n and n > 1 and type(abrir) == "function" and not enCombate() then
			if not self.SplitStack then
				self.SplitStack = function(capa, cuantos)
					local f = M.CC.SplitContainerItem
					if type(f) == "function" and capa.alfaBolsa then pcall(f, capa.alfaBolsa, capa.alfaCasilla, cuantos) end
				end
			end
			pcall(abrir, n, self, "BOTTOMLEFT", "TOPLEFT")
		end
		return
	end
	if IsModifiedClick and IsModifiedClick() then
		if boton == "RightButton" and soloAltDerecho() and id then return Cd.Menu(id, link, self) end
		if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
		return
	end
	if boton == "RightButton" then
		Cd.bloqueadas = (Cd.bloqueadas or 0) + 1
		if id then avisarVenta(id, link) end
		return
	end
	recoger(self)
end

local function capaDe(b, nivel)
	local c = capas[b]
	if c then return c end
	c = CreateFrame("Button", nil, b)
	c:SetAllPoints(b)
	c:SetFrameLevel((nivel or b:GetFrameLevel()) + 4)
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	if c.RegisterForDrag then c:RegisterForDrag("LeftButton") end
	c:SetScript("OnEnter", capaEntrar)
	c:SetScript("OnLeave", capaSalir)
	c:SetScript("OnClick", function(self, boton) M.Seguro(Cd.ClicCapa, self, boton) end)
	c:SetScript("OnDragStart", recoger)
	c:SetScript("OnReceiveDrag", recoger)
	c:Hide()
	capas[b] = c
	return c
end
Cd.Capas = capas

-- Muestra u oculta la capa de un botón en vivo (solo fuera de combate).
local function cubrir(b, si, bolsa, casilla, nivel)
	if si and (enCombate() or not comerciante) then si = false end
	if not si then
		local c = capas[b]
		if c and c:IsShown() then c:Hide() end
		return
	end
	local c = capaDe(b, nivel)
	c.alfaBolsa, c.alfaCasilla = bolsa, casilla
	c:Show()
end
Cd.Cubrir = cubrir

function Cd.QuitarCapas()
	for _, c in pairs(capas) do if c:IsShown() then c:Hide() end end
end

---------------------------------------------------------------------------
-- La marca sobre cada casilla (Botones.lua, al pintar)
---------------------------------------------------------------------------

local function marca(b, p)
	if p.candado then return p.candado end
	local t = p.capa:CreateTexture(nil, "OVERLAY", nil, 7)
	t:SetTexture(K.Ruta(ICONO))
	t:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
	t:Hide()
	local fondo = p.capa:CreateTexture(nil, "OVERLAY", nil, 6)
	fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
	fondo:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1)
	fondo:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
	fondo:SetVertexColor(0, 0, 0, 0.65)
	fondo:Hide()
	t.fondo = fondo
	p.candado = t
	return t
end

function Cd.Pintar(b, p, ent)
	if not p then return end
	local rec = ent and ent.rec
	local si = false
	if rec then
		si = Cd.Tiene(rec.i, rec.l, { q = rec.q, clase = ent.e and ent.e.clase, mision = rec.mision })
	end
	if not si then
		if p.candado then p.candado:Hide() p.candado.fondo:Hide() end
		if p.vivo then cubrir(b, false) end
		return
	end
	local t = marca(b, p)
	local lado = max(10, floor((p.tam or 36) * 0.34 + 0.5))
	t:SetSize(lado, lado)
	t:SetVertexColor(M.Color("warning", 1, 0.82, 0.3))
	t:Show()
	t.fondo:Show()
	-- Lo que tiene candado no se vende: sin la moneda de la chatarra.
	if p.chatarra then p.chatarra:Hide() end
	if p.vivo then cubrir(b, true, ent.bolsa, ent.casilla, p.capa:GetFrameLevel()) end
end

---------------------------------------------------------------------------
-- Las bolsas del juego (si Alfa no las reemplaza): la marca y la capa
---------------------------------------------------------------------------

local juego = setmetatable({}, { __mode = "k" }) -- botón del juego -> { marco, icono, fondo }

local function botonesJuego()
	local out = {}
	local function del(f)
		if type(f) ~= "table" or not (f.IsVisible and f:IsVisible()) then return end
		if type(f.EnumerateValidItems) == "function" then
			local ok, it, st, c0 = pcall(f.EnumerateValidItems, f)
			if ok and type(it) == "function" then
				for _, b in it, st, c0 do out[#out + 1] = b end
				return
			end
		end
		local nombre = f.GetName and f:GetName()
		local n = tonumber(rawget(f, "size")) or 0
		for i = 1, n do
			local b = type(nombre) == "string" and rawget(_G, nombre .. "Item" .. i)
			if type(b) == "table" then out[#out + 1] = b end
		end
	end
	for i = 1, max(tonumber(rawget(_G, "NUM_CONTAINER_FRAMES")) or 13, 13) do del(rawget(_G, "ContainerFrame" .. i)) end
	del(rawget(_G, "ContainerFrameCombinedBags"))
	return out
end

local function bolsaDe(b)
	if type(b.GetBagID) == "function" then
		local ok, x = pcall(b.GetBagID, b)
		if ok and type(x) == "number" then return x end
	end
	local p = b.GetParent and b:GetParent()
	return p and p.GetID and p:GetID() or nil
end

local function pintarJuego(b, si)
	local j = juego[b]
	if not si then
		if j then j.marco:Hide() end
		cubrir(b, false)
		return
	end
	if not j then
		local f = CreateFrame("Frame", nil, b)
		f:SetAllPoints(b)
		f:SetFrameLevel(b:GetFrameLevel() + 3)
		local fondo = f:CreateTexture(nil, "OVERLAY", nil, 6)
		fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
		fondo:SetVertexColor(0, 0, 0, 0.65)
		local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
		t:SetTexture(K.Ruta(ICONO))
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
		fondo:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1)
		fondo:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
		j = { marco = f, icono = t }
		juego[b] = j
	end
	local lado = max(10, floor((b:GetWidth() or 37) * 0.34 + 0.5))
	j.icono:SetSize(lado, lado)
	j.icono:SetVertexColor(M.Color("warning", 1, 0.82, 0.3))
	j.marco:Show()
end

-- Repasa las bolsas del juego a la vista (con las de Alfa, nada).
function Cd.Juego()
	local R = M.Reemplazo
	if R and R.Activo and R.Activo() then
		for b, j in pairs(juego) do j.marco:Hide() cubrir(b, false) end
		return 0
	end
	local n = 0
	for _, b in ipairs(botonesJuego()) do
		local bolsa, casilla = bolsaDe(b), b.GetID and b:GetID()
		local si = encendido() and bolsa and casilla and Cd.TieneCasilla(bolsa, casilla) or false
		pintarJuego(b, si)
		if si then
			n = n + 1
			cubrir(b, true, bolsa, casilla)
		end
	end
	return n
end

local function juegoPronto() N.Una("bolsas.candado.juego", 0.1, function() M.Seguro(Cd.Juego) end) end
for _, cual in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag", "OpenAllBags", "OpenBackpack", "OpenBag" }) do
	if type(rawget(_G, cual)) == "function" and hooksecurefunc then hooksecurefunc(cual, juegoPronto) end
end
A.RegisterEvent("BAG_UPDATE_DELAYED", function()
	local R = M.Reemplazo
	if not (R and R.Activo and R.Activo()) then juegoPronto() end
end)

---------------------------------------------------------------------------
-- El comerciante: las capas, y lo que se vendió con candado
---------------------------------------------------------------------------

local recompra -- el último de la pestaña «Recompra» al abrir: { n, link }

local function ultimaRecompra()
	local n = M.Num(M.Llamar(rawget(_G, "GetNumBuybackItems"))) or 0
	local link = n > 0 and M.Texto(M.Llamar(rawget(_G, "GetBuybackItemLink"), n)) or nil
	return n, link
end

local function repintar()
	if M.Ventana and M.Ventana.RepintarTodo then M.Ventana.RepintarTodo() end
	juegoPronto()
end

A.RegisterEvent("MERCHANT_SHOW", function()
	comerciante = true
	local n, link = ultimaRecompra()
	recompra = { n = n, link = link }
	repintar()
end)
A.RegisterEvent("MERCHANT_CLOSED", function()
	comerciante = false
	recompra = nil
	Cd.QuitarCapas()
end)
A.RegisterEvent("MERCHANT_UPDATE", function()
	if not (comerciante and recompra and encendido()) then return end
	local n, link = ultimaRecompra()
	if n == recompra.n and link == recompra.link then return end
	recompra = { n = n, link = link }
	local id = link and M.ItemID(link)
	if id and Cd.Tiene(id, link) and K and K.Aviso then
		K.Aviso({ id = "candado.vendido", pedido = true, importante = "siempre", icono = ICONO, tono = "aviso", duracion = 10,
			titulo = L["Vendiste algo con candado"],
			texto = format(L["%s tenía candado. Si fue un error, recómpralo en «Recompra»."], nombreDe(id, link)) })
	end
end)

-- En combate, ninguna capa (nada que atrape clics); al terminar, otra vez.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() Cd.QuitarCapas() end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() if comerciante then repintar() end end)

---------------------------------------------------------------------------
-- Comercio, correo, subasta y desencantar: un aviso claro
---------------------------------------------------------------------------

local avisados = {}
function Cd.AvisarDonde(id, link, donde)
	if not encendido() then return false end
	id = M.Num(id)
	if not id or not Cd.Tiene(id, link) then return false end
	local clave = tostring(donde) .. ":" .. (Cd.Clave(id, link) or id)
	local ahora = GetTime and GetTime() or 0
	if avisados[clave] and ahora - avisados[clave] < 20 then return false end
	avisados[clave] = ahora
	local QUE = {
		comercio = L["Lo pusiste en el comercio."], correo = L["Lo pusiste en una carta."],
		subasta = L["Lo pusiste en la subasta."], desencantar = L["Lo estás desencantando: muévete para cancelar."],
	}
	local texto = format(L["%s tiene candado."], nombreDe(id, link)) .. " " .. (QUE[donde] or "")
	Cd.ultimoAviso = texto
	if K and K.Aviso then
		K.Aviso({ id = "candado." .. tostring(donde), pedido = true, importante = "siempre", icono = ICONO, tono = "aviso", duracion = 8,
			titulo = L["Ojo: tiene candado"], texto = texto })
	end
	return true
end

A.RegisterEvent("TRADE_PLAYER_ITEM_CHANGED", function(_, ranura)
	ranura = M.Num(ranura)
	local f = rawget(_G, "GetTradePlayerItemLink")
	if not ranura or type(f) ~= "function" then return end
	local link = M.Texto(M.Llamar(f, ranura))
	if link then Cd.AvisarDonde(M.ItemID(link), link, "comercio") end
end)

A.RegisterEvent("MAIL_SEND_INFO_UPDATE", function()
	local f = rawget(_G, "GetSendMailItemLink")
	if type(f) ~= "function" then return end
	for i = 1, tonumber(rawget(_G, "ATTACHMENTS_MAX_SEND")) or 12 do
		local link = M.Texto(M.Llamar(f, i))
		if link then Cd.AvisarDonde(M.ItemID(link), link, "correo") end
	end
end)

-- La subasta de antes (AuctionFrame); la de ahora la avisa Comercio (Vender.lua).
A.RegisterEvent("NEW_AUCTION_UPDATE", function()
	local f = rawget(_G, "GetAuctionSellItemInfo")
	if type(f) ~= "function" then return end
	local id = M.Num(select(10, M.Llamar(f)))
	if id then Cd.AvisarDonde(id, nil, "subasta") end
end)

for _, ev in ipairs({ "TRADE_CLOSED", "MAIL_CLOSED", "AUCTION_HOUSE_CLOSED" }) do
	A.RegisterEvent(ev, function() avisados = {} end)
end

-- Desencantar: el objeto queda bloqueado mientras dura el hechizo.
function Cd.AlDesencantar()
	if not encendido() then return end
	local C = M.CC
	for _, bolsa in ipairs(BOLSAS) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
			if type(info) == "table" and M.Leer(info.isLocked) == true then
				local id = M.Num(info.itemID)
				local link = M.Texto(info.hyperlink)
				if id and Cd.TieneCasilla(bolsa, s) then return Cd.AvisarDonde(id, link, "desencantar") end
			end
		end
	end
end

if N.DeUnidad then
	N.DeUnidad("UNIT_SPELLCAST_START", "player", function(_, unidad, _, hechizo)
		if issecretvalue and (issecretvalue(unidad) or issecretvalue(hechizo)) then return end
		if unidad == "player" and tonumber(hechizo) == DESENCANTAR then M.Seguro(Cd.AlDesencantar) end
	end)
end

---------------------------------------------------------------------------
-- Lya lo sabe contar, y lo de afuera
---------------------------------------------------------------------------

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	pcall(Lya.Ensenar, { id = "bolsas.candado", icono = ICONO, modulo = M.ID,
		pregunta = L["¿Cómo evito borrar o vender algo por error?"],
		respuesta = L["Ponle candado: Alt+clic derecho sobre el objeto en tus bolsas. Con candado no se borra, no se vende y nada de Alfa lo toca. Lo épico, lo de misiones, tu piedra de hogar y tus conjuntos ya lo traen solos."] })
end)

A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".candado" or ruta == M.ID .. ".candadoAuto" or ruta == M.ID .. ".candadoCuenta" or ruta == M.ID or ruta == "" then
		porId = nil
		if not encendido() then Cd.QuitarCapas() end
		cambio()
	end
end)
M.Escuchar("CONJUNTOS", function()
	conjuntos = nil
	-- Solo la marca de las casillas (nada de la página ni de la sugerencia: 1.3.2, P.Rehacer).
	if M.Get("candadoAuto") ~= false and M.Ventana and M.Ventana.BolsasVisibles and M.Ventana.BolsasVisibles() then
		M.Ventana.RepintarTodo()
	end
end)

AlfaBolsas = type(rawget(_G, "AlfaBolsas")) == "table" and rawget(_G, "AlfaBolsas") or {}
AlfaBolsas.TieneCandado = function(bolsa, casilla) return (Cd.TieneCasilla(bolsa, casilla)) and true or false end
AlfaBolsas.Candado = function(id, link) return Cd.Tiene(id, link) end
AlfaBolsas.AvisarCandado = function(id, link, donde) return Cd.AvisarDonde(id, link, donde) end
