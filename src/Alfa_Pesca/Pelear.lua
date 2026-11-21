-- Alfa - Pesca: «A pelear» / «Volver a mi equipo» (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7, lo pidió Toxic: si estás pescando y te atacan (o entras en JcJ), un
-- clic te devuelve tus armas; si no hay pelea, el mismo clic te pone todo tu
-- equipo de antes y cierra el modo pesca.
--
-- Cómo funciona:
--   * AlfaPescaPelear es un botón seguro con una macro «/equipslot 16 ...»
--     (y 17) con las armas que Equipo.lua recuerda. La macro se arma FUERA de
--     combate (al abrir el modo, cuando cambia lo recordado, al empezar una
--     pelea antes del bloqueo); nunca SetAttribute en combate.
--   * En combate el juego deja cambiar las armas, no la armadura: el clic te
--     pone las armas (la macro) y lo demás queda para el fin de la pelea
--     (N.FueraDeCombate). Fuera de combate te pone todo y cierra el modo.
--   * Sin armas recordadas (o en combate sin macro) se ve apagado y su cuadro
--     dice por qué.
--   * Se ve en la barra de pesca, en un hueco que ella le guarda: el botón es
--     suyo (padre UIParent, sin anclarse a la barra) y se coloca encima del
--     hueco fuera de combate; en combate la barra no se pliega ni se mueve.
--   * Tiene su tecla (Alfa > Pescar: volver a tus armas) y, al entrar en
--     combate con la caña puesta, un aviso breve que la dice (avisoPelear).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local E = M.E
local Eq = M.Eq

local max, format, type = math.max, string.format, type

local ACCION = "CLICK AlfaPescaPelear:LeftButton"
M.ACCION_PELEAR = ACCION
_G["BINDING_NAME_" .. ACCION] = L["Pescar: volver a tus armas"]

local P = {}
M.Pelear = P

local ICONO = "Interface\\Icons\\INV_Sword_04"
local AVISO_CADA = 60 -- segundos entre dos avisos de «te atacan con la caña»

local function opt(k) return N.Get(ID, k) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- El botón seguro
---------------------------------------------------------------------------
local boton = CreateFrame("Button", "AlfaPescaPelear", UIParent, "SecureActionButtonTemplate")
boton:RegisterForClicks("AnyUp")
boton:SetFrameStrata("HIGH")
boton:SetSize(24, 24)
boton:Hide()
boton.caja = K.Caja(boton, { corte = K.CORTE.chico, fondo = "acento", alfaFondo = 0.14, borde = "acento", alfaBorde = 0.45 })
boton.velo = K.Velo(boton, K.CORTE.chico, 0.07)
boton.Icono = boton:CreateTexture(nil, "ARTWORK")
boton.Icono:SetSize(16, 16)
boton.Icono:SetPoint("CENTER")
boton.Icono:SetTexture(ICONO)
boton.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
P.boton = boton
M.VISIBLES[#M.VISIBLES + 1] = boton

-- Lo que tienen ahora sus atributos (para no tocarlos si no cambió nada).
P.macro = nil

-- -> "todo" (fuera de combate: armas y equipo) | "armas" (en combate, con macro) | "nada", motivo
function P.Estado()
	if not M.Habilitado() then return "nada", L["La pesca de Alfa está apagada"] end
	if enCombate() then
		if P.macro then return "armas" end
		return "nada", L["En combate solo se pueden cambiar las armas, y Alfa no recuerda las tuyas."]
	end
	if P.macro or Eq.HayNormal() then return "todo" end
	return "nada", L["Alfa todavía no recuerda tus armas: las anota cuando te pones la caña o el equipo de pesca."]
end

function P.Titulo()
	return enCombate() and L["A pelear"] or L["Volver a mi equipo"]
end

-- El cuadro del botón: qué hace ahora (o por qué no puede).
function P.Info()
	local estado, motivo = P.Estado()
	local lineas = {}
	if estado == "nada" then
		lineas[1] = motivo
	elseif estado == "armas" then
		lineas[1] = L["Te pone tus armas ahora. El resto de tu equipo vuelve al salir de la pelea."]
	else
		lineas[1] = L["Te pone tus armas y el resto de tu equipo, y cierra el modo pesca."]
		lineas[2] = L["En combate solo cambian las armas; lo demás, al terminar la pelea."]
	end
	local tecla = P.Tecla()
	if tecla then lineas[#lineas + 1] = format(L["Tecla: %s"], tecla) end
	return P.Titulo(), table.concat(lineas, "\n")
end

function P.Tecla()
	if not GetBindingKey then return nil end
	local ok, k = pcall(GetBindingKey, ACCION)
	if ok and type(k) == "string" and k ~= "" then return M.TextoTecla(k) end
	return nil
end

-- Solo texturas: se puede pintar también en combate.
function P.Pintar()
	local si = (P.Estado()) ~= "nada"
	local tono = si and "acento" or "neutro"
	local relleno = K.Tono(tono)
	boton.caja:Estilo({ fondo = relleno, alfaFondo = si and 0.14 or 0.06, borde = relleno, alfaBorde = si and 0.45 or 0.25 })
	boton.Icono:SetDesaturated(not si)
	boton.Icono:SetAlpha(si and 1 or 0.45)
	if boton.alfaSobre then K.MostrarInfo(boton, P.Info()) end
end

-- Arma la macro con tus armas (fuera de combate; en combate, al salir).
function P.Armar()
	if enCombate() then
		N.FueraDeCombate("pesca.pelear.armar", P.Armar)
		return
	end
	local macro = M.Habilitado() and Eq.MacroArmas() or nil
	if boton:GetAttribute("useOnKeyDown") ~= false then boton:SetAttribute("useOnKeyDown", false) end
	if macro ~= P.macro or boton:GetAttribute("macrotext") ~= macro then
		boton:SetAttribute("type", macro and "macro" or nil)
		boton:SetAttribute("macrotext", macro)
		P.macro = macro
	end
	P.Pintar()
end

-- Te devuelve todo lo demás y cierra el modo (fuera de combate).
function P.Volver()
	if enCombate() then
		N.FueraDeCombate("pesca.pelear.volver", P.Volver)
		return
	end
	if M.Modo() then M.CerrarModo(false, true) end
	Eq.Restaurar()
	P.Armar()
end

local avisoCombate = false
function P.TrasClic()
	local estado, motivo = P.Estado()
	if estado == "nada" then
		K.MostrarInfo(boton, P.Titulo(), motivo)
		return
	end
	if estado == "armas" then
		-- La macro ya te puso las armas: lo demás (y cerrar el modo), al terminar la pelea.
		N.FueraDeCombate("pesca.pelear.volver", P.Volver)
		if Eq.HayResto() and not avisoCombate and K.Aviso then
			avisoCombate = true
			K.Aviso({ id = "pesca.pelear", icono = "ic-alerta", tono = "aviso", duracion = 5,
				titulo = L["A pelear"], texto = L["En combate solo cambian las armas; el resto de tu equipo vuelve al salir de la pelea."] })
		end
		return
	end
	-- Fuera de combate: la macro ya pidió las armas; Restaurar no las vuelve a pedir.
	if P.macro then Eq.armasYa = GetTime and GetTime() or 0 end
	P.Volver()
end

boton:SetScript("PostClick", function() P.TrasClic() end)
boton:SetScript("OnEnter", function(self)
	self.alfaSobre = true
	self.velo:Show()
	K.MostrarInfo(self, P.Info())
	if M.Barra and M.Barra.Desplegar then M.Barra.Desplegar() end
end)
boton:SetScript("OnLeave", function(self)
	self.alfaSobre = nil
	self.velo:Hide()
	K.OcultarInfo(self)
	if M.Barra and M.Barra.PlegarLuego then M.Barra.PlegarLuego() end
end)

---------------------------------------------------------------------------
-- Encima del hueco de la barra (fuera de combate)
---------------------------------------------------------------------------
function P.Ocultar()
	if enCombate() then return end
	boton:Hide()
end

function P.Sincronizar()
	if enCombate() then return end
	local barra = M.Barra and M.Barra.Barra and M.Barra.Barra()
	local h = barra and barra.hueco
	if not (h and barra:IsShown() and h:IsShown() and E.modo and M.Habilitado()) then
		boton:Hide()
		return
	end
	local s = K.num(h:GetEffectiveScale(), 1)
	local us = max(0.01, K.num(UIParent:GetEffectiveScale(), 1))
	boton:SetScale(s / us)
	boton:ClearAllPoints()
	-- Las medidas del hueco están en su escala, que es la que queda en el botón.
	boton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", K.num(h:GetLeft(), 0), K.num(h:GetBottom(), 0))
	boton:SetSize(K.num(h:GetWidth(), 24), K.num(h:GetHeight(), 24))
	boton:Show()
	P.Pintar()
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
M.Escuchar(function(m)
	if m.modo or m.equipo or m.todo or m.ajustes or m.plan then
		N.FueraDeCombate("pesca.pelear.armar", P.Armar)
	end
	if not enCombate() then P.Sincronizar() else P.Pintar() end
end)

local ultimoAviso = -AVISO_CADA

-- Al empezar la pelea (todavía sin bloqueo): la macro al día, la barra
-- desplegada encima de la vista mínima, el botón en su lugar y el aviso.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	E.pelea = true
	avisoCombate = false
	if not enCombate() then
		P.Armar()
		if M.Barra then
			M.Barra.Desplegar()
			M.Barra.Actualizar()
		end
		P.Sincronizar()
	end
	P.Pintar()
	if not (opt("avisoPelear") and M.Habilitado() and P.macro and Eq.CanaPuesta() and K.Aviso) then return end
	local ahora = GetTime and GetTime() or 0
	if ahora - ultimoAviso < AVISO_CADA then return end
	ultimoAviso = ahora
	local tecla, enBarra = P.Tecla(), boton:IsShown()
	local texto
	if tecla and enBarra then texto = format(L["Pulsa %s o la espada de la barra de pesca para ponerte tus armas."], tecla)
	elseif enBarra then texto = L["Toca la espada de la barra de pesca para ponerte tus armas."]
	elseif tecla then texto = format(L["Pulsa %s para ponerte tus armas."], tecla)
	else return end
	-- 1.3.7: sale ya (la pelea acaba de empezar) o nunca: después ya no sirve.
	K.Aviso({ id = "pesca.atacan", icono = "ic-alerta", tono = "aviso", duracion = 6, prioridad = 1, caduca = 8,
		donde = true, -- (el texto dice qué hacer: tu tecla o la espada de la barra de pesca)
		titulo = L["Te atacan con la caña en la mano"], texto = texto })
end)

A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	E.pelea = nil
	P.Armar()
	if M.Barra then M.Barra.Actualizar() end
	P.Sincronizar()
end)

A.RegisterEvent("UPDATE_BINDINGS", function() if boton.alfaSobre then K.MostrarInfo(boton, P.Info()) end end)
