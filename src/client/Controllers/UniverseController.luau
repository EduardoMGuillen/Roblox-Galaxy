-- UniverseController: dibuja el universo personal en el que esta el jugador (el suyo o el que visita):
-- estrella central, orbitas luminosas, planetas colocados (orbita + rotacion propia con matematica
-- simple y sincronizada con el reloj del servidor), marcadores de slots y decoracion del sistema.
-- Solo representa el estado autorizado por el servidor; al visitar es de solo lectura.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Assets = require(Shared.Assets)
local Build = require(Shared.Util.Build)
local Format = require(Shared.Util.Format)
local Layout = require(Shared.UniverseLayout)
local Progression = require(Shared.Progression)
local PlanetVisual = require(Shared.PlanetVisual)
local Config = Defs.Config

local Universe = {}
local ctx = nil
local player = Players.LocalPlayer

local container = nil
local current = nil -- { Owner, View, StarKey, Center }
local planets = {} -- [slot] = { Model, Body, Def, Key, Tilt, Rainbow }
local markers = {} -- [slot] = { Part, Kind }
local spinners = {} -- { Model, Speed, CFrame } decoracion giratoria
local staticFolder, planetFolder = nil, nil
local boards = {}
local slotsPanel = nil

local function settings()
	return ctx.State.Data.Settings or {}
end

local function clearAll()
	if container then container:ClearAllChildren() end
	planets = {}
	markers = {}
	spinners = {}
	for _, gui in pairs(boards) do
		gui:Destroy()
	end
	boards = {}
	staticFolder, planetFolder = nil, nil
	current = nil
end

---------------------------------------------------------------- estrella y decoracion
local function orbitColor(view, theme)
	local id = view.Cosmetics and view.Cosmetics.OrbitColor
	local def = id and Defs.Cosmetics.ById[id]
	if def and def.Color then return def.Color end
	return theme.Orbit
end

