-- UniverseBuilder: estructura fija de una parcela de universo personal (plataforma de observacion,
-- terminales, portal de regreso y tableros). La estrella, las orbitas y los planetas los dibuja cada
-- cliente a partir del estado autorizado por el servidor (UniverseController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Layout = require(Shared.UniverseLayout)
local HubBuilder = require(script.Parent.HubBuilder)
local C = Build.Colors

local UniverseBuilder = {}

function UniverseBuilder.build(index, center, ownerName)
	local model = Instance.new("Model")
	model.Name = "Universe_" .. tostring(index)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerName", ownerName)

	local deckPos = Layout.deckPosition(center)
	local radius = Layout.DeckRadius
	-- marco local de la plataforma: -Z mira hacia la estrella
	local origin = CFrame.new(deckPos)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	local function facingCenter(x, y, z)
		local pos = (origin * CFrame.new(x, y, z)).Position
		return CFrame.lookAt(pos, Vector3.new(deckPos.X, pos.Y, deckPos.Z))
	end

	-- plataforma
	Build.cylinder({ CFrame = at(0, -1, 0), Radius = radius, Height = 2 },
		{ Name = "Deck", Color = C.Deck, Material = Enum.Material.SmoothPlastic, Reflectance = 0.14, Parent = model })
	Build.cylinder({ CFrame = at(0, -4, 0), Radius = radius - 8, Height = 4 },
		{ Name = "Keel1", Color = C.Hull, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
	Build.cylinder({ CFrame = at(0, -10, 0), Radius = radius - 20, Height = 8 },
		{ Name = "Keel2", Color = C.HullLight, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
	Build.cylinder({ CFrame = at(0, -22, 0), Radius = 1.2, Height = 16 },
		{ Name = "Antenna", Color = C.Trim, Material = Enum.Material.Metal, CanCollide = false, Parent = model })
	Build.cylinder({ CFrame = at(0, -2.2, 0), Radius = radius - 2, Height = 0.5 },
		{ Name = "Underglow", Color = C.Cyan, Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Parent = model })
	for _, r in ipairs({ { radius - 1.5, C.Cyan }, { 22, C.Violet }, { 9, C.Cyan } }) do
		Build.ring({ CFrame = at(0, 0.05, 0), Radius = r[1], Width = 0.5, Height = 0.12, Segments = 40 },
			{ Color = r[2], Material = Enum.Material.Neon, Parent = model })
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		Build.neon({ Name = "Ray", Size = Vector3.new(12, 0.1, 0.3), Color = C.Cyan, Transparency = 0.3,
			CFrame = at(0, 0.05, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(15.5, 0, 0), Parent = model })
	end

	-- barandilla de cristal al frente (hacia la estrella) y muro bajo detras
	Build.ring({ CFrame = at(0, 1.7, 0), Radius = radius - 0.6, Width = 0.3, Height = 3.4, Segments = 18,
		Start = math.rad(200), Arc = math.rad(140), Collide = true },
		{ Name = "GlassRail", Color = C.Cyan, Material = Enum.Material.Glass, Transparency = 0.7, Parent = model })
	Build.ring({ CFrame = at(0, 3.5, 0), Radius = radius - 0.6, Width = 0.45, Height = 0.25, Segments = 18,
		Start = math.rad(200), Arc = math.rad(140) },
		{ Name = "RailGlow", Color = C.Cyan, Material = Enum.Material.Neon, Parent = model })
	Build.ring({ CFrame = at(0, 2.5, 0), Radius = radius - 0.9, Width = 1.8, Height = 5, Segments = 26,
		Start = math.rad(-20), Arc = math.rad(220), Collide = true },
		{ Name = "BackWall", Color = C.Hull, Material = Enum.Material.Metal, Parent = model })
	Build.ring({ CFrame = at(0, 5.1, 0), Radius = radius - 0.9, Width = 0.6, Height = 0.25, Segments = 26,
		Start = math.rad(-20), Arc = math.rad(220) },
		{ Name = "BackWallGlow", Color = C.Violet, Material = Enum.Material.Neon, Parent = model })
	Build.ring({ CFrame = at(0, 30, 0), Radius = radius - 0.4, Width = 1, Height = 60, Segments = 24, Collide = true },
		{ Name = "Barrier", Transparency = 1, Parent = model })

	-- portal de regreso al Hub
	HubBuilder.buildPortal(model, facingCenter(0, 0, 27), "COSMIC HUB", "Hub", "Volver al Hub", 0.5, C.Cyan)

	-- terminales (todas miran al centro de la plataforma)
	HubBuilder.buildTerminal(model, "UpgradeTerminal", facingCenter(-19, 0, 19), "MEJORAS", "Upgrades", "Abrir mejoras", C.Cyan)
	HubBuilder.buildTerminal(model, "CapsuleTerminal", facingCenter(19, 0, 19), "CÁPSULAS", "Capsules", "Abrir cápsulas", C.Violet)
	HubBuilder.buildTerminal(model, "GalaxyTerminal", facingCenter(-29, 0, 2), "SISTEMAS", "Galaxy", "Ver sistemas", C.Blue)
	HubBuilder.buildTerminal(model, "CollectionTerminal", facingCenter(29, 0, 2), "COLECCIÓN", "Collection", "Ver colección", C.Gold)

	-- tableros que rellena el cliente: produccion (izquierda) y estadisticas del universo (derecha)
	local lookAt = (origin * CFrame.new(0, 6, 6)).Position
	HubBuilder.buildBoard(model, "Board_Production", (origin * CFrame.new(-30, 15, -22)).Position, lookAt, 22, 13, C.Cyan, deckPos.Y)
	HubBuilder.buildBoard(model, "Board_Universe", (origin * CFrame.new(30, 15, -22)).Position, lookAt, 22, 13, C.Violet, deckPos.Y)

	-- cartel del propietario
	local anchor = Build.decor({ Name = "OwnerAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = at(0, 26, 30), Parent = model })
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OwnerSign"
	billboard.Size = UDim2.fromScale(40, 6)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 600
	billboard.Parent = anchor
	local label = Build.label(billboard, "UNIVERSO DE " .. string.upper(ownerName), { Font = Enum.Font.Michroma })
	Build.stroke(label, C.Blue, 2, 0)

	-- luces de cubierta
	for _, p in ipairs({ { -16, -14 }, { 16, -14 }, { -16, 14 }, { 16, 14 } }) do
		local lamp = Build.decor({ Name = "DeckLight", Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = at(p[1], 8, p[2]), Parent = model })
		Build.light(lamp, C.Cyan, 36, 1.2)
	end

	model.Parent = Workspace:FindFirstChild("PlayerUniverseZones")
	return model
end

return UniverseBuilder
