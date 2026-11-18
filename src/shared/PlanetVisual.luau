-- PlanetVisual: construye el modelo 3D de un planeta a partir de sus datos (PlanetDefinitions.Visual).
-- Un solo constructor para todo el catalogo: superficie texturizada (si hay assets), atmosfera,
-- anillos, cristales, particulas, variantes (Shiny/Golden/Rainbow/Cosmic) y forma evolucionada (Prime).
-- Se usa en el mundo (orbitas, Hub) y en ViewportFrames (inventario, capsulas, coleccion).
local Defs = require(script.Parent.Defs)
local Assets = require(script.Parent.Assets)
local Build = require(script.Parent.Util.Build)
local Config = Defs.Config

local PlanetVisual = {}

local VARIANT_TINT = {
	golden = Vector3.new(1, 0.8, 0.36),
	shiny = Vector3.new(1, 1, 1),
}

local function v3(color)
	return Vector3.new(color.R, color.G, color.B)
end

local function material(name)
	local ok, item = pcall(function()
		return Enum.Material[name]
	end)
	if ok and item then return item end
	return Enum.Material.SmoothPlastic
end

-- Radio en studs de una instancia
function PlanetVisual.radius(def, evolved, override)
	local r = override or (Config.World.PlanetBaseRadius * def.Scale)
	if evolved then r = r * Config.Evolution.ScaleMultiplier end
	return r
end

-- Factor de extension maxima (anillos incluidos) respecto al radio; sirve para encuadrar la camara
function PlanetVisual.extent(def, evolved)
	local e = 1.15
	local visual = def.Visual
	if visual.Rings then
		for _, ring in ipairs(visual.Rings) do
			if ring.Outer > e then e = ring.Outer end
		end
	end
	if visual.Shards then e = math.max(e, 1 + visual.Shards.Length * 1.1) end
	if evolved then e = e + 0.4 end
	return e
end

local function sphereMesh(part, radius, textureUrl, tint)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = Assets.url(Assets.SphereMesh)
	mesh.TextureId = textureUrl
	local s = radius / Assets.SphereMeshRadius
	mesh.Scale = Vector3.new(s, s, s)
	mesh.VertexColor = tint or Vector3.new(1, 1, 1)
	mesh.Parent = part
	return mesh
end

local function fibonacci(i, n)
	local y = 1 - (i - 0.5) / n * 2
	local r = math.sqrt(math.max(0, 1 - y * y))
	local a = i * 2.399963
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

