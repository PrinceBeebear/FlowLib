local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local FlowLib = {}
FlowLib.Version = "1.3.0"

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

local function contentHeight(layout)
	local cs = layout and layout.AbsoluteContentSize
	if cs and cs.Y then return cs.Y end
	return 0
end

local function contentWidth(layout)
	local cs = layout and layout.AbsoluteContentSize
	if cs and cs.X then return cs.X end
	return 0
end

local COLOR = {
	BG        = Color3.fromRGB(12, 12, 12),
	ROW       = Color3.fromRGB(30, 30, 30),
	ROW_HOVER = Color3.fromRGB(45, 45, 45),
	ROW_PRESS = Color3.fromRGB(22, 22, 22),
	TEXT      = Color3.fromRGB(255, 255, 255),
	TEXT_DIM  = Color3.fromRGB(175, 175, 175),
	STROKE    = Color3.fromRGB(210, 210, 225),
	BORDER    = Color3.fromRGB(72, 72, 72),
	GLOW      = Color3.fromRGB(205, 205, 205),
	ACCENT    = Color3.fromRGB(100, 100, 100),
	DANGER    = Color3.fromRGB(255, 60, 60),
	GOLD      = Color3.fromRGB(255, 215, 0),
	GREEN     = Color3.fromRGB(60, 180, 80),
	BLUE      = Color3.fromRGB(0, 170, 255),
	RED_BG    = Color3.fromRGB(45, 18, 18),
	FIELD     = Color3.fromRGB(20, 20, 20),
	TAB_IDLE  = Color3.fromRGB(160, 160, 160),
	ROW_SEL   = Color3.fromRGB(60, 60, 60),
}
FlowLib.Colors = COLOR

local CORNER_RADIUS       = 24
local ROW_RADIUS          = 8
local ROW_H               = 36
local ROW_TRANSPARENCY    = 0.3
local SIDE_MARGIN         = 10
local SCROLL_W            = 5
local SCROLL_GAP          = 8
local FADE_TIME           = 0.3
local FAST                = 0.15
local DROP_TIME           = 0.3
local DROP_CLOSE          = 0.22
local DROP_ROW_FADE       = 0.22
local DROP_STAGGER        = 0.035
local HEADER_H            = 38
local SAFE_TEXT_LIMIT     = 90000

local SHADOW_TRANSPARENCY = 0.55
local BAR_TRANSPARENCY    = 0.6
local DRAG_BAR_IN         = UDim2.new(0.5, 0, 0, 5)
local DRAG_BAR_OUT        = UDim2.new(0.5, 0, 0, -9)
local DRAG_BAR_SIZE       = UDim2.new(0, 72, 0, 5)
local DRAG_BAR_SIZE_HOVE  = UDim2.new(0, 88, 0, 7)

local KEYBIND_ICON = "rbxthumb://type=Asset&id=125168489828313&w=420&h=420"
local RESIZE_ICON  = "rbxthumb://type=Asset&id=82041111650203&w=420&h=420"
local STAR_ICON    = "rbxassetid://90412510481264"
local COPY_ICON    = "rbxassetid://95587165617428"

local STROKE_GRADIENT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(0.14, 1),
	NumberSequenceKeypoint.new(0.86, 1),
	NumberSequenceKeypoint.new(1, 0.4),
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
local FONT_CODE = Font.fromEnum(Enum.Font.Code)

FlowLib.Fonts = { Bold = FONT_BOLD, Medium = FONT_MED, Code = FONT_CODE }

local SHORT_KEYS = {
	LeftShift = "LS", RightShift = "RS",
	LeftControl = "LC", RightControl = "RC",
	LeftAlt = "LA", RightAlt = "RA",
	Space = "SP", Backspace = "BS", Return = "ENT",
	Escape = "ESC", Tab = "TAB", CapsLock = "CAPS",
}

local function keyNameOf(key)
	if key == nil then return "" end
	local n = key.Name
	if type(n) ~= "string" then
		n = tostring(key)
		n = n:match("%.([^.]+)$") or n
	end
	return n
end

