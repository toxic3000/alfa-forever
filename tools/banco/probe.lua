FIRE_EVENT("PLAYER_LOGIN")
RUN_TIMERS(10)
local UI = Alfa.UI
UI.ShowPicker()
local win = UI.Picker.frame
local b = win.pillButtons[1]
local l, bo, w, h = b:GetRect()
print("pill1", l, bo, w, h, b.psKey)
local function show(f, depth)
  for _, c in ipairs(f._children) do
    if c._shown then
      local cl, cb, cw, ch = c:GetRect()
      print(string.rep(" ", depth), c._kind, c._tex or c._text or "", math.floor(cl), math.floor(cw), c._layer or "", c._tc4 and table.concat(c._tc4, ",") or "")
      if c._kind ~= "Texture" and c._kind ~= "FontString" then show(c, depth + 2) end
    end
  end
end
show(b, 1)