-- opts: Radius (studs), Lite (para ViewportFrame: sin luces/particulas), Static (sin particulas),
--       Distant (planeta de fondo), Hologram (tinte holografico), Welded (piezas soldadas al cuerpo
--       para moverlo con un solo CFrame)
function PlanetVisual.build(planetId, variant, evolved, opts)
	opts = opts or {}
	variant = variant or "none"
	local def = Defs.Planets.ById[planetId]
	local visual = def.Visual
	local radius = PlanetVisual.radius(def, evolved, opts.Radius)
	local lite = opts.Lite == true
	local effects = not lite and not opts.Static and not opts.Distant
	local rng = Random.new(def.Order * 977 + 13)

	local model = Instance.new("Model")
	model.Name = "Planet_" .. planetId
	model:SetAttribute("PlanetId", planetId)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("Evolved", evolved == true)
	model:SetAttribute("Radius", radius)

	local baseColor = visual.Color
	local atmosphereColor = visual.Atmosphere
	local tint = visual.Tint and v3(visual.Tint) or Vector3.new(1, 1, 1)
	if variant == "golden" then
		baseColor = Color3.fromRGB(240, 190, 80)
		atmosphereColor = Color3.fromRGB(255, 215, 110)
		tint = VARIANT_TINT.golden
	elseif variant == "cosmic" then
		atmosphereColor = Color3.fromRGB(170, 110, 255)
	elseif variant == "shiny" then
		atmosphereColor = atmosphereColor or Color3.fromRGB(220, 240, 255)
	elseif variant == "rainbow" then
		atmosphereColor = atmosphereColor or Color3.fromRGB(255, 255, 255)
		model:SetAttribute("Rainbow", true)
	end
	if opts.Hologram then
		tint = Vector3.new(0.62, 0.9, 1)
		atmosphereColor = Color3.fromRGB(90, 220, 255)
	end

	local textureUrl = Assets.texture(visual.Texture)
	local useMesh = Assets.SphereMesh ~= 0 and textureUrl ~= ""

	-- cuerpo: esfera con material integrado (siempre visible aunque un asset no cargue)
	local body = Build.ball({ Position = Vector3.zero, Radius = useMesh and radius * 0.97 or radius }, {
		Name = "Body", Color = baseColor, Material = material(visual.Material), CanCollide = false, CanTouch = false, Parent = model,
	})
	if variant == "shiny" then body.Reflectance = 0.35 end
	if visual.Emissive then body.Material = Enum.Material.Neon end
	model.PrimaryPart = body

	local parts = {}
	local function add(part)
		table.insert(parts, part)
		part.Parent = model
		return part
	end

	if useMesh then
		local surface = Build.decor({ Name = "Surface", Size = Vector3.new(1, 1, 1), CFrame = CFrame.identity, Color = baseColor })
		-- los mundos emisivos dejan ver el nucleo de neon a traves de una superficie semitransparente
		if visual.Emissive then surface.Transparency = 0.3 end
		if variant == "shiny" then surface.Reflectance = 0.3 end
		if opts.Hologram then surface.Transparency = 0.12 end
		sphereMesh(surface, radius, textureUrl, tint)
		add(surface)
		if variant == "cosmic" and Assets.texture("cosmic") ~= "" then
			local overlay = Build.decor({ Name = "CosmicOverlay", Size = Vector3.new(1, 1, 1), CFrame = CFrame.identity, Transparency = 0.45 })
			sphereMesh(overlay, radius * 1.02, Assets.texture("cosmic"), Vector3.new(0.9, 0.7, 1))
			add(overlay)
		end
		if visual.Clouds and Assets.texture("clouds") ~= "" then
			local clouds = Build.decor({ Name = "Clouds", Size = Vector3.new(1, 1, 1), CFrame = CFrame.identity, Transparency = 0.25 })
			sphereMesh(clouds, radius * 1.025, Assets.texture("clouds"), Vector3.new(1, 1, 1))
			add(clouds)
		end
	end

	-- atmosfera
	if atmosphereColor and not opts.NoAtmosphere then
		local shell = Build.ball({ Position = Vector3.zero, Radius = radius * (opts.Distant and 1.04 or 1.09) }, {
			Name = "Atmosphere", Color = atmosphereColor, CanCollide = false, CanQuery = false, CanTouch = false,
		})
		if lite or opts.Distant then
			shell.Material = Enum.Material.Neon
			shell.Transparency = opts.Distant and 0.9 or 0.86
		else
			shell.Material = Enum.Material.ForceField
			shell.Transparency = (variant == "shiny" or opts.Hologram) and 0.05 or 0.3
		end
		add(shell)
	end

	-- relieve rocoso
	if visual.Bumps and not opts.Distant then
		for i = 1, visual.Bumps do
			local dir = fibonacci(i, visual.Bumps)
			local r = radius * rng:NextNumber(0.2, 0.34)
			add(Build.ball({ Position = dir * (radius * 0.84), Radius = r }, {
				Name = "Bump", Color = baseColor:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)), Material = material(visual.Material),
				CanCollide = false, CanQuery = false, CanTouch = false,
			}))
		end
	end

	-- cristales
	if visual.Shards and not opts.Distant then
		local shards = visual.Shards
		local shardColor = variant == "golden" and Color3.fromRGB(255, 215, 120) or shards.Color
		for i = 1, shards.Count do
			local dir = fibonacci(i, shards.Count)
			local length = radius * shards.Length * rng:NextNumber(0.7, 1.35)
			local width = length * rng:NextNumber(0.28, 0.4)
			local pos = dir * (radius * 0.8 + length * 0.42)
			local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(-90), rng:NextNumber(0, math.pi), 0)
			add(Build.decor({
				Name = "Shard", Size = Vector3.new(width, length, width), CFrame = cf, Color = shardColor,
				Material = (i % 3 == 0) and Enum.Material.Neon or Enum.Material.Glass, Transparency = (i % 3 == 0) and 0.1 or 0.2,
				Reflectance = 0.25,
			}))
		end
	end

	-- anillos
	local maxOuter = 1.15
	if visual.Rings then
		for index, ring in ipairs(visual.Rings) do
			if ring.Outer > maxOuter then maxOuter = ring.Outer end
			local ringColor = variant == "golden" and Color3.fromRGB(255, 220, 130) or ring.Color
			local cf = CFrame.Angles(math.rad(ring.Tilt or 0), 0, math.rad((ring.Tilt or 0) * 0.3))
			if ring.Line then
				local mid = (ring.Inner + ring.Outer) / 2 * radius
				local width = math.max(0.12, (ring.Outer - ring.Inner) * radius)
				for _, seg in ipairs(Build.ring({ CFrame = cf, Radius = mid, Width = width, Height = math.max(0.1, radius * 0.035),
					Segments = opts.Distant and 20 or 28 }, { Name = "RingLine" .. index, Color = ringColor, Material = Enum.Material.Neon,
					Transparency = ring.Alpha or 0.1 })) do
					add(seg)
				end
			else
				local hasImage = Assets.image("ring") ~= ""
				local t = math.min(0.9, (ring.Alpha or 0.3) + (hasImage and 0.5 or 0.3))
				local inner = ring.Inner + (ring.Outer - ring.Inner) * 0.55
				add(Build.cylinder({ CFrame = cf, Radius = inner * radius, Height = math.max(0.08, radius * 0.03) }, {
					Name = "RingBandInner", Color = ringColor, Material = Enum.Material.Neon, Transparency = t,
					CanCollide = false, CanQuery = false, CanTouch = false,
				}))
				add(Build.cylinder({ CFrame = cf, Radius = ring.Outer * radius, Height = math.max(0.06, radius * 0.02) }, {
					Name = "RingBandOuter", Color = ringColor, Material = Enum.Material.Neon, Transparency = math.min(0.92, t + 0.18),
					CanCollide = false, CanQuery = false, CanTouch = false,
				}))
				if hasImage and not lite then
					local plate = Build.decor({ Name = "RingPlate", Size = Vector3.new(ring.Outer * radius * 2, 0.05, ring.Outer * radius * 2),
						CFrame = cf, Transparency = 1 })
					for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
						local decal = Instance.new("Decal")
						decal.Face = face
						decal.Texture = Assets.image("ring")
						decal.Color3 = ringColor
						decal.Transparency = 0.15
						decal.Parent = plate
					end
					add(plate)
				end
			end
		end
	end

	-- forma evolucionada: corona exterior
	if evolved then
		local crownRadius = (maxOuter + 0.32) * radius
		for _, seg in ipairs(Build.ring({ CFrame = CFrame.Angles(math.rad(38), 0, math.rad(-20)), Radius = crownRadius,
			Width = math.max(0.14, radius * 0.045), Height = math.max(0.14, radius * 0.045), Segments = 30 },
			{ Name = "PrimeCrown", Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Transparency = 0.05 })) do
			add(seg)
		end
	end

	-- luces y particulas (solo en el mundo)
	if effects then
		local glow = visual.Glow or (variant ~= "none" and atmosphereColor) or nil
		if glow then
			Build.light(body, glow, math.min(60, radius * 5), 1.4)
		end
		local kind = visual.Particles
		local presets = {
			embers = { Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20), 9, 2.2 },
			frost = { Color3.fromRGB(220, 245, 255), Color3.fromRGB(140, 210, 255), 7, 1.2 },
			stardust = { Color3.fromRGB(170, 150, 255), Color3.fromRGB(110, 170, 255), 8, 1.4 },
			vortex = { Color3.fromRGB(210, 130, 255), Color3.fromRGB(120, 50, 230), 16, 3 },
			energy = { Color3.fromRGB(120, 255, 240), Color3.fromRGB(255, 110, 230), 10, 2.6 },
		}
		local function emit(c0, c1, rate, speed, name)
			local emitter = Build.particles(body, {
				Name = name, Color = ColorSequence.new(c0, c1), Rate = rate, Speed = NumberRange.new(speed * 0.4, speed),
				Lifetime = NumberRange.new(1.2, 2.4), Size = Build.sizeSeq(radius * 0.16), RotSpeed = NumberRange.new(-90, 90),
			})
			emitter.Shape = Enum.ParticleEmitterShape.Sphere
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			return emitter
		end
		if kind and presets[kind] then
			local p = presets[kind]
			emit(p[1], p[2], p[3], p[4], "Aura")
		end
		if variant == "shiny" then
			emit(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 235, 255), 8, 1.5, "VariantFx")
		elseif variant == "golden" then
			emit(Color3.fromRGB(255, 225, 130), Color3.fromRGB(255, 180, 60), 8, 1.2, "VariantFx")
		elseif variant == "rainbow" then
			emit(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), 9, 1.5, "VariantFx")
		elseif variant == "cosmic" then
			emit(Color3.fromRGB(190, 140, 255), Color3.fromRGB(90, 120, 255), 12, 1.8, "VariantFx")
		end
		if evolved then
			emit(Color3.fromRGB(255, 245, 210), Color3.fromRGB(255, 215, 120), 6, 2.4, "PrimeFx")
		end
	end

	if opts.Welded then
		for _, part in ipairs(parts) do
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

-- Monta un planeta dentro de un ViewportFrame con su camara. Devuelve el modelo y la camara.
function PlanetVisual.mount(viewport, planetId, variant, evolved)
	local def = Defs.Planets.ById[planetId]
	local model = PlanetVisual.build(planetId, variant, evolved, { Lite = true, Radius = 4 })
	model:PivotTo(CFrame.Angles(math.rad(18), math.rad(30), math.rad(-14)))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local extent = PlanetVisual.extent(def, evolved) * 4 * (evolved and Config.Evolution.ScaleMultiplier or 1)
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, extent * 0.9, extent * 3.6), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = Color3.fromRGB(150, 150, 170)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -0.8, -1)
	return model, camera
end

return PlanetVisual