local function buildStar(view, theme, folder, low)
	local center = view.Center
	local radius = Config.World.StarRadius
	local star = Instance.new("Model")
	star.Name = "Star"
	local aura = view.Cosmetics and Defs.Cosmetics.ById[view.Cosmetics.StarAura or ""]
	local style = aura and aura.Style or nil

	if theme.BlackHole then
		-- nucleo de gravedad: esfera negra con disco de acrecion y borde luminoso
		local core = Build.ball({ Position = center, Radius = radius * 0.8 }, { Name = "Core", Color = Color3.new(0, 0, 0),
			Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = star })
		Build.ball({ Position = center, Radius = radius * 0.9 }, { Name = "Lens", Color = theme.StarGlow, Material = Enum.Material.ForceField,
			Transparency = 0.1, CanCollide = false, CanQuery = false, Parent = star })
		local tilt = CFrame.new(center) * CFrame.Angles(math.rad(14), 0, math.rad(6))
		Build.cylinder({ CFrame = tilt, Radius = radius * 2.4, Height = 0.3 }, { Name = "Disc1", Color = theme.StarGlow, Material = Enum.Material.Neon,
			Transparency = 0.45, CanCollide = false, CanQuery = false, Parent = star })
		Build.cylinder({ CFrame = tilt, Radius = radius * 3.3, Height = 0.2 }, { Name = "Disc2", Color = Color3.fromRGB(110, 50, 220),
			Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false, CanQuery = false, Parent = star })
		Build.ring({ CFrame = tilt, Radius = radius * 1.15, Width = 0.6, Height = 0.6, Segments = 36 },
			{ Name = "Photon", Color = Color3.fromRGB(255, 220, 255), Material = Enum.Material.Neon, Parent = star })
		Build.light(core, theme.StarGlow, 60, 3)
		if not low then
			local emitter = Build.particles(core, { Color = ColorSequence.new(theme.StarGlow, Color3.fromRGB(90, 30, 200)), Rate = 30,
				Speed = NumberRange.new(4, 9), Lifetime = NumberRange.new(1.5, 3), Size = Build.sizeSeq(2.2), RotSpeed = NumberRange.new(-160, 160) })
			emitter.Shape = Enum.ParticleEmitterShape.Sphere
			emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end
		star.PrimaryPart = core
	else
		local core = Build.ball({ Position = center, Radius = radius * 0.96 }, { Name = "Core", Color = theme.Star, Material = Enum.Material.Neon,
			CanCollide = false, Parent = star })
		if Assets.SphereMesh ~= 0 and Assets.texture("sun") ~= "" then
			-- superficie texturizada semitransparente sobre el nucleo de neon (aspecto emisivo con detalle)
			local surface = Build.decor({ Name = "Surface", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center), Color = theme.Star,
				Transparency = 0.35, Parent = star })
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = Assets.url(Assets.SphereMesh)
			mesh.TextureId = Assets.texture("sun")
			local s = radius / Assets.SphereMeshRadius
			mesh.Scale = Vector3.new(s, s, s)
			mesh.VertexColor = Vector3.new(theme.Star.R, theme.Star.G, theme.Star.B)
			mesh.Parent = surface
		end
		Build.ball({ Position = center, Radius = radius * 1.18 }, { Name = "Corona", Color = theme.StarGlow, Material = Enum.Material.Neon,
			Transparency = 0.78, CanCollide = false, CanQuery = false, Parent = star })
		Build.ball({ Position = center, Radius = radius * 1.5 }, { Name = "Halo", Color = theme.StarGlow, Material = Enum.Material.Neon,
			Transparency = 0.92, CanCollide = false, CanQuery = false, Parent = star })
		Build.light(core, theme.StarGlow, 60, 4)
		if Assets.image("glow") ~= "" then
			local glow = Instance.new("BillboardGui")
			glow.Name = "Glow"
			glow.Size = UDim2.fromScale(radius * 7, radius * 7)
			glow.LightInfluence = 0
			glow.MaxDistance = 2000
			glow.Parent = core
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = Assets.image("glow")
			image.ImageColor3 = theme.StarGlow
			image.ImageTransparency = 0.55
			image.Parent = glow
		end
		if not low then
			local emitter = Build.particles(core, { Color = ColorSequence.new(theme.Star, theme.StarGlow), Rate = style == "flare" and 46 or 22,
				Speed = NumberRange.new(style == "flare" and 6 or 2, style == "flare" and 14 or 6), Lifetime = NumberRange.new(1.5, 3.2),
				Size = Build.sizeSeq(style == "flare" and 4.5 or 3), RotSpeed = NumberRange.new(-60, 60) })
			emitter.Shape = Enum.ParticleEmitterShape.Sphere
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		end
		star.PrimaryPart = core
	end

	-- auras cosmeticas
	if style == "halo" then
		for i, tilt in ipairs({ 60, -60 }) do
			local ringModel = Instance.new("Model")
			ringModel.Name = "AuraRing" .. i
			local cf = CFrame.new(center) * CFrame.Angles(math.rad(tilt), 0, 0)
			Build.ring({ CFrame = cf, Radius = radius * 1.9, Width = 0.5, Height = 0.5, Segments = 36 },
				{ Color = theme.StarGlow, Material = Enum.Material.Neon, Parent = ringModel })
			ringModel.WorldPivot = cf
			ringModel.Parent = star
			table.insert(spinners, { Model = ringModel, Speed = 0.25 * (i == 1 and 1 or -1), Base = cf })
		end
	elseif style == "pulse" then
		local pulse = Build.ball({ Position = center, Radius = radius * 1.3 }, { Name = "Pulse", Color = theme.StarGlow, Material = Enum.Material.ForceField,
			Transparency = 0.2, CanCollide = false, CanQuery = false, Parent = star })
		table.insert(spinners, { Pulse = pulse, Radius = radius })
	end

	-- adornos por sistema
	if theme.Ornaments then
		local tilts = { { 0, 0 }, { 58, 20 }, { -58, -20 } }
		for i, t in ipairs(tilts) do
			local ringModel = Instance.new("Model")
			ringModel.Name = "Ornament" .. i
			local cf = CFrame.new(center) * CFrame.Angles(math.rad(t[1]), 0, math.rad(t[2]))
			Build.ring({ CFrame = cf, Radius = radius * 1.7 + i * 3.2, Width = 0.7, Height = 0.7, Segments = 40 },
				{ Color = Color3.fromRGB(255, 215, 120), Material = Enum.Material.Neon, Parent = ringModel })
			ringModel.WorldPivot = cf
			ringModel.Parent = star
			table.insert(spinners, { Model = ringModel, Speed = 0.12 * (i % 2 == 0 and -1 or 1), Base = cf })
		end
	end
	star.Parent = folder
	return star
