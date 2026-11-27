-- Escenas de la 1.4.2 para revisar a ojo y para la galería de CurseForge:
-- tu ficha («Tu personaje» y «Tus personajes») y la portada de Hoy con una
-- sesión larga. Datos de muestra (Lobato y su manada), nada de ningún jugador real.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
BANCO_LETRA = 0.64
GetMoney = function() return 1530676 end
UnitName = function() return "Lobato" end
UnitClass = function() return "Guerrero", "WARRIOR" end
UnitRace = function() return "Humano", "Human" end
UnitLevel = function() return 34 end
UnitXP = function() return 31000 end
UnitXPMax = function() return 52000 end
GetXPExhaustion = function() return 12000 end
GetGuildInfo = function() return "La Jauría" end
GetRealZoneText = function() return "Loch Modan" end
GetInventoryItemDurability = function(r) if r <= 10 then return 92, 100 end return nil end
C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 22 end
C_Container.GetContainerNumFreeSlots = function(b) return b == 0 and 3 or 4, 0 end
C_SkillInfo = C_SkillInfo or {}
C_SkillInfo.GetNumSkillLines = function() return 4 end
C_SkillInfo.GetSkillLineInfo = function(i)
  local t = { { skillID = 164, skillName = "Herrería", rank = 255, maxRank = 300 }, { skillID = 186, skillName = "Minería", rank = 300, maxRank = 300 },
    { skillID = 185, skillName = "Cocina", rank = 180, maxRank = 225 }, { skillID = 356, skillName = "Pesca", rank = 159, maxRank = 225 } }
  return t[i]
end
for clase, c in pairs({ WARRIOR = { 0.78, 0.61, 0.43 }, HUNTER = { 0.67, 0.83, 0.45 }, MAGE = { 0.25, 0.78, 0.92 } }) do
  RAID_CLASS_COLORS[clase] = { r = c[1], g = c[2], b = c[3] }
end
PRUEBA_ENTRAR()
local N = AlfaNucleo
local In = NS_OF("Alfa_Inicio")
if In.Jugado then In.Jugado.Datos = function() return { total = 810000 } end end
local db = N.Datos("inicio")
db.ficha = db.ficha or {}
db.ficha["Lyara-Reino"] = { nombre = "Lyara", clase = "HUNTER", claseNombre = "Cazadora", nivel = 60, oro = 4210050,
  oficios = { { linea = 393, nombre = "Desuello", r = 300, m = 300 }, { linea = 165, nombre = "Peletería", r = 285, m = 300 } }, descansada = 0.5, visto = time() - 7200 }
db.ficha["Brasa-Reino"] = { nombre = "Brasa", clase = "MAGE", claseNombre = "Maga", nivel = 22, oro = 85300,
  oficios = { { linea = 197, nombre = "Sastrería", r = 110, m = 150 }, { linea = 333, nombre = "Encantamiento", r = 95, m = 150 } }, descansada = 1.2, visto = time() - 3 * 86400 }
local Fi = In.Ficha
local v = Fi.Abrir("yo")
TIEMPO(1)
SNAP("142-ficha", v)
Fi.Abrir("todos")
TIEMPO(1)
SNAP("142-personajes", v)
v:Cerrar()
-- La portada de Hoy con una sesión larga (el «1 h 48 min» que se salía).
local dur = N.Duracion
N.Duracion = function(sg, r) return "1 h 48 min" end
Alfa.Fire("SHOW_OPTIONS", "inicio")
TIEMPO(1)
local o = Alfa.UI.Options.frame
SNAP("142-portada", o)
N.Duracion = dur
o:Hide()
PRUEBA_FIN("galería 1.4.2")
