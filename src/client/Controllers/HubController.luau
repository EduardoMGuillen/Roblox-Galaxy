-- HubController: vida del Cosmic Hub en el cliente. Interpreta los ProximityPrompts de las
-- instalaciones, anima el holograma central y las capsulas, rellena los tableros (probabilidades,
-- leaderboard, evento) y muestra los meteoritos de Meteor Shower.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)

local Hub = {}
local ctx = nil
local player = Players.LocalPlayer
local hub = nil
local animated = {} -- { Model, Base, Kind, Phase }
local boardLabels = {}
local leaderboardIndex = 1
local meteorFolder = nil

local LEADERBOARD = {
	{ "Rate", "PRODUCCIÓN (ENERGY/S)", function(v) return Format.rate(v) end },
	{ "Value", "VALOR DEL UNIVERSO", function(v) return Format.number(v) end },
	{ "Ascensions", "ASCENSIONES", function(v) return Format.number(v) end },
	{ "Discoveries", "PLANETAS DESCUBIERTOS", function(v) return Format.number(v) end },
	{ "Rares", "PLANETAS RAROS", function(v) return Format.number(v) end },
}

---------------------------------------------------------------- prompts
local function onPrompt(prompt, who)
	if who ~= player then return end
	local action = prompt:GetAttribute("Action")
	if type(action) ~= "string" then return end
	local capsule = string.match(action, "^Capsule:(.+)$")
	if capsule then
		ctx.UI.open("Capsules", { Capsule = capsule })
	elseif action == "Portal" then
		ctx.UI.open("Teleport")
	elseif action == "Market" then
		ctx.UI.open("Trading")
	elseif action == "Event" then
		ctx.UI.open("Event")
	elseif action == "Leaderboard" then
		ctx.UI.open("Leaderboard")
	elseif action == "Upgrades" then
		ctx.UI.open("Upgrades")
	elseif action == "Capsules" then
		ctx.UI.open("Capsules")
	elseif action == "Galaxy" then
		ctx.UI.open("Galaxy")
	elseif action == "Collection" then
		ctx.UI.open("Collection")
	elseif action == "Hub" then
		local result = ctx.UI.request("Teleport", "hub")
		if result.Ok and ctx.Audio then ctx.Audio.play("portal") end
	end
end

---------------------------------------------------------------- tableros
local function boardLabel(name, textSize)
	local boards = hub:FindFirstChild("Boards")
	local board = (boards and boards:FindFirstChild(name)) or hub:FindFirstChild(name, true)
	local panel = board and board:FindFirstChild("Panel")
	if not panel then return nil end
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Adornee = panel
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Build.label(gui, "", { Size = UDim2.fromScale(0.94, 0.92), Position = UDim2.fromScale(0.03, 0.04), TextScaled = false,
		TextSize = textSize, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true })
	boardLabels[name] = label
	return label
end

local function hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function updateOdds()
	local label = boardLabels.Board_Odds
	if not label then return end
	local lines = { "<font size=\"44\"><b>CAPSULE PROBABILITIES</b></font>  <font color=\"#A0AFD2\">probabilidades reales</font>" }
	for _, def in ipairs(Defs.Capsules.List) do
		local parts = {}
		for _, entry in ipairs(Defs.Capsules.oddsList(def, Defs.Rarities.Order)) do
			local rarity = Defs.Rarities.ById[entry.Rarity]
			table.insert(parts, "<font color=\"" .. hex(rarity.Color) .. "\">" .. rarity.Icon .. " " .. rarity.Name .. " " .. Format.percent(entry.Chance)
				.. "</font>")
		end
		table.insert(lines, "<font color=\"" .. hex(def.Color) .. "\"><b>" .. def.Name .. "</b></font>  ⚡" .. Format.number(def.Price))
		table.insert(lines, "   " .. table.concat(parts, "   "))
	end
	label.Text = table.concat(lines, "\n")
end

local function updateLeaderboard()
	local label = boardLabels.Board_Leaderboard
	if not label then return end
	local category = LEADERBOARD[leaderboardIndex]
	local board = ctx.State.Leaderboards[category[1]] or {}
	local lines = { "<font size=\"50\"><b>LEADERBOARD</b></font>", "<font color=\"#C8AAFF\">" .. category[2] .. "</font>" }
	for rank = 1, 8 do
		local entry = board[rank]
		if entry then
			local color = (rank == 1 and "#FFC850") or (rank == 2 and "#D2DCF0") or (rank == 3 and "#E6A064") or "#F0F5FF"
			table.insert(lines, "<font color=\"" .. color .. "\">" .. rank .. ".  " .. entry.Name .. "</font>   <font color=\"#46D7FF\">"
				.. category[3](entry.Value) .. "</font>")
		end
	end
	if #board == 0 then table.insert(lines, "Aún sin datos. ¡Sé el primero!") end
	label.Text = table.concat(lines, "\n")
end