end

local function buildBackdrop(view, theme, folder, low)
	local center = view.Center
	local outer = Layout.outerRadius()
	if theme.Portals then
		-- portales y anillos multidimensionales
		local portalColors = { Color3.fromRGB(120, 255, 255), Color3.fromRGB(255, 110, 255), Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 255, 255) }
		for i = 1, 4 do
			local angle = i / 4 * math.pi * 2 + 0.6
			local pos = center + Vector3.new(math.cos(angle) * (outer + 70), 40 + i * 14, math.sin(angle) * (outer + 70))
			local cf = CFrame.lookAt(pos, center) * CFrame.Angles(math.rad(90), 0, 0)
			local portal = Instance.new("Model")
			portal.Name = "DimensionPortal" .. i
			Build.ring({ CFrame = cf, Radius = 16, Width = 1.2, Height = 1.2, Segments = 24 },
				{ Color = portalColors[i], Material = Enum.Material.Neon, Parent = portal })
			Build.cylinder({ CFrame = cf, Radius = 15, Height = 0.3 }, { Name = "Core", Color = portalColors[i], Material = Enum.Material.Neon,
				Transparency = 0.7, CanCollide = false, CanQuery = false, Parent = portal })
			portal.Parent = folder
		end
		for i, tilt in ipairs({ 26, -26 }) do
			local ringModel = Instance.new("Model")
			ringModel.Name = "DimensionRing" .. i
			local cf = CFrame.new(center) * CFrame.Angles(math.rad(tilt), 0, math.rad(tilt * 0.5))
			Build.ring({ CFrame = cf, Radius = outer + 26 + i * 12, Width = 0.8, Height = 0.8, Segments = 64 },
				{ Color = i == 1 and Color3.fromRGB(120, 255, 255) or Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon,
					Transparency = 0.3, Parent = ringModel })
			ringModel.WorldPivot = cf
			ringModel.Parent = folder
			table.insert(spinners, { Model = ringModel, Speed = 0.05 * (i == 1 and 1 or -1), Base = cf })
		end
	end
	if low or settings().ReducedEffects then return end
	-- nubes de nebulosa (particulas grandes y lentas, muy transparentes)
	local rng = Random.new(view.Plot * 131 + Defs.Galaxy.ById[view.System].Order)
	for i = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(outer + 120, outer + 420)
		local pos = center + Vector3.new(math.cos(angle) * dist, rng:NextNumber(-160, 120), math.sin(angle) * dist)
		local anchor = Build.decor({ Name = "Nebula", Size = Vector3.new(60, 60, 60), Transparency = 1, CFrame = CFrame.new(pos), Parent = folder })
		local c = theme.Nebula[(i % 2) + 1]
		local smoke = Assets.image("smoke")
		Build.particles(anchor, { Texture = smoke ~= "" and smoke or Build.ParticleTextures.Smoke, Color = ColorSequence.new(c, theme.Nebula[1]), Rate = 1.2,
			Lifetime = NumberRange.new(14, 22), Speed = NumberRange.new(0.5, 2), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-4, 4),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 70), NumberSequenceKeypoint.new(1, 130) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86),
				NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 0.7, SpreadAngle = Vector2.new(180, 180) })
	end
	-- galaxias y nebulosas lejanas (imagenes con transparencia; si no cargan, simplemente no se ven)
	local sprites = { { "galaxy", 520, 360 }, { "nebula", 640, 640 }, { "galaxy", 300, 210 } }
	for i, sprite in ipairs(sprites) do
		local url = Assets.image(sprite[1])
		if url ~= "" then
			local angle = rng:NextNumber(0, math.pi * 2)
			local pos = center + Vector3.new(math.cos(angle) * 1500, rng:NextNumber(-250, 500), math.sin(angle) * 1500)
			local anchor = Build.decor({ Name = "FarSprite" .. i, Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(pos), Parent = folder })
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromScale(sprite[2], sprite[3])
			billboard.LightInfluence = 0
			billboard.MaxDistance = 5000
			billboard.Parent = anchor
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = url
			image.ImageTransparency = 0.25
			image.Parent = billboard
		end
	end
	-- polvo estelar cercano
	local dust = Build.decor({ Name = "Stardust", Size = Vector3.new(outer * 2.4, 90, outer * 2.4), Transparency = 1, CFrame = CFrame.new(center), Parent = folder })
	Build.particles(dust, { Color = ColorSequence.new(theme.Accent, Color3.new(1, 1, 1)), Rate = 26, Lifetime = NumberRange.new(5, 9),
		Speed = NumberRange.new(0.2, 1), Size = Build.sizeSeq(1.1) })
