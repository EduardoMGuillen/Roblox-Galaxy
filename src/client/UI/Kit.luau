-- Kit: componentes de interfaz reutilizables (paneles holograficos, botones, listas, tarjetas de planeta).
-- Toda la interfaz se genera por codigo para que el proyecto se pueda construir sin Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Format = require(Shared.Util.Format)
local Progression = require(Shared.Progression)
local PlanetVisual = require(Shared.PlanetVisual)
local Theme = require(script.Parent.Theme)
local C, F = Theme.Colors, Theme.Fonts

local Kit = {}

Kit.onClick = nil -- funcion opcional (sonido de clic), la asigna AudioController

---------------------------------------------------------------- basicos
function Kit.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Corner)
	c.Parent = parent
	return c
end

function Kit.stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or C.Cyan
	s.Thickness = thickness or Theme.Stroke
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Kit.gradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Kit.padding(parent, left, top, right, bottom)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, left or 0)
	p.PaddingTop = UDim.new(0, top or left or 0)
	p.PaddingRight = UDim.new(0, right or left or 0)
	p.PaddingBottom = UDim.new(0, bottom or top or left or 0)
	p.Parent = parent
	return p
end

local function applyProps(inst, props)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
end

-- Marco. opts: propiedades de Frame; Color/Alpha atajos de fondo
function Kit.frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	applyProps(f, props)
	f.Parent = parent
	return f
end

-- Caja de color con esquinas redondeadas
function Kit.box(parent, color, transparency, props, radius)
	local f = Kit.frame(parent, props)
	f.BackgroundColor3 = color or C.Row
	f.BackgroundTransparency = transparency or 0
	Kit.corner(f, radius or 10)
	return f
end

-- Texto. opts: Size, Position, AnchorPoint, TextSize, Color, Font, AlignX, AlignY, Wrap, Stroke, y cualquier
-- otra propiedad de TextLabel en Props
function Kit.label(parent, text, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = opts.Font or F.Bold
	l.Text = text or ""
	l.TextSize = opts.TextSize or 16
	l.TextColor3 = opts.Color or C.Text
	l.TextXAlignment = opts.AlignX or Enum.TextXAlignment.Left
	l.TextYAlignment = opts.AlignY or Enum.TextYAlignment.Center
	l.TextWrapped = opts.Wrap == true
	l.TextTruncate = opts.Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
	l.Size = opts.Size or UDim2.new(1, 0, 0, (opts.TextSize or 16) + 8)
	if opts.Position then l.Position = opts.Position end
	if opts.AnchorPoint then l.AnchorPoint = opts.AnchorPoint end
	if opts.Stroke then
		local s = Instance.new("UIStroke")
		s.Color = C.Dark
		s.Thickness = 1.5
		s.Transparency = 0.2
		s.Parent = l
	end
	applyProps(l, opts.Props)
	l.Parent = parent
	return l
end

function Kit.tween(inst, time, props, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

---------------------------------------------------------------- botones
function Kit.setStyle(button, style)
	local colors = Theme.Buttons[style] or Theme.Buttons.primary
	local gradient = button:FindFirstChild("Fill")
	local stroke = button:FindFirstChild("Edge")
	if gradient then gradient.Color = ColorSequence.new(colors[1], colors[2]) end
	if stroke then stroke.Color = colors[3] end
	button:SetAttribute("Style", style)
end

function Kit.setEnabled(button, enabled)
	button:SetAttribute("Disabled", not enabled)
	local style = button:GetAttribute("BaseStyle") or "primary"
	local colors = enabled and Theme.Buttons[style] or Theme.Buttons.disabled
	local gradient = button:FindFirstChild("Fill")
	local stroke = button:FindFirstChild("Edge")
	if gradient then gradient.Color = ColorSequence.new(colors[1], colors[2]) end
	if stroke then stroke.Color = colors[3] end
	button.TextTransparency = enabled and 0 or 0.45
end

-- Boton. opts: Size, Position, AnchorPoint, TextSize, Font, Radius, Props
function Kit.button(parent, text, style, opts, onClick)
	opts = opts or {}
	style = style or "primary"
	local colors = Theme.Buttons[style] or Theme.Buttons.primary
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Font = opts.Font or F.Bold
	b.Text = text or ""
	b.TextSize = opts.TextSize or 16
	b.TextColor3 = C.Text
	b.TextWrapped = true
	b.Size = opts.Size or UDim2.fromOffset(140, 40)
	if opts.Position then b.Position = opts.Position end
	if opts.AnchorPoint then b.AnchorPoint = opts.AnchorPoint end
	b:SetAttribute("BaseStyle", style)
	Kit.corner(b, opts.Radius or 10)
	local gradient = Kit.gradient(b, colors[1], colors[2], 90)
	gradient.Name = "Fill"
	local stroke = Kit.stroke(b, colors[3], 1.5, 0)
	stroke.Name = "Edge"
	local textStroke = Instance.new("UIStroke")
	textStroke.Name = "TextEdge"
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Color = C.Dark
	textStroke.Thickness = 1.2
	textStroke.Transparency = 0.35
	textStroke.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	applyProps(b, opts.Props)
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("Disabled") then stroke.Thickness = 2.5 end
	end)
	b.MouseLeave:Connect(function()
		stroke.Thickness = 1.5
		scale.Scale = 1
	end)
	b.MouseButton1Down:Connect(function()
		if not b:GetAttribute("Disabled") then scale.Scale = 0.95 end
	end)
	b.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") then return end
		if Kit.onClick then Kit.onClick() end
		if onClick then onClick(b) end
	end)
	b.Parent = parent
	return b
