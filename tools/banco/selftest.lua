loadstring("return SOME_UNDEF_GLOBAL_X", "@Alfa\UI\Picker.lua")()
for k in pairs(GLOBAL_READS) do print("GLOBAL", k) end