end

local function buildOrbits(view, theme, folder, low)
	local color = orbitColor(view, theme)
	local orbits = Instance.new("Folder")
	orbits.Name = "Orbits"
	for slot = 1, Config.Economy.SlotsPerSystem do
		local unlocked = slot <= view.Slots
		local radius = Layout.orbitRadius(slot)
		local segments = math.floor((low and 26 or 44) + slot * (low and 2 or 4))
		Build.ring({ CFrame = CFrame.new(view.Center), Radius = radius, Width = unlocked and 0.4 or 0.3, Height = 0.14, Segments = segments,
			Gap = unlocked and nil or 0.55 }, { Name = "Orbit" .. slot, Color = color, Material = Enum.Material.Neon,
			Transparency = unlocked and 0.45 or 0.86, Parent = orbits })
	end
	orbits.Parent = folder
end

---------------------------------------------------------------- planetas y marcadores
local function nameTag(part, title, subtitle, color, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Tag"
	billboard.Size = UDim2.fromOffset(170, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	billboard.MaxDistance = 700
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.Parent = part
	local top = Build.label(billboard, title, { Size = UDim2.fromScale(1, 0.55), TextScaled = false, TextSize = 15, TextColor3 = color,
		Font = Enum.Font.GothamBold })
	Build.stroke(top, Color3.fromRGB(4, 6, 18), 2, 0.1)
	if subtitle then
		local bottom = Build.label(billboard, subtitle, { Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.55), TextScaled = false,
			TextSize = 13, TextColor3 = Color3.fromRGB(255, 215, 90), Font = Enum.Font.GothamBold })
		Build.stroke(bottom, Color3.fromRGB(4, 6, 18), 2, 0.1)
	end
	return billboard
end

local function planetKey(p)
	return p.Id .. "|" .. tostring(p.V) .. "|" .. tostring(p.E)
end

local function removePlanet(slot)
	local entry = planets[slot]
	if entry then
		entry.Model:Destroy()
		planets[slot] = nil
	end
end

local function removeMarker(slot)
	local entry = markers[slot]
	if entry then
		entry.Part:Destroy()
		markers[slot] = nil
	end
end

local function addPlanet(slot, data, isOwner)
	local def = Defs.Planets.ById[data.Id]
	local low = settings().LowQuality
	local model = PlanetVisual.build(data.Id, data.V, data.E, { Welded = true, Static = low or settings().ReducedEffects })
	model:SetAttribute("Slot", slot)
	model:SetAttribute("Uid", data.Uid)
	local radius = model:GetAttribute("Radius")
	local rarity = Defs.Rarities.ById[def.Rarity]
	local inst = { Id = data.Id, V = data.V or "none", E = data.E == true }
	nameTag(model.PrimaryPart, Defs.Planets.displayName(def, data.E), "⚡ " .. Format.rate(Progression.planetRate(inst)), rarity.Color,
		radius * PlanetVisual.extent(def, data.E) * 0.75 + 3)
	model.Parent = planetFolder
	planets[slot] = { Model = model, Body = model.PrimaryPart, Def = def, Key = planetKey(data),
		Tilt = CFrame.Angles(math.rad(12 + slot * 3), 0, math.rad(-8 + slot * 2)), Rainbow = model:GetAttribute("Rainbow") == true,
		Surface = model:FindFirstChild("Surface"), Atmosphere = model:FindFirstChild("Atmosphere") }
end

local function addMarker(slot, kind, view)
	local part = Build.ball({ Position = view.Center, Radius = kind == "empty" and 2.2 or 1.8 }, { Name = "SlotMarker", CanCollide = false,
		Material = Enum.Material.Neon, Transparency = 0.45, Color = kind == "empty" and Color3.fromRGB(90, 255, 170) or Color3.fromRGB(255, 200, 90) })
	part:SetAttribute("Slot", slot)
	part:SetAttribute("Kind", kind)
	if kind == "empty" then
		nameTag(part, "+ Órbita " .. slot, "Colocar planeta", Color3.fromRGB(150, 255, 200), 5)
	else
		local cost = Progression.nextSlotCost(ctx.State.Data, view.System) or 0
		nameTag(part, "🔒 Órbita " .. slot, "⚡ " .. Format.number(cost), Color3.fromRGB(255, 215, 120), 5)
	end
	part.Parent = planetFolder
	markers[slot] = { Part = part, Kind = kind }
end

local function syncPlanets(view)
	local isOwner = view.Owner == player.UserId
	for slot = 1, Config.Economy.SlotsPerSystem do
		local data = view.Planets[Defs.Galaxy.slotKey(slot)]
		local entry = planets[slot]
		if data then
			removeMarker(slot)
			if not entry or entry.Key ~= planetKey(data) then
				removePlanet(slot)
				addPlanet(slot, data, isOwner)
			else
				entry.Model:SetAttribute("Uid", data.Uid)
			end
		else
			removePlanet(slot)
			local kind = nil
			if isOwner then
				if slot <= view.Slots then kind = "empty" elseif slot == view.Slots + 1 then kind = "locked" end
			end
			local marker = markers[slot]
			if (marker and marker.Kind) ~= kind then
				removeMarker(slot)
				if kind then addMarker(slot, kind, view) end
			end
		end
	end
end

---------------------------------------------------------------- tableros de la plataforma
local function boardGui(view, boardName)
	local zones = Workspace:FindFirstChild("PlayerUniverseZones")
	local plot = zones and zones:FindFirstChild("Universe_" .. tostring(view.Plot))
	local board = plot and plot:FindFirstChild(boardName)
	local panel = board and board:FindFirstChild("Panel")
	if not panel then return nil end
	local gui = Instance.new("SurfaceGui")
	gui.Name = boardName
	gui.Adornee = panel
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Build.label(gui, "", { Size = UDim2.fromScale(0.92, 0.9), Position = UDim2.fromScale(0.04, 0.05), TextScaled = false, TextSize = 30,
		Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, RichText = true })
	boards[boardName] = gui
	return label
end

local function updateBoards()
	if not current then return end
	local view = current.View
	local production = boards.Board_Production and boards.Board_Production:FindFirstChildOfClass("TextLabel")
	if production then
		local lines = { "<font size=\"40\"><b>PRODUCCIÓN</b></font>" }
		if view.Owner == player.UserId then
			local p = ctx.State.Data._Production
			if p then
				table.insert(lines, "<font color=\"#FFD246\" size=\"46\">⚡ " .. Format.rate(p.Total) .. "</font>")
				for _, sysId in ipairs(Defs.Galaxy.Order) do
					local sys = p.Systems[sysId]
					if sys then
						table.insert(lines, Defs.Galaxy.ById[sysId].Name .. ": " .. Format.rate(sys.Total) .. "  (" .. sys.Count .. " planetas)")
					end
				end
				local m = p.Mults
				table.insert(lines, "<font color=\"#46D7FF\">Mejoras " .. Format.mult(m.Reactor * m.Cores) .. " · Ascensión " .. Format.mult(m.Ascension)
					.. " · Evento " .. Format.mult(m.Event) .. "</font>")
			end
		else
			table.insert(lines, "<font color=\"#FFD246\" size=\"46\">⚡ " .. Format.rate(view.Stats.Rate) .. "</font>")
			table.insert(lines, "Universo de " .. view.Name)
		end
		production.Text = table.concat(lines, "\n")
	end
	local info = boards.Board_Universe and boards.Board_Universe:FindFirstChildOfClass("TextLabel")
	if info then
		local system = Defs.Galaxy.ById[view.System]
		local names = {}
		for _, sysId in ipairs(view.Stats.Systems) do
			table.insert(names, (string.gsub(Defs.Galaxy.ById[sysId].Name, " System", "")))
		end
		local placed = 0
		for _ in pairs(view.Planets) do
			placed = placed + 1
		end
		info.Text = table.concat({
			"<font size=\"40\"><b>" .. string.upper(system.Name) .. "</b></font>",
			"<font color=\"#C8AAFF\">Propietario: " .. view.Name .. "</font>",
			"Órbitas: " .. placed .. " / " .. view.Slots .. " (máx. 8)",
			"Colección: " .. view.Stats.Discovered .. " / " .. view.Stats.DiscoveredTotal,
			"Ascensiones: 👑 " .. view.Stats.Ascensions,
			"Sistemas: " .. table.concat(names, ", "),
		}, "\n")
	end
end

---------------------------------------------------------------- panel de orbitas (HUD)
local function buildSlotsPanel()
	local Kit, Theme = ctx.Kit, ctx.Theme
	local C = Theme.Colors
	local root = ctx.UI.Hud.Root
	local panel = Kit.box(root, C.Panel, 0.12, { Name = "OrbitsPanel", Size = UDim2.fromOffset(260, 392), Position = UDim2.new(1, -16, 0.5, 6),
		AnchorPoint = Vector2.new(1, 0.5), Visible = false }, 12)
	Kit.stroke(panel, C.Cyan, 1.5, 0.2)
	local title = Kit.label(panel, "ÓRBITAS", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(12, 6), TextSize = 13, Font = Theme.Fonts.Title,
		Color = C.Cyan })
	local list = Kit.frame(panel, { Name = "List", Size = UDim2.new(1, -16, 0, 300), Position = UDim2.fromOffset(8, 36) })
	Kit.listLayout(list, 4, false)
	local cameraButton = Kit.button(panel, "📷 Vista orbital", "ghost", { Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0, 8, 1, -46), TextSize = 13,
		Props = { Name = "CameraToggle" } }, function()
		if ctx.Camera then ctx.Camera.toggleOverview() end
	end)
	-- en moviles el panel se pliega tras un boton para no tapar el universo
	local toggle = Kit.button(root, "🪐 Órbitas", "cyan", { Size = UDim2.fromOffset(130, 40), Position = UDim2.new(1, -12, 0, 132),
		AnchorPoint = Vector2.new(1, 0), TextSize = 14, Props = { Name = "OrbitsToggle", Visible = false } }, function()
		slotsPanel.Expanded = not slotsPanel.Expanded
		Universe.refreshSlotsPanel()
	end)
	slotsPanel = { Frame = panel, Title = title, List = list, CameraButton = cameraButton, Toggle = toggle, Expanded = false, Compact = false }
	ctx.UI.onLayout(function(compact)
		slotsPanel.Compact = compact
		if compact then
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -330, 0.5, 0)
		else
			panel.AnchorPoint = Vector2.new(1, 0.5)
			panel.Position = UDim2.new(1, -16, 0.5, 6)
		end
		Universe.refreshSlotsPanel()
	end)