end

---------------------------------------------------------------- panel
-- Panel centrado con cabecera. opts: Size (UDim2 en offset), Title, Icon, OnClose, Name
-- Devuelve frame, body
function Kit.panel(parent, opts)
	local frame = Instance.new("Frame")
	frame.Name = opts.Name or "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = opts.Position or UDim2.fromScale(0.5, 0.5)
	frame.Size = opts.Size or UDim2.fromOffset(760, 500)
	frame.BackgroundColor3 = C.Panel
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Active = true
	Kit.corner(frame, 16)
	local stroke = Kit.stroke(frame, Color3.new(1, 1, 1), 2, 0)
	Kit.gradient(stroke, C.Cyan, C.Violet, 35)
	local glow = Kit.gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 180, 235), 90)
	glow.Name = "Shade"

	local header = Kit.frame(frame, { Name = "Header", Size = UDim2.new(1, 0, 0, 54) })
	Kit.label(header, ((opts.Icon and (opts.Icon .. "  ")) or "") .. string.upper(opts.Title or ""), {
		Font = F.Title, TextSize = 19, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -90, 1, 0), Color = C.Text,
	}).Name = "Title"
	local line = Kit.frame(frame, { Name = "Divider", Size = UDim2.new(1, -32, 0, 2), Position = UDim2.fromOffset(16, 54),
		BackgroundTransparency = 0.2, BackgroundColor3 = Color3.new(1, 1, 1) })
	Kit.gradient(line, C.Cyan, C.Violet, 0)
	if opts.OnClose then
		Kit.button(header, "✕", "danger", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 9), TextSize = 18 }, opts.OnClose).Name = "Close"
	end
	local body = Kit.frame(frame, { Name = "Body", Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 1, -78) })
	frame.Parent = parent
	return frame, body
end

---------------------------------------------------------------- listas
-- opts: Size, Position, Grid (UDim2 celda), Padding, Horizontal, Props
function Kit.scroll(parent, opts)
	opts = opts or {}
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = opts.Size or UDim2.fromScale(1, 1)
	if opts.Position then s.Position = opts.Position end
	s.CanvasSize = UDim2.new(0, 0, 0, 0)
	s.AutomaticCanvasSize = opts.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = C.Cyan
	s.ScrollingDirection = opts.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
	applyProps(s, opts.Props)
	local layout
	if opts.Grid then
		layout = Instance.new("UIGridLayout")
		layout.CellSize = opts.Grid
		layout.CellPadding = UDim2.fromOffset(opts.Padding or 8, opts.Padding or 8)
	else
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, opts.Padding or 8)
		layout.FillDirection = opts.Horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	end
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = s
	Kit.padding(s, 2, 2, 10, 2)
	s.Parent = parent
	return s, layout
end

function Kit.listLayout(parent, padding, horizontal, alignCenter)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 8)
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if alignCenter then
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	layout.Parent = parent
	return layout
end

-- Elimina los hijos que no sean layouts/paddings
function Kit.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

