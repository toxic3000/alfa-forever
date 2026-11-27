-- Prueba de la 1.4.2: tu ficha (Alfa_Inicio/Ficha.lua).
--
-- Toxic: «quiero la funcionalidad, no lo mismo: nuestra propia distinción»
-- (una vista de tu personaje para presumirla, como la de un addon de oficios).
--   1. /alfa ficha abre «Tu personaje»: el modelo 3D, el nombre, la
--      experiencia, cuatro cifras, tus oficios y «Lo que sigue».
--   2. Con datos largos (mucho oro, 108 h jugadas, oficios largos), nada se sale
--      de su recuadro, en ventana ancha y angosta.
--   3. «Tus personajes» lista a los de la cuenta con su oro y suma el total.
--   4. El lobo de la portada de Hoy la abre.
--   5. Nada tapa el ratón al cerrarla.
PRUEBA_AREA("1.4.2 ficha")

-- Un personaje con todo largo.
GetMoney = function() return 123456789 end
C_SkillInfo = C_SkillInfo or {}
C_SkillInfo.GetNumSkillLines = function() return 4 end
C_SkillInfo.GetSkillLineInfo = function(i)
  local t = { { skillID = 164, skillName = "Herrería", rank = 255, maxRank = 300 }, { skillID = 186, skillName = "Minería", rank = 300, maxRank = 300 },
    { skillID = 185, skillName = "Cocina", rank = 180, maxRank = 225 }, { skillID = 356, skillName = "Pesca", rank = 159, maxRank = 225 } }
  return t[i]
end

PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local In = NS_OF("Alfa_Inicio")
local Fi = In and In.Ficha
N.Duracion = (function(real) return function(s, r) if (s or 0) > 100000 then return "108 h 59 min" end return real(s, r) end end)(N.Duracion)
if In and In.Jugado then In.Jugado.Datos = function() return { total = 392400 } end end

local function dentro(hijo, padre, nombre)
  local hl, hb, hw, hh = hijo:GetRect()
  local pl, pb, pw, ph = padre:GetRect()
  REVISA(hl >= pl - 0.5 and hl + hw <= pl + pw + 0.5, nombre .. " se sale por los lados")
end
local function textoDentro(fs, caja, nombre)
  local w = K.AnchoTexto(fs)
  local fw = fs:GetWidth()
  local visible = (fw and fw > 0) and math.min(w, fw) or w
  local cl, _, cw = caja:GetRect()
  REVISA(fs:GetLeft() + visible <= cl + cw + 0.5, ("%s: «%s» se sale de su recuadro"):format(nombre, tostring(fs:GetText())))
end