end

local refreshSlotsPanel
refreshSlotsPanel = function()
	if not slotsPanel then return end
	local Kit, Theme = ctx.Kit, ctx.Theme
	local C = Theme.Colors
	if not current then
		slotsPanel.Frame.Visible = false
		slotsPanel.Toggle.Visible = false
		return
	end
	local view = current.View
	local isOwner = view.Owner == player.UserId
	slotsPanel.Toggle.Visible = slotsPanel.Compact
	slotsPanel.Frame.Visible = (not slotsPanel.Compact) or slotsPanel.Expanded
	if not slotsPanel.Frame.Visible then return end
	slotsPanel.Title.Text = "ÓRBITAS · " .. string.upper((string.gsub(Defs.Galaxy.ById[view.System].Name, " System", "")))
	Kit.clear(slotsPanel.List)
	for slot = 1, Config.Economy.SlotsPerSystem do
		local data = view.Planets[Defs.Galaxy.slotKey(slot)]
		local text, style, enabled, action
		if data then
			local def = Defs.Planets.ById[data.Id]
			local variant = Defs.Variants.get(data.V)
			text = slot .. " · " .. Defs.Planets.displayName(def, data.E) .. (variant.Id ~= "none" and (" " .. variant.Icon) or "")
				.. "  ⚡" .. Format.rate(Progression.planetRate({ Id = data.Id, V = data.V or "none", E = data.E == true }))
			style, enabled = "ghost", true
			action = function()
				if isOwner then
					ctx.UI.open("Inventory", { Select = data.Uid })
				else
					ctx.UI.open("Inspect", { Planet = data, Owner = view.Name })
				end
			end
		elseif slot <= view.Slots then
			text = slot .. " · " .. (isOwner and "+ Colocar planeta" or "Vacía")
			style, enabled = isOwner and "green" or "ghost", isOwner
			action = function()
				ctx.UI.open("Inventory", { PlaceSlot = slot })
			end
		elseif slot == view.Slots + 1 and isOwner then
			local cost = Progression.nextSlotCost(ctx.State.Data, view.System) or 0
			text = slot .. " · 🔒 Desbloquear ⚡" .. Format.number(cost)
			style, enabled = "gold", (ctx.State.Data.Energy or 0) >= cost
			action = function()
				local result = ctx.UI.request("UnlockSlot", view.System)
				if result.Ok and ctx.Audio then ctx.Audio.play("success") end
			end
		else
			text = slot .. " · 🔒 Bloqueada"
			style, enabled = "ghost", false
		end
		local button = Kit.button(slotsPanel.List, text, style, { Size = UDim2.new(1, 0, 0, 33), TextSize = 12, Props = { LayoutOrder = slot,
			Name = "Slot" .. slot } }, action)
		Kit.setEnabled(button, enabled)
	end
