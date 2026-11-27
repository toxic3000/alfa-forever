-- Prueba de la 1.4.2: la portada de Hoy, con datos largos.
--
-- Toxic: «el tiempo sale del recuadro que pusiste y pareciera que no está bien
-- organizado; haz un diseño más responsivo, que no se salgan de los bordes los
-- datos, que esté todo alineado». Con «1 h 48 min» (y más largo) en «Tu
-- sesión», en anchos de ventana distintos:
--   1. ningún valor ni título se sale de su recuadro;
--   2. los recuadros quedan dentro de la portada y alineados (mismo ancho, misma altura);
--   3. si no cabe en grande, la letra baja dentro de la escala del Kit (nunca se sale).
PRUEBA_AREA("1.4.2 portada")
PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local In = NS_OF("Alfa_Inicio")
local P = In and In.Pagina

local function revisar(momento)
  local s = P and P.saludo
  REVISA(s and s:IsShown(), momento .. ": no se ve la portada")
  if not (s and s:IsShown()) then return end
  local sl, sb, sw, sh = s:GetRect()
  local ancho0, alto0
  for i = 1, s.alfaN or 0 do
    local c = s.cifras[i]
    local cl, cb, cw, ch = c:GetRect()
    REVISA(cl >= sl - 0.5 and cl + cw <= sl + sw + 0.5 and cb >= sb - 0.5 and cb + ch <= sb + sh + 0.5,
      ("%s: el recuadro %s se sale de la portada"):format(momento, tostring(c.alfaClave)))
    ancho0 = ancho0 or cw
    alto0 = alto0 or ch
    REVISA(math.abs(cw - ancho0) < 0.5 and math.abs(ch - alto0) < 0.5, momento .. ": los recuadros no miden lo mismo")
    for _, fs in ipairs({ c.Valor, c.Titulo }) do
      local w = K.AnchoTexto(fs)
      local fw = fs:GetWidth()
      local visible = (fw and fw > 0) and math.min(w, fw) or w
      local fl = fs:GetLeft()
      REVISA(fl + visible <= cl + cw + 0.5, ("%s: «%s» se sale de su recuadro (%d de %d)"):format(momento, tostring(fs:GetText()), fl + visible - cl, cw))
    end
  end
end

local durReal = N.Duracion
PASO("«1 h 48 min» y más largo, en varios anchos de ventana", function()
  A.Fire("SHOW_OPTIONS", "inicio")
  TIEMPO(1)
  REVISA(P and P.saludo, "no encuentro la portada de Hoy")
  if not (P and P.saludo) then return end
  for _, valor in ipairs({ "1 h 48 min", "12 h 48 min", "108 h 59 min" }) do
    N.Duracion = function() return valor end
    for _, ancho in ipairs({ 980, 760, 560 }) do
      P.saludo:Llenar()
      P.saludo:Acomodar(ancho)
      revisar(valor .. " a " .. ancho .. " de ancho")
    end
  end
  N.Duracion = durReal
end)

PASO("El ratón sigue siendo del jugador", function()
  local o = A.UI and A.UI.Options and A.UI.Options.frame
  if o and o:IsShown() then o:Hide() end
  TIEMPO(5)
  RATON_LIMPIO("tras la portada")
end)

PRUEBA_FIN()