---------------------------------------------------------------- barra de progreso
-- Devuelve frame, set(fraccion, texto)
function Kit.progress(parent, opts)
	opts = opts or {}
	local back = Kit.box(parent, C.Dark, 0.3, { Size = opts.Size or UDim2.new(1, 0, 0, 18), Position = opts.Position }, 8)
	Kit.stroke(back, opts.Color or C.Cyan, 1, 0.5)
	local fill = Kit.box(back, opts.Color or C.Cyan, 0, { Size = UDim2.fromScale(0, 1), Name = "Fill" }, 8)
	local text = Kit.label(back, "", { Size = UDim2.fromScale(1, 1), TextSize = 12, AlignX = Enum.TextXAlignment.Center, Stroke = true })
	local function set(fraction, caption)
		fraction = math.clamp(fraction, 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.Visible = fraction > 0.001
		text.Text = caption or ""
	end
	return back, set
end

---------------------------------------------------------------- interruptor
function Kit.toggle(parent, value, onChange, opts)
	opts = opts or {}
	local state = value == true
	local b
	local function paint()
		b.Text = state and "ACTIVADO" or "DESACTIVADO"
		Kit.setStyle(b, state and "green" or "ghost")
	end
	b = Kit.button(parent, "", "ghost", { Size = opts.Size or UDim2.fromOffset(130, 34), Position = opts.Position,
		AnchorPoint = opts.AnchorPoint, TextSize = 13 }, function()
		state = not state
		paint()
		onChange(state)
	end)
	paint()
	return b, function(v)
		state = v == true
		paint()
	end
end

---------------------------------------------------------------- pestañas
-- items = { "Texto", ... }. Devuelve frame, select(indice)
function Kit.tabs(parent, items, onSelect, opts)
	opts = opts or {}
	local bar = Kit.frame(parent, { Size = opts.Size or UDim2.new(1, 0, 0, 36), Position = opts.Position })
	Kit.listLayout(bar, 6, true)
	local buttons = {}
	local function select(index, silent)
		for i, btn in ipairs(buttons) do
			Kit.setStyle(btn, i == index and "cyan" or "ghost")
		end
		if not silent then onSelect(index) end
	end
	for i, text in ipairs(items) do
		buttons[i] = Kit.button(bar, text, "ghost", { Size = UDim2.fromOffset(opts.Width or 120, 34), TextSize = 13,
			Props = { LayoutOrder = i } }, function()
			select(i)
		end)
	end
	select(1, true)
	return bar, select, buttons
end

---------------------------------------------------------------- planetas
function Kit.rarityText(rarityId)
	local r = Defs.Rarities.ById[rarityId]
	return r.Icon .. " " .. r.Name
end

-- ViewportFrame con el modelo del planeta
function Kit.viewport(parent, planetId, variant, evolved, props)
	local v = Instance.new("ViewportFrame")
	v.BackgroundTransparency = 1
	v.BorderSizePixel = 0
	v.Size = UDim2.fromScale(1, 1)
	applyProps(v, props)
	PlanetVisual.mount(v, planetId, variant, evolved)
	v.Parent = parent
	return v
end

-- Tarjeta de planeta. data = { Id, V, E, L, Placed, Silhouette }. opts: Size, OnClick, ShowRate
function Kit.planetCard(parent, data, opts)
	opts = opts or {}
	local def = Defs.Planets.ById[data.Id]
	local rarity = Defs.Rarities.ById[def.Rarity]
	local variant = Defs.Variants.get(data.V)
	local card = Instance.new("TextButton")
	card.Name = "PlanetCard"
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = C.Row
	card.BorderSizePixel = 0
	card.Size = opts.Size or UDim2.fromOffset(118, 150)
	Kit.corner(card, 10)
	local stroke = Kit.stroke(card, rarity.Color, 1.5, 0.1)
	stroke.Name = "Edge"
	Kit.gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 210), 90)

	local view = Kit.viewport(card, data.Id, data.V, data.E, { Size = UDim2.new(1, -8, 0.56, 0), Position = UDim2.fromOffset(4, 4) })
	if data.Silhouette then
		view.ImageColor3 = Color3.new(0, 0, 0)
		view.ImageTransparency = 0.25
	end
	local name = data.Silhouette and "???" or Defs.Planets.displayName(def, data.E)
	Kit.label(card, name, { Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 0.58, 0), TextSize = 13,
		AlignX = Enum.TextXAlignment.Center })
	Kit.label(card, Kit.rarityText(def.Rarity), { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 0.58, 18), TextSize = 11,
		AlignX = Enum.TextXAlignment.Center, Color = rarity.Color })
	if opts.ShowRate ~= false and not data.Silhouette then
		Kit.label(card, "⚡ " .. Format.rate(Progression.planetRate({ Id = data.Id, V = data.V or "none", E = data.E == true })),
			{ Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 0.58, 34), TextSize = 12, AlignX = Enum.TextXAlignment.Center,
				Color = C.Energy })
	end
	if variant.Id ~= "none" then
		local tag = Kit.box(card, C.Dark, 0.25, { Size = UDim2.fromOffset(64, 16), Position = UDim2.fromOffset(4, 4) }, 6)
		Kit.label(tag, variant.Icon .. " " .. string.upper(variant.Name), { Size = UDim2.fromScale(1, 1), TextSize = 10,
			AlignX = Enum.TextXAlignment.Center, Color = variant.Color })
	end
	if data.L then
		Kit.label(card, "🔒", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -22, 0, 3), TextSize = 13 })
	end
	if data.Placed then
		local ribbon = Kit.box(card, C.Cyan, 0.1, { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 0.56, -12) }, 5)
		Kit.label(ribbon, "EN ÓRBITA", { Size = UDim2.fromScale(1, 1), TextSize = 10, AlignX = Enum.TextXAlignment.Center, Color = C.Dark })
	end
	if opts.OnClick then
		card.Activated:Connect(function()
			if Kit.onClick then Kit.onClick() end
			opts.OnClick(card)
		end)
	end
	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = C.RowHover
	end)
	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = C.Row
	end)
	card.Parent = parent
	return card
end

-- Fila de "icono + valor" usada en resumenes
function Kit.stat(parent, title, value, color, order)
	local row = Kit.box(parent, C.Row, 0.15, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order or 0 }, 8)
	Kit.label(row, title, { Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 13, Color = C.TextDim })
	local v = Kit.label(row, value, { Size = UDim2.new(0.4, -10, 1, 0), Position = UDim2.new(0.6, 0, 0, 0), TextSize = 14,
		AlignX = Enum.TextXAlignment.Right, Color = color or C.Text })
	return row, v
end

return Kit
