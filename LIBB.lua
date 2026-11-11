--[[
	FlowLib.lua → LIBB.lua  ·  Libreria de ventana "cristal" para los scripts Flow
	===================================================================

	El script principal deja de construir la ventana a mano: solo carga la lib
	y va agregando elementos. La lib se encarga de todo el chrome visual
	(fade, arrastre con inercia, minimizar, cerrar, scrollbars, tabs, binds).

	Carga desde un script:
		local Lib = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/PrinceBeebear/FlowLib/main/LIBB.lua"
		))()

		local win = Lib:CreateWindow({
			title   = "Flow • Mi Script",          -- texto del header
			width   = 270,                          -- opcional (default 270)
			height  = 480,                          -- opcional (default 480)
			keybind = Enum.KeyCode.RightControl,    -- opcional: mostrar/ocultar
			onClose = function() end,               -- tu logica de "Stop" primero
		})

		local tab = win:CreateTab("General")       -- opcional (si no, todo va directo)
		tab:AddButton { name = "Hola", callback = function() print("hola") end }
		tab:AddToggle { name = "Modo", default = false, callback = function(v) end }
		tab:AddSlider { name = "Velocidad", min = 0, max = 100, default = 25, callback = function(v) end }
		tab:AddKeybind{ name = "Tecla", default = Enum.KeyCode.F, callback = function(k) end }
		tab:AddList   { name = "Jugadores", items = Lib:GetPlayerItems(), callback = function(item) end }
		tab:AddDropdown{ name = "Opciones", items = {"A","B"}, callback = function(item) end }
		tab:AddLabel  { text = "Texto informativo" }
		tab:AddSection{ name = "Configuracion" }

	Singleton (obligatorio para re-ejecutar sin duplicar ventanas):
		Lib:Singleton("MiScript")   -- mata la instancia anterior y registra cleanup

	Reglas IA-skill aplicadas aqui:
	  · ventana estilo cristal (DropShadow + GlassBackdrop + stroke con gradiente)
	  · fade UNIFORME via CanvasGroup.GroupTransparency (0.3s Quad Out); los
	    contenedores intermedios y las hitboxes nunca se tween-an, asi que no
	    aparecen "recuadros grises"
	  · arrastre con inercia (x1.8, 0.45 Quart) limitado a pantalla
	  · scrollbar vertical y horizontal estilo RR (track/thumb/trackHit Z 50/52/53)
	  · espera de tecla con timeout de 30s (nunca un Wait() infinito)
	  · singleton _G + cleanup registrado para re-ejecucion
]]

-- ============================================================== servicios
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local FlowLib = {}
FlowLib.Version = "1.0.0"

-- ============================================================== helpers
local function Create(className, props, children)
	local inst = Instance.new(className)
	for prop, value in pairs(props or {}) do
		if prop ~= "Parent" then
			inst[prop] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function Round(radius, parent)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function Circle(parent)
	return Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

local function Tween(obj, props, duration, style, direction)
	if not obj then return nil end
	local t = TweenService:Create(obj, TweenInfo.new(
		duration or 0.2,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	), props)
	t:Play()
	return t
end

-- AbsolutePosition / AbsoluteSize con guardas (robusto si el entorno no los
-- calcula aun, p.ej. GUIs recien creadas o entornos de prueba)
local function absPos(obj)
	local p = obj and obj.AbsolutePosition
	if p and p.X then return p end
	return Vector2.new(0, 0)
end

local function absSize(obj)
	local s = obj and obj.AbsoluteSize
	if s and s.X then return s end
	return Vector2.new(0, 0)
end

-- AbsoluteContentSize de un UIListLayout (puede no existir aun)
local function contentHeight(layout)
	local cs = layout and layout.AbsoluteContentSize
	if cs and cs.Y then return cs.Y end
	return 0
end

-- ============================================================== estilo
local COLOR = {
	BG        = Color3.fromRGB(12, 12, 12),
	ROW       = Color3.fromRGB(30, 30, 30),
	ROW_HOVER = Color3.fromRGB(45, 45, 45),
	ROW_PRESS = Color3.fromRGB(22, 22, 22),
	TEXT      = Color3.fromRGB(255, 255, 255),
	TEXT_DIM  = Color3.fromRGB(175, 175, 175),
	STROKE    = Color3.fromRGB(210, 210, 225),
	ACCENT    = Color3.fromRGB(100, 100, 100),
	DANGER    = Color3.fromRGB(255, 60, 60),
	GOLD      = Color3.fromRGB(255, 215, 0),
	GREEN     = Color3.fromRGB(60, 180, 80),
	FIELD     = Color3.fromRGB(20, 20, 20),
	TAB_IDLE  = Color3.fromRGB(160, 160, 160),
	ROW_SEL   = Color3.fromRGB(60, 60, 60),
}
FlowLib.Colors = COLOR

local CORNER_RADIUS     = 18
local ROW_RADIUS        = 8
local ROW_H             = 36
local ROW_TRANSPARENCY  = 0.3
local SIDE_MARGIN       = 10
local SCROLL_W          = 5
local SCROLL_GAP        = 8
local FADE_TIME         = 0.3
local FAST              = 0.15
local HEADER_H          = 38

local STROKE_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.466, 0),
	NumberSequenceKeypoint.new(0.947, 0.906),
	NumberSequenceKeypoint.new(1, 1),
})

local function makeFont(weight)
	local ok, font = pcall(function()
		return Font.new("rbxasset://fonts/families/BuilderSans.json", weight)
	end)
	if ok and font then return font end
	if weight == Enum.FontWeight.Bold then
		return Enum.Font.GothamBold
	end
	return Enum.Font.Gotham
end

local FONT_BOLD = makeFont(Enum.FontWeight.Bold)
local FONT_MED  = makeFont(Enum.FontWeight.Medium)

FlowLib.Fonts = { Bold = FONT_BOLD, Medium = FONT_MED }

-- ============================================================== teclas
local SHORT_KEYS = {
	LeftShift = "LS", RightShift = "RS",
	LeftControl = "LC", RightControl = "RC",
	LeftAlt = "LA", RightAlt = "RA",
	Space = "SP", Backspace = "BS", Return = "ENT",
	Escape = "ESC", Tab = "TAB", CapsLock = "CAPS",
}

-- Nombre legible de un Enum.KeyCode (funciona tambien en entornos sin .Name)
local function keyNameOf(key)
	if key == nil then return "NONE" end
	local n = key.Name
	if type(n) ~= "string" then
		n = tostring(key)
		n = n:match("%.([^.]+)$") or n
	end
	return n
end

