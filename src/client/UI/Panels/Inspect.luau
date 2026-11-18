-- PlanetInspectUI (solo lectura): ficha de un planeta de otro universo o del indice.
return function(ctx, parent)
	local Kit, Defs, Format, Progression, Theme = ctx.Kit, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "PlanetInspectUI", Size = UDim2.fromOffset(420, 500), Title = "Planeta", Icon = "🪐",
		OnClose = function() ctx.UI.close() end })

	local function show(args)
		Kit.clear(body)
		local planet = args.Planet
		if not planet then return end
		local def = Defs.Planets.ById[planet.Id]
		local rarity = Defs.Rarities.ById[def.Rarity]
		local variant = Defs.Variants.get(planet.V)
		Kit.viewport(body, planet.Id, planet.V, planet.E, { Size = UDim2.new(1, 0, 0, 200) })
		Kit.label(body, Defs.Planets.displayName(def, planet.E), { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 204), TextSize = 24,
			Font = F.Black, AlignX = Enum.TextXAlignment.Center, Color = rarity.Color })
		Kit.label(body, Kit.rarityText(def.Rarity) .. "  ·  " .. def.TypeLabel, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 238),
			TextSize = 13, AlignX = Enum.TextXAlignment.Center })
		local line = "⚡ " .. Format.rate(Progression.planetRate({ Id = planet.Id, V = planet.V or "none", E = planet.E == true }))
		if variant.Id ~= "none" then line = line .. "  ·  " .. variant.Icon .. " " .. variant.Name end
		Kit.label(body, line, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 260), TextSize = 14, AlignX = Enum.TextXAlignment.Center,
			Color = C.Energy })
		Kit.label(body, def.Description, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 288), TextSize = 13, Wrap = true,
			Color = C.TextDim, Font = F.Body, AlignY = Enum.TextYAlignment.Top, AlignX = Enum.TextXAlignment.Center })
		if args.Owner then
			Kit.label(body, "Pertenece al universo de " .. args.Owner .. " (solo lectura)", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -22),
				TextSize = 12, AlignX = Enum.TextXAlignment.Center, Color = C.Stardust })
		end
	end

	return { Frame = frame, OnOpen = show }
end
