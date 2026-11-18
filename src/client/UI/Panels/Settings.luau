-- SettingsUI: audio, efectos, calidad visual, accesibilidad y tutorial.
return function(ctx, parent)
	local Kit, State, Defs, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "SettingsUI", Size = UDim2.fromOffset(600, 540), Title = "Ajustes", Icon = "⚙️",
		OnClose = function() ctx.UI.close() end })
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -34), Padding = 6 })
	local setters = {}

	local ITEMS = {
		{ "Music", "Música", "Música ambiental del espacio." },
		{ "Sfx", "Efectos de sonido", "Clics, recompensas y portales." },
		{ "ReducedEffects", "Efectos reducidos", "Menos partículas y destellos (accesibilidad)." },
		{ "SkipCapsuleAnimation", "Saltar animación de cápsulas", "Muestra el resultado al instante." },
		{ "LowQuality", "Calidad visual baja", "Mejora el rendimiento en móviles." },
		{ "LargeText", "Interfaz grande", "Aumenta el tamaño de la interfaz." },
		{ "ShowOtherNames", "Mostrar nombres en universos", "Carteles con el nombre del propietario." },
	}
	for index, item in ipairs(ITEMS) do
		local key = item[1]
		local row = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 54), LayoutOrder = index, Name = "Setting_" .. key }, 10)
		Kit.label(row, item[2], { Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(12, 6), TextSize = 15 })
		Kit.label(row, item[3], { Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(12, 30), TextSize = 12, Color = C.TextDim,
			Font = F.Body })
		local _, set = Kit.toggle(row, State.Data.Settings[key], function(value)
			State.Data.Settings[key] = value
			ctx.UI.request("UpdateSetting", key, value)
			if ctx.onSettingChanged then ctx.onSettingChanged(key, value) end
		end, { Position = UDim2.new(1, -142, 0, 10) })
		setters[key] = set
	end
	local tutorialRow = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 54), LayoutOrder = 50, Name = "Tutorial" }, 10)
	Kit.label(tutorialRow, "Tutorial", { Size = UDim2.new(1, -170, 0, 24), Position = UDim2.fromOffset(12, 6), TextSize = 15 })
	Kit.label(tutorialRow, "Oculta la guía inicial si ya sabes jugar.", { Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(12, 30),
		TextSize = 12, Color = C.TextDim, Font = F.Body })
	Kit.button(tutorialRow, "Saltar tutorial", "ghost", { Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -142, 0, 10), TextSize = 13 }, function()
		ctx.UI.request("SkipTutorial")
	end)

	local footer = Kit.label(body, "", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), TextSize = 12, Color = C.TextDim,
		Font = F.Body })

	local function refresh()
		for key, set in pairs(setters) do
			set(State.Data.Settings[key])
		end
		local session = State.Data._Session
		if session and session.SessionOnly then
			footer.Text = "⚠ Modo de prueba: el progreso NO se guardará (activa el acceso a API en Studio)."
			footer.TextColor3 = C.Gold
		else
			footer.Text = "PLANET COLLECTOR v" .. Defs.Config.Version .. " · tu progreso se guarda automáticamente."
			footer.TextColor3 = C.TextDim
		end
	end

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
