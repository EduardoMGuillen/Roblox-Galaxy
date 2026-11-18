-- Estadisticas: desglose de produccion (de donde viene tu Energy) y estadisticas del jugador.
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "StatsUI", Size = UDim2.fromOffset(860, 560), Title = "Producción y estadísticas", Icon = "📊",
		OnClose = function() ctx.UI.close() end })
	local left = Kit.scroll(body, { Size = UDim2.new(0.58, -6, 1, 0), Padding = 5 })
	local right = Kit.scroll(body, { Size = UDim2.new(0.42, -6, 1, 0), Position = UDim2.new(0.58, 6, 0, 0), Padding = 5 })

	local function header(holder, text, order, color)
		Kit.label(holder, text, { Size = UDim2.new(1, -6, 0, 24), TextSize = 12, Font = F.Title, Color = color or C.Cyan,
			Props = { LayoutOrder = order } })
	end

	local function refresh()
		Kit.clear(left)
		Kit.clear(right)
		local data = State.Data
		local production = data._Production or Progression.production(data, 1)
		local order = 0
		local function nextOrder()
			order = order + 1
			return order
		end
		header(left, "PRODUCCIÓN POR SISTEMA", nextOrder())
		for _, sysId in ipairs(Defs.Galaxy.Order) do
			local sys = production.Systems[sysId]
			if sys then
				local def = Defs.Galaxy.ById[sysId]
				local box = Kit.box(left, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 62), LayoutOrder = nextOrder() }, 8)
				Kit.label(box, def.Name, { Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(10, 4), TextSize = 14, Color = def.Theme.Accent })
				Kit.label(box, "⚡ " .. Format.rate(sys.Total), { Size = UDim2.new(0.4, -20, 0, 22), Position = UDim2.new(0.6, 0, 0, 4), TextSize = 14,
					AlignX = Enum.TextXAlignment.Right, Color = C.Energy })
				local names = {}
				for _, id in ipairs(sys.Synergies) do
					table.insert(names, Defs.Synergies.ById[id].Name)
				end
				Kit.label(box, sys.Count .. " planetas · base " .. Format.number(sys.Base) .. " · sistema " .. Format.mult(def.Multiplier)
					.. " · sinergias " .. Format.mult(math.floor(sys.SynergyMult * 100 + 0.5) / 100), { Size = UDim2.new(1, -20, 0, 16),
					Position = UDim2.fromOffset(10, 26), TextSize = 11, Color = C.TextDim, Font = F.Body })
				Kit.label(box, #names > 0 and ("🔗 " .. table.concat(names, ", ")) or "Sin sinergias activas", { Size = UDim2.new(1, -20, 0, 16),
					Position = UDim2.fromOffset(10, 42), TextSize = 11, Color = #names > 0 and C.Green or C.TextDim, Font = F.Body })
			end
		end
		header(left, "MULTIPLICADORES GLOBALES", nextOrder())
		local mults = production.Mults
		Kit.stat(left, "Reactor Estelar", Format.mult(mults.Reactor), C.Cyan, nextOrder())
		Kit.stat(left, "Núcleo de Poder", Format.mult(mults.Cores), C.Cores, nextOrder())
		Kit.stat(left, "Galactic Ascension", Format.mult(mults.Ascension), C.Gold, nextOrder())
		Kit.stat(left, "Colecciones completas", Format.mult(mults.Collections), C.Violet, nextOrder())
		Kit.stat(left, "Evento activo", Format.mult(mults.Event), C.Gold, nextOrder())
		Kit.stat(left, "PRODUCCIÓN TOTAL", "⚡ " .. Format.rate(production.Total), C.Energy, nextOrder())
		header(left, "SINERGIAS DISPONIBLES (por sistema)", nextOrder())
		for _, synergy in ipairs(Defs.Synergies.List) do
			Kit.label(left, "• " .. synergy.Name .. " +" .. math.floor(synergy.Bonus * 100) .. "%: " .. synergy.Description,
				{ Size = UDim2.new(1, -6, 0, 18), TextSize = 11, Color = C.TextDim, Font = F.Body, Props = { LayoutOrder = nextOrder() } })
		end

		local stats = data.Stats
		local found, total = Progression.discoveryTotals(data)
		order = 0
		header(right, "TU PROGRESO", nextOrder())
		Kit.stat(right, "Energy total generada", Format.number(data.TotalEnergy), C.Energy, nextOrder())
		Kit.stat(right, "Mejor producción", Format.rate(stats.BestRate), C.Energy, nextOrder())
		Kit.stat(right, "Ascensiones", tostring(data.Ascensions), C.Gold, nextOrder())
		Kit.stat(right, "Planetas descubiertos", found .. " / " .. total, C.Violet, nextOrder())
		Kit.stat(right, "Planetas en inventario", Progression.inventoryCount(data) .. " / " .. Progression.inventoryCapacity(data), C.Text, nextOrder())
		Kit.stat(right, "Cápsulas abiertas", Format.commas(stats.CapsulesOpened), C.Text, nextOrder())
		Kit.stat(right, "Planetas obtenidos", Format.commas(stats.PlanetsObtained), C.Text, nextOrder())
		Kit.stat(right, "Raros o superiores", Format.commas(stats.RaresObtained), C.Text, nextOrder())
		Kit.stat(right, "Evoluciones", tostring(stats.Evolutions), C.Text, nextOrder())
		Kit.stat(right, "Intercambios", tostring(stats.Trades), C.Text, nextOrder())
		Kit.stat(right, "Universos visitados", tostring(stats.Visits), C.Text, nextOrder())
		Kit.stat(right, "Meteoritos recogidos", tostring(stats.MeteorsCollected), C.Text, nextOrder())
		header(right, "CÓMO PRODUCIR MÁS", nextOrder(), C.Gold)
		local tips = {
			"Llena los 8 slots de cada sistema.", "Combina elementos para activar sinergias.",
			"Desbloquea sistemas: multiplican la producción.", "Evoluciona duplicados a su forma Prime.",
			"Las variantes producen más (hasta x6).", "Asciende para multiplicar todo.",
		}
		for _, tip in ipairs(tips) do
			Kit.label(right, "• " .. tip, { Size = UDim2.new(1, -6, 0, 18), TextSize = 11, Color = C.TextDim, Font = F.Body,
				Props = { LayoutOrder = nextOrder() } })
		end
	end

	State.onAny(function(changed)
		if frame.Visible and (changed._Production or changed.Stats or changed.Discovered) then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
