-- TutorialController: guia inicial (abrir, colocar, producir y mejorar). El avance lo decide el servidor
-- segun las acciones reales del jugador; aqui solo se muestra el paso actual y se resalta el boton.
local RunService = game:GetService("RunService")

local Tutorial = {}
local ctx = nil
local banner, textLabel, actionButton, highlight = nil, nil, nil, nil
local highlighted = nil

local STEPS = {
	welcome = { Text = "¡Bienvenido a PLANET COLLECTOR! Colecciona planetas, colócalos en órbita alrededor de tu estrella y genera Energy.",
		Button = "Empezar", Ack = "welcome" },
	open_capsule = { Text = "Paso 1 · Abre tu primera cápsula: pulsa OPEN CAPSULE (o acércate a la Capsule Station) y abre una Starter Capsule.",
		Target = "Capsule" },
	go_universe = { Text = "Paso 2 · ¡Ya tienes planetas! Viaja a tu universo personal con la tarjeta «Tu Universo» o por el Portal Room.",
		Target = "UniverseCard" },
	place_planet = { Text = "Paso 3 · Coloca un planeta: usa el panel ÓRBITAS de la derecha (+ Colocar planeta) o toca un marcador verde.",
		Target = nil },
	watch_production = { Text = "Paso 4 · Tu planeta ya produce Energy cada segundo. Mira el contador ⚡ arriba a la izquierda.",
		Button = "Entendido", Ack = "watch_production" },
	buy_upgrade = { Text = "Paso 5 · Invierte tu Energy: abre Mejoras y compra «Reactor Estelar» para producir más.", Target = "Upgrades" },
}

local function clearHighlight()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	highlighted = nil
end

local function setHighlight(target)
	if highlighted == target then return end
	clearHighlight()
	if not target then return end
	highlighted = target
	highlight = Instance.new("UIStroke")
	highlight.Name = "TutorialGlow"
	highlight.Color = ctx.Theme.Colors.Gold
	highlight.Thickness = 4
	highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	highlight.Parent = target
end

local function refresh()
	local steps = ctx.Defs.Config.TutorialSteps
	local name = steps[ctx.State.Data.Tutorial or #steps]
	local step = name and STEPS[name]
	if not step then
		banner.Visible = false
		clearHighlight()
		return
	end
	banner.Visible = true
	textLabel.Text = step.Text
	actionButton.Visible = step.Button ~= nil
	actionButton.Text = step.Button or ""
	actionButton:SetAttribute("Ack", step.Ack)
	local hud = ctx.UI.Hud
	local target = nil
	if step.Target == "Upgrades" then
		target = hud.Root:FindFirstChild("Right") and hud.Root.Right:FindFirstChild("Upgrades")
	elseif step.Target then
		target = hud[step.Target]
	end
	setHighlight(target)
end

function Tutorial.init(context)
	ctx = context
	local Kit, Theme = ctx.Kit, ctx.Theme
	local C = Theme.Colors
	banner = Kit.box(ctx.UI.Hud.Root, C.Panel, 0.08, { Name = "Tutorial", Size = UDim2.fromOffset(640, 84), Position = UDim2.new(0.5, 0, 1, -130),
		AnchorPoint = Vector2.new(0.5, 1), Visible = false }, 12)
	Kit.stroke(banner, C.Gold, 2, 0)
	textLabel = Kit.label(banner, "", { Size = UDim2.new(1, -190, 1, -12), Position = UDim2.fromOffset(14, 6), TextSize = 14, Wrap = true,
		Font = Theme.Fonts.Body })
	actionButton = Kit.button(banner, "", "gold", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -164, 0.5, -20), TextSize = 14,
		Props = { Name = "Continue" } }, function(button)
		local ack = button:GetAttribute("Ack")
		if ack then ctx.UI.request("TutorialAck", ack) end
	end)
	Kit.button(banner, "Saltar", "ghost", { Size = UDim2.fromOffset(64, 22), Position = UDim2.new(1, -70, 0, -26), TextSize = 11,
		Props = { Name = "Skip" } }, function()
		ctx.UI.request("SkipTutorial")
	end)
	ctx.State.on("Tutorial", refresh)
	ctx.UI.onLayout(function(compact)
		banner.Position = compact and UDim2.new(0.5, 0, 1, -96) or UDim2.new(0.5, 0, 1, -130)
	end)
	refresh()
	-- latido del resaltado
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		if highlight then
			t = t + dt
			highlight.Transparency = 0.25 + 0.25 * math.sin(t * 5)
		end
	end)
end

return Tutorial