-- Texto corto sobre el icono de bind: LS/RS/LC/RC/LA/RA/SP/BS/ENT/ESC/TAB
local function shortKey(key)
	local name = keyNameOf(key)
	local mapped = SHORT_KEYS[name]
	if mapped then return mapped end
	return (#name <= 3) and name or name:sub(1, 3)
end

-- Convierte "RightControl" (string de config) o Enum.KeyCode en Enum.KeyCode
local function toKeyCode(v)
	if v == nil then return nil end
	if type(v) == "string" then
		local ok, code = pcall(function() return Enum.KeyCode[v] end)
		if ok then return code end
		return nil
	end
	return v
end

-- ============================================================== singleton
-- Patrón IA-skill: si ya corre una instancia, se limpia antes de continuar.
local pendingSingleton = nil

function FlowLib:Singleton(key)
	key = tostring(key)
	local k = "FlowLib_Singleton_" .. key
	if _G[k] then
		local cleanup = _G[k .. "_Cleanup"]
		if type(cleanup) == "function" then pcall(cleanup) end
		task.wait(0.1)
	end
	_G[k] = true
	pendingSingleton = k
	return true
end

-- ============================================================== utilidades
-- Lista de jugadores lista para AddList / AddDropdown
function FlowLib:GetPlayerItems(excludeLocal)
	local items = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local p = list[i]
		if not (excludeLocal and p == LocalPlayer) then
			items[#items + 1] = {
				id = p.UserId,
				name = p.DisplayName or p.Name,
				subtitle = "@" .. tostring(p.Name),
				icon = p.UserId,
			}
		end
	end
	return items
end

-- Escucha cambios de texto de un TextBox: usa el evento TextChanged (estandar
-- de Roblox) y cae a GetPropertyChangedSignal("Text") si no existe.
local function connectTextChanged(box, fn)
	if box.TextChanged then
		box.TextChanged:Connect(fn)
	else
		box:GetPropertyChangedSignal("Text"):Connect(fn)
	end
end

-- ============================================================== items
local function resolveIcon(item, opts)
	local ic = item.icon
	if ic == nil then return nil end
	if type(ic) == "string" then return ic end
	local kind = (opts and opts.thumbType) or "AvatarHeadShot"
	return "rbxthumb://type=" .. kind .. "&id=" .. tostring(ic) .. "&w=150&h=150"
end

local function normalizeItems(items)
	local out = {}
	items = items or {}
	for i = 1, #items do
		local it = items[i]
		if type(it) == "table" then
			out[i] = {
				id = it.id or it.Id or it.UserId or it.Name or it.name or i,
				name = it.name or it.Name or it.DisplayName or tostring(it.id or i),
				subtitle = it.subtitle or it.Username or (it.UserId and it.Name and ("@" .. tostring(it.Name))) or nil,
				icon = it.icon or it.Icon or it.Thumbnail or it.UserId,
				raw = it,
			}
		else
			out[i] = { id = tostring(it), name = tostring(it), raw = it }
		end
	end
	return out
end

local function itemMatches(item, query)
	if not query or query == "" then return true end
	query = tostring(query):lower()
	if tostring(item.name or ""):lower():find(query, 1, true) then return true end
	if tostring(item.subtitle or ""):lower():find(query, 1, true) then return true end
	if tostring(item.id or ""):lower():find(query, 1, true) then return true end
	return false
end

-- ============================================================== scrollbars
-- Scrollbar vertical personalizada estilo RR (track 50 / trackHit 52 / thumb 53)
local function applyVerticalScroll(win, scrollFrame, parentFrame, topOffset, bottomOffset)
	scrollFrame.ScrollBarThickness = 0

	local track = Create("Frame", {
		Name = "Track_" .. scrollFrame.Name,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.95,
		Position = UDim2.new(1, -(SIDE_MARGIN + SCROLL_W), 0, 0),
		Size = UDim2.new(0, SCROLL_W, 1, -10),
		ZIndex = 50,
		Active = true,
		Parent = parentFrame,
	})
	Round(99, track)

	local thumb = Create("Frame", {
		Name = "Thumb",
		BackgroundColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 53,
		Parent = track,
	})
	Round(99, thumb)

	-- hitbox invisible sobre el track: NUNCA entra al fade (BackgroundTransparency = 1)
	local trackHit = Create("TextButton", {
		Name = "TrackHit",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 52,
		Active = true,
		Parent = track,
	})

	local function updateScroll()
		local tOffset = type(topOffset) == "function" and topOffset() or topOffset
		local bOffset = type(bottomOffset) == "function" and bottomOffset() or (tonumber(bottomOffset) or 10)
		track.Position = UDim2.new(1, -(SIDE_MARGIN + SCROLL_W), 0, tOffset)
		track.Size = UDim2.new(0, SCROLL_W, 1, -(tOffset + bOffset))

		local view = absSize(scrollFrame).Y
		local content = (scrollFrame.CanvasSize and scrollFrame.CanvasSize.Y.Offset) or 0
		local overflow = view > 0 and content > view + 1
		track.Visible = overflow
		thumb.Visible = overflow
		if not overflow then return end

		local trackH = absSize(track).Y
		local thumbH = math.max(26, math.floor(trackH * (view / content)))
		local maxThumbY = trackH - thumbH
		local maxCanvasY = content - view
		local cp = scrollFrame.CanvasPosition
		local canvasY = (cp and cp.Y) or 0
		local ratio = (maxCanvasY > 0) and math.clamp(canvasY / maxCanvasY, 0, 1) or 0
		thumb.Size = UDim2.new(1, 0, 0, thumbH)
		thumb.Position = UDim2.new(0, 0, 0, math.floor(maxThumbY * ratio))
	end

	scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScroll)
	scrollFrame:GetPropertyChangedSignal("CanvasSize"):Connect(updateScroll)
	scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)

	local scrollDragging, scrollDragOffsetY = false, 0
	local function scrollToTrackLocalY(localY)
		local view = absSize(scrollFrame).Y
		local content = (scrollFrame.CanvasSize and scrollFrame.CanvasSize.Y.Offset) or 0
		if content <= view + 1 then return end
		local maxThumbY = absSize(track).Y - absSize(thumb).Y
		local y = math.clamp(localY - scrollDragOffsetY, 0, maxThumbY)
		scrollFrame.CanvasPosition = Vector2.new(0, (maxThumbY > 0) and ((y / maxThumbY) * (content - view)) or 0)
	end

	win:_track(thumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = true
			scrollDragOffsetY = i.Position.Y - absPos(thumb).Y
		end
	end))
	win:_track(trackHit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = true
			scrollDragOffsetY = absSize(thumb).Y / 2
			scrollToTrackLocalY(i.Position.Y - absPos(track).Y)
		end
	end))
	win:_track(UserInputService.InputChanged:Connect(function(i)
		if scrollDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			scrollToTrackLocalY(i.Position.Y - absPos(track).Y)
		end
	end))
	win:_track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = false
		end
	end))

	task.delay(0.1, updateScroll)
	return updateScroll
end

-- Scrollbar horizontal para la barra de tabs (track abajo, estilo RR)
local function applyTabScroll(win, tabContainer, tabBar)
	local track = Create("Frame", {
		Name = "Track_Tabs",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.95,
		Position = UDim2.new(0, 10, 1, -6),
		Size = UDim2.new(1, -20, 0, 4),
		ZIndex = 5,
		Active = true,
		Parent = tabBar,
	})
	Round(99, track)

	local thumb = Create("Frame", {
		Name = "Thumb",
		BackgroundColor3 = Color3.fromRGB(200, 200, 200),
		BackgroundTransparency = 0.55,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 8,
		Parent = track,
	})
	Round(99, thumb)

	local trackHit = Create("TextButton", {
		Name = "TrackHit",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 7,
		Active = true,
		Parent = track,
	})

	local function updateScroll()
		track.Position = UDim2.new(0, 10, 1, -6)
		track.Size = UDim2.new(1, -20, 0, 4)
		local view = absSize(tabContainer).X
		local content = (tabContainer.CanvasSize and tabContainer.CanvasSize.X.Offset) or 0
		local overflow = view > 0 and content > view + 1
		track.Visible = overflow
		thumb.Visible = overflow
		if not overflow then return end

		local trackW = absSize(track).X
		local thumbW = math.max(26, math.floor(trackW * (view / content)))
		local maxThumbX = trackW - thumbW
		local maxCanvasX = content - view
		local cp = tabContainer.CanvasPosition
		local canvasX = (cp and cp.X) or 0
		local ratio = (maxCanvasX > 0) and math.clamp(canvasX / maxCanvasX, 0, 1) or 0
		thumb.Size = UDim2.new(0, thumbW, 1, 0)
		thumb.Position = UDim2.new(0, math.floor(maxThumbX * ratio), 0, 0)
	end

	tabContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScroll)
	tabContainer:GetPropertyChangedSignal("CanvasSize"):Connect(updateScroll)
	tabContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScroll)

	local scrollDragging, scrollDragOffsetX = false, 0
	local function scrollToTrackLocalX(localX)
		local view = absSize(tabContainer).X
		local content = (tabContainer.CanvasSize and tabContainer.CanvasSize.X.Offset) or 0
		if content <= view + 1 then return end
		local maxThumbX = absSize(track).X - absSize(thumb).X
		local x = math.clamp(localX - scrollDragOffsetX, 0, maxThumbX)
		tabContainer.CanvasPosition = Vector2.new((maxThumbX > 0) and ((x / maxThumbX) * (content - view)) or 0, 0)
	end

	win:_track(thumb.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = true
			scrollDragOffsetX = i.Position.X - absPos(thumb).X
		end
	end))
	win:_track(trackHit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = true
			scrollDragOffsetX = absSize(thumb).X / 2
			scrollToTrackLocalX(i.Position.X - absPos(track).X)
		end
	end))
	win:_track(UserInputService.InputChanged:Connect(function(i)
		if scrollDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			scrollToTrackLocalX(i.Position.X - absPos(track).X)
		end
	end))
	win:_track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			scrollDragging = false
		end
	end))

	task.delay(0.1, updateScroll)
	return updateScroll
