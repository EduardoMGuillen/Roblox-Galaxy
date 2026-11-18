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

local function makeScreen(name, order, ignoreInset)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoreInset
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Name = "ScreenScale"
	scale.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(size.Y / 900, size.X / 1500), 0.5, 1.35)
	local large = State.Data.Settings and State.Data.Settings.LargeText
	if large then s = s * 1.12 end
	for _, gui in ipairs({ hudGui, panelGui, overlayGui }) do
		local scale = gui:FindFirstChild("ScreenScale")
		if scale then scale.Scale = s end
	end
end

function UI.overlay()
	return overlayGui
end

function UI.context()
	return ctx
end

---------------------------------------------------------------- avisos
local TOAST_COLORS = { info = C.Cyan, error = C.Red, reward = C.Gold, secret = C.Magenta, event = C.Gold,
	collection = C.Green, system = C.Violet }

function UI.toast(text, kind)
	kind = kind or "info"
	local color = TOAST_COLORS[kind] or C.Cyan
	local big = kind == "secret" or kind == "collection" or kind == "system"
	local box = Kit.box(toastHolder, C.Panel, 0.05, { Size = UDim2.fromOffset(big and 620 or 520, big and 58 or 44) }, 10)
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

local function squareButton(parent, icon, text, size, order, onClick)
	local b = Kit.button(parent, "", "ghost", { Size = size, Props = { LayoutOrder = order } }, onClick)
	Kit.label(b, icon, { Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.fromScale(0, 0.06), TextSize = math.floor(size.Y.Offset * 0.4),
		AlignX = Enum.TextXAlignment.Center }).Name = "Icon"
	Kit.label(b, text, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.64), TextSize = 13,
		AlignX = Enum.TextXAlignment.Center, Stroke = true }).Name = "Caption"
	return b
end