end
Universe.refreshSlotsPanel = refreshSlotsPanel

---------------------------------------------------------------- ciclo
local function starKey(view)
	local c = view.Cosmetics or {}
	local s = settings()
	return view.System .. "|" .. tostring(view.Slots) .. "|" .. tostring(c.OrbitColor) .. "|" .. tostring(c.StarAura) .. "|" .. tostring(view.Plot)
		.. "|" .. tostring(s.LowQuality) .. "|" .. tostring(s.ReducedEffects)
end

local function render()
	local owner = ctx.State.locationOwner()
	local view = owner and ctx.State.Universes[owner] or nil
	if not view then
		if current then clearAll() end
		refreshSlotsPanel()
		return
	end
	local key = starKey(view)
	if not current or current.Owner ~= owner or current.StarKey ~= key then
		clearAll()
		local theme = Defs.Galaxy.ById[view.System].Theme
		local low = settings().LowQuality == true
		staticFolder = Instance.new("Folder")
		staticFolder.Name = "Static"
		planetFolder = Instance.new("Folder")
		planetFolder.Name = "Planets"
		buildStar(view, theme, staticFolder, low)
		buildOrbits(view, theme, staticFolder, low)
		buildBackdrop(view, theme, staticFolder, low)
		staticFolder.Parent = container
		planetFolder.Parent = container
		current = { Owner = owner, View = view, StarKey = key, Center = view.Center }
		boardGui(view, "Board_Production")
		boardGui(view, "Board_Universe")
	end
	current.View = view
	syncPlanets(view)
	updateBoards()
	refreshSlotsPanel()