end

-- ============================================================== filas
local function rightLabel(btn, text, color, width)
	width = width or 44
	return Create("TextLabel", {
		Name = "Right",
		Size = UDim2.new(0, width, 1, 0),
		Position = UDim2.new(1, -(width + 12), 0, 0),
		BackgroundTransparency = 1,
		Text = text or "",
		TextColor3 = color or COLOR.TEXT_DIM,
		FontFace = FONT_BOLD,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = btn,
	})
end

-- Fila base (TextButton) con su etiqueta a la izquierda.
-- rightPad deja espacio para la etiqueta derecha (evita que los textos se pisen)
local function makeRow(parent, order, name, height, rightPad)
	local btn = Create("TextButton", {
		Name = name or "Row",
		Size = UDim2.new(1, 0, 0, height or ROW_H),
		BackgroundColor3 = COLOR.ROW,
		BackgroundTransparency = ROW_TRANSPARENCY,
		Text = "",
		AutoButtonColor = false,
		FontFace = FONT_MED,
		TextSize = 12,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Round(ROW_RADIUS, btn)

	local label = Create("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -(rightPad or 24), 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = name or "",
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_MED,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = btn,
	})
	return btn, label
end

-- Hover / press manual (AutoButtonColor = false siempre)
-- getState() -> { base = Color3, hover = Color3, press = Color3 }
local function bindRowHover(btn, getState)
	btn.MouseEnter:Connect(function()
		Tween(btn, { BackgroundColor3 = getState().hover }, FAST, Enum.EasingStyle.Quart)
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, { BackgroundColor3 = getState().base }, FAST, Enum.EasingStyle.Quart)
	end)
	btn.MouseButton1Down:Connect(function()
		Tween(btn, { BackgroundColor3 = getState().press }, FAST, Enum.EasingStyle.Quart)
	end)
	btn.MouseButton1Up:Connect(function()
		Tween(btn, { BackgroundColor3 = getState().hover }, FAST, Enum.EasingStyle.Quart)
	end)
end

-- Contenedor de buscador (fondo 20,20,20 transparencia 0.78, esquina 8)
local function makeSearchBox(parent, opts, order)
	local container = Create("Frame", {
		Name = "Search",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 0.78,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Round(ROW_RADIUS, container)

	local box = Create("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = (opts and opts.placeholder) or "Buscar...",
		PlaceholderColor3 = COLOR.TEXT_DIM,
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_MED,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = container,
	})
	return container, box
end

-- Fila de lista/dropdown: icono 26px + nombre (+ @usuario opcional)
local function buildListRow(parent, item, opts, order, isSelected, onSelect)
	local h = item.subtitle and 40 or ROW_H
	local btn = Create("TextButton", {
		Name = "Item_" .. tostring(item.id),
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = isSelected and COLOR.ROW_SEL or COLOR.ROW,
		BackgroundTransparency = 0.25,
		Text = "",
		AutoButtonColor = false,
		FontFace = FONT_MED,
		LayoutOrder = order,
		Parent = parent,
	})
	Round(ROW_RADIUS, btn)

	local textX = 12
	local icon = resolveIcon(item, opts)
	if icon then
		local img = Create("ImageLabel", {
			Name = "Thumb",
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(0, 6, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			Image = icon,
			Parent = btn,
		})
		Circle(img)
		textX = 38
	end

	if item.subtitle then
		Create("TextLabel", {
			Name = "Name",
			Size = UDim2.new(1, -(textX + 12), 0, 14),
			Position = UDim2.new(0, textX, 0, 5),
			BackgroundTransparency = 1,
			Text = tostring(item.name),
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_MED,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})
		Create("TextLabel", {
			Name = "Sub",
			Size = UDim2.new(1, -(textX + 12), 0, 12),
			Position = UDim2.new(0, textX, 0, 21),
			BackgroundTransparency = 1,
			Text = tostring(item.subtitle),
			TextColor3 = COLOR.TEXT_DIM,
			FontFace = FONT_MED,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})
	else
		Create("TextLabel", {
			Name = "Name",
			Size = UDim2.new(1, -(textX + 12), 0, 16),
			Position = UDim2.new(0, textX, 0.5, -8),
			BackgroundTransparency = 1,
			Text = tostring(item.name),
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_MED,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})
	end

	bindRowHover(btn, function()
		return {
			base = isSelected and COLOR.ROW_SEL or COLOR.ROW,
			hover = COLOR.ROW_HOVER,
			press = COLOR.ROW_PRESS,
		}
	end)

	btn.MouseButton1Click:Connect(function()
		onSelect(item, btn)
	end)
	return btn
end

-- ============================================================== pagina
local Page = {}
Page.__index = Page

function Page:_nextOrder()
	self.order = self.order + 1
	return self.order
end

function Page:_refresh()
	local win = self.window
	task.defer(function()
		if win and not win.destroyed and self.UpdateScroll then
			self.UpdateScroll()
		end
	end)
end

function Page:AddSection(opts)
	opts = opts or {}
	local label = Create("TextLabel", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = string.upper(tostring(opts.name or opts.text or "Seccion")),
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_BOLD,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	return {
		Frame = label,
		SetText = function(t) label.Text = string.upper(tostring(t)) end,
	}
end

function Page:AddLabel(opts)
	opts = opts or {}
	local label = Create("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = tostring(opts.text or opts.name or ""),
		TextColor3 = opts.color or COLOR.TEXT_DIM,
		FontFace = FONT_MED,
		TextSize = opts.textSize or 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	return {
		Frame = label,
		SetText = function(t) label.Text = tostring(t) end,
	}
end

function Page:AddButton(opts)
	opts = opts or {}
	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, opts.height, opts.value and 56 or nil)
	if opts.value then
		rightLabel(btn, tostring(opts.value), COLOR.TEXT_DIM)
	end
	bindRowHover(btn, function()
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end)
	btn.MouseButton1Click:Connect(function()
		if opts.callback then opts.callback(btn) end
	end)
	self:_refresh()
	return {
		Frame = btn,
		SetText = function(t) label.Text = tostring(t) end,
		SetValue = function(v)
			local rl = btn:FindFirstChild("Right")
			if rl then rl.Text = tostring(v) end
		end,
	}
end

function Page:AddToggle(opts)
	opts = opts or {}
	local value = (opts.default == true)
	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, ROW_H, 56)
	local state = rightLabel(btn, value and "ON" or "OFF", value and COLOR.TEXT or COLOR.TEXT_DIM)

	local getState
	getState = function()
		if value then
			return { base = COLOR.ACCENT, hover = Color3.fromRGB(115, 115, 115), press = Color3.fromRGB(85, 85, 85) }
		end
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end
	bindRowHover(btn, getState)

	local function apply(v, fire)
		if value == v then return end
		value = v
		Tween(btn, { BackgroundColor3 = getState().base }, FAST, Enum.EasingStyle.Quart)
		state.Text = value and "ON" or "OFF"
		Tween(state, { TextColor3 = value and COLOR.TEXT or COLOR.TEXT_DIM }, FAST, Enum.EasingStyle.Quart)
		if fire and opts.callback then opts.callback(value) end
	end

	btn.MouseButton1Click:Connect(function()
		apply(not value, true)
	end)

	self:_refresh()
	return {
		Frame = btn,
		Get = function() return value end,
		Set = function(v) apply(v == true, false) end,
	}
end

function Page:AddSlider(opts)
	opts = opts or {}
	local minV = tonumber(opts.min) or 0
	local maxV = tonumber(opts.max) or 100
	if maxV < minV then minV, maxV = maxV, minV end
	local step = opts.step
	if step == nil then
		if minV % 1 == 0 and maxV % 1 == 0 then step = 1 end
	end
	local fmt = opts.format
	if not fmt then
		fmt = function(v)
			if step and step < 1 then return string.format("%.2f", v) end
			if math.floor(v + 0.0001) == v then return tostring(math.floor(v)) end
			return string.format("%.1f", v)
		end
	end

	local order = self:_nextOrder()
	local holder = Create("Frame", {
		Name = "Slider",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = self.Scroll,
	})

	Create("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -70, 0, 14),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(opts.name or ""),
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_MED,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = holder,
	})

	local valueLabel = Create("TextLabel", {
		Name = "Value",
		Size = UDim2.new(0, 56, 0, 14),
		Position = UDim2.new(1, -68, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_BOLD,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})

	-- track: fondo transparente (nunca se tween-a) + fill + knob
	local track = Create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -24, 0, 5),
		Position = UDim2.new(0, 12, 1, -16),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = holder,
	})
	Circle(track)

	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLOR.TEXT,
		Parent = track,
	})
	Circle(fill)

	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 11, 0, 11),
		Position = UDim2.new(1, -5, 0.5, 0),
		BackgroundColor3 = COLOR.TEXT,
		Parent = fill,
	})
	Circle(knob)

	-- hitbox invisible mas alta que la barra: NUNCA entra al fade
	local hit = Create("TextButton", {
		Name = "KnobHit",
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.new(0, 12, 1, -21),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 6,
		Parent = holder,
	})

	local value = math.clamp(tonumber(opts.default) or minV, minV, maxV)
	local dragging = false

	local function render()
		local range = (maxV - minV)
		local pct = range ~= 0 and ((value - minV) / range) or 0
		pct = math.clamp(pct, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		valueLabel.Text = fmt(value)
	end

	local function setValue(v, fire)
		v = math.clamp(v, minV, maxV)
		if step then
			v = math.floor((v - minV) / step + 0.5) * step + minV
			v = math.clamp(v, minV, maxV)
		end
		local changed = (v ~= value)
		value = v
		render()
		if fire and changed and opts.callback then opts.callback(value) end
	end

	local function applyFromInput(input)
		local w = absSize(track).X
		if w <= 0 then return end
		local pct = math.clamp((input.Position.X - absPos(track).X) / w, 0, 1)
		setValue(minV + pct * (maxV - minV), true)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			applyFromInput(input)
		end
	end)
	self.window:_track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyFromInput(input)
		end
	end))
	self.window:_track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then dragging = false end
		end
	end))

	render()
	self:_refresh()
	return {
		Frame = holder,
		Get = function() return value end,
		Set = function(v) setValue(tonumber(v) or value, false) end,
	}
