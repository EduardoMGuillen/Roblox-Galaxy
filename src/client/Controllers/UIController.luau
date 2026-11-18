-- UIController: HUD principal, gestor de paneles, avisos (toasts) y dialogos de confirmacion.
-- El mundo 3D es el foco: los paneles se abren bajo demanda y solo uno a la vez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Format = require(Shared.Util.Format)
local Progression = require(Shared.Progression)
local Client = script.Parent.Parent
local State = require(Client.ClientState)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local C, F = Theme.Colors, Theme.Fonts

local UI = {}

local player = Players.LocalPlayer
local playerGui = nil
local hudGui, panelGui, overlayGui = nil, nil, nil
local panels = {} -- [nombre] = { Frame, OnOpen, OnClose }
local current = nil
local ctx = nil
local toastHolder = nil
local hud = {}
local openListeners = {}

UI.Hud = hud

local screens = {} -- [contenedor] = ScreenGui

-- Crea una ScreenGui con un marco raiz escalable. El UIScale vive en el marco (un GuiObject) y el
-- marco mide 1/escala de la pantalla, asi que tras escalar ocupa exactamente toda la pantalla.
-- Devuelve el marco raiz, que es donde se colocan los elementos.
local function makeScreen(name, order, ignoreInset)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "ScreenScale"
	scale.Parent = root
	gui.Parent = playerGui
	screens[root] = gui
	return root
end

local compact = false
local layoutListeners = {}

-- Posiciones y tamaños del HUD: modo normal (escritorio/tablet) y compacto (moviles apaisados)
local LAYOUTS = {
	normal = {
		Energy = { UDim2.fromOffset(16, 16), UDim2.fromOffset(270, 54) },
		Rate = { UDim2.fromOffset(24, 76), UDim2.fromOffset(190, 34) },
		Stardust = { UDim2.fromOffset(24, 116), UDim2.fromOffset(124, 30) },
		Cores = { UDim2.fromOffset(154, 116), UDim2.fromOffset(110, 30) },
		Rebirth = { UDim2.new(1, -16, 0, 16), UDim2.fromOffset(236, 54) },
		Ascension = { UDim2.new(1, -16, 0, 78), UDim2.fromOffset(236, 36) },
		TopButtons = { UDim2.new(1, -16, 0, 122), UDim2.fromOffset(236, 44), UDim2.fromOffset(114, 40) },
		Left = { UDim2.new(0, 16, 0.5, 30), UDim2.fromOffset(104, 470), UDim2.fromOffset(104, 86), Vector2.new(0, 0.5), 34 },
		UniverseCard = { UDim2.new(0, 16, 1, -16), UDim2.fromOffset(370, 96) },
		Capsule = { UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(310, 100) },
		Right = { UDim2.new(1, -16, 1, -16), UDim2.fromOffset(400, 104), UDim2.fromOffset(124, 104), Vector2.new(1, 1), 40 },
		Event = { UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(400, 44) },
		Visit = { UDim2.new(0.5, 0, 0, 64), UDim2.fromOffset(460, 34) },
		Toasts = { UDim2.new(0.5, 0, 0, 108), UDim2.fromOffset(640, 400) },
		CapsuleText = 27, RebirthText = 22,
	},
	compact = {
		Energy = { UDim2.fromOffset(12, 6), UDim2.fromOffset(240, 46) },
		Rate = { UDim2.fromOffset(12, 56), UDim2.fromOffset(130, 28) },
		Stardust = { UDim2.fromOffset(146, 56), UDim2.fromOffset(106, 28) },
		Cores = { UDim2.fromOffset(12, 88), UDim2.fromOffset(100, 26) },
		Rebirth = { UDim2.new(1, -12, 0, 6), UDim2.fromOffset(190, 44) },
		Ascension = { UDim2.new(1, -12, 0, 54), UDim2.fromOffset(190, 30) },
		TopButtons = { UDim2.new(1, -12, 0, 88), UDim2.fromOffset(190, 36), UDim2.fromOffset(91, 34) },
		Left = { UDim2.fromOffset(12, 122), UDim2.fromOffset(190, 200), UDim2.fromOffset(90, 60), Vector2.new(0, 0), 24 },
		UniverseCard = { UDim2.new(0, 12, 1, -10), UDim2.fromOffset(290, 70) },
		Capsule = { UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(250, 76) },
		Right = { UDim2.new(1, -12, 1, -10), UDim2.fromOffset(310, 78), UDim2.fromOffset(96, 78), Vector2.new(1, 1), 30 },
		Event = { UDim2.new(0.5, 0, 0, 6), UDim2.fromOffset(330, 36) },
		Visit = { UDim2.new(0.5, 0, 0, 46), UDim2.fromOffset(400, 28) },
		Toasts = { UDim2.new(0.5, 0, 0, 80), UDim2.fromOffset(640, 300) },
		CapsuleText = 21, RebirthText = 18,
	},
}

