-- EffectsController: presentaciones breves y saltables (ascension, resumen de ganancias sin conexion).
-- Siempre se muestran DESPUES de que el servidor confirme el resultado.
local Effects = {}
local ctx = nil

-- Animacion de ascension: la pantalla pasa a blanco/azul, onda de energia y renacer con nuevo halo.
function Effects.ascension(data)
	local Kit, Theme, Format = ctx.Kit, ctx.Theme, ctx.Format
	local C, F = Theme.Colors, Theme.Fonts
	if ctx.Audio then ctx.Audio.play("fanfare") end
	local root = Kit.frame(ctx.UI.overlay(), { Name = "Ascension", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(215, 235, 255),
		BackgroundTransparency = 1, Active = true, ZIndex = 40 })
	local closed = false
	local function close()
		if closed then return end
		closed = true
		root:Destroy()
	end
	local skip = Instance.new("TextButton")
	skip.Text = ""
	skip.BackgroundTransparency = 1
	skip.Size = UDim2.fromScale(1, 1)
	skip.ZIndex = 45
	skip.Activated:Connect(close)
	skip.Parent = root
	if not (ctx.State.Data.Settings or {}).ReducedEffects then
		Kit.tween(root, 0.35, { BackgroundTransparency = 0.05 })
		task.wait(0.4)
		if closed then return end
		Kit.tween(root, 0.8, { BackgroundTransparency = 0.55, BackgroundColor3 = Color3.fromRGB(20, 30, 80) })
	else
		root.BackgroundColor3 = Color3.fromRGB(20, 30, 80)
		root.BackgroundTransparency = 0.4
	end
	local wave = Kit.box(root, C.Cyan, 1, { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 41 }, 400)
	local waveStroke = Kit.stroke(wave, C.Gold, 6, 0)
	Kit.tween(wave, 1.1, { Size = UDim2.fromOffset(900, 900) })
	Kit.tween(waveStroke, 1.1, { Transparency = 1 })
	local title = Kit.label(root, "ASCENSIÓN " .. tostring(data.Ascensions), { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.5, -70),
		TextSize = 56, Font = F.Title, AlignX = Enum.TextXAlignment.Center, Color = C.Gold, Stroke = true, Props = { ZIndex = 42 } })
	local sub = Kit.label(root, "Producción permanente " .. Format.mult(data.Multiplier) .. "   ·   +" .. data.Cores .. " 💠 Cosmic Cores",
		{ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0.5, 10), TextSize = 22, AlignX = Enum.TextXAlignment.Center, Stroke = true,
			Props = { ZIndex = 42 } })
	Kit.label(root, "Toca para continuar", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.5, 60), TextSize = 14,
		AlignX = Enum.TextXAlignment.Center, Color = C.TextDim, Props = { ZIndex = 42 } })
	title.TextTransparency = 1
	sub.TextTransparency = 1
	Kit.tween(title, 0.4, { TextTransparency = 0 })
	Kit.tween(sub, 0.6, { TextTransparency = 0 })
	task.delay(4.5, close)
end

-- Resumen de ganancias sin conexion al volver
function Effects.offline(summary)
	local Format = ctx.Format
	ctx.UI.confirm({ Title = "¡Bienvenido de nuevo!", Icon = "🌙", Confirm = "¡Genial!", Cancel = "Cerrar", Style = "gold",
		Text = "Mientras no estabas (" .. Format.duration(summary.Away) .. "), tus planetas siguieron trabajando durante "
			.. Format.duration(summary.Seconds) .. " y generaron " .. Format.number(summary.Energy) .. " de Energy.\n\n"
			.. "Mejora Baterías Offline y Colector Nocturno para ganar más." })
end

function Effects.init(context)
	ctx = context
	ctx.Effects = Effects
end

return Effects
