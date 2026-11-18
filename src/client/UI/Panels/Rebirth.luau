-- RebirthUI: Galactic Ascension. Muestra requisitos, que se reinicia y que se conserva (con cantidades
-- actuales), recompensas exactas y pide doble confirmacion. La ascension solo ocurre si el servidor la valida.
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "RebirthUI", Size = UDim2.fromOffset(820, 570), Title = "Galactic Ascension", Icon = "♻",
		OnClose = function() ctx.UI.close() end })

	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end

	local function refresh()
		Kit.clear(body)
		local data = State.Data
		local milestone = Defs.Ascension.next(data.Ascensions)
		local currentMult = Defs.Ascension.multiplier(data.Ascensions)
		Kit.label(body, "Ascensión " .. data.Ascensions .. "  →  " .. milestone.Index, { Size = UDim2.new(0.5, 0, 0, 30), TextSize = 22,
			Font = F.Black, Color = C.Gold })
		Kit.label(body, "Reinicia parte de tu progreso a cambio de un multiplicador permanente y Cosmic Cores.", { Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 30), TextSize = 12, Color = C.TextDim, Font = F.Body })

		-- recompensas
		local rewards = Kit.box(body, C.Row, 0.1, { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, 56) }, 10)
		Kit.stroke(rewards, C.Gold, 1.5, 0.2)
		Kit.label(rewards, "RECOMPENSAS", { Size = UDim2.fromOffset(150, 58), Position = UDim2.fromOffset(12, 0), TextSize = 12, Font = F.Title,
			Color = C.Gold })
		Kit.label(rewards, "Producción permanente  " .. Format.mult(currentMult) .. "  →  " .. Format.mult(milestone.Multiplier),
			{ Size = UDim2.new(0.5, -90, 1, 0), Position = UDim2.fromOffset(160, 0), TextSize = 15, Color = C.Energy })
		Kit.label(rewards, "+" .. milestone.Cores .. " 💠 Cosmic Cores", { Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.7, -10, 0, 0),
			TextSize = 15, AlignX = Enum.TextXAlignment.Right, Color = C.Cores })

		-- requisitos
		Kit.label(body, "REQUISITOS", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 122), TextSize = 12, Font = F.Title, Color = C.Cyan })
		local allOk = true
		for i, req in ipairs(milestone.Requirements) do
			local check = Progression.checkRequirement(data, req, State.rate())
			if not check.Ok then allOk = false end
			local y = 144 + (i - 1) * 30
			Kit.label(body, (check.Ok and "✔ " or "✖ ") .. check.Text, { Size = UDim2.new(0.56, 0, 0, 24), Position = UDim2.fromOffset(0, y),
				TextSize = 13, Color = check.Ok and C.Green or C.Text })
			local _, set = Kit.progress(body, { Size = UDim2.new(0.42, 0, 0, 20), Position = UDim2.new(0.58, 0, 0, y + 2),
				Color = check.Ok and C.Green or C.Gold })
			set(check.Current / check.Goal, Format.number(check.Current) .. " / " .. Format.number(check.Goal))
		end

		-- columnas: se reinicia / se conserva
		local energyLevels = 0
		for id, level in pairs(data.Upgrades) do
			if Defs.Upgrades.ById[id] and Defs.Upgrades.ById[id].Currency == "Energy" then energyLevels = energyLevels + level end
		end
		local placed = 0
		for sysId in pairs(data.Placed) do
			placed = placed + Progression.placedCount(data, sysId)
		end
		local found, total = Progression.discoveryTotals(data)
		local resets = {
			"Energy actual: " .. Format.number(data.Energy) .. " → " .. Format.number(Progression.startingEnergy(data)),
			"Mejoras con Energy: " .. energyLevels .. " niveles → 0",
			"Sistemas: " .. count(data.Systems) .. " → 1 (Solar)",
			"Slots orbitales comprados → 3 por sistema",
			"Planetas en órbita: " .. placed .. " vuelven al inventario",
		}
		local keeps = {
			"Tus " .. Progression.inventoryCount(data) .. " planetas",
			"Collection Index: " .. found .. "/" .. total .. " descubiertos",
			"✨ " .. Format.number(data.Stardust) .. " Stardust y 💠 " .. Format.number(data.Cores) .. " Cores",
			"Mejoras de núcleo y bonos de colección",
			"Cosméticos, misiones y estadísticas",
		}
		local columns = { { "SE REINICIA", C.Red, resets, 0 }, { "SE CONSERVA", C.Green, keeps, 0.5 } }
		for _, col in ipairs(columns) do
			local box = Kit.box(body, C.Row, 0.15, { Size = UDim2.new(0.5, -6, 0, 178), Position = UDim2.new(col[4], col[4] > 0 and 6 or 0, 0, 214) }, 10)
			Kit.stroke(box, col[2], 1.5, 0.3)
			Kit.label(box, col[1], { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(12, 6), TextSize = 13, Font = F.Title, Color = col[2] })
			for i, text in ipairs(col[3]) do
				Kit.label(box, "•  " .. text, { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 30 + (i - 1) * 27), TextSize = 12,
					Font = F.Body, Color = C.Text })
			end
		end

		Kit.label(body, "⚠ La ascensión no se puede deshacer.", { Size = UDim2.new(0.5, 0, 0, 44), Position = UDim2.new(0, 0, 1, -46), TextSize = 13,
			Color = C.Gold })
		local button = Kit.button(body, "ASCENDER", "gold", { Size = UDim2.fromOffset(280, 46), Position = UDim2.new(1, -280, 1, -48), TextSize = 19,
			Font = F.Black, Props = { Name = "Ascend" } }, function()
			ctx.UI.confirm({ Title = "Confirmar ascensión", Icon = "♻", Confirm = "Sí, ascender", Style = "gold",
				Text = "Vas a reiniciar tu Energy, tus mejoras con Energy, tus sistemas y tus slots. Conservas todos tus planetas, tu colección, "
					.. "Stardust y Cosmic Cores. Recibirás producción permanente " .. Format.mult(milestone.Multiplier) .. " y +" .. milestone.Cores
					.. " Cosmic Cores.",
				OnConfirm = function()
					local result = ctx.UI.request("Rebirth", true)
					if result.Ok then
						ctx.UI.close()
						if ctx.Effects then ctx.Effects.ascension(result.Data) end
					end
				end })
		end)
		Kit.setEnabled(button, allOk)
	end

	local last = 0
	State.onAny(function(changed)
		if not frame.Visible then return end
		if changed.Ascensions or changed.Planets or changed.Discovered or changed.RunEnergy or (changed.Energy and os.clock() - last > 2) then
			last = os.clock()
			refresh()
		end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
