--[[
    Ejemplo-FlowLib.lua · uso mínimo de LIBB.lua

    Carga:
        local FlowLib = loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/PrinceBeebear/FlowLib/main/LIBB.lua"
        ))()
]]

local FlowLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/PrinceBeebear/FlowLib/main/LIBB.lua"
))()

FlowLib:Singleton("FlowUI")

local Win = FlowLib:CreateWindow({
    title   = "Flow Example",
    size    = { 260, 360 },
    keybind = Enum.KeyCode.RightControl,
})

local Tab1 = Win:CreateTab("Principal")
local Tab2 = Win:CreateTab("Jugadores")
local Tab3 = Win:CreateTab("Ajustes")

Tab1:AddSection({ name = "Acciones" })
Tab1:AddButton({ name = "Hola", callback = function() end })
Tab1:AddLabel({ text = "Configuración:" })
Tab1:AddToggle({ name = "Modo seguro", default = false, callback = function(state) end })
Tab1:AddSlider({ name = "Volumen", min = 0, max = 100, default = 50, callback = function(value) end })
Tab1:AddKeybind({ name = "Tecla de pánico", default = Enum.KeyCode.F, callback = function(key) end })

Tab2:AddSection({ name = "Jugadores cercanos" })
Tab2:AddList({
    name        = "Elegir jugador",
    items       = FlowLib:GetPlayerItems(),
    placeholder = "Buscar jugador...",
    callback    = function(item) end,
})
Tab2:AddDropdown({
    name = "Acción sobre el jugador",
    items = {
        { id = "seg", name = "Seguir" },
        { id = "vig", name = "Vigilar" },
    },
    callback = function(item) end,
})
Tab2:AddSearchBox({ placeholder = "Buscar...", callback = function(text) end })

Tab3:AddSection({ name = "Atajos" })
Win:AddUIBind({ name = "Mostrar/ocultar menú" })
Tab3:AddLabel({ text = "Fin del ejemplo." })

return Win
