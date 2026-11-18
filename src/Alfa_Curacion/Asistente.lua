-- Alfa - Curación: el asistente de 3 pasos (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana propia del Kit (K.Ventana con K.Asistente), chica, para que se
-- vean tus marcos mientras la usas:
--   1. Elige un preajuste: los de tu clase en tarjetas, con lo que pone en
--      tus clics; y "el clic izquierdo solo selecciona" si curas.
--   2. Acomoda tus marcos: el modo prueba con 5 o 20 marcos de ejemplo, que
--      arrastras a donde los quieras, con su ancho, su alto y sus columnas.
--   3. Prueba tus clics: haz clic en un marco de ejemplo (con o sin Mayús,
--      Ctrl o Alt) y aquí ves qué lanzaría; debajo, todo tu mapa.
-- Al terminar, los marcos quedan encendidos y el asistente, hecho para este
-- personaje (M.Datos().asistente). Cerrarlo a medias quita la prueba.
--   M.AbrirAsistente(paso) ; M.RefrescarAsistente()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local format, ipairs, type = string.format, ipairs, type
local ESP = K.ESP

local v, asis
local ui = {}

local function acomodar()
	if not (v and asis and v:IsShown()) then return end
	asis:Acomodar(v:AnchoCuerpo(), v:AltoCuerpo())
	asis:Refrescar()
end

---------------------------------------------------------------------------
-- Paso 1: el preajuste
---------------------------------------------------------------------------

local function llenarPreajustes()
	local p = ui.p1
	if not p then return end
	local actual = M.Datos().preajuste
	for i, pre in ipairs(M.PreajustesDe()) do
		local t = p.tarjetas[i]
		if not t then
			t = K.Tarjeta(p, { variante = "normal" })
			p:Agregar(t, { espacio = ESP.s })
			p.tarjetas[i] = t
		end
		local elegido = actual == pre
		local esta = pre
		t:Set({
			icono = M.ICONO_PRE[pre] or "ic-curacion", tono = elegido and "exito" or nil,
			titulo = M.TituloPreajuste(pre), texto = M.DescripcionPreajuste(pre),
			insignias = elegido and { { L["Elegido"], "exito", "ic-exito" } } or nil,
			alClic = not elegido and function() M.UsarPreajuste(esta) end or nil,
		})
		K.Mostrar(t, true)
	end
	-- Una tarjeta que ya no se ofrece ("Desde cero" tras dejarlo, sin buffs) se oculta.
	for i = #M.PreajustesDe() + 1, #p.tarjetas do K.Mostrar(p.tarjetas[i], false) end
	if p.izq then
		K.Mostrar(p.izq, actual == "curar")
		p.izq:Refrescar()
	end
end

local function paso1()
	return {
		titulo = L["Elige tus clics"],
		texto = L["Cada preajuste llena tus clics con los hechizos que ya sabes. Después cambias lo que quieras en la página Curación."],
		construir = function(pila)
			ui.p1 = pila
			pila.tarjetas = {}
			llenarPreajustes()
			pila.izq = K.FilaAjuste(pila, {
				titulo = L["El clic izquierdo solo selecciona"],
				texto = L["La cura de ese clic pasa al botón central."],
				control = function(fila)
					local s = K.Interruptor(fila, { valor = M.IzquierdoSelecciona(), alCambiar = function(on) M.FijarIzquierdoSelecciona(on == true) end })
					function s:Leer() self:SetValor(M.IzquierdoSelecciona()) end
					return s
				end,
			})
			pila.izq.caja = K.Caja(pila.izq, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
			pila:Agregar(pila.izq, { espacio = ESP.base })
			llenarPreajustes()
		end,
		alMostrar = llenarPreajustes,
		listo = function() return M.Datos().preajuste ~= nil end,
	}
end

---------------------------------------------------------------------------
-- Paso 2: dónde van tus marcos
---------------------------------------------------------------------------

local function ponerPrueba(n)
	if M.EnCombate() then return end
	if M.EnPrueba() ~= n then M.Prueba(n) end
end

local function paso2()
	return {
		titulo = L["Acomoda tus marcos"],
		texto = L["Aparecen marcos de ejemplo: arrástralos a donde los quieras y ajusta su tamaño. Así se verá tu grupo."],
		construir = function(pila)
			ui.p2 = pila
			pila.cuantos = K.Segmentos(pila, { estilo = "segmentos", valor = 5, opciones = {
				{ valor = 5, texto = L["Grupo de 5"] }, { valor = 20, texto = L["Banda de 20"] } },
				alCambiar = function(n) ponerPrueba(n) end })
			pila.cuantos.alfaAnchoPropio = true
			pila:Agregar(pila.cuantos)
			local g = K.GrupoAjustes(pila, {})
			local function desl(clave, a, b, paso, formato)
				return function(fila)
					local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave, formato = formato })
					d.alfaAnchoFila = 200
					return d
				end
			end
			g:Fila({ titulo = L["Ancho"], control = desl("ancho", 50, 200, 2, M.Px) })
			g:Fila({ titulo = L["Alto"], control = desl("alto", 20, 80, 1, M.Px) })
			g:Fila({ titulo = L["Compañeros por columna"], control = desl("porColumna", 1, 40, 1, M.Entero) })
			g:Fila({ titulo = L["Crecen hacia"], control = function(fila)
				return K.Desplegable(fila, { clave = ID .. ".crecer", ancho = 150, opciones = {
					{ valor = "abajo", texto = L["Abajo"] }, { valor = "derecha", texto = L["La derecha"] } } })
			end })
			pila.grupo = pila:Agregar(g, { espacio = ESP.base })
			pila.Nota = CreateFrame("Frame", nil, pila)
			pila.Nota.Texto = K.Texto(pila.Nota, "nota", "aviso")
			function pila.Nota:Acomodar(ancho)
				self.Texto:ClearAllPoints()
				self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
				local h = K.Parrafo(self.Texto, ancho, 2)
				self:SetSize(ancho, h)
				return h
			end
			pila:Agregar(pila.Nota, { espacio = ESP.s })
		end,
		alMostrar = function(pila)
			local enCombate = M.EnCombate()
			K.Escribir(pila.Nota.Texto, enCombate and L["En combate no hay prueba: sal de la pelea y vuelve a este paso."] or "")
			K.Mostrar(pila.Nota, enCombate)
			ponerPrueba(M.EnPrueba() or 5)
			pila.cuantos:SetValor(M.EnPrueba() or 5)
			pila.grupo:Refrescar()
		end,
	}
