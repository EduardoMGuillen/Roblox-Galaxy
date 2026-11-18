-- HubBuilder: construye el COSMIC HUB (estacion orbital compartida) por codigo.
-- Compacto y sin laberintos: desde el spawn se ven el nucleo central y las cinco instalaciones
-- (Capsule Station, Galactic Market, Leaderboard, Portal Room y Event Terminal).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local PlanetVisual = require(Shared.PlanetVisual)
local C = Build.Colors

local HubBuilder = {}

local FLOOR_RADIUS = 120
local CENTER = Vector3.new(0, 0, 0)

local function facing(pos, target)
	return CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------- suelo y borde
local function buildFloor(parent)
	Build.cylinder({ Position = Vector3.new(0, -2, 0), Radius = FLOOR_RADIUS, Height = 4 },
		{ Name = "Floor", Color = C.Deck, Material = Enum.Material.SmoothPlastic, Reflectance = 0.14, Parent = parent })
	Build.cylinder({ Position = Vector3.new(0, -5, 0), Radius = FLOOR_RADIUS - 6, Height = 2 },
		{ Name = "Underglow", Color = C.Blue, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, Parent = parent })
	Build.cylinder({ Position = Vector3.new(0, -10, 0), Radius = FLOOR_RADIUS - 20, Height = 8 },
		{ Name = "Keel", Color = C.Hull, Material = Enum.Material.Metal, CanCollide = false, Parent = parent })

	local inlays = folder("Inlays", parent)
	local rings = { { 31, C.Cyan, 0.7 }, { 66, C.Violet, 0.6 }, { 101, C.Cyan, 0.7 } }
	for _, r in ipairs(rings) do
		Build.ring({ CFrame = CFrame.new(0, 0.1, 0), Radius = r[1], Width = r[3], Height = 0.24, Segments = 56 },
			{ Color = r[2], Material = Enum.Material.Neon, Parent = inlays })
	end
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2 + math.rad(15)
		local color = (i % 2 == 0) and C.Cyan or C.Violet
		Build.neon({ Name = "Ray", Size = Vector3.new(34, 0.2, 0.35), Color = color, Transparency = 0.25,
			CFrame = CFrame.new(0, 0.09, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(83.5, 0, 0), Parent = inlays })
		Build.neon({ Name = "Ray", Size = Vector3.new(34, 0.2, 0.35), Color = color, Transparency = 0.25,
			CFrame = CFrame.new(0, 0.09, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(48.5, 0, 0), Parent = inlays })
	end
	-- paneles oscuros alternos para dar ritmo al suelo
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		Build.decor({ Name = "Tile", Size = Vector3.new(26, 0.16, 9), Color = C.Hull, Material = Enum.Material.Metal,
			CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(84, 0, 0), Parent = inlays })
	end

	local rim = folder("Rim", parent)
	Build.ring({ CFrame = CFrame.new(0, 1.6, 0), Radius = FLOOR_RADIUS - 1.2, Width = 2.4, Height = 3.2, Segments = 48, Collide = true },
		{ Color = C.Hull, Material = Enum.Material.Metal, Parent = rim })
	Build.ring({ CFrame = CFrame.new(0, 3.35, 0), Radius = FLOOR_RADIUS - 1.2, Width = 0.7, Height = 0.3, Segments = 48 },
		{ Color = C.Cyan, Material = Enum.Material.Neon, Parent = rim })
	Build.ring({ CFrame = CFrame.new(0, 24, 0), Radius = FLOOR_RADIUS - 0.5, Width = 1, Height = 48, Segments = 32, Collide = true },
		{ Name = "Barrier", Transparency = 1, Parent = rim })

	-- punto de aparicion
	local spawnPos = Defs.Config.World.HubSpawn
	Build.cylinder({ Position = Vector3.new(spawnPos.X, 0.08, spawnPos.Z), Radius = 9, Height = 0.16 },
		{ Name = "SpawnPad", Color = C.HullLight, Material = Enum.Material.Metal, CanCollide = false, Parent = parent })
	Build.ring({ CFrame = CFrame.new(spawnPos.X, 0.2, spawnPos.Z), Radius = 9, Width = 0.5, Height = 0.12, Segments = 28 },
		{ Color = C.Cyan, Material = Enum.Material.Neon, Parent = inlays })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = facing(Vector3.new(spawnPos.X, 0.5, spawnPos.Z), CENTER)
	spawn.Parent = parent
end

---------------------------------------------------------------- nucleo central
local function buildCore(parent)
	local core = folder("Core", parent)
	local tiers = { { 28, 0.6 }, { 21, 1.8 }, { 14, 3.0 } }
	for i, t in ipairs(tiers) do
		Build.cylinder({ Position = Vector3.new(0, t[2], 0), Radius = t[1], Height = 1.2 },
			{ Name = "Tier" .. i, Color = (i % 2 == 1) and C.HullLight or C.Hull, Material = Enum.Material.Metal, Parent = core })
		Build.ring({ CFrame = CFrame.new(0, t[2] + 0.62, 0), Radius = t[1] - 0.4, Width = 0.45, Height = 0.14, Segments = 40 },
			{ Color = (i == 2) and C.Violet or C.Cyan, Material = Enum.Material.Neon, Parent = core })
	end
	Build.cylinder({ Position = Vector3.new(0, 4.0, 0), Radius = 7, Height = 0.8 },
		{ Name = "Projector", Color = C.Cyan, Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false, Parent = core })
	Build.cylinder({ Position = Vector3.new(0, 14, 0), Radius = 6, Height = 20 },
		{ Name = "Beam", Color = C.Cyan, Material = Enum.Material.Neon, Transparency = 0.92, CanCollide = false,
			CanQuery = false, Parent = core })
	Build.cylinder({ Position = Vector3.new(0, 46, 0), Radius = 0.5, Height = 26 },
		{ Name = "BeamCore", Color = C.White, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false,
			CanQuery = false, Parent = core })

	-- holograma de planeta (el cliente lo hace girar)
	local globe = PlanetVisual.build("terra", "none", false, { Radius = 12, Static = true, Hologram = true })
	globe.Name = "HubGlobe"
	globe:PivotTo(CFrame.new(0, 26, 0))
	globe.Parent = core
	local ringColors = { C.Cyan, C.Violet, C.Blue }
	local tilts = { { 12, 0 }, { -24, 40 }, { 30, -30 } }
	for i = 1, 3 do
		local ringModel = Instance.new("Model")
		ringModel.Name = "HoloRing" .. i
		Build.ring({ CFrame = CFrame.new(0, 26, 0) * CFrame.Angles(math.rad(tilts[i][1]), 0, math.rad(tilts[i][2])),
			Radius = 16 + i * 2.6, Width = 0.35, Height = 0.35, Segments = 40 },
			{ Color = ringColors[i], Material = Enum.Material.Neon, Transparency = 0.15, Parent = ringModel })
		ringModel.Parent = core
	end
	local lamp = Build.decor({ Name = "CoreLight", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(0, 12, 0), Parent = core })
	Build.light(lamp, C.Cyan, 60, 2.2)
	Build.particles(lamp, { Color = ColorSequence.new(C.Cyan, C.Violet), Rate = 14, Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 4), Size = Build.sizeSeq(0.9), SpreadAngle = Vector2.new(25, 25) })

	-- titulo
	local anchor = Build.decor({ Name = "TitleAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(0, 60, 0), Parent = core })
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Title"
	billboard.Size = UDim2.fromScale(74, 24)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 900
	billboard.Brightness = 1.6
	billboard.Parent = anchor
	local title = Build.label(billboard, "PLANET\nCOLLECTOR", { Font = Enum.Font.Michroma, TextColor3 = C.White, LineHeight = 0.95 })
	Build.stroke(title, C.Blue, 3, 0)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(170, 215, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 110, 255)) })
	gradient.Rotation = 90
	gradient.Parent = title