local function applyLayout()
	local spec = compact and LAYOUTS.compact or LAYOUTS.normal
	for _, name in ipairs({ "Energy", "Rate", "Stardust", "Cores", "Rebirth", "Ascension", "UniverseCard", "Capsule", "Event", "Visit", "Toasts" }) do
		local item = hud.Items[name]
		item.Position = spec[name][1]
		item.Size = spec[name][2]
	end
	for _, name in ipairs({ "TopButtons", "Left", "Right" }) do
		local item = hud.Items[name]
		local grid = item:FindFirstChildOfClass("UIGridLayout")
		item.Position = spec[name][1]
		item.Size = spec[name][2]
		grid.CellSize = spec[name][3]
		if spec[name][4] then item.AnchorPoint = spec[name][4] end
		if spec[name][5] then
			for _, child in ipairs(item:GetChildren()) do
				local icon = child:FindFirstChild("Icon")
				if icon then icon.TextSize = spec[name][5] end
			end
		end
	end
	hud.CapsuleText.TextSize = spec.CapsuleText
	hud.Rebirth.TextSize = spec.RebirthText
	for _, fn in ipairs(layoutListeners) do
		task.spawn(fn, compact)
	end
end

function UI.isCompact()
	return compact
end

-- fn(compact) se llama cada vez que cambia el modo de layout (y una vez al registrarse)
function UI.onLayout(fn)
	table.insert(layoutListeners, fn)
	task.spawn(fn, compact)
end

local function setScale(root, value)
	local scale = root:FindFirstChild("ScreenScale")
	if scale then scale.Scale = value end
	root.Size = UDim2.fromScale(1 / value, 1 / value)
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local large = State.Data.Settings and State.Data.Settings.LargeText
	local boost = large and 1.12 or 1
	local wasCompact = compact
	compact = size.Y < 600
	local hudScale
	if compact then
		hudScale = math.clamp(math.min(size.Y / 540, size.X / 1150), 0.5, 0.9)
	else
		hudScale = math.clamp(math.min(size.Y / 900, size.X / 1500), 0.6, 1.35)
	end
	-- los paneles (hasta 980x580) siempre deben caber en pantalla
	local panelScale = math.clamp(math.min(size.X / 1010, size.Y / 610), 0.4, 1.35)
	setScale(hudGui, hudScale * boost)
	setScale(panelGui, panelScale)
	setScale(overlayGui, panelScale)
	if compact ~= wasCompact or not hud.LayoutApplied then
		hud.LayoutApplied = true
		applyLayout()
	end
end

function UI.overlay()
	return overlayGui
end

function UI.context()
	return ctx
end

---------------------------------------------------------------- avisos
local toastCount = 0
local TOAST_COLORS = { info = C.Cyan, error = C.Red, reward = C.Gold, secret = C.Magenta, event = C.Gold,
	collection = C.Green, system = C.Violet }

function UI.toast(text, kind)
	kind = kind or "info"
	local color = TOAST_COLORS[kind] or C.Cyan
	local big = kind == "secret" or kind == "collection" or kind == "system"
	toastCount = toastCount + 1
	local box = Kit.box(toastHolder, C.Panel, 0.05, { Size = UDim2.fromOffset(big and 620 or 520, big and 58 or 44), LayoutOrder = toastCount }, 10)
	Kit.stroke(box, color, 2, 0)
	local label = Kit.label(box, text, { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = big and 16 or 14,
		AlignX = Enum.TextXAlignment.Center, Wrap = true, Color = big and color or C.Text })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = box
	Kit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(big and 6 or 3.5, function()
		if box.Parent then
			Kit.tween(box, 0.3, { BackgroundTransparency = 1 })
			Kit.tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.32)
			box:Destroy()
		end
	end)
	return box