PASO("/alfa ficha abre tu personaje con todo", function()
  REVISA(Fi, "no existe Inicio/Ficha.lua")
  if not Fi then return end
  A.RunCommand("ficha")
  TIEMPO(1)
  local v = Fi.Ventana()
  REVISA(v and v:IsShown(), "/alfa ficha no abrió la ficha")
  local d = Fi.Datos()
  REVISA(#d.oficios == 4 and d.oficios[1].linea ~= 185, "los oficios no salen (o los secundarios van primero)")
  REVISA(d.oro == 123456789, "el oro no es el del personaje")
  local s = Fi.LoQueSigue(d)
  REVISA(#s >= 1, "«Lo que sigue» vacío")
end)

PASO("Nada se sale, ancha y angosta", function()
  local v = Fi and Fi.Ventana()
  if not v then return end
  local In2 = NS_OF("Alfa_Inicio")
  for _, ancho in ipairs({ 900, 640 }) do
    local revisados = 0
    v:SetTamano(ancho, 620)
    Fi.Pintar()
    TIEMPO(0.3)
    -- Las cifras y los oficios: sus textos dentro de su recuadro.
    for _, f in ipairs(ALL_FRAMES()) do
      if f:IsVisible() and rawget(f, "Valor") and rawget(f, "Titulo") and rawget(f, "caja") and f.Acomodar and RATON_DE_ALFA(f) then
        local p = f
        local enFicha = false
        for _ = 1, 6 do p = rawget(p, "_parent") if p == v or (p and p == v.Cuerpo) then enFicha = true break end end
        if enFicha then
          textoDentro(f.Valor, f, "ancho " .. ancho)
          textoDentro(f.Titulo, f, "ancho " .. ancho)
          revisados = revisados + 1
        end
      end
    end
    REVISA(revisados >= 4, "a " .. ancho .. " de ancho no se revisaron las cifras (" .. revisados .. ")")
  end
  v:SetTamano(900, 620)
end)

PASO("«Tus personajes» con el oro de todos", function()
  if not Fi then return end
  -- Otro personaje de la cuenta que ya había entrado.
  local db = N.Datos("inicio")
  db.ficha = db.ficha or {}
  db.ficha["Lyara-Reino"] = { nombre = "Lyara", clase = "HUNTER", claseNombre = "Cazadora", nivel = 60, oro = 1000000,
    oficios = { { linea = 393, nombre = "Desuello", r = 300, m = 300 } }, descansada = 0.5, visto = (time() or 0) - 7200 }
  Fi.Abrir("todos")
  TIEMPO(0.5)
  local lista = Fi.Personajes()
  REVISA(#lista >= 2, "no salen los personajes de la cuenta")
  REVISA(lista[1].nombre == "Lyara", "no van ordenados por nivel")
  local v = Fi.Ventana()
  v:Cerrar()
end)

PASO("Las recargas de oficio: en la ficha y en «Tus personajes»", function()
  if not Fi then return end
  IsPlayerSpell = function(id) return id == 18560 end
  C_Spell = C_Spell or {}
  C_Spell.GetSpellName = function(id) return id == 18560 and "Tela lunar" or nil end
  local enCurso = true
  C_Spell.GetSpellCooldown = function() if enCurso then return { startTime = GetTime(), duration = 345600 } end return { startTime = 0, duration = 0 } end
  local r = Fi.Recargas()
  REVISA(#r == 1 and r[1].nombre == "Tela lunar" and r[1].listo > 0, "no se lee la recarga de la tela lunar")
  enCurso = false
  r = Fi.Recargas()
  REVISA(#r == 1 and r[1].listo == 0, "la tela lunar lista no dice que ya se puede")
  local s = Fi.LoQueSigue(Fi.Datos())
  local dice = false
  for _, x in ipairs(s) do if tostring(x.texto):find("Tela lunar", 1, true) then dice = true end end
  REVISA(dice, "«Lo que sigue» no avisa que la tela lunar ya se puede usar")
  enCurso = true
  Fi.Anotar()
  Fi.Abrir("todos")
  TIEMPO(0.5)
  local vista = false
  for _, f in ipairs(ALL_FRAMES()) do
    if rawget(f, "Linea") and f:IsVisible() and tostring(f.Linea:GetText() or ""):find("Tela lunar: en", 1, true) then vista = true end
  end
  REVISA(vista, "«Tus personajes» no dice cuánto le falta a la tela lunar")
  Fi.Ventana():Cerrar()
end)

PASO("El lobo de la portada de Hoy abre la ficha", function()
  local P = In and In.Pagina
  A.Fire("SHOW_OPTIONS", "inicio")
  TIEMPO(1)
  local s = P and P.saludo
  REVISA(s and s.Toque, "la portada no tiene el lobo que abre la ficha")
  if s and s.Toque then
    s.Toque:Click()
    TIEMPO(0.5)
    REVISA(Fi.Ventana() and Fi.Ventana():IsShown(), "el lobo de la portada no abrió la ficha")
    Fi.Ventana():Cerrar()
  end
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o and o:IsShown() then o:Hide() end
end)

PASO("Al cerrar, nada tapa el ratón", function() TIEMPO(5) RATON_LIMPIO("tras la ficha") end)

PRUEBA_FIN()