end
Universe.render = render

local function onFrame()
	if not current then return end
	local now = ctx.State.serverTime()
	local center = current.Center
	for slot, entry in pairs(planets) do
		local angle = Layout.orbitAngle(slot, entry.Def.OrbitSpeed, now)
		local pos = Layout.orbitPosition(center, slot, angle)
		entry.Body.CFrame = CFrame.new(pos) * entry.Tilt * CFrame.Angles(0, math.rad(entry.Def.RotationSpeed) * now % (math.pi * 2), 0)
		if entry.Rainbow then
			local hue = (now * 0.08 + slot * 0.13) % 1
			local color = Color3.fromHSV(hue, 0.5, 1)
			if entry.Atmosphere then entry.Atmosphere.Color = color end
			local mesh = entry.Surface and entry.Surface:FindFirstChildOfClass("SpecialMesh")
			if mesh then mesh.VertexColor = Vector3.new(color.R, color.G, color.B) end
		end
	end
	for slot, entry in pairs(markers) do
		local angle = Layout.orbitAngle(slot, 1, now)
		entry.Part.CFrame = CFrame.new(Layout.orbitPosition(center, slot, angle))
	end
	for _, spinner in ipairs(spinners) do
		if spinner.Model then
			spinner.Model:PivotTo(spinner.Base * CFrame.Angles(0, now * spinner.Speed % (math.pi * 2), 0))
		elseif spinner.Pulse then
			local s = spinner.Radius * (1.3 + 0.25 * math.sin(now * 1.4)) * 2
			spinner.Pulse.Size = Vector3.new(s, s, s)
		end
	end