end

-- Llama al servidor y muestra el error si lo hay. Devuelve el resultado.
function UI.request(name, ...)
	local result = State.call(name, ...)
	if not result.Ok and result.Code ~= "rate" then
		UI.toast(result.Error or "No se pudo completar la acción.", "error")
	end
	return result
end

-- Dialogo de confirmacion. opts: Title, Text, Confirm, Cancel, Style, OnConfirm
function UI.confirm(opts)
	local shade = Kit.frame(overlayGui, { Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.45, Active = true, ZIndex = 50 })
	local frame, body = Kit.panel(shade, { Size = UDim2.fromOffset(460, 250), Title = opts.Title or "Confirmar", Icon = opts.Icon })
	Kit.label(body, opts.Text or "", { Size = UDim2.new(1, 0, 1, -56), TextSize = 15, Wrap = true, AlignY = Enum.TextYAlignment.Top,
		Color = C.TextDim, Font = F.Body })
	local function close()
		shade:Destroy()
	end
	Kit.button(body, opts.Cancel or "Cancelar", "ghost", { Size = UDim2.fromOffset(190, 42), Position = UDim2.new(0, 0, 1, -44) }, close)
	Kit.button(body, opts.Confirm or "Confirmar", opts.Style or "primary", { Size = UDim2.fromOffset(190, 42), Position = UDim2.new(1, -190, 1, -44) },
		function()
			close()
			if opts.OnConfirm then opts.OnConfirm() end
		end).Name = "ConfirmButton"
	return frame
end

---------------------------------------------------------------- paneles
function UI.onOpen(fn)
	table.insert(openListeners, fn)
end

function UI.isOpen(name)
	if name then return current == name end
	return current ~= nil
end

function UI.close()
	if not current then return end
	local panel = panels[current]
	current = nil
	if panel then
		panel.Frame.Visible = false
		if panel.OnClose then panel.OnClose() end
	end
	for _, fn in ipairs(openListeners) do
		task.spawn(fn, nil)
	end
end

function UI.open(name, args)
	if current and current ~= name then UI.close() end
	local panel = panels[name]
	if not panel then
		local module = Client.UI.Panels:FindFirstChild(name)
		if not module then
			warn("[UI] panel desconocido: " .. tostring(name))
			return
		end
		panel = require(module)(ctx, panelGui)
		panel.Frame.Visible = false
		panels[name] = panel
	end
	current = name
	panel.Frame.Visible = true
	local scale = panel.Frame:FindFirstChild("Pop")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "Pop"
		scale.Parent = panel.Frame
	end
	scale.Scale = 0.88
	Kit.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	if panel.OnOpen then panel.OnOpen(args or {}) end
	for _, fn in ipairs(openListeners) do
		task.spawn(fn, name)
	end
end

function UI.toggle(name, args)
	if current == name then UI.close() else UI.open(name, args) end
end

-- Refresca el panel abierto (si expone Refresh)
function UI.refresh(name)
	local panel = panels[name]
	if panel and current == name and panel.Refresh then panel.Refresh() end
end

---------------------------------------------------------------- HUD
local function pill(parent, size, position, anchor, strokeColor)
	local box = Kit.box(parent, C.Panel, 0.12, { Size = size, Position = position, AnchorPoint = anchor or Vector2.new(0, 0) }, 12)
	Kit.stroke(box, strokeColor or C.Cyan, 1.5, 0.15)
	return box
end

local function squareButton(parent, icon, text, order, onClick)
	local b = Kit.button(parent, "", "ghost", { Props = { LayoutOrder = order } }, onClick)
	Kit.label(b, icon, { Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.06), TextSize = 34,
		AlignX = Enum.TextXAlignment.Center }).Name = "Icon"
	Kit.label(b, text, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.64), TextSize = 13,
		AlignX = Enum.TextXAlignment.Center, Stroke = true }).Name = "Caption"
	return b
end

local function gridFrame(parent, name, padding, alignRight)
	local frame = Kit.frame(parent, { Name = name })
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(padding, padding)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = alignRight and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	grid.Parent = frame
	return frame
end