local function shortKey(key)
	local name = keyNameOf(key)
	local mapped = SHORT_KEYS[name]
	if mapped then return mapped end
	return (#name <= 3) and name or name:sub(1, 3)
end

local function toKeyCode(v)
	if v == nil then return nil end
	if type(v) == "string" then
		local ok, code = pcall(function() return Enum.KeyCode[v] end)
		if ok then return code end
		return nil
	end
	return v
end

local function smartSearch(text, query)
	if not query or query == "" then return true end
	local lowerText = tostring(text or ""):lower()
	for word in query:lower():gmatch("%S+") do
		if not lowerText:find(word, 1, true) then
			return false
		end
	end
	return true
end

local function setSafeText(box, rawText)
	rawText = tostring(rawText or "")
	if #rawText > SAFE_TEXT_LIMIT then
		box.Text = rawText:sub(1, SAFE_TEXT_LIMIT) .. "\n-- [Truncated] --"
	else
		box.Text = rawText
	end
end

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

local function connectTextChanged(box, fn)
	box:GetPropertyChangedSignal("Text"):Connect(fn)
end

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
	local hay = tostring(item.name or "") .. " " .. tostring(item.subtitle or "") .. " " .. tostring(item.id or "")
	return smartSearch(hay, query)
end

local function applyVerticalScroll(win, scrollFrame, parentFrame, topOffset, bottomOffset, contentFn, reclaimWidth)
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
		if win.destroyed then return end
		local tOffset = type(topOffset) == "function" and topOffset() or topOffset
		local bOffset = type(bottomOffset) == "function" and bottomOffset() or (tonumber(bottomOffset) or 10)
		track.Position = UDim2.new(1, -(SIDE_MARGIN + SCROLL_W), 0, tOffset)
		track.Size = UDim2.new(0, SCROLL_W, 1, -(tOffset + bOffset))

		local view = absSize(scrollFrame).Y
		local content = contentFn and (contentFn() or 0)
			or (scrollFrame.CanvasSize and scrollFrame.CanvasSize.Y.Offset)
			or 0
		local overflow = view > 0 and content > view + 1
		track.Visible = overflow
		thumb.Visible = overflow
		if reclaimWidth then
			local wantOffset = overflow and -(SCROLL_W + SCROLL_GAP) or 0
			if scrollFrame.Size.X.Offset ~= wantOffset then
				scrollFrame.Size = UDim2.new(1, wantOffset, 1, 0)
			end
		end
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
	updateScroll()
	task.delay(0.1, updateScroll)

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

local function applyTabScroll(win, tabContainer, tabBar)
	local track = Create("Frame", {
		Name = "Track_Tabs",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.95,
		Position = UDim2.new(0, 18, 1, -6),
		Size = UDim2.new(1, -28, 0, 4),
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
		track.Position = UDim2.new(0, 18, 1, -6)
		track.Size = UDim2.new(1, -28, 0, 4)
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
		Position = UDim2.new(0, 10, 0, 0),
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
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
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

	local textX = 14
	local icon = resolveIcon(item, opts)
	if icon then
		local img = Create("ImageLabel", {
			Name = "Thumb",
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(0, 8, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			Image = icon,
			Parent = btn,
		})
		Circle(img)
		textX = 40
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
		SetColor = function(c) label.TextColor3 = c or COLOR.TEXT_DIM end,
	}
end

function Page:AddButton(opts)
	opts = opts or {}
	local rightW = opts.rightWidth or 80
	local hasRight = (opts.value ~= nil) or (opts.status ~= nil)
	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, opts.height, hasRight and (rightW + 16) or nil)
	local rl = nil
	if hasRight then
		rl = rightLabel(btn, tostring(opts.value or opts.status or ""), opts.statusColor or COLOR.TEXT_DIM, rightW)
	end
	local baseCol = opts.color or COLOR.ROW
	btn.BackgroundColor3 = baseCol
	bindRowHover(btn, function()
		return { base = baseCol, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end)
	local ctrl = {
		Frame = btn,
		SetText = function(t) label.Text = tostring(t) end,
		SetColor = function(c)
			baseCol = c or COLOR.ROW
			btn.BackgroundColor3 = baseCol
		end,
		SetValue = function(v, col)
			if not rl then rl = rightLabel(btn, "", col or COLOR.TEXT_DIM, rightW) end
			rl.Text = tostring(v)
			if col then rl.TextColor3 = col end
		end,
	}
	btn.MouseButton1Click:Connect(function()
		if opts.callback then opts.callback(ctrl, btn) end
	end)
	self:_refresh()
	return ctrl
end

local function waitForKey(win, onKey)
	local finished = false
	local conn
	local function finish(newKey, sourceInput)
		if finished then return end
		finished = true
		if conn then pcall(function() conn:Disconnect() end) end
		onKey(newKey, sourceInput)
	end
	conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
			finish(nil, input)
			return
		end
		finish(input.KeyCode, input)
	end)
	win:_track(conn)
	task.delay(30, function() finish(nil) end)
end

function Page:AddToggle(opts)
	opts = opts or {}
	local value = (opts.default == true)
	local key = toKeyCode(opts.keybind)
	local skipProc = opts.skipGameProcessed
	if skipProc == nil then skipProc = true end
	local transparent = (opts.transparent == true)
	local win = self.window
	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, ROW_H, key and 128 or 68)
	if transparent then btn.BackgroundTransparency = 1 end

	local switch = Create("Frame", {
		Name = "Switch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 56, 0, 26),
		Position = UDim2.new(1, -40, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(60, 60, 60),
		BorderSizePixel = 0,
		Parent = btn,
	})
	Round(13, switch)

	Create("UIShadow", {
		Name = "SwitchShadow",
		BlurRadius = UDim.new(0, 8),
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 0.72,
		Offset = UDim2.new(0, 0, 0, 0),
		ShowBehindParent = false,
		Parent = switch,
	})

	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 32, 0, 20),
		Position = UDim2.new(0, 19, 0.5, 0),
		BackgroundColor3 = COLOR.TEXT,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = switch,
	})
	local knobCorner = Round(10, knob)

	local lens = Create("UIStroke", {
		Name = "Lens",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = COLOR.TEXT,
		Thickness = 1.4,
		Transparency = 1,
		Parent = knob,
	})

	local keyBtn, keyLabel, bindIcon, binding, lastBindSet = nil, nil, nil, false, nil
	if key or opts.allowBind then
		keyBtn = Create("TextButton", {
			Name = "KeyBtn",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 52, 1, -12),
			Position = UDim2.new(1, -98, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(48, 48, 48),
			BackgroundTransparency = 0,
			Text = "",
			AutoButtonColor = false,
			Parent = btn,
		})
		Round(12, keyBtn)
		keyBtn.MouseEnter:Connect(function()
			Tween(keyBtn, { BackgroundColor3 = Color3.fromRGB(66, 66, 66) }, FAST, Enum.EasingStyle.Quart)
		end)
		keyBtn.MouseLeave:Connect(function()
			Tween(keyBtn, { BackgroundColor3 = Color3.fromRGB(48, 48, 48) }, FAST, Enum.EasingStyle.Quart)
		end)
		bindIcon = Create("ImageLabel", {
			Name = "BindIcon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 24, 0, 18),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 1,
			Image = KEYBIND_ICON,
			ImageRectOffset = Vector2.new(15, 68),
			ImageRectSize = Vector2.new(390, 284),
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = COLOR.TEXT_DIM,
			ImageTransparency = 0.1,
			Parent = keyBtn,
		})
		keyLabel = Create("TextLabel", {
			Name = "Key",
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.new(0, 4, 0, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = COLOR.TEXT_DIM,
			FontFace = FONT_BOLD,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = keyBtn,
		})
	end

	local function renderBind()
		if not keyBtn then return end
		if binding then
			bindIcon.Visible = false
			keyLabel.Visible = true
			keyLabel.Text = "..."
		elseif key then
			bindIcon.Visible = false
			keyLabel.Visible = true
			keyLabel.Text = shortKey(key)
		else
			bindIcon.Visible = true
			keyLabel.Visible = false
			keyLabel.Text = ""
		end
	end
	renderBind()

	local getState
	getState = function()
		if value then
			return { base = COLOR.ACCENT, hover = Color3.fromRGB(115, 115, 115), press = Color3.fromRGB(85, 85, 85) }
		end
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end
	if not transparent then bindRowHover(btn, getState) end

	local function trackColor()
		if value then return Color3.fromRGB(150, 150, 150) end
		return Color3.fromRGB(60, 60, 60)
	end

	local function apply(v, fire)
		if value == v then return end
		value = v
		Tween(btn, { BackgroundColor3 = getState().base }, FAST, Enum.EasingStyle.Quart)
		Tween(switch, { BackgroundColor3 = trackColor() }, FAST, Enum.EasingStyle.Quart)
		Tween(knob, { Position = UDim2.new(0, value and 37 or 19, 0.5, 0) }, FAST, Enum.EasingStyle.Quart)
		if fire and opts.callback then opts.callback(value) end
	end

	switch.BackgroundColor3 = trackColor()
	if value then
		knob.Position = UDim2.new(0, 37, 0.5, 0)
	end

	btn.MouseButton1Click:Connect(function()
		apply(not value, true)
	end)

	local function setLens(on)
		Tween(knob, {
			BackgroundTransparency = on and 0.5 or 0.15,
			Size = on and UDim2.new(0, 36, 0, 24) or UDim2.new(0, 32, 0, 20),
		}, FAST, Enum.EasingStyle.Quart)
		knobCorner.CornerRadius = UDim.new(0, on and 12 or 10)
		Tween(lens, { Transparency = on and 0.1 or 1, Thickness = on and 2 or 1.4 }, FAST, Enum.EasingStyle.Quart)
	end
	btn.MouseButton1Down:Connect(function() setLens(true) end)
	btn.MouseButton1Up:Connect(function() setLens(false) end)
	btn.MouseLeave:Connect(function() setLens(false) end)
	win:_track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setLens(false)
		end
	end))

	if keyBtn then
		win:_track(UserInputService.InputBegan:Connect(function(input, processed)
			if binding then return end
			if lastBindSet and os.clock() - lastBindSet < 0.2 then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if key == nil or input.KeyCode ~= key then return end
			if processed and skipProc then return end
			apply(not value, true)
		end))

		keyBtn.MouseButton1Click:Connect(function()
			if binding then return end
			if key ~= nil then
				key = nil
				if opts.onBind then pcall(opts.onBind, nil) end
				renderBind()
				return
			end
			binding = true
			renderBind()
			waitForKey(win, function(newKey)
				binding = false
				if win.destroyed then return end
				if newKey then
					key = newKey
					lastBindSet = os.clock()
					if opts.onBind then opts.onBind(key) end
				end
				renderBind()
			end)
		end)
	end

	self:_refresh()
	return {
		Frame = btn,
		Get = function() return value end,
		Set = function(v) apply(v == true, false) end,
		Toggle = function() apply(not value, true) end,
		GetKey = function() return key end,
		SetKey = function(k)
			key = toKeyCode(k)
			renderBind()
		end,
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
		Size = UDim2.new(1, -72, 0, 14),
		Position = UDim2.new(0, 14, 0, 0),
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

	local track = Create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -28, 0, 6),
		Position = UDim2.new(0, 14, 1, -17),
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		BackgroundTransparency = 0,
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

	Create("UIShadow", {
		Name = "FillGlow",
		BlurRadius = UDim.new(0, 5),
		Color = COLOR.TEXT,
		Transparency = 0.5,
		Offset = UDim2.new(0, 0, 0, 0),
		ShowBehindParent = false,
		Parent = fill,
	})

	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 20, 0, 12),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = COLOR.TEXT,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = track,
	})
	Circle(knob)

	Create("UIShadow", {
		Name = "KnobShadow",
		BlurRadius = UDim.new(0, 5),
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 0.62,
		Offset = UDim2.new(0, 0, 0, 0),
		ShowBehindParent = false,
		Parent = knob,
	})

	local lens = Create("UIStroke", {
		Name = "Lens",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = COLOR.TEXT,
		Thickness = 1.4,
		Transparency = 1,
		Parent = knob,
	})

	local hit = Create("TextButton", {
		Name = "KnobHit",
		Size = UDim2.new(1, -4, 0, 22),
		Position = UDim2.new(0, 2, 1, -21),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 6,
		Parent = holder,
	})

	local value = math.clamp(tonumber(opts.default) or minV, minV, maxV)
	local dragging = false
	local knobTween, fillTween

	local function render()
		local range = (maxV - minV)
		local pct = range ~= 0 and ((value - minV) / range) or 0
		pct = math.clamp(pct, 0, 1)
		if knobTween then pcall(function() knobTween:Cancel() end) end
		if fillTween then pcall(function() fillTween:Cancel() end) end
		knobTween = Tween(knob, { Position = UDim2.new(pct, 0, 0.5, 0) }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		fillTween = Tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
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
			Tween(knob, { BackgroundTransparency = 0.5, Size = UDim2.new(0, 26, 0, 16) }, FAST, Enum.EasingStyle.Quart)
			Tween(lens, { Transparency = 0.1, Thickness = 2 }, FAST, Enum.EasingStyle.Quart)
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
			Tween(knob, { BackgroundTransparency = 0, Size = UDim2.new(0, 20, 0, 12) }, FAST, Enum.EasingStyle.Quart)
			Tween(lens, { Transparency = 1, Thickness = 1.4 }, FAST, Enum.EasingStyle.Quart)
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
	local lastBindSet = nil
	local skipGameProcessed = opts.skipGameProcessed
	if skipGameProcessed == nil then skipGameProcessed = true end

	local btn, label = makeRow(self.Scroll, self:_nextOrder(), opts.name, ROW_H, 82)

	local bindIcon = Create("ImageLabel", {
		Name = "BindIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 24, 0, 18),
		Position = UDim2.new(1, -53, 0.5, 0),
		BackgroundTransparency = 1,
		Image = KEYBIND_ICON,
		ImageRectOffset = Vector2.new(15, 68),
		ImageRectSize = Vector2.new(390, 284),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = COLOR.TEXT_DIM,
		Parent = btn,
	})

	local keyLabel = rightLabel(btn, "", COLOR.TEXT_DIM, 44)
	keyLabel.TextSize = 11

	local function refresh()
		keyLabel.TextColor3 = COLOR.TEXT_DIM
		if binding then
			bindIcon.Visible = false
			keyLabel.Text = "..."
		elseif key then
			bindIcon.Visible = false
			keyLabel.Text = shortKey(key)
		else
			bindIcon.Visible = true
			keyLabel.Text = ""
		end
	end
	refresh()

	self.window:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if binding or win.destroyed then return end
		if lastBindSet and os.clock() - lastBindSet < 0.2 then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if key == nil or input.KeyCode ~= key then return end
		if processed and skipGameProcessed then return end
		if opts.callback then opts.callback(key) end
	end))

	bindRowHover(btn, function()
		return { base = COLOR.ROW, hover = COLOR.ROW_HOVER, press = COLOR.ROW_PRESS }
	end)

	btn.MouseButton1Click:Connect(function()
		if binding then return end
		if key ~= nil then
			key = nil
			if opts.onBind then pcall(opts.onBind, nil) end
			refresh()
			return
		end
		binding = true
		refresh()
		waitForKey(win, function(newKey)
			binding = false
			if win.destroyed then return end
			if newKey then
				key = newKey
				lastBindSet = os.clock()
				if opts.onBind then opts.onBind(key) end
			end
			refresh()
		end)
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
		task.delay(0.2, function()
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

	local rowsHost, rowsParent, isScroll, updateRowsScroll, rowsLayout
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
		updateRowsScroll = applyVerticalScroll(win, sf, rowsHost, 0, 0, function()
			return contentHeight(rowsLayout)
		end)
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

	rowsLayout = Create("UIListLayout", {
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

local function hideListRow(btn)
	btn.BackgroundTransparency = 1
	for _, d in ipairs(btn:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextBox") then
			d.TextTransparency = 1
		elseif d:IsA("ImageLabel") then
			d.ImageTransparency = 1
			d.BackgroundTransparency = 1
		end
	end
end

local function fadeListRow(btn, delay)
	task.delay(delay, function()
		if not btn.Parent then return end
		Tween(btn, { BackgroundTransparency = 0.25 }, DROP_ROW_FADE, Enum.EasingStyle.Quart)
		for _, d in ipairs(btn:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextBox") then
				Tween(d, { TextTransparency = 0 }, DROP_ROW_FADE, Enum.EasingStyle.Quart)
			elseif d:IsA("ImageLabel") then
				Tween(d, { ImageTransparency = 0, BackgroundTransparency = 0 }, DROP_ROW_FADE, Enum.EasingStyle.Quart)
			end
		end
	end)
end

function Page:AddDropdown(opts)
	opts = opts or {}
	local win = self.window
	local page = self
	local maxHeight = tonumber(opts.maxHeight) or 240
	local selectedId = (opts.default ~= nil) and opts.default or nil
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
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = root,
	})
	Round(ROW_RADIUS, panel)

	local _, box = makeSearchBox(panel, opts, 1)
	box.Position = UDim2.new(0, 12, 0, 6)
	box.Size = UDim2.new(1, -24, 0, 20)

	local listScroll = Create("ScrollingFrame", {
		Name = "ListScroll",
		Size = UDim2.new(1, -16, 1, -40),
		Position = UDim2.new(0, 10, 0, 34),
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
	local updateRowsScroll = applyVerticalScroll(win, listScroll, panel, 34, 6, function()
		return contentHeight(rowsLayout)
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

	local function refreshValue()
		local found = nil
		for i = 1, #items do
			if items[i].id == selectedId then found = items[i] break end
		end
		valueLabel.Text = found and tostring(found.name) or ""
		triggerLabel.Text = tostring(opts.name or "")
	end

	local function setOpen(nowOpen)
		open = nowOpen
		local target = 0
		if open then
			local rows = math.min(#items, 5)
			target = math.clamp(40 + rows * 40 + 6, 0, maxHeight)
		end
		local dur = open and DROP_TIME or DROP_CLOSE
		Tween(panel, { Size = UDim2.new(1, 0, 0, target) }, dur, Enum.EasingStyle.Quart)
		Tween(panel, { BackgroundTransparency = open and 0.78 or 1 }, dur, Enum.EasingStyle.Quart)
		Tween(arrow, { Rotation = open and 180 or 0 }, dur, Enum.EasingStyle.Quart)
		if open then
			for i = 1, #rowFrames do
				local btn = rowFrames[i]
				if btn and btn.Parent then
					hideListRow(btn)
					fadeListRow(btn, math.min(i * DROP_STAGGER, 0.35))
				end
			end
			task.defer(updateRowsScroll)
		end
	end

	local function choose(item)
		selectedId = item.id
		refreshValue()
		markSelected()
		if opts.callback then opts.callback(item) end
		setOpen(false)
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
				if open then
					hideListRow(btn)
					fadeListRow(btn, math.min(idx * DROP_STAGGER, 0.35))
				end
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
		setOpen(not open)
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

function Page:AddVirtualList(opts)
	opts = opts or {}
	local win = self.window
	local order = self:_nextOrder()
	local rowH = tonumber(opts.rowHeight) or 34
	local gap = 4
	local stepY = rowH + gap
	local listHeight = tonumber(opts.height) or 260

	local root = Create("Frame", {
		Name = "VirtualList",
		Size = UDim2.new(1, 0, 0, listHeight + (opts.searchable ~= false and 36 or 0)),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = self.Scroll,
	})

	local box
	local topOffset = 0
	if opts.searchable ~= false then
		local searchContainer
		searchContainer, box = makeSearchBox(root, opts, 1)
		searchContainer.Position = UDim2.new(0, 0, 0, 0)
		topOffset = 36
	end

	local host = Create("Frame", {
		Name = "RowsHost",
		Size = UDim2.new(1, 0, 1, -topOffset),
		Position = UDim2.new(0, 0, 0, topOffset),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	})

	local sf = Create("ScrollingFrame", {
		Name = "VirtualScroll",
		Size = UDim2.new(1, -(SCROLL_W + SCROLL_GAP), 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ClipsDescendants = true,
		Parent = host,
	})

	local updateScroll = applyVerticalScroll(win, sf, host, 0, 0, function()
		return sf.CanvasSize.Y.Offset
	end, true)

	local allItems = opts.items or {}
	local filtered = {}
	local materialized = {}
	local activeId = opts.activeId
	local filterFn = opts.filterFn

	local function styleRow(btn, item)
		local isPlaying = (activeId ~= nil and item.id == activeId)
		btn.BackgroundColor3 = isPlaying and COLOR.GREEN or COLOR.ROW
		local star = btn:FindFirstChild("FavBtn")
		if star then
			star.ImageColor3 = item.fav and COLOR.GOLD or COLOR.TEXT_DIM
		end
		local bindBtn = btn:FindFirstChild("BindBtn")
		if bindBtn then
			local bIcon = bindBtn:FindFirstChild("Icon")
			local bTxt = bindBtn:FindFirstChild("Txt")
			local clrBtn = btn:FindFirstChild("ClearBindBtn")
			if item.bind then
				if bIcon then bIcon.Visible = false end
				if bTxt then bTxt.Visible = true; bTxt.Text = shortKey(toKeyCode(item.bind)) end
				if clrBtn then clrBtn.Visible = true end
			else
				if bIcon then bIcon.Visible = true end
				if bTxt then bTxt.Visible = false end
				if clrBtn then clrBtn.Visible = false end
			end
		end
	end

	local function createRowAt(idx)
		if materialized[idx] or not filtered[idx] then return end
		local item = filtered[idx]

		local btn = Create("TextButton", {
			Name = "VRow_" .. idx,
			Size = UDim2.new(1, -4, 0, rowH),
			Position = UDim2.new(0, 2, 0, (idx - 1) * stepY),
			BackgroundColor3 = (activeId == item.id) and COLOR.GREEN or COLOR.ROW,
			BackgroundTransparency = ROW_TRANSPARENCY,
			Text = "",
			AutoButtonColor = false,
			Parent = sf,
		})
		Round(ROW_RADIUS, btn)
		materialized[idx] = btn

		local rightX = -6
		local function nextRightPos(w)
			rightX = rightX - w
			local p = rightX
			rightX = rightX - 4
			return p
		end

		if opts.showDelete or item.canDelete then
			local delPos = nextRightPos(22)
			local delBtn = Create("TextButton", {
				Name = "DelBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 22, 0, 22),
				Position = UDim2.new(1, delPos, 0.5, 0),
				BackgroundColor3 = COLOR.DANGER,
				BackgroundTransparency = 0.25,
				Text = "X",
				TextColor3 = COLOR.TEXT,
				FontFace = FONT_BOLD,
				TextSize = 10,
				AutoButtonColor = false,
				Parent = btn,
			})
			Round(6, delBtn)
			delBtn.MouseButton1Click:Connect(function()
				if opts.onDelete then opts.onDelete(item) end
			end)
		end

		if opts.showLoad then
			local loadPos = nextRightPos(38)
			local loadBtn = Create("TextButton", {
				Name = "LoadBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 38, 0, 22),
				Position = UDim2.new(1, loadPos, 0.5, 0),
				BackgroundColor3 = COLOR.GREEN,
				BackgroundTransparency = 0.2,
				Text = "Load",
				TextColor3 = COLOR.TEXT,
				FontFace = FONT_BOLD,
				TextSize = 9,
				AutoButtonColor = false,
				Parent = btn,
			})
			Round(6, loadBtn)
			loadBtn.MouseButton1Click:Connect(function()
				if opts.onLoad then opts.onLoad(item) end
			end)
		end

		if opts.showCopy then
			local copyPos = nextRightPos(22)
			local copyBtn = Create("ImageButton", {
				Name = "CopyBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 22, 0, 22),
				Position = UDim2.new(1, copyPos, 0.5, 0),
				BackgroundColor3 = COLOR.FIELD,
				BackgroundTransparency = 0.2,
				Image = COPY_ICON,
				ImageColor3 = COLOR.TEXT_DIM,
				AutoButtonColor = false,
				Parent = btn,
			})
			Round(6, copyBtn)
			copyBtn.MouseButton1Click:Connect(function()
				if opts.onCopy then opts.onCopy(item, copyBtn) end
			end)
		end

		if opts.showBind ~= false then
			local bindPos = nextRightPos(34)
			local bindBtn = Create("TextButton", {
				Name = "BindBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 34, 0, 22),
				Position = UDim2.new(1, bindPos, 0.5, 0),
				BackgroundColor3 = COLOR.FIELD,
				BackgroundTransparency = 0.2,
				Text = "",
				AutoButtonColor = false,
				Parent = btn,
			})
			Round(6, bindBtn)

			local bIcon = Create("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, 18, 0, 14),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				Image = KEYBIND_ICON,
				ImageRectOffset = Vector2.new(15, 68),
				ImageRectSize = Vector2.new(390, 284),
				ImageColor3 = COLOR.TEXT_DIM,
				Parent = bindBtn,
			})
			local bTxt = Create("TextLabel", {
				Name = "Txt",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = COLOR.BLUE,
				FontFace = FONT_BOLD,
				TextSize = 9,
				Visible = false,
				Parent = bindBtn,
			})

			local clrPos = nextRightPos(16)
			local clrBtn = Create("TextButton", {
				Name = "ClearBindBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 16, 0, 18),
				Position = UDim2.new(1, clrPos, 0.5, 0),
				BackgroundColor3 = COLOR.DANGER,
				BackgroundTransparency = 0.3,
				Text = "x",
				TextColor3 = COLOR.TEXT,
				FontFace = FONT_BOLD,
				TextSize = 9,
				Visible = false,
				AutoButtonColor = false,
				Parent = btn,
			})
			Round(4, clrBtn)

			bindBtn.MouseButton1Click:Connect(function()
				bIcon.Visible = false
				bTxt.Visible = true
				bTxt.Text = ".."
				waitForKey(win, function(newKey)
					if newKey then
						item.bind = newKey
						if opts.onBindChanged then opts.onBindChanged(item, newKey) end
					end
					styleRow(btn, item)
				end)
			end)

			clrBtn.MouseButton1Click:Connect(function()
				item.bind = nil
				if opts.onBindChanged then opts.onBindChanged(item, nil) end
				styleRow(btn, item)
			end)
		end

		if opts.showFav ~= false then
			local favPos = nextRightPos(22)
			local favBtn = Create("ImageButton", {
				Name = "FavBtn",
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(1, favPos, 0.5, 0),
				BackgroundTransparency = 1,
				Image = STAR_ICON,
				ImageColor3 = item.fav and COLOR.GOLD or COLOR.TEXT_DIM,
				Parent = btn,
			})
			favBtn.MouseButton1Click:Connect(function()
				item.fav = not item.fav
				styleRow(btn, item)
				if opts.onFavChanged then opts.onFavChanged(item, item.fav) end
			end)
		end

		Create("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, rightX - 12, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			BackgroundTransparency = 1,
			Text = tostring(item.name or item.id),
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_MED,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = btn,
		})

		styleRow(btn, item)

		btn.MouseButton1Click:Connect(function()
			if opts.onSelect then opts.onSelect(item, btn) end
		end)
	end

	local function materializeVisible()
		if #filtered == 0 then return end
		local scrollY = sf.CanvasPosition.Y
		local viewH = math.max(absSize(sf).Y, listHeight)
		local firstIdx = math.max(1, math.floor(scrollY / stepY))
		local lastVisible = math.min(#filtered, math.ceil((scrollY + viewH) / stepY) + 20)

		for i = firstIdx, lastVisible do
			createRowAt(i)
		end
	end

	local function rebuild()
		for _, r in pairs(materialized) do
			if r and r.Parent then r:Destroy() end
		end
		materialized = {}
		filtered = {}

		local q = box and box.Text or ""
		for i = 1, #allItems do
			local it = allItems[i]
			local passTab = (not filterFn) or filterFn(it)
			if passTab and smartSearch(it.name or it.id, q) then
				filtered[#filtered + 1] = it
			end
		end

		sf.CanvasSize = UDim2.new(0, 0, 0, #filtered * stepY)
		materializeVisible()
		updateScroll()
	end

	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(materializeVisible)

	if box then
		local debounceV = 0
		connectTextChanged(box, function()
			debounceV = debounceV + 1
			local myV = debounceV
			task.delay(0.15, function()
				if myV == debounceV and not win.destroyed then
					sf.CanvasPosition = Vector2.new(0, 0)
					rebuild()
				end
			end)
		end)
	end

	rebuild()
	self:_refresh()

	return {
		Frame = root,
		Scroll = sf,
		Box = box,
		SetItems = function(newItems)
			allItems = newItems or {}
			rebuild()
		end,
		SetFilter = function(fn)
			filterFn = fn
			rebuild()
		end,
		SetActive = function(id)
			activeId = id
			for idx, btn in pairs(materialized) do
				if filtered[idx] then styleRow(btn, filtered[idx]) end
			end
		end,
		Refresh = rebuild,
	}
end

function Page:AddInput(opts)
	opts = opts or {}
	local multiline = (opts.multiline == true)
	local h = tonumber(opts.height) or (multiline and 76 or 32)
	local rawValue = tostring(opts.default or "")

	local holder = Create("Frame", {
		Name = opts.name or "Input",
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 0.25,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	Round(ROW_RADIUS, holder)

	local box = Create("TextBox", {
		Name = "Box",
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.new(0, 10, 0, 5),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = opts.placeholder or "Escribe...",
		PlaceholderColor3 = COLOR.TEXT_DIM,
		TextColor3 = COLOR.TEXT,
		FontFace = multiline and FONT_CODE or FONT_MED,
		TextSize = multiline and 10 or 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		MultiLine = multiline,
		TextWrapped = multiline,
		ClearTextOnFocus = false,
		Parent = holder,
	})
	setSafeText(box, rawValue)

	box.FocusLost:Connect(function(enterPressed)
		if #box.Text <= SAFE_TEXT_LIMIT then
			rawValue = box.Text
		end
		if opts.callback then opts.callback(rawValue, enterPressed) end
	end)

	self:_refresh()
	return {
		Frame = holder,
		Box = box,
		Get = function() return rawValue end,
		Set = function(txt)
			rawValue = tostring(txt or "")
			setSafeText(box, rawValue)
		end,
	}
end

function Page:AddButtonRow(opts)
	opts = opts or {}
	local buttonsCfg = opts.buttons or {}
	local h = tonumber(opts.height) or 32
	local row = Create("Frame", {
		Name = "ButtonRow",
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})

	local count = math.max(1, #buttonsCfg)
	local gap = 6
	local controllers = {}

	for i = 1, count do
		local cfg = buttonsCfg[i]
		local btn = Create("TextButton", {
			Name = cfg.name or ("Btn_" .. i),
			Size = UDim2.new(1 / count, -math.floor((gap * (count - 1)) / count), 1, 0),
			Position = UDim2.new((i - 1) / count, math.floor((i - 1) * (gap / count)), 0, 0),
			BackgroundColor3 = cfg.color or COLOR.ROW,
			BackgroundTransparency = ROW_TRANSPARENCY,
			Text = tostring(cfg.text or cfg.name or "Button"),
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_BOLD,
			TextSize = tonumber(cfg.textSize) or 11,
			AutoButtonColor = false,
			Parent = row,
		})
		Round(ROW_RADIUS, btn)

		btn.MouseButton1Click:Connect(function()
			if cfg.callback then cfg.callback(controllers[i], btn) end
		end)

		controllers[i] = {
			Button = btn,
			SetText = function(t) btn.Text = tostring(t) end,
			SetColor = function(c) Tween(btn, { BackgroundColor3 = c or COLOR.ROW }, FAST) end,
		}
	end

	self:_refresh()
	return {
		Frame = row,
		Buttons = controllers,
	}
end

function Page:AddCollapsible(opts)
	opts = opts or {}
	local open = (opts.defaultOpen == true)
	local win = self.window
	local page = self

	local container = Create("Frame", {
		Name = opts.name or "Collapsible",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = open and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = open and 0.4 or 1,
		ClipsDescendants = true,
		Visible = open,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	Round(ROW_RADIUS, container)

	Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = container,
	})
	local layout = Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})

	local subPage = setmetatable({
		window = win,
		Scroll = container,
		Layout = layout,
		order = 0,
		UpdateScroll = function()
			if page.UpdateScroll then page.UpdateScroll() end
		end,
	}, Page)

	function subPage:SetOpen(state)
		open = (state == true)
		container.Visible = open
		container.AutomaticSize = open and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
		Tween(container, {
			BackgroundTransparency = open and 0.4 or 1,
			Size = open and UDim2.new(1, 0, 0, contentHeight(layout) + 12) or UDim2.new(1, 0, 0, 0),
		}, DROP_TIME, Enum.EasingStyle.Quart)
		page:_refresh()
	end

	function subPage:IsOpen()
		return open
	end

	return subPage
end

function Page:AddMultiSelectAccordion(opts)
	opts = opts or {}
	local items = opts.items or {}
	local selected = opts.selected or {}
	local open = false
	local maxH = tonumber(opts.maxHeight) or 150

	local root = Create("Frame", {
		Name = "MultiAccordion",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = root })

	local header, _ = makeRow(root, 1, opts.name or "Select Parts", ROW_H, 40)
	local arrow = rightLabel(header, ">", COLOR.TEXT_DIM, 20)

	local panel = Create("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = root,
	})
	Round(ROW_RADIUS, panel)

	local listScroll = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -14, 1, -8),
		Position = UDim2.new(0, 6, 0, 4),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})
	local listLayout = Create("UIListLayout", { Padding = UDim.new(0, 4), Parent = listScroll })
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		listScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight(listLayout) + 4)
	end)
	local updateSubScroll = applyVerticalScroll(self.window, listScroll, panel, 4, 4, function()
		return contentHeight(listLayout)
	end)

	local function rebuild(newList)
		if newList then items = newList end
		for _, c in ipairs(listScroll:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for i = 1, #items do
			local partName = tostring(items[i])
			local row, _ = makeRow(listScroll, i, partName, 28, 70)
			local status = rightLabel(row, "", COLOR.GREEN, 60)

			local function style()
				local isHidden = (selected[partName] == true)
				row.BackgroundColor3 = isHidden and COLOR.RED_BG or COLOR.ROW
				status.Text = isHidden and (opts.offText or "HIDDEN") or (opts.onText or "VISIBLE")
				status.TextColor3 = isHidden and COLOR.DANGER or COLOR.GREEN
			end
			style()

			row.MouseButton1Click:Connect(function()
				selected[partName] = not selected[partName]
				if not selected[partName] then selected[partName] = nil end
				style()
				if opts.callback then opts.callback(partName, selected[partName] == true, selected) end
			end)
		end
		updateSubScroll()
	end

	header.MouseButton1Click:Connect(function()
		open = not open
		arrow.Text = open and "v" or ">"
		if open and opts.onOpen then
			local dynamicItems = opts.onOpen()
			if dynamicItems then rebuild(dynamicItems) end
		end
		Tween(panel, {
			Size = UDim2.new(1, 0, 0, open and maxH or 0),
			BackgroundTransparency = open and 0.45 or 1,
		}, DROP_TIME, Enum.EasingStyle.Quart)
		self:_refresh()
	end)

	rebuild(items)
	self:_refresh()

	return {
		Frame = root,
		SetItems = rebuild,
		GetSelected = function() return selected end,
	}
end

function Page:AddStateCard(opts)
	opts = opts or {}
	local rawCode = tostring(opts.defaultCode or "")
	local card = Create("Frame", {
		Name = "StateCard_" .. tostring(opts.name or "State"),
		Size = UDim2.new(1, 0, 0, 152),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 0.35,
		LayoutOrder = self:_nextOrder(),
		Parent = self.Scroll,
	})
	Round(ROW_RADIUS, card)

	Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0.4, 0, 0, 18),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundTransparency = 1,
		Text = tostring(opts.name or "State"),
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_BOLD,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	local selLabel = Create("TextLabel", {
		Name = "Selected",
		Size = UDim2.new(0.55, -10, 0, 18),
		Position = UDim2.new(0.45, 0, 0, 6),
		BackgroundTransparency = 1,
		Text = "Selected: " .. tostring(opts.selectedName or "None"),
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_MED,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	local selectBtn = Create("TextButton", {
		Name = "SelectBtn",
		Size = UDim2.new(1, -76, 0, 26),
		Position = UDim2.new(0, 10, 0, 28),
		BackgroundColor3 = COLOR.ROW,
		BackgroundTransparency = 0.2,
		Text = "Select animation",
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_BOLD,
		TextSize = 10,
		AutoButtonColor = false,
		Parent = card,
	})
	Round(6, selectBtn)

	local clearBtn = Create("TextButton", {
		Name = "ClearBtn",
		Size = UDim2.new(0, 52, 0, 26),
		Position = UDim2.new(1, -62, 0, 28),
		BackgroundColor3 = COLOR.DANGER,
		BackgroundTransparency = 0.25,
		Text = "Clear",
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_BOLD,
		TextSize = 10,
		AutoButtonColor = false,
		Parent = card,
	})
	Round(6, clearBtn)

	local codeBox = Create("TextBox", {
		Name = "CodeBox",
		Size = UDim2.new(1, -20, 0, 84),
		Position = UDim2.new(0, 10, 0, 60),
		BackgroundColor3 = COLOR.BG,
		BackgroundTransparency = 0.3,
		Text = "",
		PlaceholderText = "Keyframe code / URL / AssetId...",
		PlaceholderColor3 = COLOR.TEXT_DIM,
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_CODE,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		MultiLine = true,
		TextWrapped = true,
		ClearTextOnFocus = false,
		Parent = card,
	})
	Round(6, codeBox)
	setSafeText(codeBox, rawCode)

	local copyBtn = Create("TextButton", {
		Name = "CopyKF",
		Size = UDim2.new(0, 56, 0, 20),
		Position = UDim2.new(1, -66, 1, -28),
		BackgroundColor3 = COLOR.ROW,
		BackgroundTransparency = 0.1,
		Text = "Copy KF",
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_BOLD,
		TextSize = 9,
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = card,
	})
	Round(5, copyBtn)

	codeBox.FocusLost:Connect(function()
		if #codeBox.Text <= SAFE_TEXT_LIMIT then
			rawCode = codeBox.Text
		end
		if opts.onCodeChanged then opts.onCodeChanged(rawCode) end
	end)

	selectBtn.MouseButton1Click:Connect(function()
		if opts.onSelectClick then opts.onSelectClick(selectBtn) end
	end)

	clearBtn.MouseButton1Click:Connect(function()
		rawCode = ""
		codeBox.Text = ""
		selLabel.Text = "Selected: None"
		if opts.onClear then opts.onClear() end
	end)

	copyBtn.MouseButton1Click:Connect(function()
		if opts.onCopy then opts.onCopy(rawCode, copyBtn) end
	end)

	self:_refresh()
	return {
		Frame = card,
		SelectButton = selectBtn,
		SetSelected = function(name, code)
			selLabel.Text = "Selected: " .. tostring(name or "None")
			if code ~= nil then
				rawCode = tostring(code)
				setSafeText(codeBox, rawCode)
			end
		end,
		GetCode = function() return rawCode end,
	}
end

local function makePage(win, name, parent)
	local self = setmetatable({ window = win, name = name, order = 0 }, Page)

	local group = Create("Frame", {
		Name = "Page_" .. name,
		Size = UDim2.new(1, -24, 1, -20),
		Position = UDim2.new(0, 14, 0, 10),
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
	self.UpdateScroll = applyVerticalScroll(win, scroll, group, 0, 10, function()
		return contentHeight(layout)
	end, true)
	return self
end

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

function Window:_registerFade(obj, prop, on, off)
	if not obj then return end
	table.insert(self._fadeList, { obj = obj, prop = prop, on = on, off = off })
end

function Window:SetVisible(show)
	if self.destroyed or self.visible == show then return end
	self.visible = show
	self._fadeVersion = (self._fadeVersion or 0) + 1
	local version = self._fadeVersion

	if show then
		self.MainFrame.Visible = true
	end
	for _, f in ipairs(self._fadeList) do
		local goal = {}
		goal[f.prop] = show and f.on or f.off
		Tween(f.obj, goal, FADE_TIME)
	end

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
	self:_flushPending()

	self.minimized = not self.minimized
	local info = TweenInfo.new(FAST, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	if self.minimized then
		self.MinIcon.Text = "+"
		self.ContentArea.Visible = false
		if self.Grip then self.Grip.Visible = false end
		TweenService:Create(self.MainFrame, info, { Size = self.minSize }):Play()
		if self.DragBar then
			TweenService:Create(self.DragBar, info, { Position = DRAG_BAR_OUT }):Play()
		end
	else
		self.MinIcon.Text = "-"
		if self.Grip then self.Grip.Visible = true end
		local t = TweenService:Create(self.MainFrame, info, { Size = self.fullSize })
		t:Play()
		if self.DragBar then
			TweenService:Create(self.DragBar, info, { Position = DRAG_BAR_IN }):Play()
		end
		t.Completed:Connect(function()
			if not self.minimized and not self.destroyed then
				self.ContentArea.Visible = true
			end
		end)
	end
end

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

	self:_flushPending()

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
	local currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
	self._dragVelocity = Vector2.new(
		currentMousePos.X - self._lastMousePos.X,
		currentMousePos.Y - self._lastMousePos.Y
	)
	self._lastMousePos = currentMousePos

	local delta = Vector2.new(input.Position.X - self._dragStart.X, input.Position.Y - self._dragStart.Y)
	self._dragTarget = self:_clampPosition(
		self._dragStartPos.X.Offset + delta.X,
		self._dragStartPos.Y.Offset + delta.Y
	)
end

function Window:_flushPending()
	if self._dragTarget then
		self.MainFrame.Position = self._dragTarget
		self._dragTarget = nil
	end
	if self._resizeTarget then
		local t = self._resizeTarget
		self._resizeTarget = nil
		self.MainFrame.Position = t.position
		self.MainFrame.Size = t.size
		self.fullSize = t.size
		self.minSize = UDim2.new(0, t.size.X.Offset, 0, HEADER_H)
	end
end

function Window:_dragEnd()
	self:_flushPending()
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

function Window:_layoutPages()
	local hasTabs = self._tabsShown
	local topY = hasTabs and 40 or 10
	local footerH = (self._footer and self._footerVisible) and (self._footerHeight + 6) or 0
	for i = 1, #self._pages do
		local page = self._pages[i]
		page.Group.Position = UDim2.new(0, 18, 0, topY)
		page.Group.Size = UDim2.new(1, -28, 1, -(topY + 10 + footerH))
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
	local prevTab = self._selectedTab
	if prevTab and prevTab.Page and prevTab.Page.Scroll then
		prevTab._savedScroll = prevTab.Page.Scroll.CanvasPosition
	end

	self._selectedTab = tab
	for i = 1, #self._tabs do
		local t = self._tabs[i]
		local active = (t == tab)
		t.Button.TextColor3 = active and COLOR.TEXT or COLOR.TAB_IDLE
		if t.Page ~= tab.Page then
			t.Page.Group.Visible = false
		end
	end
	tab.Page.Group.Visible = true

	if self._footer then
		local wantFooter = (tab.showFooter == true)
		if self._footerVisible ~= wantFooter then
			self._footerVisible = wantFooter
			self._footer.Visible = wantFooter
			self:_layoutPages()
		end
	end

	self:_moveIndicator(tab.Button, true)
	self:_autoScrollTo(tab.Button)

	if tab.onSelect then
		pcall(tab.onSelect, tab)
	end

	task.defer(function()
		if self.destroyed then return end
		if tab._savedScroll and tab.Page and tab.Page.Scroll then
			tab.Page.Scroll.CanvasPosition = tab._savedScroll
		end
		if tab.Page.UpdateScroll then tab.Page.UpdateScroll() end
	end)
end

function Window:CreateTab(name, opts)
	opts = opts or {}
	name = tostring(name or ("Tab " .. (#self._tabs + 1)))
	local page

	if opts.sharePageWith then
		page = opts.sharePageWith.Page or opts.sharePageWith
	elseif not self._tabsShown then
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

	local tab = {
		Name = name,
		Button = btn,
		Page = page,
		window = self,
		showFooter = (opts.showFooter == true),
		onSelect = opts.onSelect,
	}
	function tab:AddSection(o) return page:AddSection(o) end
	function tab:AddLabel(o) return page:AddLabel(o) end
	function tab:AddButton(o) return page:AddButton(o) end
	function tab:AddToggle(o) return page:AddToggle(o) end
	function tab:AddSlider(o) return page:AddSlider(o) end
	function tab:AddKeybind(o) return page:AddKeybind(o) end
	function tab:AddSearchBox(o) return page:AddSearchBox(o) end
	function tab:AddList(o) return page:AddList(o) end
	function tab:AddDropdown(o) return page:AddDropdown(o) end
	function tab:AddVirtualList(o) return page:AddVirtualList(o) end
	function tab:AddInput(o) return page:AddInput(o) end
	function tab:AddButtonRow(o) return page:AddButtonRow(o) end
	function tab:AddCollapsible(o) return page:AddCollapsible(o) end
	function tab:AddMultiSelectAccordion(o) return page:AddMultiSelectAccordion(o) end
	function tab:AddStateCard(o) return page:AddStateCard(o) end
	function tab:Select() self.window:_selectTab(tab) end

	table.insert(self._tabs, tab)
	btn.MouseButton1Click:Connect(function()
		self:_selectTab(tab)
	end)

	self:_layoutPages()

	if not self._selectedTab then
		self:_selectTab(tab)
	end
	return tab
end

function Window:AddHeaderToggle(opts)
	opts = opts or {}
	local value = (opts.default == true)
	local debounceTime = tonumber(opts.debounce) or 0.5
	local busy = false

	self.Title.Size = UDim2.new(1, -145, 0, HEADER_H)
	self.DragArea.Size = UDim2.new(1, -145, 0, HEADER_H)

	local switch = Create("TextButton", {
		Name = "HeaderSwitch",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 44, 0, 22),
		Position = UDim2.new(1, -104, 0, HEADER_H / 2),
		BackgroundColor3 = value and COLOR.GREEN or Color3.fromRGB(60, 60, 60),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 15,
		Parent = self.Body,
	})
	Round(11, switch)

	Create("UIShadow", {
		Name = "SwitchShadow",
		BlurRadius = UDim.new(0, 6),
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 0.72,
		Parent = switch,
	})

	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 22, 0, 16),
		Position = UDim2.new(0, value and 30 or 14, 0.5, 0),
		BackgroundColor3 = COLOR.TEXT,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 16,
		Parent = switch,
	})
	local knobCorner = Round(8, knob)

	local lens = Create("UIStroke", {
		Name = "Lens",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = COLOR.TEXT,
		Thickness = 1.4,
		Transparency = 1,
		Parent = knob,
	})

	local function apply(v, fire)
		value = (v == true)
		Tween(switch, {
			BackgroundColor3 = value and COLOR.GREEN or Color3.fromRGB(60, 60, 60),
		}, FAST, Enum.EasingStyle.Quart)
		Tween(knob, {
			Position = UDim2.new(0, value and 30 or 14, 0.5, 0),
		}, FAST, Enum.EasingStyle.Quart)
		if fire and opts.callback then
			task.spawn(opts.callback, value)
		end
	end

	local function setLens(on)
		Tween(knob, {
			BackgroundTransparency = on and 0.5 or 0.15,
			Size = on and UDim2.new(0, 26, 0, 18) or UDim2.new(0, 22, 0, 16),
		}, FAST, Enum.EasingStyle.Quart)
		knobCorner.CornerRadius = UDim.new(0, on and 9 or 8)
		Tween(lens, { Transparency = on and 0.1 or 1, Thickness = on and 2 or 1.4 }, FAST, Enum.EasingStyle.Quart)
	end

	switch.MouseButton1Down:Connect(function() setLens(true) end)
	switch.MouseButton1Up:Connect(function() setLens(false) end)
	switch.MouseLeave:Connect(function() setLens(false) end)

	switch.MouseButton1Click:Connect(function()
		if busy then return end
		busy = true
		apply(not value, true)
		task.delay(debounceTime, function() busy = false end)
	end)

	return {
		Frame = switch,
		Get = function() return value end,
		Set = function(v, fire) apply(v, fire == true) end,
	}
end

function Window:CreateSpeedFooter(opts)
	opts = opts or {}
	local footerH = 104
	self._footerHeight = footerH
	self._footerVisible = true

	local footer = Create("Frame", {
		Name = "SpeedFooter",
		Size = UDim2.new(1, -28, 0, footerH),
		Position = UDim2.new(0, 14, 1, -(footerH + 8)),
		BackgroundColor3 = COLOR.FIELD,
		BackgroundTransparency = 0.35,
		ZIndex = 15,
		Parent = self.ContentArea,
	})
	Round(12, footer)
	self._footer = footer

	local statusLabel = Create("TextLabel", {
		Name = "StatusLabel",
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.new(0, 8, 0, 4),
		BackgroundTransparency = 1,
		Text = opts.statusText or "Animations: 0/0",
		TextColor3 = COLOR.TEXT_DIM,
		FontFace = FONT_MED,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})

	Create("TextLabel", {
		Name = "SpeedTitle",
		Size = UDim2.new(0, 68, 0, 18),
		Position = UDim2.new(0, 8, 0, 20),
		BackgroundTransparency = 1,
		Text = "Speed",
		TextColor3 = COLOR.TEXT,
		FontFace = FONT_BOLD,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})

	local speedValLabel = Create("TextLabel", {
		Name = "SpeedValue",
		Size = UDim2.new(0, 36, 0, 18),
		Position = UDim2.new(0, 50, 0, 20),
		BackgroundTransparency = 1,
		Text = tostring(opts.defaultSpeed or 5),
		TextColor3 = COLOR.GREEN,
		FontFace = FONT_BOLD,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})

	local function makeMiniBtn(name, text, posX, width)
		local b = Create("TextButton", {
			Name = name,
			Size = UDim2.new(0, width, 0, 18),
			Position = UDim2.new(1, posX, 0, 20),
			BackgroundColor3 = COLOR.ROW,
			BackgroundTransparency = 0.2,
			Text = text,
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_BOLD,
			TextSize = 9,
			AutoButtonColor = false,
			Parent = footer,
		})
		Round(6, b)
		return b
	end

	local resetBtn = makeMiniBtn("Reset", "Reset", -128, 42)
	local revBtn   = makeMiniBtn("Reverse", "Reverse", -82, 48)
	local revBind  = makeMiniBtn("RevBind", "+", -30, 22)

	local track = Create("Frame", {
		Name = "Track",
		Size = UDim2.new(1, -20, 0, 5),
		Position = UDim2.new(0, 10, 0, 45),
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		Parent = footer,
	})
	Circle(track)

	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLOR.GREEN,
		Parent = track,
	})
	Circle(fill)

	local knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 16, 0, 10),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = COLOR.TEXT,
		ZIndex = 3,
		Parent = track,
	})
	Circle(knob)

	local hit = Create("TextButton", {
		Name = "Hit",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = footer,
	})

	local slotCount = 5
	local slotsRow = Create("Frame", {
		Name = "SlotsRow",
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.new(0, 8, 0, 56),
		BackgroundTransparency = 1,
		Parent = footer,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = slotsRow,
	})

	local minS, maxS = tonumber(opts.min) or 0, tonumber(opts.max) or 30
	local curSpeed = tonumber(opts.defaultSpeed) or 5
	local isReversed = false
	local revKey = toKeyCode(opts.reverseKey)
	local slots = {}

	local function updateAccent()
		local col = isReversed and COLOR.DANGER or COLOR.GREEN
		fill.BackgroundColor3 = col
		speedValLabel.TextColor3 = col
		revBtn.BackgroundColor3 = isReversed and COLOR.DANGER or COLOR.ROW
	end

	local function setSpeed(val, fire)
		curSpeed = math.clamp(tonumber(val) or 5, minS, maxS)
		local pct = math.clamp((curSpeed - minS) / (maxS - minS), 0, 1)
		Tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.08)
		Tween(knob, { Position = UDim2.new(pct, 0, 0.5, 0) }, 0.08)
		speedValLabel.Text = string.format("%.1f", curSpeed):gsub("%.0$", "")
		if fire and opts.onSpeedChanged then
			opts.onSpeedChanged(curSpeed, isReversed)
		end
	end

	local dragging = false
	local function updateFromInput(input)
		local w = absSize(track).X
		if w <= 0 then return end
		local pct = math.clamp((input.Position.X - absPos(track).X) / w, 0, 1)
		local stepped = math.floor((minS + pct * (maxS - minS)) * 10 + 0.5) / 10
		setSpeed(stepped, true)
	end

	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(i)
		end
	end)
	self:_track(UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(i)
		end
	end))
	self:_track(UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	resetBtn.MouseButton1Click:Connect(function()
		setSpeed(opts.defaultSpeed or 5, true)
	end)

	revBtn.MouseButton1Click:Connect(function()
		isReversed = not isReversed
		updateAccent()
		if opts.onReverseChanged then opts.onReverseChanged(isReversed) end
	end)

	local bindingRev = false
	revBind.MouseButton1Click:Connect(function()
		if bindingRev then return end
		if revKey then
			revKey = nil
			revBind.Text = "+"
			if opts.onReverseBind then opts.onReverseBind(nil) end
			return
		end
		bindingRev = true
		revBind.Text = ".."
		waitForKey(self, function(newKey)
			bindingRev = false
			revKey = newKey
			revBind.Text = revKey and shortKey(revKey) or "+"
			if opts.onReverseBind then opts.onReverseBind(revKey) end
		end)
	end)

	for idx = 1, slotCount do
		local defSlot = (opts.slots and opts.slots[idx]) or {}
		local slotCol = Create("Frame", {
			Name = "Slot_" .. idx,
			Size = UDim2.new(0, 38, 1, 0),
			BackgroundTransparency = 1,
			Parent = slotsRow,
		})
		local valBox = Create("TextBox", {
			Name = "Val",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundColor3 = COLOR.ROW,
			BackgroundTransparency = 0.2,
			Text = tostring(defSlot.value or (idx * 2)),
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_BOLD,
			TextSize = 10,
			ClearTextOnFocus = false,
			Parent = slotCol,
		})
		Round(5, valBox)

		local bindBtn = Create("TextButton", {
			Name = "Bind",
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0, 21),
			BackgroundColor3 = COLOR.ROW,
			BackgroundTransparency = 0.2,
			Text = defSlot.key and shortKey(toKeyCode(defSlot.key)) or "",
			TextColor3 = COLOR.TEXT_DIM,
			FontFace = FONT_BOLD,
			TextSize = 9,
			AutoButtonColor = false,
			Parent = slotCol,
		})
		Round(5, bindBtn)

		local icon = Create("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 16, 0, 12),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 1,
			Image = KEYBIND_ICON,
			ImageRectOffset = Vector2.new(15, 68),
			ImageRectSize = Vector2.new(390, 284),
			ImageColor3 = COLOR.TEXT_DIM,
			Visible = (defSlot.key == nil),
			Parent = bindBtn,
		})

		local slotState = {
			value = tonumber(defSlot.value) or (idx * 2),
			key = toKeyCode(defSlot.key),
			binding = false,
		}
		slots[idx] = slotState

		valBox.FocusLost:Connect(function()
			local n = tonumber(valBox.Text)
			if n then
				slotState.value = math.clamp(n, minS, maxS)
				valBox.Text = tostring(slotState.value)
				if opts.onSlotChanged then opts.onSlotChanged(idx, slotState.value, slotState.key) end
			else
				valBox.Text = tostring(slotState.value)
			end
		end)

		bindBtn.MouseButton1Click:Connect(function()
			if slotState.binding then return end
			if slotState.key then
				slotState.key = nil
				bindBtn.Text = ""
				icon.Visible = true
				if opts.onSlotChanged then opts.onSlotChanged(idx, slotState.value, nil) end
				return
			end
			slotState.binding = true
			icon.Visible = false
			bindBtn.Text = ".."
			waitForKey(self, function(newKey)
				slotState.binding = false
				slotState.key = newKey
				bindBtn.Text = newKey and shortKey(newKey) or ""
				icon.Visible = (newKey == nil)
				if opts.onSlotChanged then opts.onSlotChanged(idx, slotState.value, newKey) end
			end)
		end)
	end

	self:_track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or self.destroyed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if revKey and not bindingRev and input.KeyCode == revKey then
			isReversed = not isReversed
			updateAccent()
			if opts.onReverseChanged then opts.onReverseChanged(isReversed) end
		end
		for idx = 1, slotCount do
			local st = slots[idx]
			if st.key and not st.binding and input.KeyCode == st.key then
				setSpeed(st.value, true)
			end
		end
	end))

	setSpeed(curSpeed, false)
	updateAccent()
	self:_layoutPages()

	return {
		Frame = footer,
		SetStatus = function(text, col)
			statusLabel.Text = tostring(text)
			statusLabel.TextColor3 = col or COLOR.TEXT_DIM
		end,
		SetSpeed = function(v, fire) setSpeed(v, fire == true) end,
		GetSpeed = function() return curSpeed end,
		SetReversed = function(r, fire)
			isReversed = (r == true)
			updateAccent()
			if fire and opts.onReverseChanged then opts.onReverseChanged(isReversed) end
		end,
		IsReversed = function() return isReversed end,
	}
