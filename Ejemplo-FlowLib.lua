--!strict
--[[
    Ejemplo-FlowLib.lua
    Script de ejemplo mínimo para usar la lib (lib/LIBB.lua, antes FlowLib).

    Flujo:
      1. Sube lib/LIBB.lua a la raíz de la rama `main` de PrinceBeebear/FlowLib.
      2. Este archivo solo carga la lib y agrega elementos.
      3. Copia el bloque "CARGA DE LA LIB" en cada script que quieras usar.

    Estándar: IA-skill (ventana cristal, fade 0.3s, singleton _G.FlowUI)
]]

-- ============================================================
-- CARGA DE LA LIB (bloque a copiar en cada script)
-- ============================================================
local FlowLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/PrinceBeebear/FlowLib/main/LIBB.lua"
))()

-- Singleton: si la lib ya está cargada en esta sesión, destruye la ventana
-- anterior en vez de duplicarla (evita GUIs apiladas al re-ejecutar).
FlowLib:Singleton("FlowUI")

-- ============================================================
-- VENTANA (cristal)
-- ============================================================
local Win = FlowLib:CreateWindow({
    title   = "Flow Example",
    width   = 270,   -- opcional (default 270)
    height  = 480,   -- opcional (default 480)
    keybind = Enum.KeyCode.RightControl,  -- ocultar/mostrar la ventana
})

-- Las tabs se crean por orden de izquierda a derecha
local Tab1 = Win:CreateTab("Principal")
local Tab2 = Win:CreateTab("Jugadores")
local Tab3 = Win:CreateTab("Ajustes")

-- ============================================================
-- PÁGINA 1: botón, toggle, slider, keybind
-- ============================================================
Tab1:AddSection({ name = "Acciones" })

Tab1:AddButton({
    name = "Hola",
    callback = function()
        print("¡Botón Hola!")
    end,
})

Tab1:AddLabel({ text = "Configuración:" })

Tab1:AddToggle({
    name    = "Modo seguro",
    default = false,
    callback = function(state)
        print("Modo seguro =", state)
    end,
})

Tab1:AddSlider({
    name    = "Volumen",
    min     = 0,
    max     = 100,
    default = 50,
    step    = 1,               -- opcional (se infiere si min/max son enteros)
    callback = function(value)
        print("Volumen =", value)
    end,
})

Tab1:AddKeybind({
    name     = "Tecla de pánico",
    default  = Enum.KeyCode.F,  -- tecla inicial
    callback = function(key)
        print("¡Tecla de pánico!", key)
    end,
    -- onBind = function(key) end  -- opcional: se dispara al reasignar
})

-- ============================================================
-- PÁGINA 2: lista con buscador, dropdown y caja de texto
-- ============================================================
Tab2:AddSection({ name = "Jugadores cercanos" })

Tab2:AddList({
    name        = "Elegir jugador",
    items       = FlowLib:GetPlayerItems(),  -- { id, name, subtitle }
    placeholder = "Buscar jugador...",        -- buscador con debounce 0.35s
    callback    = function(item)
        print("Seleccionado:", item.name)
    end,
})

Tab2:AddDropdown({
    name = "Acción sobre el jugador",
    items = {
        { id = "seg", name = "Seguir" },
        { id = "vig", name = "Vigilar" },
    },
    callback = function(item)
        print("Acción:", item.name)
    end,
})

Tab2:AddSearchBox({
    placeholder = "Escribe y espera...",
    callback = function(text)
        print("Texto:", text)   -- se dispara 0.35s después de dejar de escribir
    end,
})

-- ============================================================
-- PÁGINA 3: bind global de la ventana
-- (Win:AddUIBind siempre se agrega a la primer tab, como los binds)
-- ============================================================
Tab3:AddSection({ name = "Atajos" })

local MenuBind = Win:AddUIBind({
    name = "Mostrar/ocultar menú",
    -- la tecla inicial es la de `keybind` en CreateWindow
})

-- Cambiar la tecla en caliente (no bloquea el hilo):
-- Win:SetUIBind(Enum.KeyCode.M)   o   MenuBind:Set(Enum.KeyCode.M)

Tab3:AddLabel({ text = "Fin del ejemplo." })

return Win
