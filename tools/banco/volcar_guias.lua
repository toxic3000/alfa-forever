-- Huella de cada guía ya armada (1.3.4, guías diferidas). tools/prueba.py la
-- corre dos veces: con dist/ (pasos diferidos) y con una copia revertida
-- (tools/diferir.py --revertir, los pasos como venían), y compara las dos
-- salidas línea por línea: los pasos y la ficha de cada guía deben quedar
-- iguales después de pasar por el motor (traducción y escapes incluidos).
local A = Alfa
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
local G = A.Guides
G.LoadFaction("All")
RUN_TIMERS(5)

local OMITIR = { stepsSrc = true, qref = true, groupQuests = true, steps = true }

local function serial(v, out, visto, raiz)
  local t = type(v)
  if t == "table" then
    if visto[v] then out[#out + 1] = "<ciclo>" return end
    visto[v] = true
    local claves = {}
    for k in pairs(v) do
      if not (raiz and OMITIR[k]) then claves[#claves + 1] = k end
    end
    table.sort(claves, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(claves) do
      out[#out + 1] = tostring(k) .. "="
      serial(v[k], out, visto, false)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
    visto[v] = nil
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "function" then
    out[#out + 1] = "<fn>"
  else
    out[#out + 1] = tostring(v)
  end
end

local function huella(s)
  local h, n = 0, #s
  for i = 1, n, 64 do
    local b = { s:byte(i, math.min(n, i + 63)) }
    for j = 1, #b do h = (h * 31 + b[j]) % 2147483629 end
  end
  return h, n
end

local ids = {}
for _, h in ipairs(G.List()) do ids[#ids + 1] = h.id end
table.sort(ids)
for _, id in ipairs(ids) do
  local g = G.Get(id)
  local cab, pas = {}, {}
  local h
  for _, x in ipairs(G.List()) do if x.id == id then h = x end end
  serial(h, cab, {}, true)
  serial(g and g.steps, pas, {}, false)
  local hc, nc = huella(table.concat(cab))
  local hp, np = huella(table.concat(pas))
  print(("GUIA %s cabecera %d/%d pasos %d/%d"):format(id, hc, nc, hp, np))
end
print("GUIAS VOLCADAS", #ids)