local function buildHud()
	local root = hudGui
	hud.Root = root
	local items = {}
	hud.Items = items

	-- superior izquierda: Energy, Energy/s y monedas secundarias
	local energy = pill(root, UDim2.fromOffset(270, 54), UDim2.fromOffset(16, 16), nil, C.Energy)
	energy.Name = "Energy"
	items.Energy = energy
	Kit.label(energy, "⚡", { Size = UDim2.new(0, 44, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 28, AlignX = Enum.TextXAlignment.Center })
	hud.Energy = Kit.label(energy, "0", { Size = UDim2.new(1, -106, 1, 0), Position = UDim2.fromOffset(54, 0), TextSize = 26, Font = F.Black,
		Stroke = true })
	Kit.button(energy, "+", "cyan", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -44, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		TextSize = 24 }, function()
		UI.toggle("Stats")
	end).Name = "Plus"
	local rate = pill(root, UDim2.fromOffset(190, 34), UDim2.fromOffset(24, 76), nil, C.Cyan)
	rate.Name = "Rate"
	items.Rate = rate
	hud.Rate = Kit.label(rate, "0/s", { Size = UDim2.fromScale(1, 1), TextSize = 17, AlignX = Enum.TextXAlignment.Center, Color = C.Cyan })
	local stardust = pill(root, UDim2.fromOffset(124, 30), UDim2.fromOffset(24, 116), nil, C.Stardust)
	stardust.Name = "Stardust"
	items.Stardust = stardust
	hud.Stardust = Kit.label(stardust, "✨ 0", { Size = UDim2.fromScale(1, 1), TextSize = 14, AlignX = Enum.TextXAlignment.Center, Color = C.Stardust })
	local cores = pill(root, UDim2.fromOffset(110, 30), UDim2.fromOffset(154, 116), nil, C.Cores)
	cores.Name = "Cores"
	items.Cores = cores
	hud.Cores = Kit.label(cores, "💠 0", { Size = UDim2.fromScale(1, 1), TextSize = 14, AlignX = Enum.TextXAlignment.Center, Color = C.Cores })

	-- superior derecha: ascension, estadisticas y clasificacion
	hud.Rebirth = Kit.button(root, "🔄  REBIRTH", "primary", { Size = UDim2.fromOffset(236, 54), Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0), TextSize = 22, Font = F.Black }, function()
		UI.toggle("Rebirth")
	end)
	hud.Rebirth.Name = "Rebirth"
	items.Rebirth = hud.Rebirth
	local asc = pill(root, UDim2.fromOffset(236, 36), UDim2.new(1, -16, 0, 78), Vector2.new(1, 0), C.Gold)
	asc.Name = "Ascension"
	items.Ascension = asc
	hud.Ascension = Kit.label(asc, "👑 Ascensión: 0", { Size = UDim2.fromScale(1, 1), TextSize = 16, AlignX = Enum.TextXAlignment.Center, Color = C.Gold })
	local topButtons = gridFrame(root, "TopButtons", 8, true)
	topButtons.AnchorPoint = Vector2.new(1, 0)
	items.TopButtons = topButtons
	Kit.button(topButtons, "📊 Estadísticas", "ghost", { TextSize = 12, Props = { LayoutOrder = 1 } }, function()
		UI.toggle("Stats")
	end).Name = "Stats"
	Kit.button(topButtons, "🏅 Ranking", "ghost", { TextSize = 12, Props = { LayoutOrder = 2 } }, function()
		UI.toggle("Leaderboard")
	end).Name = "Leaderboard"

	-- lateral izquierdo
	local left = gridFrame(root, "Left", 8, false)
	items.Left = left
	squareButton(left, "🎒", "Inventario", 1, function() UI.toggle("Inventory") end).Name = "Inventory"
	squareButton(left, "📖", "Colección", 2, function() UI.toggle("Collection") end).Name = "Collection"
	hud.Missions = squareButton(left, "🏆", "Misiones", 3, function() UI.toggle("Missions") end)
	hud.Missions.Name = "Missions"
	squareButton(left, "🔁", "Trading", 4, function() UI.toggle("Trading") end).Name = "Trading"
	squareButton(left, "⚙️", "Ajustes", 5, function() UI.toggle("Settings") end).Name = "Settings"
	hud.MissionBadge = Kit.box(hud.Missions, C.Red, 0, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -18, 0, -4), Visible = false }, 11)
	hud.MissionBadgeText = Kit.label(hud.MissionBadge, "!", { Size = UDim2.fromScale(1, 1), TextSize = 13, AlignX = Enum.TextXAlignment.Center })

	-- inferior izquierda: tarjeta del universo
	hud.UniverseCard = Kit.button(root, "", "ghost", { Size = UDim2.fromOffset(370, 96), Position = UDim2.new(0, 16, 1, -16),
		AnchorPoint = Vector2.new(0, 1) }, function()
		local owner = State.locationOwner()
		if owner == nil then
			UI.request("Teleport", "universe")
		elseif owner == player.UserId then
			UI.toggle("Galaxy")
		else
			UI.request("Teleport", "hub")
		end
	end)
	hud.UniverseCard.Name = "UniverseCard"
	items.UniverseCard = hud.UniverseCard
	Kit.label(hud.UniverseCard, "🌌", { Size = UDim2.new(0, 76, 1, 0), Position = UDim2.fromOffset(6, 0), TextSize = 42, AlignX = Enum.TextXAlignment.Center })
	hud.UniverseTitle = Kit.label(hud.UniverseCard, "Tu Universo", { Size = UDim2.new(1, -130, 0.34, 0), Position = UDim2.new(0, 88, 0.14, 0),
		TextSize = 14, Color = C.TextDim })
	hud.UniverseName = Kit.label(hud.UniverseCard, "Solar System", { Size = UDim2.new(1, -130, 0.4, 0), Position = UDim2.new(0, 88, 0.46, 0),
		TextSize = 22, Stroke = true })
	Kit.label(hud.UniverseCard, ">", { Size = UDim2.new(0, 36, 1, 0), Position = UDim2.new(1, -42, 0, 0), TextSize = 32, Color = C.Cyan,
		AlignX = Enum.TextXAlignment.Center, Font = F.Black })

	-- inferior centro: capsulas
	hud.Capsule = Kit.button(root, "", "primary", { Size = UDim2.fromOffset(310, 100), Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1), Radius = 22 }, function()
		UI.toggle("Capsules")
	end)
	hud.Capsule.Name = "OpenCapsule"
	items.Capsule = hud.Capsule
	Kit.label(hud.Capsule, "💊", { Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.fromScale(0.03, 0), TextSize = 44, AlignX = Enum.TextXAlignment.Center })
	hud.CapsuleText = Kit.label(hud.Capsule, "OPEN\nCAPSULE", { Size = UDim2.new(0.64, 0, 1, 0), Position = UDim2.fromScale(0.34, 0), TextSize = 27,
		Font = F.Black, Stroke = true, Wrap = true, Props = { LineHeight = 1.05 } })

	-- inferior derecha: mejoras, teletransporte y tienda
	local right = gridFrame(root, "Right", 8, true)
	right.AnchorPoint = Vector2.new(1, 1)
	items.Right = right
	squareButton(right, "📈", "Mejoras", 1, function() UI.toggle("Upgrades") end).Name = "Upgrades"
	squareButton(right, "🌀", "Teleport", 2, function() UI.toggle("Teleport") end).Name = "Teleport"
	squareButton(right, "🛒", "Tienda", 3, function() UI.toggle("Shop") end).Name = "Shop"

	-- superior centro: evento y aviso de visita
	hud.Event = Kit.button(root, "", "ghost", { Size = UDim2.fromOffset(400, 44), Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0), TextSize = 14 }, function()
		UI.toggle("Event")
	end)
	hud.Event.Name = "EventChip"
	items.Event = hud.Event
	hud.Visit = pill(root, UDim2.fromOffset(460, 34), UDim2.new(0.5, 0, 0, 64), Vector2.new(0.5, 0), C.Violet)
	hud.Visit.Name = "VisitBanner"
	hud.Visit.Visible = false
	items.Visit = hud.Visit
	hud.VisitText = Kit.label(hud.Visit, "", { Size = UDim2.fromScale(1, 1), TextSize = 13, AlignX = Enum.TextXAlignment.Center, Color = C.Stardust })

	toastHolder = Kit.frame(overlayGui, { Name = "Toasts", Size = UDim2.fromOffset(640, 400), Position = UDim2.new(0.5, 0, 0, 108),
		AnchorPoint = Vector2.new(0.5, 0) })
	items.Toasts = toastHolder
	local layout = Kit.listLayout(toastHolder, 6, false)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

