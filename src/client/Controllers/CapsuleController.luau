-- CapsuleController: animacion de apertura de capsulas. Solo reproduce el resultado que ya decidio el
-- servidor: capsula y nombre -> vibracion y luz -> apertura -> el planeta emerge girando -> datos.
-- Es corta y se puede saltar tocando la pantalla (o desactivar en Ajustes).
local RunService = game:GetService("RunService")

local Capsule = {}
local ctx = nil
local playing = false
local queue = {}

local function reveal(root, data, skipIntro)
	local Kit, Defs, Format, Progression, Theme = ctx.Kit, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local capsuleDef = Defs.Capsules.ById[data.Capsule]
	local results = data.Results
	-- se muestra el mejor resultado (mayor rareza; variante como desempate)
	local best = results[1]
	local function score(r)
		local s = Defs.Rarities.ById[r.Rarity].Order * 10
		if r.V ~= "none" then s = s + 5 end
		if r.New then s = s + 1 end
		return s
	end
	for _, r in ipairs(results) do
		if score(r) > score(best) then best = r end
	end
	local def = Defs.Planets.ById[best.Id]
	local rarity = Defs.Rarities.ById[def.Rarity]
	local variant = Defs.Variants.get(best.V)
	local skipped = skipIntro
	local finished = false

	local stage = Kit.frame(root, { Name = "Stage", Size = UDim2.fromOffset(700, 560), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5) })
	local title = Kit.label(stage, string.upper(capsuleDef.Name), { Size = UDim2.new(1, 0, 0, 40), TextSize = 26, Font = F.Title,
		AlignX = Enum.TextXAlignment.Center, Color = capsuleDef.Color, Stroke = true })

	-- capsula (dos mitades)
	local pill = Kit.frame(stage, { Name = "Pill", Size = UDim2.fromOffset(130, 250), Position = UDim2.new(0.5, 0, 0, 190),
		AnchorPoint = Vector2.new(0.5, 0.5) })
	local glow = Kit.box(pill, capsuleDef.Color, 0.7, { Size = UDim2.fromOffset(260, 260), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5) }, 130)
	local top = Kit.box(pill, Color3.fromRGB(240, 244, 255), 0, { Size = UDim2.new(1, 0, 0.5, 0) }, 60)
	local bottom = Kit.box(pill, capsuleDef.Color, 0, { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5) }, 60)
	Kit.gradient(bottom, capsuleDef.CoreColor, capsuleDef.Color, 90)
	local core = Kit.box(pill, capsuleDef.CoreColor, 0, { Size = UDim2.new(1, 8, 0, 26), Position = UDim2.new(0, -4, 0.5, -13) }, 8)
	Kit.stroke(core, Color3.new(1, 1, 1), 2, 0.2)

	local flash = Kit.frame(root, { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1, ZIndex = 5 })

	local skipConn = nil
	local catcher = Instance.new("TextButton")
	catcher.Name = "Skip"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 4
	catcher.Parent = root
	skipConn = catcher.Activated:Connect(function()
		skipped = true
	end)
	local hint = Kit.label(root, "Toca para saltar", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -40), TextSize = 13,
		AlignX = Enum.TextXAlignment.Center, Color = C.TextDim })

	local function waitOrSkip(seconds)
		local t = 0
		while t < seconds and not skipped do
			t = t + task.wait(0.03)
		end
	end

	if not skipped then
		if ctx.Audio then ctx.Audio.play("charge") end
		-- vibracion breve y aumento de luz
		for i = 1, 9 do
			if skipped then break end
			pill.Rotation = (i % 2 == 0) and 5 or -5
			glow.BackgroundTransparency = math.max(0.2, 0.7 - i * 0.055)
			glow.Size = UDim2.fromOffset(260 + i * 14, 260 + i * 14)
			waitOrSkip(0.085)
		end
		pill.Rotation = 0
		-- apertura mecanica + destello
		Kit.tween(top, 0.25, { Position = UDim2.new(0, 0, 0, -70), BackgroundTransparency = 1 })
		Kit.tween(bottom, 0.25, { Position = UDim2.new(0, 0, 0.5, 70), BackgroundTransparency = 1 })
		Kit.tween(core, 0.2, { BackgroundTransparency = 1 })
		flash.BackgroundTransparency = 0.15
		Kit.tween(flash, 0.45, { BackgroundTransparency = 1 })
		waitOrSkip(0.25)
	end
	pill:Destroy()
	flash.BackgroundTransparency = 1
	hint:Destroy()
	skipConn:Disconnect()
	catcher:Destroy()
	if ctx.Audio then
		ctx.Audio.play(rarity.Order >= 4 and "fanfare" or "reveal")
	end

	-- el planeta emerge y rota
	title.Text = (best.New and "¡NUEVO DESCUBRIMIENTO!") or (best.NewVariant and "¡NUEVA VARIANTE!") or string.upper(capsuleDef.Name)
	title.TextColor3 = (best.New or best.NewVariant) and C.Gold or capsuleDef.Color
	local halo = Kit.box(stage, rarity.Color, 0.78, { Size = UDim2.fromOffset(330, 330), Position = UDim2.new(0.5, 0, 0, 205),
		AnchorPoint = Vector2.new(0.5, 0.5) }, 165)
	Kit.stroke(halo, rarity.Color, 3, 0.1)
	local view = Kit.viewport(stage, best.Id, best.V, false, { Size = UDim2.fromOffset(300, 300), Position = UDim2.new(0.5, 0, 0, 205),
		AnchorPoint = Vector2.new(0.5, 0.5) })
	local viewScale = Instance.new("UIScale")
	viewScale.Scale = 0.2
	viewScale.Parent = view
	Kit.tween(viewScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local model = view:FindFirstChildOfClass("Model")
	local spin = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		spin = spin + dt * 0.9
		if model and model.Parent then
			model:PivotTo(CFrame.Angles(math.rad(18), spin, math.rad(-14)))
		end
	end)

	local info = Kit.frame(stage, { Name = "Info", Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 372) })
	Kit.label(info, def.Name, { Size = UDim2.new(1, 0, 0, 40), TextSize = 34, Font = F.Black, AlignX = Enum.TextXAlignment.Center,
		Color = rarity.Color, Stroke = true })
	local sub = Kit.rarityText(def.Rarity) .. "   ·   " .. def.TypeLabel
	if variant.Id ~= "none" then sub = sub .. "   ·   " .. variant.Icon .. " " .. variant.Name end
	Kit.label(info, sub, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 42), TextSize = 16, AlignX = Enum.TextXAlignment.Center })
	Kit.label(info, "⚡ " .. Format.rate(Progression.planetRate({ Id = best.Id, V = best.V, E = false })) .. " base",
		{ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 68), TextSize = 17, AlignX = Enum.TextXAlignment.Center, Color = C.Energy })
	if #results > 1 then
		local names = {}
		for _, r in ipairs(results) do
			local d = Defs.Planets.ById[r.Id]
			local v = Defs.Variants.get(r.V)
			table.insert(names, Defs.Rarities.ById[d.Rarity].Icon .. " " .. d.Name .. (v.Id ~= "none" and (" " .. v.Icon) or ""))
		end
		Kit.label(info, "x" .. #results .. ":  " .. table.concat(names, "  ·  "), { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 94),
			TextSize = 12, AlignX = Enum.TextXAlignment.Center, Color = C.TextDim, Font = F.Body })
	end

	local buttons = Kit.frame(stage, { Name = "Buttons", Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -52) })
	local layout = Kit.listLayout(buttons, 12, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function finish()
		if finished then return end
		finished = true
		conn:Disconnect()
	end
	Kit.button(buttons, "Guardar", "ghost", { Size = UDim2.fromOffset(170, 46), Props = { LayoutOrder = 1, Name = "Keep" } }, finish)
	Kit.button(buttons, "Colocar en órbita", "primary", { Size = UDim2.fromOffset(200, 46), Props = { LayoutOrder = 2, Name = "Place" } }, function()
		finish()
		ctx.UI.open("Inventory", { Select = best.Uid, Place = true })
	end)
	Kit.button(buttons, "Inspeccionar", "cyan", { Size = UDim2.fromOffset(170, 46), Props = { LayoutOrder = 3, Name = "Inspect" } }, function()
		finish()
		ctx.UI.open("Inventory", { Select = best.Uid })
	end)
	while not finished do
		task.wait(0.05)
	end
end

local function run(data)
	local Kit, Theme = ctx.Kit, ctx.Theme
	local settings = ctx.State.Data.Settings or {}
	local root = Kit.frame(ctx.UI.overlay(), { Name = "CapsuleOpening", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Colors.Dark,
		BackgroundTransparency = 0.25, Active = true, ZIndex = 30 })
	local ok, err = pcall(reveal, root, data, settings.SkipCapsuleAnimation == true)
	if not ok then warn("[Capsule] " .. tostring(err)) end
	root:Destroy()
end

-- Reproduce la apertura del resultado recibido del servidor (en cola si ya hay una en curso)
function Capsule.play(data)
	table.insert(queue, data)
	if playing then return end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			run(table.remove(queue, 1))
		end
		playing = false
	end)
end

function Capsule.isPlaying()
	return playing
end

function Capsule.init(context)
	ctx = context
	ctx.Capsule = Capsule
end

return Capsule