end

-- Clic/toque sobre un planeta o un marcador de slot
local function onPointer(screenPosition)
	if not current then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { planetFolder }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
	if not hit then return end
	local part = hit.Instance
	local view = current.View
	local isOwner = view.Owner == player.UserId
	if part.Name == "SlotMarker" then
		if not isOwner then return end
		local slot = part:GetAttribute("Slot")
		if part:GetAttribute("Kind") == "empty" then
			ctx.UI.open("Inventory", { PlaceSlot = slot })
		else
			local cost = Progression.nextSlotCost(ctx.State.Data, view.System) or 0
			ctx.UI.confirm({ Title = "Desbloquear órbita", Icon = "🔓", Confirm = "Desbloquear", Style = "gold",
				Text = "¿Desbloquear la órbita " .. slot .. " de " .. Defs.Galaxy.ById[view.System].Name .. " por " .. Format.number(cost) .. " de Energy?",
				OnConfirm = function()
					ctx.UI.request("UnlockSlot", view.System)
				end })
		end
		return
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("PlanetId") then
		local slot = model:GetAttribute("Slot")
		local data = view.Planets[Defs.Galaxy.slotKey(slot)]
		if not data then return end
		if isOwner then
			ctx.UI.open("Inventory", { Select = data.Uid })
		else
			ctx.UI.open("Inspect", { Planet = data, Owner = view.Name })
		end
	end
end

function Universe.currentCenter()
	return current and current.Center or nil
end

function Universe.init(context)
	ctx = context
	ctx.Universe = Universe
	container = Instance.new("Folder")
	container.Name = "ClientUniverse"
	container.Parent = Workspace
	buildSlotsPanel()

	ctx.State.on("_Session", render)
	ctx.State.onUniverse(function(userId)
		if ctx.State.locationOwner() == userId then render() end
	end)
	ctx.State.on("Settings", render)
	ctx.State.on("_Production", updateBoards)
	local lastEnergyRefresh = 0
	ctx.State.on("Energy", function()
		if current and os.clock() - lastEnergyRefresh > 1.5 then
			lastEnergyRefresh = os.clock()
			refreshSlotsPanel()
		end
	end)
	RunService:BindToRenderStep("PlanetCollectorOrbits", Enum.RenderPriority.Camera.Value - 5, onFrame)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPointer(UserInputService:GetMouseLocation())
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then onPointer(position) end
	end)
	render()
end

return Universe