end

function Page:AddKeybind(opts)
	opts = opts or {}
	local win = self.window
	local key = toKeyCode(opts.default)
	local binding = false
	local skipGameProcessed = opts.skipGameProcessed
	if skipGameProcessed == nil then skipGameProcessed = true end

	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, ROW_H, 60)
	local keyLabel = rightLabel(btn, shortKey(key), COLOR.TEXT_DIM, 48)
	keyLabel.TextSize = 9

	local function refresh()
		keyLabel.Text = shortKey(key)
		keyLabel.TextColor3 = COLOR.TEXT_DIM
	end
	refresh()

	-- accion: se dispara al presionar la tecla
	self.window:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if binding or win.destroyed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if key == nil or input.KeyCode ~= key then return end
		if processed and skipGameProcessed then return end
		if opts.callback then opts.callback(key) end
	end))

	bindRowHover(btn, function()
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end)

	-- Reasignar: espera con timeout de 30s, sin dejar ningun hilo colgado.
	-- Escape cancela y conserva la tecla anterior.
	btn.MouseButton1Click:Connect(function()
		if binding then return end
		binding = true
		keyLabel.Text = "..."
		win:SetBindPrompt("Press a key...")

		local finished = false
		local conn
		local function finish(newKey)
			if finished then return end
			finished = true
			if conn then pcall(function() conn:Disconnect() end) end
			binding = false
			if win.destroyed then return end
			win:SetBindPrompt("")
			if newKey then
				key = newKey
				refresh()
				if opts.onBind then opts.onBind(key) end
			else
				refresh()
			end
		end

		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if input.KeyCode == Enum.KeyCode.Escape then
				finish(nil)
				return
			end
			finish(input.KeyCode)
		end)
		win:_track(conn)
		task.delay(30, function() finish(nil) end)
	end)

	self:_refresh()
	return {
		Frame = btn,
		Get = function() return key end,
		Set = function(k)
			key = toKeyCode(k)
			refresh()
		end,
	}
end