local function buildHud()
	local root = Kit.frame(hudGui, { Name = "Root", Size = UDim2.fromScale(1, 1) })
	hud.Root = root

	-- superior izquierda: Energy, Energy/s y monedas secundarias
	local energy = pill(root, UDim2.fromOffset(270, 54), UDim2.fromOffset(16, 16), nil, C.Energy)
	energy.Name = "Energy"
	Kit.label(energy, "⚡", { Size = UDim2.fromOffset(44, 54), Position = UDim2.fromOffset(8, 0), TextSize = 30, AlignX = Enum.TextXAlignment.Center })
	hud.Energy = Kit.label(energy, "0", { Size = UDim2.new(1, -106, 1, 0), Position = UDim2.fromOffset(54, 0), TextSize = 27, Font = F.Black,
		Stroke = true })
	Kit.button(energy, "+", "cyan", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -46, 0, 8), TextSize = 24 }, function()
		UI.toggle("Stats")
	end).Name = "Plus"
	local rate = pill(root, UDim2.fromOffset(190, 34), UDim2.fromOffset(24, 76), nil, C.Cyan)
	rate.Name = "Rate"
	hud.Rate = Kit.label(rate, "0/s", { Size = UDim2.fromScale(1, 1), TextSize = 18, AlignX = Enum.TextXAlignment.Center, Color = C.Cyan })
	local stardust = pill(root, UDim2.fromOffset(124, 30), UDim2.fromOffset(24, 116), nil, C.Stardust)
	stardust.Name = "Stardust"
	hud.Stardust = Kit.label(stardust, "✨ 0", { Size = UDim2.fromScale(1, 1), TextSize = 14, AlignX = Enum.TextXAlignment.Center, Color = C.Stardust })
	local cores = pill(root, UDim2.fromOffset(110, 30), UDim2.fromOffset(154, 116), nil, C.Cores)
	cores.Name = "Cores"
	hud.Cores = Kit.label(cores, "💠 0", { Size = UDim2.fromScale(1, 1), TextSize = 14, AlignX = Enum.TextXAlignment.Center, Color = C.Cores })

	-- superior derecha: ascension, estadisticas y clasificacion
	hud.Rebirth = Kit.button(root, "♻  REBIRTH", "primary", { Size = UDim2.fromOffset(236, 54), Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0), TextSize = 22, Font = F.Black }, function()
		UI.toggle("Rebirth")
	end)
	hud.Rebirth.Name = "Rebirth"
	local asc = pill(root, UDim2.fromOffset(236, 36), UDim2.new(1, -16, 0, 78), Vector2.new(1, 0), C.Gold)
	asc.Name = "Ascension"
	hud.Ascension = Kit.label(asc, "👑 Ascensión: 0", { Size = UDim2.fromScale(1, 1), TextSize = 17, AlignX = Enum.TextXAlignment.Center, Color = C.Gold })
	local topButtons = Kit.frame(root, { Name = "TopButtons", Size = UDim2.fromOffset(236, 44), Position = UDim2.new(1, -16, 0, 122),
		AnchorPoint = Vector2.new(1, 0) })
	Kit.listLayout(topButtons, 8, true)
	Kit.button(topButtons, "📊 Estadísticas", "ghost", { Size = UDim2.fromOffset(114, 40), TextSize = 12, Props = { LayoutOrder = 1 } }, function()
		UI.toggle("Stats")
	end).Name = "Stats"
	Kit.button(topButtons, "🏅 Ranking", "ghost", { Size = UDim2.fromOffset(114, 40), TextSize = 12, Props = { LayoutOrder = 2 } }, function()
		UI.toggle("Leaderboard")
	end).Name = "Leaderboard"

	-- lateral izquierdo
	local left = Kit.frame(root, { Name = "Left", Size = UDim2.fromOffset(104, 470), Position = UDim2.new(0, 16, 0.5, 30), AnchorPoint = Vector2.new(0, 0.5) })
	Kit.listLayout(left, 8, false)
	local leftSize = UDim2.fromOffset(104, 86)
	squareButton(left, "🎒", "Inventario", leftSize, 1, function() UI.toggle("Inventory") end).Name = "Inventory"
	squareButton(left, "📖", "Colección", leftSize, 2, function() UI.toggle("Collection") end).Name = "Collection"
	hud.Missions = squareButton(left, "🏆", "Misiones", leftSize, 3, function() UI.toggle("Missions") end)
	hud.Missions.Name = "Missions"
	squareButton(left, "🔁", "Trading", leftSize, 4, function() UI.toggle("Trading") end).Name = "Trading"
	squareButton(left, "⚙️", "Ajustes", leftSize, 5, function() UI.toggle("Settings") end).Name = "Settings"
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
	Kit.label(hud.UniverseCard, "🌌", { Size = UDim2.fromOffset(84, 96), Position = UDim2.fromOffset(6, 0), TextSize = 50, AlignX = Enum.TextXAlignment.Center })
	hud.UniverseTitle = Kit.label(hud.UniverseCard, "Tu Universo", { Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(96, 16),
		TextSize = 15, Color = C.TextDim })
	hud.UniverseName = Kit.label(hud.UniverseCard, "Solar System", { Size = UDim2.new(1, -150, 0, 34), Position = UDim2.fromOffset(96, 44),
		TextSize = 23, Stroke = true })
	Kit.label(hud.UniverseCard, "›", { Size = UDim2.fromOffset(40, 96), Position = UDim2.new(1, -46, 0, -4), TextSize = 50, Color = C.Cyan,
		AlignX = Enum.TextXAlignment.Center })

	-- inferior centro: capsulas
	hud.Capsule = Kit.button(root, "", "primary", { Size = UDim2.fromOffset(310, 100), Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1), Radius = 22 }, function()
		UI.toggle("Capsules")
	end)
	hud.Capsule.Name = "OpenCapsule"
	Kit.label(hud.Capsule, "💊", { Size = UDim2.fromOffset(90, 100), Position = UDim2.fromOffset(14, 0), TextSize = 52, AlignX = Enum.TextXAlignment.Center })
	Kit.label(hud.Capsule, "OPEN\nCAPSULE", { Size = UDim2.new(1, -112, 1, 0), Position = UDim2.fromOffset(104, 0), TextSize = 27, Font = F.Black,
		Stroke = true, Wrap = true, Props = { LineHeight = 1.05 } })

	-- inferior derecha: mejoras, teletransporte y tienda
	local right = Kit.frame(root, { Name = "Right", Size = UDim2.fromOffset(400, 104), Position = UDim2.new(1, -16, 1, -16), AnchorPoint = Vector2.new(1, 1) })
	local rightLayout = Kit.listLayout(right, 10, true)
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local rightSize = UDim2.fromOffset(124, 104)
	squareButton(right, "📈", "Mejoras", rightSize, 1, function() UI.toggle("Upgrades") end).Name = "Upgrades"
	squareButton(right, "🌀", "Teleport", rightSize, 2, function() UI.toggle("Teleport") end).Name = "Teleport"
	squareButton(right, "🛍️", "Tienda", rightSize, 3, function() UI.toggle("Shop") end).Name = "Shop"

	-- superior centro: evento y aviso de visita
	hud.Event = Kit.button(root, "", "ghost", { Size = UDim2.fromOffset(400, 44), Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0), TextSize = 15 }, function()
		UI.toggle("Event")
	end)
	hud.Event.Name = "EventChip"
	hud.Visit = pill(root, UDim2.fromOffset(460, 34), UDim2.new(0.5, 0, 0, 64), Vector2.new(0.5, 0), C.Violet)
	hud.Visit.Name = "VisitBanner"
	hud.Visit.Visible = false
	hud.VisitText = Kit.label(hud.Visit, "", { Size = UDim2.fromScale(1, 1), TextSize = 14, AlignX = Enum.TextXAlignment.Center, Color = C.Stardust })

	toastHolder = Kit.frame(overlayGui, { Name = "Toasts", Size = UDim2.fromOffset(640, 400), Position = UDim2.new(0.5, 0, 0, 108),
		AnchorPoint = Vector2.new(0.5, 0) })
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
		hud.UniverseTitle.Text = "Sistemas de tu universo"
		hud.UniverseName.Text = system.Name
		hud.Visit.Visible = false
	else
		local view = State.Universes[owner]
		hud.UniverseTitle.Text = "Visitando a " .. (view and view.Name or "otro jugador")
		hud.UniverseName.Text = "Volver al Hub"
		hud.Visit.Visible = true
		hud.VisitText.Text = "👁 Universo de " .. (view and view.Name or "?") .. " · modo solo lectura"
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
	hudGui.Enabled = visible
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