end

function Window:AddSection(o) return self._defaultPage:AddSection(o) end
function Window:AddLabel(o) return self._defaultPage:AddLabel(o) end
function Window:AddButton(o) return self._defaultPage:AddButton(o) end
function Window:AddToggle(o) return self._defaultPage:AddToggle(o) end
function Window:AddSlider(o) return self._defaultPage:AddSlider(o) end
function Window:AddKeybind(o) return self._defaultPage:AddKeybind(o) end
function Window:AddSearchBox(o) return self._defaultPage:AddSearchBox(o) end
function Window:AddList(o) return self._defaultPage:AddList(o) end
function Window:AddDropdown(o) return self._defaultPage:AddDropdown(o) end
function Window:AddVirtualList(o) return self._defaultPage:AddVirtualList(o) end
function Window:AddInput(o) return self._defaultPage:AddInput(o) end
function Window:AddButtonRow(o) return self._defaultPage:AddButtonRow(o) end
function Window:AddCollapsible(o) return self._defaultPage:AddCollapsible(o) end
function Window:AddMultiSelectAccordion(o) return self._defaultPage:AddMultiSelectAccordion(o) end
function Window:AddStateCard(o) return self._defaultPage:AddStateCard(o) end

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

local function calcSizes(opts)
	local ow, oh
	if type(opts.size) == "table" then
		ow, oh = tonumber(opts.size[1]), tonumber(opts.size[2])
	end
	ow = tonumber(opts.width) or ow
	oh = tonumber(opts.height) or oh
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local isSmall = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or math.min(vp.X, vp.Y) < 700)
	if isSmall then
		local w = math.clamp(math.floor(ow or (vp.X * 0.6)), 200, 240)
		local h = math.clamp(math.floor(oh or (vp.Y * 0.85)), 280, 420)
		return UDim2.new(0, w, 0, h), UDim2.new(0, w, 0, HEADER_H)
	end
	local w = math.floor(ow or 270)
	local h = math.floor(oh or 480)
	return UDim2.new(0, w, 0, h), UDim2.new(0, w, 0, HEADER_H)