function Page:AddSearchBox(opts)
	opts = opts or {}
	local win = self.window
	local root = Create("Frame", {
		Name = "SearchBox",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	local _, box = makeSearchBox(root, opts, 1)

	local version = 0
	local function fire()
		if opts.callback then opts.callback(box.Text) end
	end
	connectTextChanged(box, function()
		version = version + 1
		local v = version
		task.delay(0.35, function()
			if v == version and not win.destroyed then fire() end
		end)
	end)

	self:_refresh()
	return {
		Frame = root,
		GetText = function() return box.Text end,
		SetText = function(t) box.Text = tostring(t) end,
		Box = box,
	}
end

-- Lista con buscador (filas 36-40px, icono 26px, @usuario opcional)
function Page:AddList(opts)
	opts = opts or {}
	local win = self.window
	local page = self
	local order = self:_nextOrder()
	local maxHeight = tonumber(opts.maxHeight) or 0
	local selectedId = nil
	local items = normalizeItems(opts.items)

	local root = Create("Frame", {
		Name = "List",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = self.Scroll,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = root,
	})

	if opts.name then
		Create("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Text = tostring(opts.name),
			TextColor3 = COLOR.TEXT_DIM,
			FontFace = FONT_MED,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Parent = root,
		})
	end

	local _, box = makeSearchBox(root, opts, 2)

	-- host de filas: con maxHeight tiene su propio scroll (scrollbar RR),
	-- sin maxHeight crece con el contenido y hace scroll la pagina
	local rowsHost, rowsParent, isScroll, updateRowsScroll
	if maxHeight > 0 then
		rowsHost = Create("Frame", {
			Name = "Rows",
			Size = UDim2.new(1, 0, 0, maxHeight),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 3,
			Parent = root,
		})
		local sf = Create("ScrollingFrame", {
			Name = "RowsScroll",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 0,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			CanvasPosition = Vector2.new(0, 0),
			ClipsDescendants = true,
			ZIndex = 2,
			Parent = rowsHost,
		})
		Create("UIPadding", { PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 7), Parent = sf })
		rowsParent = sf
		isScroll = true
		updateRowsScroll = applyVerticalScroll(win, sf, rowsHost, 0, 0)
	else
		rowsHost = Create("Frame", {
			Name = "Rows",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = root,
		})
		rowsParent = rowsHost
		isScroll = false
	end

	local rowsLayout = Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rowsParent,
	})
	rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if isScroll then
			rowsParent.CanvasSize = UDim2.new(0, 0, 0, contentHeight(rowsLayout) + 8)
		end
	end)

	local token = 0
	local rowFrames = {}
	local rowItems = {}

	local function markSelected()
		for i = 1, #rowFrames do
			local f = rowFrames[i]
			if f and f.Parent then
				local it = rowItems[i]
				f.BackgroundColor3 = (it and it.id == selectedId) and COLOR.ROW_SEL or COLOR.ROW
			end
		end
	end

	local function choose(item, btn)
		selectedId = item.id
		markSelected()
		if opts.callback then opts.callback(item, btn) end
	end

	local function render()
		token = token + 1
		local myToken = token
		for _, c in ipairs(rowsParent:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		rowFrames = {}
		rowItems = {}

		local query = box.Text
		local visible = {}
		for i = 1, #items do
			if itemMatches(items[i], query) then
				visible[#visible + 1] = items[i]
			end
		end

		-- carga por lotes para listas grandes (checklist de rendimiento)
		local idx = 1
		local BATCH = 25
		local function buildChunk()
			if myToken ~= token or win.destroyed then return end
			local n = 0
			while idx <= #visible and n < BATCH do
				local item = visible[idx]
				local btn = buildListRow(rowsParent, item, opts, idx,
					item.id == selectedId, choose)
				rowFrames[#rowFrames + 1] = btn
				rowItems[#rowItems + 1] = item
				idx = idx + 1
				n = n + 1
			end
			if updateRowsScroll then updateRowsScroll() end
			if idx <= #visible then
				task.defer(buildChunk)
			elseif not win.destroyed then
				page:_refresh()
			end
		end
		buildChunk()
	end

	connectTextChanged(box, function()
		token = token + 1
		local v = token
		task.delay(0.35, function()
			if v == token and not win.destroyed then render() end
		end)
	end)

	render()
	self:_refresh()

	return {
		Frame = root,
		Get = function() return selectedId end,
		Set = function(id)
			selectedId = id
			markSelected()
		end,
		SetItems = function(list)
			items = normalizeItems(list)
			render()
		end,
		Refresh = render,
		Box = box,
	}
end

-- Dropdown: boton que despliega panel con buscador + lista (scroll propio)
function Page:AddDropdown(opts)
	opts = opts or {}
	local win = self.window
	local page = self
	local maxHeight = tonumber(opts.maxHeight) or 240
	local selectedId = nil
	local items = normalizeItems(opts.items)
	local open = false

	local root = Create("Frame", {
		Name = "Dropdown",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = root,
	})

	local trigger, triggerLabel = makeRow(root, 1, opts.name, ROW_H, 74)
	trigger.LayoutOrder = 1
	local valueLabel = rightLabel(trigger, "", COLOR.TEXT_DIM, 58)
	local arrow = Create("TextLabel", {
		Name = "Arrow",
		Size = UDim2.new(0, 14, 1, 0),
		Position = UDim2.new(1, -20, 0, 0),
		BackgroundTransparency = 1,
		Text = "v",
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_BOLD,
		TextSize = 10,
		Parent = trigger,
	})

	local panel = Create("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 0.78,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = root,
	})
	Round(ROW_RADIUS, panel)

	local _, box = makeSearchBox(panel, opts, 1)
	box.Position = UDim2.new(0, 10, 0, 6)
	box.Size = UDim2.new(1, -20, 0, 20)

	local listScroll = Create("ScrollingFrame", {
		Name = "ListScroll",
		Size = UDim2.new(1, -16, 1, -40),
		Position = UDim2.new(0, 8, 0, 34),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		CanvasPosition = Vector2.new(0, 0),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = panel,
	})
	local rowsLayout = Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = listScroll,
	})
	rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight(rowsLayout) + 8)
	end)
	local updateRowsScroll = applyVerticalScroll(win, listScroll, panel, 34, 6)

	local token = 0
	local rowFrames = {}
	local rowItems = {}

	local function markSelected()
		for i = 1, #rowFrames do
			local f = rowFrames[i]
			if f and f.Parent then
				local it = rowItems[i]
				f.BackgroundColor3 = (it and it.id == selectedId) and COLOR.ROW_SEL or COLOR.ROW
			end
		end
	end

	local function refreshValue()
		local found = nil
		for i = 1, #items do
			if items[i].id == selectedId then found = items[i] break end
		end
		valueLabel.Text = found and tostring(found.name) or ""
		triggerLabel.Text = tostring(opts.name or "")
	end

	local function choose(item)
		selectedId = item.id
		refreshValue()
		markSelected()
		if opts.callback then opts.callback(item) end
		panel.Size = UDim2.new(1, 0, 0, 0)
		open = false
		arrow.Text = "v"
	end

	local function render()
		token = token + 1
		local myToken = token
		for _, c in ipairs(listScroll:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		rowFrames = {}
		rowItems = {}

		local query = box.Text
		local visible = {}
		for i = 1, #items do
			if itemMatches(items[i], query) then
				visible[#visible + 1] = items[i]
			end
		end

		local idx = 1
		local BATCH = 25
		local function buildChunk()
			if myToken ~= token or win.destroyed then return end
			local n = 0
			while idx <= #visible and n < BATCH do
				local item = visible[idx]
				local btn = buildListRow(listScroll, item, opts, idx,
					item.id == selectedId, choose)
				rowFrames[#rowFrames + 1] = btn
				rowItems[#rowItems + 1] = item
				idx = idx + 1
				n = n + 1
			end
			updateRowsScroll()
			if idx <= #visible then
				task.defer(buildChunk)
			end
		end
		buildChunk()
		if not win.destroyed then page:_refresh() end
	end

	connectTextChanged(box, function()
		token = token + 1
		local v = token
		task.delay(0.35, function()
			if v == token and not win.destroyed then render() end
		end)
	end)

	trigger.MouseButton1Click:Connect(function()
		open = not open
		arrow.Text = open and "^" or "v"
		local target = 0
		if open then
			local rows = math.min(#items, 5)
			target = math.clamp(40 + rows * 40 + 6, 0, maxHeight)
		end
		Tween(panel, { Size = UDim2.new(1, 0, 0, target) }, 0.25, Enum.EasingStyle.Quart)
		if open then
			task.defer(updateRowsScroll)
		end
	end)

	bindRowHover(trigger, function()
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end)

	refreshValue()
	render()
	self:_refresh()

	return {
		Frame = root,
		Get = function() return selectedId end,
		Set = function(id)
			selectedId = id
			refreshValue()
			markSelected()
		end,
		SetItems = function(list)
			items = normalizeItems(list)
			render()
		end,
		Refresh = render,
		Box = box,
	}
end

-- ============================================================== pagina (creacion)
local function makePage(win, name, parent)
	local self = setmetatable({ window = win, name = name, order = 0 }, Page)

	local group = Create("Frame", {
		Name = "Page_" .. name,
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		Parent = parent,
	})

	local scroll = Create("ScrollingFrame", {
		Name = name .. "_Scroll",
		Size = UDim2.new(1, -(SCROLL_W + SCROLL_GAP), 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		CanvasPosition = Vector2.new(0, 0),
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = group,
	})
	Create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), Parent = scroll })

	local layout = Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight(layout) + 10)
	end)

	self.Group = group
	self.Scroll = scroll
	self.Layout = layout
	self.UpdateScroll = applyVerticalScroll(win, scroll, group, 0, 10)
	return self
end

-- ============================================================== ventana
local Window = {}
Window.__index = Window

function Window:_track(conn)
	if conn then table.insert(self._connections, conn) end
	return conn
end

function Window:_disconnectAll()
	for _, c in ipairs(self._connections) do
		pcall(function() c:Disconnect() end)
	end
	self._connections = {}
end

function Window:SetBindPrompt(text)
	if self.destroyed then return end
	self.BindPrompt.Text = tostring(text or "")
end

-- Fade uniforme: Body (CanvasGroup) + DropShadow. Nada mas se tween-a, asi
-- que los contenedores transparentes y las hitboxes jamas generan recuadros.
function Window:SetVisible(show)
	if self.destroyed or self.visible == show then return end
	self.visible = show
	self._fadeVersion = (self._fadeVersion or 0) + 1
	local version = self._fadeVersion

	if show then
		self.MainFrame.Visible = true
	end
	Tween(self.Body, { GroupTransparency = show and 0 or 1 }, FADE_TIME)
	Tween(self.DropShadow, { ImageTransparency = show and 0.60 or 1 }, FADE_TIME)

	if not show then
		task.delay(FADE_TIME, function()
			if version == self._fadeVersion and not self.visible and not self.destroyed then
				self.MainFrame.Visible = false
			end
		end)
	end
end

function Window:Show()
	self:SetVisible(true)
end

function Window:Hide()
	self:SetVisible(false)
end

function Window:SetTitle(text)
	if self.destroyed then return end
	self.Title.Text = tostring(text)
end

function Window:ToggleMinimize()
	if self.destroyed or not self.visible then return end
	if self._dragTween then
		pcall(function() self._dragTween:Cancel() end)
		self._dragTween = nil
	end

	self.minimized = not self.minimized
	local info = TweenInfo.new(FAST, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	if self.minimized then
		self.MinIcon.Text = "+"
		self.ContentArea.Visible = false
		TweenService:Create(self.MainFrame, info, { Size = self.minSize }):Play()
	else
		self.MinIcon.Text = "-"
		local t = TweenService:Create(self.MainFrame, info, { Size = self.fullSize })
		t:Play()
		t.Completed:Connect(function()
			if not self.minimized and not self.destroyed then
				self.ContentArea.Visible = true
			end
		end)
	end
end

-- Cerrar: primero la logica del script, luego desconectar, luego fade, luego destroy
function Window:Destroy()
	if self.destroyed then return end

	if self.onClose then pcall(self.onClose) end
	if self._dragTween then pcall(function() self._dragTween:Cancel() end) end
	self:_disconnectAll()
	self:SetVisible(false)
	self.destroyed = true

	if self._singletonKey then
		_G[self._singletonKey] = nil
		_G[self._singletonKey .. "_Cleanup"] = nil
		self._singletonKey = nil
	end

	task.delay(FADE_TIME + 0.05, function()
		if self.ScreenGui and self.ScreenGui.Parent then
			self.ScreenGui:Destroy()
		end
	end)
end

function Window:Close()
	self:Destroy()
end

-- ============================================================== arrastre
function Window:_clampPosition(x, y)
	local screen = absSize(self.ScreenGui)
	local frame = absSize(self.MainFrame)
	local minX, maxX = frame.X / 2, screen.X - (frame.X / 2)
	local minY, maxY = 0, screen.Y - frame.Y
	if minX > maxX then minX, maxX = maxX, minX end
	if minY > maxY then minY, maxY = maxY, minY end
	return UDim2.new(0, math.clamp(x, minX, maxX), 0, math.clamp(y, minY, maxY))
end

function Window:_dragBegan(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if self._dragTween then
		pcall(function() self._dragTween:Cancel() end)
		self._dragTween = nil
	end
	if self._dragging then return end

	self._dragging = true
	self._dragStart = input.Position

	local screen = absSize(self.ScreenGui)
	local curX = (self.MainFrame.Position.X.Scale * screen.X) + self.MainFrame.Position.X.Offset
	local curY = (self.MainFrame.Position.Y.Scale * screen.Y) + self.MainFrame.Position.Y.Offset
	self._dragStartPos = UDim2.new(0, curX, 0, curY)
	self._lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
	self._dragVelocity = Vector2.new(0, 0)
end

function Window:_dragChanged(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		self._dragInput = input
	end
end

function Window:_dragMove(input)
	local screen = absSize(self.ScreenGui)
	local curX = (self.MainFrame.Position.X.Scale * screen.X) + self.MainFrame.Position.X.Offset
	local curY = (self.MainFrame.Position.Y.Scale * screen.Y) + self.MainFrame.Position.Y.Offset

	local currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
	self._dragVelocity = Vector2.new(
		currentMousePos.X - self._lastMousePos.X,
		currentMousePos.Y - self._lastMousePos.Y
	)
	self._lastMousePos = currentMousePos

	local delta = Vector2.new(input.Position.X - self._dragStart.X, input.Position.Y - self._dragStart.Y)
	self.MainFrame.Position = self:_clampPosition(
		self._dragStartPos.X.Offset + delta.X,
		self._dragStartPos.Y.Offset + delta.Y
	)
end

-- Al soltar: deslizamiento x1.8 con tween 0.45 Quart (inercia)
function Window:_dragEnd()
	local screen = absSize(self.ScreenGui)
	local curX = (self.MainFrame.Position.X.Scale * screen.X) + self.MainFrame.Position.X.Offset
	local curY = (self.MainFrame.Position.Y.Scale * screen.Y) + self.MainFrame.Position.Y.Offset
	local mult = 1.8
	local safe = self:_clampPosition(
		curX + (self._dragVelocity.X * mult),
		curY + (self._dragVelocity.Y * mult)
	)
	self._dragTween = Tween(self.MainFrame, { Position = safe }, 0.45, Enum.EasingStyle.Quart)
end

-- ============================================================== tabs
function Window:_layoutPages()
	local hasTabs = self._tabsShown
	for i = 1, #self._pages do
		local page = self._pages[i]
		if hasTabs then
			page.Group.Position = UDim2.new(0, 10, 0, 40)
			page.Group.Size = UDim2.new(1, -20, 1, -50)
		else
			page.Group.Position = UDim2.new(0, 10, 0, 10)
			page.Group.Size = UDim2.new(1, -20, 1, -20)
		end
		if page.UpdateScroll then page.UpdateScroll() end
	end
end

function Window:_moveIndicator(btn, animate)
	if not btn then return end
	local relX = absPos(btn).X - absPos(self.TabBar).X
	local w = absSize(btn).X
	if w <= 0 or relX < 0 then return end
	local goal = {
		Position = UDim2.new(0, math.floor(relX), 1, -8),
		Size = UDim2.new(0, math.floor(w), 0, 2),
	}
	if animate then
		Tween(self.Indicator, goal, 0.25, Enum.EasingStyle.Quart)
	else
		self.Indicator.Position = goal.Position
		self.Indicator.Size = goal.Size
	end
end

function Window:_autoScrollTo(btn)
	local view = absSize(self.TabContainer).X
	local content = (self.TabContainer.CanvasSize and self.TabContainer.CanvasSize.X.Offset) or 0
	if view <= 0 or content <= view + 1 then return end
	local rel = absPos(btn).X - absPos(self.TabContainer).X + ((self.TabContainer.CanvasPosition and self.TabContainer.CanvasPosition.X) or 0)
	local w = absSize(btn).X
	local target = math.clamp(rel - ((view - w) / 2), 0, content - view)
	Tween(self.TabContainer, { CanvasPosition = Vector2.new(target, 0) }, 0.25, Enum.EasingStyle.Quart)
end

function Window:_selectTab(tab)
	if self._selectedTab == tab then return end
	self._selectedTab = tab
	for i = 1, #self._tabs do
		local t = self._tabs[i]
		local active = (t == tab)
		t.Button.TextColor3 = active and COLOR.TEXT or COLOR.TAB_IDLE
		t.Page.Group.Visible = active
	end
	self:_moveIndicator(tab.Button, true)
	self:_autoScrollTo(tab.Button)
	task.defer(function()
		if not self.destroyed and tab.Page.UpdateScroll then tab.Page.UpdateScroll() end
	end)
end

function Window:CreateTab(name)
	name = tostring(name or ("Tab " .. (#self._tabs + 1)))
	local page

	if not self._tabsShown then
		-- primera pestaña: la pagina por defecto se adopta como su contenido
		self._tabsShown = true
		self.TabBar.Visible = true
		page = self._defaultPage
		self:_layoutPages()
	else
		page = makePage(self, name, self.ContentArea)
		table.insert(self._pages, page)
	end

	local order = #self._tabs + 1
	local btn = Create("TextButton", {
		Name = "Tab_" .. name,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLOR.ROW,
		BackgroundTransparency = 1,
		Text = string.upper(name),
		TextColor3 = COLOR.TAB_IDLE,
		FontFace = FONT_MED,
		TextSize = 12,
		AutoButtonColor = false,
		LayoutOrder = order,
		ZIndex = 4,
		Parent = self.TabContainer,
	})
	Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = btn })

	btn.MouseEnter:Connect(function()
		if self._selectedTab and self._selectedTab.Button == btn then return end
		Tween(btn, { TextColor3 = COLOR.TEXT }, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		if self._selectedTab and self._selectedTab.Button == btn then return end
		Tween(btn, { TextColor3 = COLOR.TAB_IDLE }, 0.12)
	end)

	local tab = { Name = name, Button = btn, Page = page, window = self }
	function tab:AddSection(o) return page:AddSection(o) end
	function tab:AddLabel(o) return page:AddLabel(o) end
	function tab:AddButton(o) return page:AddButton(o) end
	function tab:AddToggle(o) return page:AddToggle(o) end
	function tab:AddSlider(o) return page:AddSlider(o) end
	function tab:AddKeybind(o) return page:AddKeybind(o) end
	function tab:AddSearchBox(o) return page:AddSearchBox(o) end
	function tab:AddList(o) return page:AddList(o) end
	function tab:AddDropdown(o) return page:AddDropdown(o) end
	function tab:Select() self.window:_selectTab(tab) end

	table.insert(self._tabs, tab)
	btn.MouseButton1Click:Connect(function()
		self:_selectTab(tab)
	end)

	-- la pagina nueva (y cualquier otra) respeta el layout con tabs
	self:_layoutPages()

	if not self._selectedTab then
		self:_selectTab(tab)
	end
	return tab
end

-- ============================================================== elementos
-- (delegados a la pagina por defecto: sirven con o sin tabs)
function Window:AddSection(o) return self._defaultPage:AddSection(o) end
function Window:AddLabel(o) return self._defaultPage:AddLabel(o) end
function Window:AddButton(o) return self._defaultPage:AddButton(o) end
function Window:AddToggle(o) return self._defaultPage:AddToggle(o) end
function Window:AddSlider(o) return self._defaultPage:AddSlider(o) end
function Window:AddKeybind(o) return self._defaultPage:AddKeybind(o) end
function Window:AddSearchBox(o) return self._defaultPage:AddSearchBox(o) end
function Window:AddList(o) return self._defaultPage:AddList(o) end
function Window:AddDropdown(o) return self._defaultPage:AddDropdown(o) end

-- Fila que reasigna la tecla para mostrar/ocultar la ventana
function Window:AddUIBind(opts)
	opts = opts or {}
	return self._defaultPage:AddKeybind({
		name = opts.name or "Menu",
		default = self.UIBind,
		onBind = function(key) self:SetUIBind(key) end,
	})
end

function Window:SetUIBind(key)
	self.UIBind = toKeyCode(key)
end

function Window:GetUIBind()
	return self.UIBind
end

-- ============================================================== CreateWindow
local function GetSafeParent()
	local ok, parent = pcall(function()
		if gethui then return gethui() end
		return CoreGui
	end)
	if not ok or not parent then
		return LocalPlayer:WaitForChild("PlayerGui")
	end
	return parent
end

-- Tamaño responsivo (IA-skill): 270x480 en escritorio, clamp en móvil
local function calcSizes(opts)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local isSmall = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or math.min(vp.X, vp.Y) < 700)
	if isSmall then
		local w = math.clamp(math.floor(opts.width or (vp.X * 0.6)), 200, 240)
		local h = math.clamp(math.floor(opts.height or (vp.Y * 0.85)), 280, 420)
		return UDim2.new(0, w, 0, h), UDim2.new(0, w, 0, HEADER_H)
	end
	local w = math.floor(tonumber(opts.width) or 270)
	local h = math.floor(tonumber(opts.height) or 480)
	return UDim2.new(0, w, 0, h), UDim2.new(0, w, 0, HEADER_H)
end

function FlowLib:CreateWindow(opts)
	opts = opts or {}
	local title = tostring(opts.title or "Flow")
	local fullSize, minSize = calcSizes(opts)
	local guiName = tostring(opts.name or ("FlowLib_" .. title:gsub("%W", "_")))
	local parent = GetSafeParent()

	-- destruye la ventana anterior con el mismo nombre (re-ejecución limpia)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == guiName then
			child:Destroy()
		end
	end

	local win = setmetatable({
		opts = opts,
		onClose = opts.onClose,
		fullSize = fullSize,
		minSize = minSize,
		guiName = guiName,
		_connections = {},
		pages = {},
		_pages = {},
		tabs = {},
		_tabs = {},
		visible = false,
		destroyed = false,
		minimized = false,
		_tabsShown = false,
		_selectedTab = nil,
		_fadeVersion = 0,
		_dragging = false,
		_dragVelocity = Vector2.new(0, 0),
		_dragStart = Vector2.new(0, 0),
		_lastMousePos = Vector2.new(0, 0),
		_dragStartPos = UDim2.new(0, 0, 0, 0),
		UIBind = toKeyCode(opts.keybind),
	}, Window)

	-- ------------------------------------------------------------ ScreenGui
	local ScreenGui = Create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	win.ScreenGui = ScreenGui

	-- MainFrame: solo maneja posición/tamaño/arrastre
	local MainFrame = Create("Frame", {
		Name = "MainFrame",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = fullSize,
		Position = UDim2.new(0.5, 0, 0.5, -math.floor(fullSize.Y.Offset / 2)),
		BackgroundColor3 = COLOR.BG,
		BackgroundTransparency = 1,
		ZIndex = 10,
		ClipsDescendants = false,
		Parent = ScreenGui,
	})
	Round(CORNER_RADIUS, MainFrame)
	win.MainFrame = MainFrame

	-- La sombra vive fuera del CanvasGroup para poder salirse del borde
	local DropShadow = Create("ImageLabel", {
		Name = "DropShadow",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, -20, 0, -20),
		Size = UDim2.new(1, 40, 1, 40),
		ZIndex = 1,
		Image = "rbxassetid://6015897843",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(25, 25, 475, 475),
		Parent = MainFrame,
	})
	win.DropShadow = DropShadow

	-- Body: CanvasGroup que contiene TODO lo visual. Su GroupTransparency es
	-- el fade global (un solo tween, cero recuadros grises).
	local Body = Create("CanvasGroup", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = COLOR.BG,
		BackgroundTransparency = 0.25,
		GroupTransparency = 1,
		ZIndex = 10,
		Parent = MainFrame,
	})
	Round(CORNER_RADIUS, Body)
	win.Body = Body

	local WindowStroke = Create("UIStroke", {
		Name = "WindowStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = COLOR.STROKE,
		Thickness = 1.2,
		Transparency = 0.3,
		Parent = Body,
	})
	Create("UIGradient", { Rotation = -22, Transparency = STROKE_GRADIENT, Parent = WindowStroke })
	win.WindowStroke = WindowStroke

	local GlassBackdrop = Create("ImageLabel", {
		Name = "GlassBackdrop",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://10849683935",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.5,
		ZIndex = 11,
		Parent = Body,
	})
	Round(CORNER_RADIUS, GlassBackdrop)
	win.GlassBackdrop = GlassBackdrop

	local Title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -90, 0, HEADER_H),
		Position = UDim2.new(0, 15, 0, 0),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_BOLD,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Active = true,
		ZIndex = 15,
		Parent = Body,
	})
	win.Title = Title

	local BindPrompt = Create("TextLabel", {
		Name = "BindPrompt",
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.new(0, 10, 0, 30),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(220, 220, 220),
		FontFace = FONT_MED,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 15,
		Parent = Body,
	})
	win.BindPrompt = BindPrompt

	-- Area de arrastre: ancho completo menos 90px (nunca tapa los botones)
	local DragArea = Create("TextButton", {
		Name = "DragArea",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, -90, 0, HEADER_H),
		ZIndex = 13,
		Active = true,
		Parent = Body,
	})
	win.DragArea = DragArea

	-- Botones circulares 26x26 (estilo RR)
	local function createWindowButton(name, iconText, posX, hoverColor)
		local btn = Create("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(1, posX, 0, HEADER_H / 2),
			BackgroundColor3 = COLOR.TEXT,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 15,
			Parent = Body,
		})
		Circle(btn)

		local stroke = Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = COLOR.STROKE,
			Thickness = 1.2,
			Transparency = 0.3,
			Parent = btn,
		})
		Create("UIGradient", { Rotation = -22, Transparency = STROKE_GRADIENT, Parent = stroke })

		local icon = Create("TextLabel", {
			Name = "Icon",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = iconText,
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_BOLD,
			TextSize = (iconText == "-") and 18 or 12,
			ZIndex = 16,
			Parent = btn,
		})

		btn.MouseEnter:Connect(function()
			if not win.visible then return end
			Tween(btn, { BackgroundTransparency = 0.85 }, FAST, Enum.EasingStyle.Quart)
			Tween(stroke, { Color = COLOR.TEXT, Transparency = 0 }, FAST, Enum.EasingStyle.Quart)
			if hoverColor then
				Tween(icon, { TextColor3 = hoverColor }, FAST, Enum.EasingStyle.Quart)
			end
		end)
		btn.MouseLeave:Connect(function()
			if not win.visible then return end
			Tween(btn, { BackgroundTransparency = 1 }, FAST, Enum.EasingStyle.Quart)
			Tween(stroke, { Color = COLOR.STROKE, Transparency = 0.3 }, FAST, Enum.EasingStyle.Quart)
			if hoverColor then
				Tween(icon, { TextColor3 = COLOR.TEXT }, FAST, Enum.EasingStyle.Quart)
			end
		end)
		btn.MouseButton1Down:Connect(function()
			Tween(btn, { Size = UDim2.new(0, 23, 0, 23) }, FAST, Enum.EasingStyle.Quart)
		end)
		btn.MouseButton1Up:Connect(function()
			Tween(btn, { Size = UDim2.new(0, 26, 0, 26) }, FAST, Enum.EasingStyle.Quart)
		end)
		return btn, icon
	end

	local MinimizeBtn, MinIcon = createWindowButton("MinimizeBtn", "-", -60, nil)
	local CloseBtn, CloseIcon = createWindowButton("CloseBtn", "X", -25, COLOR.DANGER)
	win.MinimizeBtn = MinimizeBtn
	win.MinIcon = MinIcon
	win.CloseBtn = CloseBtn
	win.CloseIcon = CloseIcon

	local ContentArea = Create("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, 0, 1, -HEADER_H),
		Position = UDim2.new(0, 0, 0, HEADER_H),
		BackgroundTransparency = 1,
		ZIndex = 12,
		ClipsDescendants = true,
		Parent = Body,
	})
	win.ContentArea = ContentArea

	-- ------------------------------------------------------------ tabs
	local TabBar = Create("Frame", {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 35),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Visible = false,
		Parent = ContentArea,
	})
	win.TabBar = TabBar

	local TabContainer = Create("ScrollingFrame", {
		Name = "TabContainer",
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		CanvasPosition = Vector2.new(0, 0),
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = TabBar,
	})
	win.TabContainer = TabContainer

	local TabListLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = TabContainer,
	})
	TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TabContainer.CanvasSize = UDim2.new(0, contentHeight(TabListLayout) + 4, 0, 0)
	end)

	applyTabScroll(win, TabContainer, TabBar)

	local Indicator = Create("Frame", {
		Name = "Indicator",
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = COLOR.TEXT,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = TabBar,
	})
	Circle(Indicator)
	win.Indicator = Indicator

	TabContainer:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if win._selectedTab then win:_moveIndicator(win._selectedTab.Button, false) end
	end)

	-- ------------------------------------------------------------ paginas
	local defaultPage = makePage(win, "Main", ContentArea)
	defaultPage.Group.Visible = true
	win._defaultPage = defaultPage
	win.defaultPage = defaultPage
	table.insert(win._pages, defaultPage)

	-- ------------------------------------------------------------ arrastre
	Title.InputBegan:Connect(function(i) win:_dragBegan(i) end)
	Title.InputChanged:Connect(function(i) win:_dragChanged(i) end)
	DragArea.InputBegan:Connect(function(i) win:_dragBegan(i) end)
	DragArea.InputChanged:Connect(function(i) win:_dragChanged(i) end)

	win:_track(UserInputService.InputChanged:Connect(function(input)
		if input == win._dragInput and win._dragging then
			win:_dragMove(input)
		end
	end))
	win:_track(UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and win._dragging then
			win._dragging = false
			win:_dragEnd()
		end
	end))

	-- ------------------------------------------------------------ botones
	MinimizeBtn.MouseButton1Click:Connect(function()
		win:ToggleMinimize()
	end)
	CloseBtn.MouseButton1Click:Connect(function()
		win:Destroy()
	end)

	-- ------------------------------------------------------------ bind de la UI
	-- Se conecta siempre: si no hay tecla inicial, AddUIBind() puede asignarla
	-- despues y el listener ya esta escuchando.
	win:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if win.destroyed or not win.UIBind then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode ~= win.UIBind then return end
		if processed and opts.skipGameProcessedUI then return end
		win:SetVisible(not win.visible)
	end))

	-- ------------------------------------------------------------ singleton
	if pendingSingleton then
		win._singletonKey = pendingSingleton
		_G[pendingSingleton .. "_Cleanup"] = function()
			win:Destroy()
		end
		pendingSingleton = nil
	end

	-- arranque: todo invisible y luego fade in (0.3s)
	task.delay(0.05, function()
		if not win.destroyed then win:SetVisible(true) end
	end)

	return win
end

return FlowLib