local function refreshStatic()
	local data = State.Data
	hud.Stardust.Text = "✨ " .. Format.number(data.Stardust or 0)
	hud.Cores.Text = "💠 " .. Format.number(data.Cores or 0)
	hud.Ascension.Text = "👑 Ascensión: " .. tostring(data.Ascensions or 0)
	hud.Rate.Text = Format.rate(State.rate())
	local system = Defs.Galaxy.ById[data.ActiveSystem or "solar"]
	local owner = State.locationOwner()
	if owner == nil then
		hud.UniverseTitle.Text = "Tu Universo"
		hud.UniverseName.Text = system.Name
		hud.Visit.Visible = false
	elseif owner == player.UserId then
		hud.UniverseTitle.Text = "Tu universo · sistemas"
		hud.UniverseName.Text = system.Name
		hud.Visit.Visible = false
	else
		local view = State.Universes[owner]
		hud.UniverseTitle.Text = "Visitando a " .. (view and view.Name or "otro jugador")
		hud.UniverseName.Text = "Volver al Hub"
		hud.Visit.Visible = true
		hud.VisitText.Text = "👀 Universo de " .. (view and view.Name or "?") .. " · modo solo lectura"
	end
	-- misiones reclamables
	local claimable = 0
	local missions = data.Missions
	if missions then
		for _, list in ipairs({ missions.Daily, missions.Weekly }) do
			for _, m in ipairs(list) do
				if m.Progress >= m.Goal and not m.Claimed then claimable = claimable + 1 end
			end
		end
	end
	hud.MissionBadge.Visible = claimable > 0
	hud.MissionBadgeText.Text = tostring(claimable)
	-- la ascension resalta cuando esta lista
	local milestone = Defs.Ascension.next(data.Ascensions or 0)
	local ready = true
	for _, req in ipairs(milestone.Requirements) do
		if not Progression.checkRequirement(data, req, State.rate()).Ok then ready = false end
	end
	Kit.setStyle(hud.Rebirth, ready and "gold" or "primary")