end

function FlowLib:CreateWindow(opts)
	opts = opts or {}
	local title = tostring(opts.title or "Flow")
	local fullSize, minSize = calcSizes(opts)
	local guiName = tostring(opts.name or ("FlowLib_" .. title:gsub("%W", "_")))
	local parent = GetSafeParent()

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
		_fadeList = {},
		_dragging = false,
		_dragVelocity = Vector2.new(0, 0),
		_dragStart = Vector2.new(0, 0),
		_lastMousePos = Vector2.new(0, 0),
		_dragStartPos = UDim2.new(0, 0, 0, 0),
		_dragTarget = nil,
		_resizeTarget = nil,
		resizeMin = nil,
		UIBind = toKeyCode(opts.keybind),
	}, Window)

	local minRW, minRH = 180, 160
	if type(opts.minSize) == "table" then
		minRW = math.max(24, tonumber(opts.minSize[1]) or 180)
		minRH = math.max(24, tonumber(opts.minSize[2]) or 160)
	end
	minRW = math.min(minRW, fullSize.X.Offset)
	minRH = math.min(minRH, fullSize.Y.Offset)
	win.resizeMin = { w = minRW, h = minRH }

	local ScreenGui = Create("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	win.ScreenGui = ScreenGui

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

	local WinShadow = Create("UIShadow", {
		Name = "WinShadow",
		BlurRadius = UDim.new(0, 10),
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 1,
		Offset = UDim2.new(0, 0, 0, 0),
		ShowBehindParent = false,
		Parent = MainFrame,
	})
	win.WinShadow = WinShadow

	local DragBar = Create("Frame", {
		Name = "DragBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = DRAG_BAR_SIZE,
		Position = DRAG_BAR_IN,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 11,
		Active = true,
		Parent = MainFrame,
	})
	Circle(DragBar)
	win.DragBar = DragBar

	local function dragBarHover(on)
		if win.destroyed then return end
		local tr = 1
		if win.visible then tr = on and 0 or BAR_TRANSPARENCY end
		local baseY = win.minimized and DRAG_BAR_OUT.Y.Offset or DRAG_BAR_IN.Y.Offset
		Tween(DragBar, {
			BackgroundTransparency = tr,
			Size = on and DRAG_BAR_SIZE_HOVE or DRAG_BAR_SIZE,
			Position = UDim2.new(0.5, 0, 0, on and (baseY - 3) or baseY),
		}, FAST, Enum.EasingStyle.Quart)
	end
	DragBar.MouseEnter:Connect(function() dragBarHover(true) end)
	DragBar.MouseLeave:Connect(function() dragBarHover(false) end)

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

	win:_registerFade(Body, "GroupTransparency", 0, 1)
	win:_registerFade(WinShadow, "Transparency", SHADOW_TRANSPARENCY, 1)
	win:_registerFade(DragBar, "BackgroundTransparency", BAR_TRANSPARENCY, 1)

	local WindowStroke = Create("UIStroke", {
		Name = "WindowStroke",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = COLOR.BORDER,
		Thickness = 1.2,
		Transparency = 1,
		Parent = Body,
	})
	Create("UIGradient", { Rotation = 90, Transparency = STROKE_GRADIENT, Parent = WindowStroke })
	win.WindowStroke = WindowStroke
	win:_registerFade(WindowStroke, "Transparency", 0.1, 1)

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

	local BottomGlow = Create("Frame", {
		Name = "BottomGlow",
		Size = UDim2.new(1, 0, 0.35, 0),
		Position = UDim2.new(0, 0, 0.65, 0),
		BackgroundColor3 = COLOR.GLOW,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = Body,
	})
	Round(CORNER_RADIUS, BottomGlow)
	Create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.87),
		}),
		Parent = BottomGlow,
	})
	win.BottomGlow = BottomGlow

	local Title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -90, 0, HEADER_H),
		Position = UDim2.new(0, 14, 0, 0),
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

	local function createWindowButton(name, iconText, posX)
		local btn = Create("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 26, 0, 26),
			Position = UDim2.new(1, posX, 0, HEADER_H / 2),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.92,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 15,
			Parent = Body,
		})
		Circle(btn)

		local icon = Create("TextLabel", {
			Name = "Icon",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = iconText,
			TextColor3 = COLOR.TEXT,
			FontFace = FONT_BOLD,
			TextSize = (iconText == "-") and 16 or 12,
			ZIndex = 16,
			Parent = btn,
		})
		return btn, icon
	end

	local MinimizeBtn, MinIcon = createWindowButton("MinimizeBtn", "-", -60)
	local CloseBtn, CloseIcon = createWindowButton("CloseBtn", "X", -25)
	win.MinimizeBtn = MinimizeBtn
	win.MinIcon = MinIcon
	win.CloseBtn = CloseBtn
	win.CloseIcon = CloseIcon

	local Grip = Create("ImageLabel", {
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		Image = RESIZE_ICON,
		ImageRectOffset = Vector2.new(50, 50),
		ImageRectSize = Vector2.new(320, 320),
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 14,
		Parent = Body,
	})
	win.Grip = Grip

	local resizing, resizeStart = false, nil
	local startW, startH, startOffsetX = 0, 0, 0

	local function setGripTransparency(tr)
		Tween(Grip, { ImageTransparency = tr }, FAST, Enum.EasingStyle.Quart)
	end

	Grip.MouseEnter:Connect(function()
		if not win.destroyed then
			setGripTransparency(0.15)
		end
	end)
	Grip.MouseLeave:Connect(function()
		if not win.destroyed then
			setGripTransparency(resizing and 0.15 or 0.45)
		end
	end)

	Grip.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if win.destroyed or win.minimized then return end
		resizing = true
		resizeStart = Vector2.new(input.Position.X, input.Position.Y)
		startW = MainFrame.Size.X.Offset
		startH = MainFrame.Size.Y.Offset
		startOffsetX = MainFrame.Position.X.Offset
	end)

	win:_track(UserInputService.InputChanged:Connect(function(input)
		if not resizing then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local rmin = win.resizeMin or { w = 24, h = 24 }
		local w = math.max(rmin.w, math.floor(startW + (input.Position.X - resizeStart.X)))
		local h = math.max(rmin.h, math.floor(startH + (input.Position.Y - resizeStart.Y)))
		local pos = MainFrame.Position
		win._resizeTarget = {
			position = UDim2.new(pos.X.Scale, startOffsetX + math.floor((w - startW) / 2), pos.Y.Scale, pos.Y.Offset),
			size = UDim2.new(0, w, 0, h),
		}
	end))

	win:_track(UserInputService.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and resizing then
			resizing = false
			win:_flushPending()
			for _, page in ipairs(win._pages) do
				if page.UpdateScroll then page.UpdateScroll() end
			end
		end
	end))

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
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 18, 0, 0),
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
		TabContainer.CanvasSize = UDim2.new(0, contentWidth(TabListLayout) + 8, 0, 0)
	end)