end

---------------------------------------------------------------------------
-- Paso 3: prueba tus clics
---------------------------------------------------------------------------

local function mapaComoTarjetas(ultima)
	local lista = {}
	local mapa = M.Mapa()
	for _, r in ipairs(M.RANURAS) do
		local e = mapa[r]
		if type(e) == "table" and e.t ~= "nada" then
			local icono = (e.t == "target" and "ic-raros") or (e.t == "menu" and "ic-lista") or "ic-curacion"
			lista[#lista + 1] = { variante = "compacta", icono = icono, tono = r == ultima and "acento" or "neutro",
				titulo = M.NombreAccion(e), texto = M.NombreRanura(r), ranura = r, entrada = e }
		end
	end
	return lista
end

local function llenarPrueba()
	local p = ui.p3
	if not p then return end
	local r, e = ui.ranura, ui.entrada
	if r then
		local nada = type(e) ~= "table" or e.t == "nada"
		p.Resultado:Set({ icono = "ic-curacion", tono = nada and "aviso" or "exito", sobre = L["Tu prueba"],
			titulo = M.NombreRanura(r),
			texto = nada and L["Este clic no hace nada. Elígele algo en Tu ratón, en la página Curación."]
				or format(L["Sobre tu compañero, este clic %s."], M.Frase(e)) })
	else
		p.Resultado:Set({ icono = "ic-curacion", tono = "acento", sobre = L["A probar"],
			titulo = L["Haz clic en un marco de ejemplo"],
			texto = L["Con o sin Mayús, Ctrl o Alt. No lanza nada: aquí ves qué lanzaría sobre tu compañero."] })
	end
	local lista = mapaComoTarjetas(r)
	p.Rejilla:Llenar(lista)
	-- Los hechizos, con su ícono del juego.
	for i, d in ipairs(lista) do
		local c = p.Rejilla.pool[i]
		if c and d.entrada.t == "spell" then
			M.PintarRanura(c.Icono, c.Titulo, nil, d.entrada)
			c.Icono:SetSize(22, 22)
		elseif c then
			c.Icono:SetTexCoord(0, 1, 0, 1)
			c.Icono:SetSize(16, 16)
		end
	end
	K.Mostrar(p.Rejilla, #lista > 0)
end

local function paso3()
	return {
		titulo = L["Prueba tus clics"],
		texto = L["Así sabes qué hace cada clic antes de tu próxima pelea."],
		construir = function(pila)
			ui.p3 = pila
			pila.Resultado = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
			pila.Rejilla = pila:Agregar(K.Rejilla(pila, { min = 170, gap = ESP.s }), { espacio = ESP.base })
			llenarPrueba()
		end,
		alMostrar = function()
			ponerPrueba(M.EnPrueba() or 5)
			llenarPrueba()
		end,
	}
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function terminar()
	local d = M.Datos()
	d.asistente = true
	d.asistenteOmitido = nil
	ui.hecho = true
	if not N.Get(ID, "activo") then N.Set(ID, "activo", true) end
	v:Cerrar()
	K.Aviso({ titulo = L["Tus marcos están listos"], texto = L["Pasa el ratón sobre un compañero y cúralo con un clic."], lobo = "aullando", tono = "acento", duracion = 6 })
	A.Fire("ALFA_CURACION_ASISTENTE")
	M.Avisar()
end

local function armar()
	v = K.Ventana({
		nombre = "AlfaCuracionAsistente", titulo = L["Prepara tus marcos de curación"], subtitulo = L["Tres pasos y listo"],
		icono = "ic-curacion", ancho = 600, alto = 640,
		alCerrar = function()
			M.alProbarClic = nil
			if M.EnPrueba() then M.Prueba(nil) end
			if M.Moviendo() then M.Mover(false) end
			ui.ranura, ui.entrada = nil, nil
		end,
	})
	asis = K.Asistente(v.Cuerpo, { margen = v.margen, textoTerminar = L["Listo"], alTerminar = terminar,
		pasos = { paso1(), paso2(), paso3() } })
	asis.alCambiar = function() acomodar() end
	v.alAcomodar = function() acomodar() end
end

function M.AbrirAsistente(paso)
	if not v then armar() end
	ui.hecho = nil
	M.alProbarClic = function(r, e)
		ui.ranura, ui.entrada = r, e
		if asis and asis:Paso() == 3 then
			llenarPrueba()
			acomodar()
		end
	end
	v:Abrir()
	asis:Ir(paso or 1)
	acomodar()
end

-- Algo cambió (el mapa, la prueba, un ajuste): el paso de ahora se repinta.
function M.RefrescarAsistente()
	if not (v and v:IsShown() and asis) then return end
	local i = asis:Paso()
	if i == 1 then llenarPreajustes()
	elseif i == 2 and ui.p2 then ui.p2.grupo:Refrescar() ui.p2.cuantos:SetValor(M.EnPrueba() or 5)
	elseif i == 3 then llenarPrueba() end
	acomodar()
end