local function updateEventBoard()
	local label = boardLabels.Board_Event
	if not label then return end
	local event = ctx.State.Data._Event
	if not event then return end
	local now = ctx.State.serverTime()
	if event.Id and now < (event.EndsAt or 0) then
		local def = Defs.Events.ById[event.Id]
		label.Text = "<font size=\"46\" color=\"" .. hex(def.Color) .. "\"><b>" .. def.Icon .. " " .. string.upper(def.Name) .. "</b></font>\n"
			.. "<font size=\"40\">Termina en " .. Format.clock(event.EndsAt - now) .. "</font>\n" .. def.Description
	else
		local def = Defs.Events.ById[event.NextId]
		label.Text = "<font size=\"40\"><b>COSMIC EVENTS</b></font>\nPróximo: <font color=\"" .. hex(def.Color) .. "\">" .. def.Icon .. " " .. def.Name
			.. "</font>\n<font size=\"46\">" .. Format.clock(math.max(0, event.NextStartsAt - now)) .. "</font>"
	end
end

---------------------------------------------------------------- animacion ambiental
local function collectAnimated()
	animated = {}
	local core = hub:FindFirstChild("Core")
	if core then
		local globe = core:FindFirstChild("HubGlobe")
		if globe then table.insert(animated, { Model = globe, Base = globe:GetPivot(), Kind = "spin", Speed = 0.25 }) end
		for i = 1, 3 do
			local ring = core:FindFirstChild("HoloRing" .. i)
			if ring then
				table.insert(animated, { Model = ring, Base = ring:GetPivot(), Kind = "spin", Speed = 0.35 * (i % 2 == 0 and -1 or 1) })
			end
		end
	end
	local station = hub:FindFirstChild("CapsuleStation")
	if station then
		for index, machine in ipairs(station:GetChildren()) do
			local capsule = machine:IsA("Model") and machine:FindFirstChild("Capsule")
			if capsule then
				table.insert(animated, { Model = capsule, Base = capsule:GetPivot(), Kind = "bob", Phase = index * 1.3 })
			end
		end
	end
end

local function animate()
	if ctx.State.locationOwner() ~= nil then return end
	local t = os.clock()
	for _, item in ipairs(animated) do
		if item.Kind == "spin" then
			item.Model:PivotTo(item.Base * CFrame.Angles(0, t * item.Speed % (math.pi * 2), 0))
		else
			item.Model:PivotTo(item.Base * CFrame.new(0, math.sin(t * 1.6 + item.Phase) * 0.35, 0) * CFrame.Angles(0, t * 0.8 % (math.pi * 2), 0))
		end
	end
end

---------------------------------------------------------------- meteoritos
local function spawnMeteor(info)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local rng = Random.new(info.Seed)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(10, 26)
	local ground = root.Position.Y - 2.2
	local target = Vector3.new(root.Position.X + math.cos(angle) * dist, ground, root.Position.Z + math.sin(angle) * dist)
	local meteor = Build.ball({ Position = target + Vector3.new(rng:NextNumber(-30, 30), 90, rng:NextNumber(-30, 30)), Radius = 1.4 },
		{ Name = "Meteor", Color = Color3.fromRGB(255, 170, 80), Material = Enum.Material.Neon, CanCollide = false })
	Build.light(meteor, Color3.fromRGB(255, 170, 80), 18, 2)
	Build.particles(meteor, { Texture = Build.ParticleTextures.Fire, Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30)),
		Rate = 30, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(1, 3), Size = Build.sizeSeq(2.2) })
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 60
	click.Parent = meteor
	meteor.Parent = meteorFolder
	local collected = false
	local function collect()
		if collected then return end
		collected = true
		local result = ctx.State.call("CollectMeteor", info.Id)
		if result.Ok then
			ctx.UI.toast("☄️ +" .. result.Data.Stardust .. " Stardust", "reward")
			if ctx.Audio then ctx.Audio.play("collect") end
		end
		meteor:Destroy()
	end
	click.MouseClick:Connect(collect)
	meteor.Touched:Connect(function(hit)
		if hit:IsDescendantOf(player.Character or meteorFolder) then collect() end
	end)
	-- caida
	task.spawn(function()
		local start = meteor.Position
		local t = 0
		while t < 1 and meteor.Parent do
			t = math.min(1, t + RunService.Heartbeat:Wait() / 1.2)
			meteor.CFrame = CFrame.new(start:Lerp(target + Vector3.new(0, 1.4, 0), t * t))
		end
	end)
	task.delay(info.Lifetime or 14, function()
		if meteor.Parent then meteor:Destroy() end
	end)
end

function Hub.init(context)
	ctx = context
	ctx.Hub = Hub
	hub = Workspace:WaitForChild("CosmicHub")
	meteorFolder = Workspace:FindFirstChild("EventEnvironment") or Workspace

	ProximityPromptService.PromptTriggered:Connect(onPrompt)

	boardLabel("Board_Odds", 30)
	boardLabel("Board_Leaderboard", 38)
	boardLabel("Board_Event", 30)
	updateOdds()
	updateLeaderboard()
	updateEventBoard()
	ctx.State.onLeaderboard(updateLeaderboard)

	collectAnimated()
	RunService.Heartbeat:Connect(animate)
	local accumulator, cycle = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		cycle = cycle + dt
		if accumulator >= 1 then
			accumulator = 0
			updateEventBoard()
		end
		if cycle >= 8 then
			cycle = 0
			leaderboardIndex = leaderboardIndex % #LEADERBOARD + 1
			updateLeaderboard()
		end
	end)

	ctx.State.remotes():WaitForChild("Meteor").OnClientEvent:Connect(function(info)
		local ok, err = pcall(spawnMeteor, info)
		if not ok then warn("[Hub] meteor: " .. tostring(err)) end
	end)
end

return Hub