end

local function refreshEvent()
	local event = State.Data._Event
	if not event then
		hud.Event.Text = ""
		return
	end
	local now = State.serverTime()
	if event.Id and event.EndsAt and now < event.EndsAt then
		local def = Defs.Events.ById[event.Id]
		hud.Event.Text = def.Icon .. "  " .. def.Name .. "  ·  " .. Format.clock(event.EndsAt - now)
		Kit.setStyle(hud.Event, "gold")
	else
		local def = Defs.Events.ById[event.NextId]
		hud.Event.Text = "Próximo evento: " .. def.Icon .. " " .. def.Name .. " en " .. Format.clock(math.max(0, event.NextStartsAt - now))
		Kit.setStyle(hud.Event, "ghost")
	end
end

function UI.setHudVisible(visible)
	screens[hudGui].Enabled = visible
end

function UI.init(context)
	ctx = context
	ctx.UI = UI
	playerGui = player:WaitForChild("PlayerGui")
	-- el HUD respeta la barra superior de Roblox; paneles y overlays ocupan toda la pantalla
	hudGui = makeScreen("MainHUD", 5, false)
	panelGui = makeScreen("Panels", 10, true)
	overlayGui = makeScreen("Overlay", 20, true)
	buildHud()
	updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	State.on("Settings", updateScale)

	refreshStatic()
	refreshEvent()
	State.onAny(function(changed)
		if changed.Energy and not (changed.Stardust or changed.Cores or changed.Ascensions or changed._Production
			or changed.ActiveSystem or changed._Session or changed.Missions or changed.Planets or changed.Discovered) then
			return
		end
		refreshStatic()
	end)
	State.onUniverse(refreshStatic)

	local accumulator, eventAccumulator = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		eventAccumulator = eventAccumulator + dt
		if accumulator >= 0.1 then
			accumulator = 0
			hud.Energy.Text = Format.number(State.displayEnergy())
		end
		if eventAccumulator >= 0.5 then
			eventAccumulator = 0
			refreshEvent()
		end
	end)

	State.remotes():WaitForChild("Notify").OnClientEvent:Connect(function(message)
		UI.toast(message.Text, message.Kind)
		if ctx.Audio then
			if message.Kind == "secret" or message.Kind == "collection" or message.Kind == "system" then
				ctx.Audio.play("fanfare")
			elseif message.Kind == "reward" then
				ctx.Audio.play("success")
			end
		end
	end)
end

return UI
