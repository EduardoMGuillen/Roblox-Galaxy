-- Build: utilidades para construir geometria por codigo (piezas, anillos, carteles, luces, prompts).
-- Las usan el servidor (Cosmic Hub, parcelas) y el cliente (estrella, orbitas, efectos).
local Build = {}

Build.Colors = {
	Hull = Color3.fromRGB(22, 27, 44), -- metal oscuro / grafito azulado
	HullLight = Color3.fromRGB(40, 48, 74),
	Deck = Color3.fromRGB(28, 34, 56),
	Trim = Color3.fromRGB(58, 70, 108),
	Cyan = Color3.fromRGB(70, 215, 255),
	Blue = Color3.fromRGB(60, 120, 255),
	Violet = Color3.fromRGB(170, 95, 255),
	Magenta = Color3.fromRGB(255, 80, 210),
	Gold = Color3.fromRGB(255, 200, 90),
	White = Color3.fromRGB(235, 240, 255),
}

local function apply(inst, props)
	local parent = nil
	for key, value in pairs(props) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	if parent then inst.Parent = parent end
	return inst
end
Build.apply = apply

function Build.new(className, props)
	return apply(Instance.new(className), props or {})
end

-- Pieza anclada generica. props admite cualquier propiedad de Part.
function Build.part(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = Build.Colors.Hull
	return apply(part, props)
end

-- Pieza decorativa sin colision ni consultas
function Build.decor(props)
	local part = Build.part(props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

function Build.neon(props)
	local part = Build.decor(props)
	part.Material = Enum.Material.Neon
	return part
end

-- Cilindro con el eje en Y (vertical) por defecto. opts: Position, Radius, Height, CFrame (opcional, eje Y local)
function Build.cylinder(opts, props)
	local cf = opts.CFrame or CFrame.new(opts.Position)
	local p = props or {}
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(opts.Height, opts.Radius * 2, opts.Radius * 2)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	return Build.part(p)
end

function Build.ball(opts, props)
	local p = props or {}
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(opts.Radius * 2, opts.Radius * 2, opts.Radius * 2)
	p.CFrame = opts.CFrame or CFrame.new(opts.Position)
	return Build.part(p)
end

-- Anillo de segmentos en el plano XZ local de `cf`.
-- opts: CFrame, Radius, Width (grosor radial), Height, Segments, Gap (0-1, fraccion vacia entre segmentos),
--       Arc (radianes, por defecto circulo completo), Start (angulo inicial)
function Build.ring(opts, props)
	local segments = opts.Segments or 32
	local arc = opts.Arc or (math.pi * 2)
	local start = opts.Start or 0
	local step = arc / segments
	local length = 2 * opts.Radius * math.tan(step / 2) * (1 - (opts.Gap or 0)) + (opts.Gap and 0 or 0.02)
	local parts = {}
	for i = 0, segments - 1 do
		local angle = start + (i + 0.5) * step
		local p = {}
		for k, v in pairs(props or {}) do
			p[k] = v
		end
		p.Size = Vector3.new(opts.Width, opts.Height, length)
		p.CFrame = opts.CFrame * CFrame.Angles(0, -angle, 0) * CFrame.new(opts.Radius, 0, 0)
		if opts.Collide then
			table.insert(parts, Build.part(p))
		else
			table.insert(parts, Build.decor(p))
		end
	end
	return parts
end

function Build.light(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 24
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

-- SurfaceGui con un marco raiz. Devuelve gui, frame.
function Build.surfaceGui(part, face, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 30
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.ResetOnSpawn = false
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	return gui, frame
end

-- Etiqueta de texto con el estilo de la interfaz (blanco con borde luminoso)
function Build.label(parent, text, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Build.Colors.White
	label.TextScaled = true
	label.TextWrapped = true
	apply(label, props or {})
	label.Parent = parent
	return label
end

function Build.stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

-- Cartel luminoso: panel oscuro con borde neon y texto. `cf` mira hacia el espectador (cara Front).
-- opts: CFrame, Width, Height, Text, Color (acento), TextColor, Parent, Name, PixelsPerStud, Font
function Build.sign(opts)
	local accent = opts.Color or Build.Colors.Cyan
	local model = Instance.new("Model")
	model.Name = opts.Name or "Sign"
	local panel = Build.decor({
		Name = "Panel", Size = Vector3.new(opts.Width, opts.Height, 0.5), CFrame = opts.CFrame,
		Color = Color3.fromRGB(10, 14, 30), Material = Enum.Material.Glass, Transparency = 0.2, Parent = model,
	})
	local t = 0.35
	local w, h = opts.Width, opts.Height
	Build.neon({ Name = "Top", Size = Vector3.new(w + t, t, 0.7), CFrame = opts.CFrame * CFrame.new(0, h / 2, 0), Color = accent, Parent = model })
	Build.neon({ Name = "Bottom", Size = Vector3.new(w + t, t, 0.7), CFrame = opts.CFrame * CFrame.new(0, -h / 2, 0), Color = accent, Parent = model })
	Build.neon({ Name = "Left", Size = Vector3.new(t, h + t, 0.7), CFrame = opts.CFrame * CFrame.new(-w / 2, 0, 0), Color = accent, Parent = model })
	Build.neon({ Name = "Right", Size = Vector3.new(t, h + t, 0.7), CFrame = opts.CFrame * CFrame.new(w / 2, 0, 0), Color = accent, Parent = model })
	if opts.Text then
		local _, root = Build.surfaceGui(panel, Enum.NormalId.Front, opts.PixelsPerStud or 24)
		local label = Build.label(root, opts.Text, {
			Size = UDim2.fromScale(0.92, 0.78), Position = UDim2.fromScale(0.04, 0.11),
			Font = opts.Font or Enum.Font.Michroma, TextColor3 = opts.TextColor or accent,
		})
		Build.stroke(label, Color3.fromRGB(8, 12, 40), 2, 0.2)
	end
	model.PrimaryPart = panel
	model.Parent = opts.Parent
	return model, panel
end

-- ProximityPrompt con una accion que el cliente interpreta (atributo "Action")
function Build.prompt(part, actionText, objectText, action, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Action", action)
	prompt.Parent = part
	return prompt
end

-- Emisor de particulas con una textura integrada del cliente (no requiere assets subidos)
Build.ParticleTextures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

function Build.particles(parent, props)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Build.ParticleTextures.Sparkle
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	apply(emitter, props or {})
	emitter.Parent = parent
	return emitter
end

-- Secuencia de tamaño simple: aparece, se mantiene y desaparece
function Build.sizeSeq(size)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, size), NumberSequenceKeypoint.new(1, 0) })
end

function Build.fadeSeq(minTransparency)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, minTransparency),
		NumberSequenceKeypoint.new(1, 1) })
end

return Build