end

---------------------------------------------------------------- Capsule Station
local function buildCapsuleMachine(parent, def, cf)
	local model = Instance.new("Model")
	model.Name = "Capsule_" .. def.Id
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local base = Build.cylinder({ CFrame = at(0, 0.5, 0), Radius = 4.6, Height = 1 },
		{ Name = "Base", Color = C.HullLight, Material = Enum.Material.Metal, Parent = model })
	Build.ring({ CFrame = at(0, 1.06, 0), Radius = 4.3, Width = 0.4, Height = 0.14, Segments = 24 },
		{ Color = def.Color, Material = Enum.Material.Neon, Parent = model })
	Build.cylinder({ CFrame = at(0, 1.5, 0), Radius = 3.3, Height = 1 },
		{ Name = "Pedestal", Color = C.Hull, Material = Enum.Material.Metal, Parent = model })
	Build.cylinder({ CFrame = at(0, 6, 0), Radius = 2.9, Height = 8 },
		{ Name = "Glass", Color = def.Color, Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = false, Parent = model })
	Build.cylinder({ CFrame = at(0, 10.6, 0), Radius = 3.4, Height = 1.2 },
		{ Name = "Cap", Color = C.HullLight, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
	Build.ring({ CFrame = at(0, 11.25, 0), Radius = 3.1, Width = 0.35, Height = 0.14, Segments = 20 },
		{ Color = def.Color, Material = Enum.Material.Neon, Parent = model })
	Build.cylinder({ CFrame = at(0, 12.4, 0), Radius = 0.25, Height = 2.6 },
		{ Name = "Antenna", Color = C.Trim, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
	Build.ball({ CFrame = at(0, 13.9, 0), Radius = 0.5 },
		{ Name = "Beacon", Color = def.CoreColor, Material = Enum.Material.Neon, CanCollide = false, Parent = model })

	-- capsula flotante (el cliente la hace levitar y girar)
	local capsule = Instance.new("Model")
	capsule.Name = "Capsule"
	local corePart = Build.cylinder({ CFrame = at(0, 6, 0), Radius = 1.25, Height = 2.4 },
		{ Name = "Core", Color = def.CoreColor, Material = Enum.Material.Neon, Transparency = 0.05, CanCollide = false, Parent = capsule })
	Build.ball({ CFrame = at(0, 7.2, 0), Radius = 1.25 },
		{ Name = "Top", Color = C.White, Material = Enum.Material.SmoothPlastic, Reflectance = 0.3, CanCollide = false, Parent = capsule })
	Build.ball({ CFrame = at(0, 4.8, 0), Radius = 1.25 },
		{ Name = "Bottom", Color = def.Color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.2, CanCollide = false, Parent = capsule })
	capsule.PrimaryPart = corePart
	capsule.Parent = model
	Build.light(corePart, def.Color, 20, 2)
	Build.particles(corePart, { Color = ColorSequence.new(def.CoreColor, def.Color), Rate = 8, Speed = NumberRange.new(0.4, 1.2),
		Size = Build.sizeSeq(0.5), Lifetime = NumberRange.new(1, 2) })

	for _, y in ipairs({ 3.4, 8.6 }) do
		Build.ring({ CFrame = at(0, y, 0), Radius = 3.25, Width = 0.25, Height = 0.25, Segments = 20 },
			{ Color = def.CoreColor, Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		Build.cylinder({ CFrame = at(side * 4.1, 4.5, 0.6), Radius = 0.65, Height = 7 },
			{ Name = "Coil", Color = C.Hull, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
		for band = 0, 2 do
			Build.cylinder({ CFrame = at(side * 4.1, 2.6 + band * 1.9, 0.6), Radius = 0.78, Height = 0.3 },
				{ Name = "CoilBand", Color = def.Color, Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		end
	end
	-- las maquinas superiores ganan aros exteriores
	if def.Order >= 4 then
		Build.ring({ CFrame = at(0, 6, 0) * CFrame.Angles(math.rad(70), 0, 0), Radius = 5.6, Width = 0.3, Height = 0.3, Segments = 28 },
			{ Color = def.Color, Material = Enum.Material.Neon, Parent = model })
	end
	if def.Order >= 5 then
		Build.ring({ CFrame = at(0, 6, 0) * CFrame.Angles(math.rad(70), math.rad(90), 0), Radius = 6.2, Width = 0.3, Height = 0.3, Segments = 28 },
			{ Color = def.CoreColor, Material = Enum.Material.Neon, Parent = model })
	end
	if def.Order >= 6 then
		Build.ring({ CFrame = at(0, 6, 0), Radius = 6.8, Width = 0.3, Height = 0.3, Segments = 32 },
			{ Color = C.White, Material = Enum.Material.Neon, Parent = model })
	end

	local screenCf = at(0, 2.6, -5.4) * CFrame.Angles(math.rad(-18), 0, 0)
	Build.sign({ Name = "PriceScreen", CFrame = screenCf, Width = 6.4, Height = 3, Color = def.Color, Parent = model,
		Text = def.Name .. "\n⚡ " .. Format.number(def.Price), Font = Enum.Font.GothamBold, TextColor = C.White, PixelsPerStud = 40 })
	Build.prompt(base, "Abrir cápsulas", def.Name, "Capsule:" .. def.Id, 16)
	model.PrimaryPart = base
	model.Parent = parent
	return model
end

local function buildCapsuleStation(parent)
	local station = folder("CapsuleStation", parent)
	Build.part({ Name = "Deck", Size = Vector3.new(46, 0.5, 92), CFrame = CFrame.new(-80, 0.25, 0), Color = C.HullLight,
		Material = Enum.Material.Metal, Parent = station })
	Build.neon({ Name = "DeckEdge", Size = Vector3.new(0.4, 0.2, 92), CFrame = CFrame.new(-57, 0.52, 0), Color = C.Cyan, Parent = station })
	Build.part({ Name = "UpperDeck", Size = Vector3.new(16, 3.5, 92), CFrame = CFrame.new(-95, 1.75, 0), Color = C.Hull,
		Material = Enum.Material.Metal, Parent = station })
	Build.neon({ Name = "UpperEdge", Size = Vector3.new(0.4, 0.25, 92), CFrame = CFrame.new(-87, 3.55, 0), Color = C.Violet, Parent = station })
	-- pared trasera con franjas de luz
	Build.part({ Name = "BackWall", Size = Vector3.new(3, 40, 96), CFrame = CFrame.new(-105, 20, 0), Color = C.Hull,
		Material = Enum.Material.Metal, Parent = station })
	for i = -4, 4 do
		Build.neon({ Name = "WallStrip", Size = Vector3.new(0.3, 30, 0.6), CFrame = CFrame.new(-103.4, 20, i * 10.5),
			Color = (i % 2 == 0) and C.Cyan or C.Violet, Transparency = 0.2, Parent = station })
	end
	Build.sign({ Name = "StationSign", CFrame = CFrame.lookAt(Vector3.new(-102.6, 31, 0), Vector3.new(0, 31, 0)), Width = 62, Height = 9,
		Text = "CAPSULE STATION", Color = C.Cyan, Parent = station })

	local positions = {
		{ Vector3.new(-66, 0.5, -27), false }, { Vector3.new(-70, 0.5, 0), false }, { Vector3.new(-66, 0.5, 27), false },
		{ Vector3.new(-94, 3.5, -30), true }, { Vector3.new(-96, 3.5, 0), true }, { Vector3.new(-94, 3.5, 30), true },
	}
	for index, def in ipairs(Defs.Capsules.List) do
		local slot = positions[index]
		local pos = slot[1]
		buildCapsuleMachine(station, def, facing(pos, CENTER))
	end
end

---------------------------------------------------------------- tableros (el cliente los rellena)
local function buildBoard(parent, name, pos, lookTarget, width, height, color, floorY)
	local cf = CFrame.lookAt(pos, lookTarget)
	local model, panel = Build.sign({ Name = name, CFrame = cf, Width = width, Height = height, Color = color, Parent = parent })
	panel.Name = "Panel"
	panel.CanQuery = true
	-- soportes hasta el suelo
	for _, side in ipairs({ -1, 1 }) do
		local top = cf * CFrame.new(side * (width / 2 - 2), -height / 2, 0.4)
		local length = top.Position.Y - (floorY or 0)
		if length > 1 then
			Build.decor({ Name = "Pylon", Size = Vector3.new(1.2, length, 1.2), CFrame = CFrame.new(top.Position.X, (floorY or 0) + length / 2, top.Position.Z),
				Color = C.Hull, Material = Enum.Material.Metal, Parent = model })
		end
	end
	return model
end

---------------------------------------------------------------- Portal Room
local function buildPortal(parent, cf, signText, action, promptText, scale, color)
	local portal = Instance.new("Model")
	portal.Name = "Portal"
	local s = scale or 1
	local centerCf = cf * CFrame.new(0, 13 * s, 0)
	local vertical = centerCf * CFrame.Angles(math.rad(90), 0, 0)
	Build.cylinder({ CFrame = cf * CFrame.new(0, 0.25, 0), Radius = 15 * s, Height = 0.5 },
		{ Name = "Platform", Color = C.HullLight, Material = Enum.Material.Metal, Parent = portal })
	Build.ring({ CFrame = cf * CFrame.new(0, 0.56, 0), Radius = 14.4 * s, Width = 0.5, Height = 0.14, Segments = 32 },
		{ Color = color, Material = Enum.Material.Neon, Parent = portal })
	Build.ring({ CFrame = vertical * CFrame.Angles(0, math.rad(22.5), 0), Radius = 11.6 * s, Width = 2.6 * s, Height = 3 * s, Segments = 8, Collide = true },
		{ Name = "Frame", Color = C.Hull, Material = Enum.Material.Metal, Parent = portal })
	Build.ring({ CFrame = vertical * CFrame.Angles(0, math.rad(22.5), 0), Radius = 10.1 * s, Width = 0.5, Height = 3.3 * s, Segments = 8 },
		{ Name = "FrameGlow", Color = color, Material = Enum.Material.Neon, Parent = portal })
	local core = Build.cylinder({ CFrame = vertical, Radius = 9.6 * s, Height = 0.5 },
		{ Name = "PortalCore", Color = color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = portal })
	Build.cylinder({ CFrame = vertical * CFrame.new(0, -0.2, 0), Radius = 6 * s, Height = 0.5 },
		{ Name = "PortalEye", Color = Color3.fromRGB(240, 220, 255), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, Parent = portal })
	Build.light(core, color, 40, 2.5)
	Build.particles(core, { Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255)), Rate = 30, Speed = NumberRange.new(1, 4),
		Lifetime = NumberRange.new(1, 2.2), Size = Build.sizeSeq(1.1), RotSpeed = NumberRange.new(-120, 120) })
	if signText then
		Build.sign({ Name = "PortalSign", CFrame = cf * CFrame.new(0, 28.5 * s, 0), Width = 30 * s, Height = 5.5 * s, Text = signText,
			Color = color, Parent = portal })
	end
	Build.prompt(core, promptText, signText or "Portal", action, 18)
	portal.PrimaryPart = core
	portal.Parent = parent
	return portal
end
HubBuilder.buildPortal = buildPortal

---------------------------------------------------------------- Galactic Market
local function buildMarket(parent)
	local market = folder("GalacticMarket", parent)
	local pos = Vector3.new(78, -0.5, -34)
	local cf = facing(pos, CENTER)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	Build.part({ Name = "Deck", Size = Vector3.new(40, 0.5, 26), CFrame = at(0, 0.75, 2), Color = C.HullLight, Material = Enum.Material.Metal, Parent = market })
	Build.neon({ Name = "DeckEdge", Size = Vector3.new(40, 0.2, 0.4), CFrame = at(0, 1.02, -11), Color = C.Violet, Parent = market })
	local counter = Build.part({ Name = "Counter", Size = Vector3.new(26, 3.4, 4), CFrame = at(0, 2.7, -4), Color = C.Hull, Material = Enum.Material.Metal, Parent = market })
	Build.neon({ Name = "CounterGlow", Size = Vector3.new(26.2, 0.3, 4.2), CFrame = at(0, 4.5, -4), Color = C.Cyan, Parent = market })
	Build.neon({ Name = "CounterStrip", Size = Vector3.new(26.2, 0.4, 0.2), CFrame = at(0, 2.2, -6.1), Color = C.Violet, Parent = market })
	for _, x in ipairs({ -17, 17 }) do
		Build.part({ Name = "Pillar", Size = Vector3.new(2, 18, 2), CFrame = at(x, 10, 6), Color = C.Hull, Material = Enum.Material.Metal, Parent = market })
		Build.neon({ Name = "PillarGlow", Size = Vector3.new(0.3, 16, 0.3), CFrame = at(x, 10, 4.9), Color = C.Cyan, Parent = market })
	end
	Build.part({ Name = "Roof", Size = Vector3.new(40, 1.2, 14), CFrame = at(0, 19.6, 4), Color = C.Hull, Material = Enum.Material.Metal, CanCollide = false, Parent = market })
	Build.part({ Name = "Back", Size = Vector3.new(36, 18, 1.4), CFrame = at(0, 10, 10.4), Color = C.Hull, Material = Enum.Material.Metal, Parent = market })
	local screens = { { -11, "🔁 OFERTAS" }, { 0, "🪐 INTERCAMBIO SEGURO" }, { 11, "✅ DOBLE CONFIRMACIÓN" } }
	for _, sdef in ipairs(screens) do
		Build.sign({ Name = "MarketScreen", CFrame = at(sdef[1], 11.5, 9.4), Width = 9.6, Height = 6, Text = sdef[2], Color = C.Cyan,
			TextColor = C.White, Font = Enum.Font.GothamBold, Parent = market })
	end
	Build.sign({ Name = "MarketSign", CFrame = at(0, 23.6, -1), Width = 36, Height = 6, Text = "GALACTIC MARKET", Color = C.Cyan, Parent = market })
	Build.light(counter, C.Cyan, 28, 1.6)
	Build.prompt(counter, "Comerciar", "Galactic Market", "Market", 16)
end

---------------------------------------------------------------- Event Terminal y Leaderboard
local function buildTerminal(parent, name, cf, title, action, promptText, color)
	local terminal = Instance.new("Model")
	terminal.Name = name
	local base = Build.part({ Name = "Console", Size = Vector3.new(9, 3.6, 3.4), CFrame = cf * CFrame.new(0, 1.8, 0), Color = C.Hull,
		Material = Enum.Material.Metal, Parent = terminal })
	Build.neon({ Name = "ConsoleGlow", Size = Vector3.new(9.2, 0.25, 3.6), CFrame = cf * CFrame.new(0, 3.7, 0), Color = color, Parent = terminal })
	Build.sign({ Name = "ConsoleScreen", CFrame = cf * CFrame.new(0, 5.6, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Width = 8.4, Height = 3.2,
		Text = title, Color = color, TextColor = C.White, Font = Enum.Font.GothamBold, Parent = terminal })
	Build.light(base, color, 18, 1.4)
	Build.prompt(base, promptText, title, action, 14)
	terminal.PrimaryPart = base
	terminal.Parent = parent
	return terminal
end
HubBuilder.buildTerminal = buildTerminal
HubBuilder.buildBoard = buildBoard

---------------------------------------------------------------- decoracion
local function buildTree(parent, pos)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	Build.cylinder({ Position = pos + Vector3.new(0, 0.9, 0), Radius = 3.4, Height = 1.8 },
		{ Name = "Planter", Color = C.HullLight, Material = Enum.Material.Metal, Parent = tree })
	Build.ring({ CFrame = CFrame.new(pos + Vector3.new(0, 1.84, 0)), Radius = 3.2, Width = 0.35, Height = 0.12, Segments = 18 },
		{ Color = C.Cyan, Material = Enum.Material.Neon, Parent = tree })
	Build.cylinder({ Position = pos + Vector3.new(0, 1.7, 0), Radius = 2.8, Height = 0.3 },
		{ Name = "Soil", Color = Color3.fromRGB(46, 36, 30), Material = Enum.Material.Ground, CanCollide = false, Parent = tree })
	Build.cylinder({ Position = pos + Vector3.new(0, 5, 0), Radius = 0.55, Height = 6.5 },
		{ Name = "Trunk", Color = Color3.fromRGB(92, 66, 48), Material = Enum.Material.Wood, CanCollide = false, Parent = tree })
	local leaves = { { 0, 9.2, 0, 3.3 }, { 1.9, 8.2, 0.6, 2.4 }, { -1.7, 8.4, -0.8, 2.5 }, { 0.3, 8, 1.9, 2.2 }, { -0.4, 10.6, -0.3, 2.3 } }
	for _, l in ipairs(leaves) do
		Build.ball({ Position = pos + Vector3.new(l[1], l[2], l[3]), Radius = l[4] },
			{ Name = "Leaves", Color = Color3.fromRGB(58, 150, 84), Material = Enum.Material.Grass, CanCollide = false, Parent = tree })
	end
	tree.Parent = parent
end

local function buildSkyline(parent)
	local skyline = folder("Skyline", parent)
	local rng = Random.new(20261)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local dist = rng:NextNumber(165, 235)
		local height = rng:NextNumber(110, 280)
		local width = rng:NextNumber(16, 30)
		local pos = Vector3.new(math.cos(angle) * dist, height / 2 - 70, math.sin(angle) * dist)
		local cf = facing(pos, CENTER)
		local tower = Instance.new("Model")
		tower.Name = "Tower"
		Build.decor({ Name = "Body", Size = Vector3.new(width, height, width), CFrame = cf, Color = C.Hull, Material = Enum.Material.Metal, Parent = tower })
		Build.decor({ Name = "Crown", Size = Vector3.new(width * 0.6, height * 0.22, width * 0.6), CFrame = cf * CFrame.new(0, height * 0.61, 0),
			Color = C.HullLight, Material = Enum.Material.Metal, Parent = tower })
		Build.decor({ Name = "Spire", Size = Vector3.new(1.4, height * 0.3, 1.4), CFrame = cf * CFrame.new(0, height * 0.87, 0),
			Color = C.Trim, Material = Enum.Material.Metal, Parent = tower })
		local color = (i % 3 == 0) and C.Violet or C.Cyan
		Build.neon({ Name = "Beacon", Size = Vector3.new(2.4, 2.4, 2.4), Shape = Enum.PartType.Ball, CFrame = cf * CFrame.new(0, height * 1.03, 0),
			Color = color, Parent = tower })
		-- franjas de ventanas en la cara que mira al Hub
		local strips = math.floor(width / 7)
		for sIndex = 1, strips do
			local x = (sIndex - (strips + 1) / 2) * 6
			Build.neon({ Name = "Windows", Size = Vector3.new(1, height * rng:NextNumber(0.45, 0.85), 0.4),
				CFrame = cf * CFrame.new(x, rng:NextNumber(-10, 10), -width / 2 - 0.1), Color = color, Transparency = 0.25, Parent = tower })
		end
		Build.neon({ Name = "Band", Size = Vector3.new(width + 0.6, 1, width + 0.6), CFrame = cf * CFrame.new(0, height * 0.5 - 2, 0),
			Color = color, Transparency = 0.1, Parent = tower })
		tower.Parent = skyline
	end
	-- anillos orbitales gigantes sobre la estacion
	local arcs = { { 150, 68, 20, C.Cyan }, { 172, -62, -28, C.Violet } }
	for _, a in ipairs(arcs) do
		local cf = CFrame.new(0, 40, 0) * CFrame.Angles(math.rad(a[2]), 0, math.rad(a[3]))
		Build.ring({ CFrame = cf, Radius = a[1], Width = 4, Height = 3, Segments = 56 },
			{ Name = "OrbitalRing", Color = C.Hull, Material = Enum.Material.Metal, Parent = skyline })
		Build.ring({ CFrame = cf, Radius = a[1] - 2.4, Width = 0.6, Height = 0.6, Segments = 56 },
			{ Name = "OrbitalRingGlow", Color = a[4], Material = Enum.Material.Neon, Parent = skyline })
	end
	-- planetas lejanos
	local far = {
		{ "jovian", 250, Vector3.new(-1150, 340, -1500) },
		{ "aureon", 170, Vector3.new(1250, 420, -1150) },
		{ "lunaris", 70, Vector3.new(-520, 520, -820) },
		{ "nebulon", 120, Vector3.new(700, 150, 1500) },
	}
	for _, f in ipairs(far) do
		local planet = PlanetVisual.build(f[1], "none", false, { Radius = f[2], Static = true, Distant = true })
		planet.Name = "Far_" .. f[1]
		planet:PivotTo(CFrame.new(f[3]) * CFrame.Angles(math.rad(18), 0, math.rad(-12)))
		planet.Parent = skyline
	end
end

---------------------------------------------------------------- build
function HubBuilder.build()
	local hub = Instance.new("Model")
	hub.Name = "CosmicHub"

	buildFloor(hub)
	buildCore(hub)
	buildCapsuleStation(hub)

	local boards = folder("Boards", hub)
	buildBoard(boards, "Board_Odds", Vector3.new(-44, 34, -84), Vector3.new(0, 18, 40), 46, 26, C.Cyan)
	buildBoard(boards, "Board_Leaderboard", Vector3.new(48, 34, -84), Vector3.new(0, 18, 40), 42, 26, C.Violet)

	local portalRoom = folder("PortalRoom", hub)
	buildPortal(portalRoom, facing(Vector3.new(88, 0, 34), CENTER), "PORTAL ROOM", "Portal", "Viajar", 1, C.Violet)

	buildMarket(hub)

	local eventFolder = folder("EventTerminal", hub)
	buildTerminal(eventFolder, "EventConsole", facing(Vector3.new(0, 0, -86), CENTER), "EVENT TERMINAL", "Event", "Ver evento", C.Gold)
	buildBoard(eventFolder, "Board_Event", Vector3.new(0, 16, -98), Vector3.new(0, 12, 0), 30, 15, C.Gold)

	local lbFolder = folder("LeaderboardKiosk", hub)
	buildTerminal(lbFolder, "LeaderboardConsole", facing(Vector3.new(40, 0, -76), CENTER), "LEADERBOARD", "Leaderboard", "Ver clasificación", C.Violet)

	local decor = folder("Decor", hub)
	for _, angle in ipairs({ 40, 140, 220, 320, 95, 265 }) do
		local a = math.rad(angle)
		buildTree(decor, Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46))
	end
	-- farolas
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.rad(22.5)
		local pos = Vector3.new(math.cos(a) * 60, 0, math.sin(a) * 60)
		Build.cylinder({ Position = pos + Vector3.new(0, 5, 0), Radius = 0.35, Height = 10 },
			{ Name = "LampPost", Color = C.Trim, Material = Enum.Material.Metal, CanCollide = false, Parent = decor })
		local lamp = Build.neon({ Name = "Lamp", Size = Vector3.new(1.6, 1.6, 1.6), Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(pos + Vector3.new(0, 10.4, 0)), Color = (i % 2 == 0) and C.Cyan or C.Violet, Parent = decor })
		Build.light(lamp, lamp.Color, 34, 1.3)
	end

	buildSkyline(hub)
	hub.Parent = Workspace
	return hub
end

return HubBuilder
