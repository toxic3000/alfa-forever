-- Alfa - Rutas: lo que esta área ofrece a las demás (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- AlfaRuta (global), el contrato de docs/PLAN-1.0.md:
--   AlfaRuta.Asistente(camino)       "¿Qué quieres hacer?"; camino: "nivel" | "profesiones" | "oro" | "mazmorras" | "planes" | nil
--   AlfaRuta.Liberar(filtro)         arma y abre el plan para cerrar tus misiones (filtro: "todas" | "listas" | "zona"; sin él, el que eligió el jugador)
--   AlfaRuta.Recoger()               toma las mejores misiones de cerca
--   AlfaRuta.AgregarObjeto(itemID)   un tramo para conseguir ese objeto en tu ruta (la Enciclopedia: "Agregar a mi ruta")
-- y además:
--   AlfaRuta.Entregar()              solo las listas para entregar (1.3.7: la Vuelta a entregar; sin ella, Liberar("listas"))
--   AlfaRuta.AgregarMision(questID)  a tu plan de misiones (con lo que pide antes) -> ok, por qué
--   AlfaRuta.QuitarMision(questID)   fuera de tu plan
--   AlfaRuta.EnPlan(questID) -> bool
--   AlfaRuta.Desbloquear(questID)    guía con lo que pide una misión que aún no puedes tomar
--   AlfaRuta.Disponible(questID) -> ok, texto   si ya se puede tomar y, si no, qué falta ("Disponible a nivel 20")
--   AlfaRuta.EsDeMiRuta(questID, verbo) -> bool  si una guía abierta la toma ("accept") o la entrega ("turnin")
--       en algún paso de aquí en adelante, o si está en tu plan de misiones (Comodidades lo consulta
--       con ruta.soloRuta encendido)
--   AlfaRuta.EnRuta(questID, verbo)  lo mismo (el nombre que usa Comodidades)
--   AlfaRuta.SoloRuta() -> bool      el ajuste ruta.soloRuta
--   AlfaRuta.Listas() -> n           misiones listas para entregar (al momento)
--   AlfaRuta.Biblioteca()            la biblioteca de guías
--   AlfaRuta.MostrarGuia()           muestra el rastreador
--   AlfaRuta.RastreadorVisible() -> bool  si el rastreador está a la vista (Hoy no repite "Mientras estás aquí")
--   AlfaRuta.Pagina()                la página Ruta
--   AlfaRuta.UnaHora() -> por qué     (1.2.7) «Una hora de caza»: un plan corto con lo que más
--       rinde cerca de ti: 2 o más listas -> Entregar(); misiones sin terminar en tu zona ->
--       Liberar("zona"); si no, Recoger(). Devuelve "entregar" | "zona" | "recoger" (Hora.lua)
--   AlfaRuta.Estimado() -> minutos | nil  (1.2.7) lo que te falta de tu guía, por tu ritmo
--       (los pasos que quedan por lo que tardas en cada uno); nil con muy pocas medidas
--   AlfaRuta.GrisValiosa(questID) -> motivo | nil  (1.2.7) «Vale la pena: …» de una misión gris
--   AlfaRuta.VueltaEntregar() -> ok, motivo  (1.2.8) «Vuelta a entregar»: tus misiones listas
--       por el camino más corto (vecino más cercano), la flecha de una en una (Vuelta.lua)
--   AlfaRuta.CancelarVuelta()        la deja
--   AlfaRuta.Vuelta() -> { i, total, parada } | nil   la vuelta en curso («Entrega 2 de 4»)
--   1.3.0:
--   AlfaRuta.Circuito()              el circuito de la zona: tus misiones y las de aquí en el mejor orden (Circuito.lua)
--   AlfaRuta.Grises() -> { { qid, titulo, nivel } } | nil   grises que no valen la pena (Grises.lua)
--   AlfaRuta.AbrirGrises()           su ventana, con «Abandonar» en cada una
--   AlfaRuta.Cadena(questID) -> { lista, final, premio, xp } | nil   la cadena completa (Cadena.lua);
--       la Enciclopedia la puede mostrar en la ficha de la misión
--   AlfaRuta.VerCadena(questID)      la ventana de la cadena
--   AlfaRuta.Llevame(destino) -> ok  destino = { map, x, y, f, nombre }: la flecha y el viaje (Viaje.lua)
--   AlfaRuta.AbrirLlevame()          «Llévame a…»
--   AlfaRuta.Pasos() -> { { texto, segundos, tipo } } | nil   los tramos del viaje en curso
--   AlfaRuta.Horarios() -> { { id, tipo, desde, hasta, texto, segundos } }   barcos y zepelines (Barcos.lua)
-- Buscar cerca (AlfaCerca, Cerca.lua) y Mis planes (AlfaPlanes, Planes.lua)
-- tienen su propio global.
-- Las misiones también se agregan y se quitan del plan desde el menú del
-- registro de misiones del juego (clic derecho en una misión) y del
-- seguimiento de objetivos.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Cr = M.Cerrar

local type, tonumber, ipairs = type, tonumber, ipairs

local R = AlfaRuta or {}
AlfaRuta = R

function R.Asistente(camino) M.Asistente.Abrir(camino) end
function R.Liberar(filtro) Cr.Ahora(filtro) end
-- 1.3.9 (12): un solo botón para «Cerrar mis misiones» (el resumen antes de salir).
function R.CerrarTodo(origen) return M.CerrarTodo.Abrir({ origen = type(origen) == "string" and origen or "otro" }) end
function R.TextoCerrar() return L["Cerrar mis misiones"] end
-- 1.3.9: restablecer la guía que sigues y empezar desde un paso (Restablecer.lua).
function R.Restablecer(sinPreguntar) return M.Restablecer.Restablecer(sinPreguntar) end
function R.EmpezarDesde(paso) return M.Restablecer.EmpezarDesde(paso) end
function R.TextoRestablecer() return L["Restablecer esta guía"] end
-- 1.3.9 (revisión): «¡Plan cumplido! Te quedan N misiones en tu registro…» (Hoy, con el cierre).
function R.TextoPlanCumplido(c)
	local n = type(c) == "table" and tonumber(c.quedan) or 0
	return string.format(n == 1 and L["¡Plan cumplido! Te queda %d misión en tu registro: Alfa arma la ruta para cerrarla."]
		or L["¡Plan cumplido! Te quedan %d misiones en tu registro: Alfa arma la ruta para cerrarlas."], n)
end
function R.TextoEmpezarDesde() return L["Empezar desde este paso"] end
-- 1.4.0: «Comprar lo que falta» de la guía de oficio que sigues (Comprar.lua,
-- 31) -> n | nil, motivo; tus guías terminadas (Historial.lua, 32); saltar a
-- la parte de tu nivel (MiNivel.lua, 26) -> ok.
function R.ComprarFalta() return M.Comprar.Agregar() end
function R.FaltanOficio() return M.Comprar.Faltan() end
function R.Historial() return M.Historial.Lista() end
function R.AbrirHistorial() return M.Historial.Abrir() end
function R.SaltarAMiNivel() return M.MiNivel.Saltar() end
function R.Entregar() return M.EntregarListas() end -- 1.3.7: la misma manera en todos lados
function R.Recoger() M.Recoger.Ahora() end
function R.AgregarObjeto(itemID) return M.AgregarObjeto(itemID) end

function R.AgregarMision(qid)
	local ok, por = Cr.Agregar(qid)
	if ok then
		M.Aviso(L["Agregada a Cerrar mis misiones"], M.TituloMision(qid), {
			icono = "ic-misiones", accion = { texto = L["Armar mi plan"], alClic = function() Cr.Ahora() end } })
	else
		M.Aviso(L["No la agregué"], por, { icono = "ic-aviso", tono = "aviso" })
	end
	return ok, por
end

function R.QuitarMision(qid)
	local ok = Cr.Quitar(qid, true)
	if ok then M.Aviso(L["Fuera de Cerrar mis misiones"], M.TituloMision(qid), { icono = "ic-misiones" }) end
	return ok
end

function R.EnPlan(qid) return Cr.EnPlan(qid) end
function R.Desbloquear(qid) M.Recoger.Desbloquear(qid) end

function R.Disponible(qid)
	local ok, motivo, info = M.Disp.Estado(qid)
	if ok then return true, nil end
	return false, M.Disp.Texto(motivo, info)
end

function R.EsDeMiRuta(qid, verbo)
	qid = tonumber(qid)
	if not qid then return false end
	local E = A.Engine
	if E and E.WantsQuest then
		local verbos = verbo and { verbo } or { "accept", "turnin" }
		for _, v in ipairs(verbos) do
			local ok, si = pcall(E.WantsQuest, v, qid, 9999)
			if ok and si then return true end
		end
	end
	return Cr.EnPlan(qid)
end
-- El nombre con que la busca Comodidades (área H).
function R.EnRuta(qid, verbo) return R.EsDeMiRuta(qid, verbo) end

function R.SoloRuta() return A.Get("ruta.soloRuta") ~= false end
function R.Listas() return Cr.ListasAhora() end
function R.Biblioteca() M.Biblioteca.Abrir() end
function R.MostrarGuia() M.Empezar() end
function R.RastreadorVisible() return M.Rastreador.Visible() and true or false end
-- 1.2.6: el fin pendiente de tu guía (lo que dice el rastreador), para Hoy:
-- { complete, undone, label, next, nextLabel } o nil.
function R.FinGuia() return M.Rastreador.Fin and M.Rastreador.Fin() or nil end
-- 1.3.7: lo mismo que el rastreador, para Hoy y la página Ruta.
--   AlfaRuta.GuiaTerminada() -> bool   cada paso hecho de verdad (los omitidos no cuentan)
--   AlfaRuta.Cierre() -> { id, nombre, terminada, omitidos, recuperar, elegir, sig } | nil
--   AlfaRuta.SeguirCierre(c), AlfaRuta.Recuperar(c), AlfaRuta.TextoCierre(c)
--   AlfaRuta.Distancia() -> texto, tono, a qué | nil   la distancia y el rumbo de la flecha
--   AlfaRuta.VerEnMapa()   el mapa de Alfa encuadrado en la flecha
function R.GuiaTerminada() return M.GuiaTerminada and M.GuiaTerminada() or false end
function R.Distancia() return M.Rastreador.Distancia() end
-- 1.3.9 (74): el tiempo de camino con el formato de la flecha («1 min 20 s», «12 min»).
function R.Tiempo(seg) return M.Rastreador.Tiempo(seg) end
--   AlfaRuta.XPListas() -> { n, xp, conocidas, subes, faltan }   lo que dan tus misiones listas
--   AlfaRuta.XPMision(questID) -> xp | nil
function R.XPListas() return M.XPListas() end
function R.XPMision(qid) return M.XPMision(qid) end
function R.VerEnMapa() return M.Rastreador.VerEnMapa() end
-- 1.3.9 (42): el título de un paso en tu idioma y si un texto quedó en inglés (Hoy, el Escritorio).
function R.TituloPaso(v) return M.Rastreador.TituloPaso(v) end
function R.SinTraducir(s) return M.Rastreador.SinTraducir(s) end
function R.Cierre() return M.Rastreador.Cierre() end
function R.SeguirCierre(c) return M.Rastreador.SeguirCierre(c) end
function R.Recuperar(c) return M.Rastreador.Recuperar(c) end
function R.TextoCierre(c) return M.Rastreador.TextoCierre(c) end
function R.Pagina() N.Abrir(M.ID) end
-- 1.2.7
function R.UnaHora() return M.Hora.UnaHora() end
function R.Estimado() return M.Hora.Estimado() end
function R.GrisValiosa(qid) return M.GrisValiosa(qid) end
-- 1.2.8
function R.VueltaEntregar() return M.Vuelta.Empezar() end
function R.CancelarVuelta() return M.Vuelta.Cancelar() end
function R.Vuelta() return M.Vuelta.Estado() end
-- 1.3.0
function R.Circuito() return M.Circuito.Ahora() end
function R.Grises() return M.Grises.Lista() end
function R.AbrirGrises() return M.Grises.Abrir() end
function R.Cadena(qid) return M.Cadena.De(qid) end
function R.VerCadena(qid) return M.Cadena.Abrir(qid) end
function R.Llevame(destino) return M.Viaje.Ir(destino) end
function R.AbrirLlevame() return M.Viaje.Abrir() end
function R.Pasos() return M.Viaje.Pasos() end
function R.Horarios() return M.Barcos.Lista() end
-- 1.3.3: cuántas misiones listas se entregan en el pueblo de tu piedra (la
-- placa «Usa tu piedra de hogar» de la flecha). -> n, lugar
function R.EntregasPiedra() return M.Hogar.Entregas() end

---------------------------------------------------------------------------
-- El menú del registro de misiones y del seguimiento de objetivos
---------------------------------------------------------------------------

local function mision(v)
	local C = M.Motor("Compat")
	if C and C.Readable then v = C.Readable(v) end
	if type(v) == "number" and v > 0 and v < math.huge and v % 1 == 0 then return v end
	return nil
end

-- El seguimiento de objetivos no dice de qué misión es su menú: la del
-- bloque bajo el ratón.
local function misionDelSeguimiento()
	if not GetMouseFoci then return nil end
	for _, foco in ipairs(GetMouseFoci() or {}) do
		local f = foco
		while f do
			if f.IsForbidden and f:IsForbidden() then break end
			local mod = f.parentModule
			if mod and (mod == QuestObjectiveTracker or mod == CampaignQuestObjectiveTracker) then
				local id = mision(f.id)
				if id and mod.GetExistingBlock and mod:GetExistingBlock(id) == f then return id end
			end
			f = f.GetParent and f:GetParent()
		end
	end
	return nil
end

local function agregarAlMenu(root, qid)
	if not qid or (A.Hidden and A.Hidden()) then return end
	root:CreateDivider()
	-- 1.2.7: una gris que vale la pena, dicho en el menú.
	local vale = M.GrisValiosa and M.GrisValiosa(qid)
	if vale and root.CreateTitle then root:CreateTitle(vale) end
	-- 1.4.2: la flecha a esa misión (su objetivo más cerca, o quien la recibe) (IrMision.lua).
	local Ir = M.IrMision
	if Ir and Ir.Encendido() then
		local Cp = M.Motor("Compat")
		local lista = Cp and Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid)
		root:CreateButton(lista and L["Alfa: llévame a entregarla"] or L["Alfa: llévame"], function() Ir.Ir(qid) end)
	end
	if Cr.EnPlan(qid) then
		root:CreateButton(L["Alfa: quitar de Cerrar mis misiones"], function() R.QuitarMision(qid) end)
	else
		root:CreateButton(L["Alfa: agregar a Cerrar mis misiones"], function() R.AgregarMision(qid) end)
	end
	root:CreateButton(L["Alfa: cerrar mis misiones"], function() Cr.Ahora() end)
	-- 1.3.0: la cadena completa (Cadena.lua).
	if M.Cadena and A.Get(M.ID .. ".cadenaCompleta") ~= false then
		root:CreateButton(L["Alfa: ver la cadena completa"], function() M.Cadena.Abrir(qid) end)
	end
	-- 1.3.8: de élite, de grupo o de mazmorra: «Busco grupo» a tu manada (La Jauría).
	local Ma = rawget(_G, "AlfaManada")
	if type(Ma) == "table" and type(Ma.BuscoGrupo) == "function" and M.Rastreador.DeGrupo({ quest = qid }) then
		root:CreateButton(L["Alfa: busco grupo para esta misión"], function() Ma.BuscoGrupo(M.TituloMision(qid), "q") end)
	end
end

-- 1.3.8: tu guía de ahora y seguir una por su id (La Jauría: compartir tu ruta).
function R.GuiaActual()
	local E = A.Engine
	local g = E and E.GetGuide and E.GetGuide()
	if type(g) ~= "table" or type(g.id) ~= "string" then return nil end
	return { id = g.id, nombre = M.NombreGuia(g) or g.id }
end
function R.NombreGuia(id) return type(id) == "string" and M.NombreGuia(id) or nil end
function R.SeguirGuia(id)
	if type(id) ~= "string" or not M.NombreGuia(id) then return false end
	M.Biblioteca.Seguir(id)
	return true
end

A.OnLogin(function()
	if (A.GamepadUI and A.GamepadUI()) or not (Menu and Menu.ModifyMenu) then return end
	Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", function(owner, root)
		agregarAlMenu(root, mision(owner and owner.questID))
	end)
	Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(_, root)
		agregarAlMenu(root, misionDelSeguimiento())
	end)
end)
