-- Collection Index: descubiertos y no descubiertos, rareza, sistema, variantes, produccion de
-- referencia y porcentaje de coleccion. Filtros por sistema, rareza y estado. Las pistas de secretos
-- solo aparecen cuando corresponde.
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "CollectionUI", Size = UDim2.fromOffset(980, 580), Title = "Collection Index", Icon = "📖",
		OnClose = function() ctx.UI.close() end })

	local systemFilter = 0 -- 0 = todos
	local stateFilter = 1 -- 1 todos, 2 descubiertos, 3 por descubrir
	local rarityFilter = 0
	local selected = nil
	local STATE_NAMES = { "Estado: todos", "Solo descubiertos", "Por descubrir" }

	local summary = Kit.label(body, "", { Size = UDim2.new(1, -300, 0, 26), TextSize = 15, Color = C.Gold })
	local _, setTotal = Kit.progress(body, { Size = UDim2.new(1, -300, 0, 14), Position = UDim2.fromOffset(0, 28), Color = C.Gold })
	local grid = Kit.scroll(body, { Size = UDim2.new(1, -300, 1, -96), Position = UDim2.fromOffset(0, 94), Grid = UDim2.fromOffset(112, 138), Padding = 8 })
	local side = Kit.box(body, C.PanelLight, 0.2, { Name = "Detail", Size = UDim2.new(0, 288, 1, 0), Position = UDim2.new(1, -288, 0, 0) }, 12)
	Kit.stroke(side, C.Violet, 1, 0.5)
	local sideBody = Kit.frame(side, { Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10) })
	local refresh

	local function hintsUnlocked()
		local found = Progression.discoveryTotals(State.Data)
		return State.Data.Ascensions >= 1 or found >= 12
	end

	local function showDetail()
		Kit.clear(sideBody)
		local def = selected and Defs.Planets.ById[selected]
		if not def then
			Kit.label(sideBody, "Selecciona una entrada del índice.", { Size = UDim2.new(1, 0, 0, 60), TextSize = 14, Wrap = true, Color = C.TextDim,
				Font = F.Body, AlignX = Enum.TextXAlignment.Center })
			return
		end
		local data = State.Data
		local discovered = data.Discovered[def.Id] == true
		local rarity = Defs.Rarities.ById[def.Rarity]
		local view = Kit.viewport(sideBody, def.Id, "none", false, { Size = UDim2.new(1, 0, 0, 150) })
		if not discovered then
			view.ImageColor3 = Color3.new(0, 0, 0)
			view.ImageTransparency = 0.2
		end
		Kit.label(sideBody, discovered and def.Name or "???", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 152), TextSize = 21,
			Font = F.Black, AlignX = Enum.TextXAlignment.Center, Color = rarity.Color })
		Kit.label(sideBody, Kit.rarityText(def.Rarity) .. " · " .. Defs.Galaxy.ById[def.System].Name, { Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 180), TextSize = 12, AlignX = Enum.TextXAlignment.Center })
		local text
		if discovered then
			text = def.TypeLabel .. "  ·  ⚡ " .. Format.rate(def.Base) .. " base\n\n" .. def.Description
		elseif def.Secret then
			text = hintsUnlocked() and ("Pista: " .. def.Secret.Hint) or "Descubrimiento secreto. Sigue ampliando tu colección para recibir una pista."
		else
			local sources = {}
			for _, cap in ipairs(Defs.Capsules.List) do
				local pool = cap.Pools[def.Rarity]
				if pool and table.find(pool, def.Id) then table.insert(sources, cap.Name) end
			end
			text = "Aún no descubierto.\nSe obtiene en: " .. table.concat(sources, ", ") .. "."
		end
		Kit.label(sideBody, text, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 204), TextSize = 12, Wrap = true, Color = C.TextDim,
			Font = F.Body, AlignY = Enum.TextYAlignment.Top, AlignX = Enum.TextXAlignment.Center })
		-- variantes y forma Prime descubiertas
		Kit.label(sideBody, "VARIANTES DESCUBIERTAS", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -118), TextSize = 11,
			Font = F.Title, Color = C.Cyan, AlignX = Enum.TextXAlignment.Center })
		local variants = Kit.frame(sideBody, { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 1, -96) })
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -4, 0, 26)
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = variants
		local order = 0
		for _, id in ipairs(Defs.Variants.Order) do
			if id ~= "none" then
				order = order + 1
				local v = Defs.Variants.ById[id]
				local has = data.Discovered[def.Id .. "#" .. id] == true
				local chip = Kit.box(variants, C.Row, has and 0 or 0.5, { LayoutOrder = order }, 6)
				Kit.label(chip, (has and "✔ " or "· ") .. v.Icon .. " " .. v.Name, { Size = UDim2.fromScale(1, 1), TextSize = 12,
					AlignX = Enum.TextXAlignment.Center, Color = has and v.Color or C.TextDim })
			end
		end
		local hasPrime = data.Discovered[def.Id .. "#evo"] == true
		local prime = Kit.box(variants, C.Row, hasPrime and 0 or 0.5, { LayoutOrder = 10 }, 6)
		Kit.label(prime, (hasPrime and "✔ " or "· ") .. "🌟 Prime", { Size = UDim2.fromScale(1, 1), TextSize = 12, AlignX = Enum.TextXAlignment.Center,
			Color = hasPrime and C.Gold or C.TextDim })
	end

	refresh = function()
		local data = State.Data
		local found, total = Progression.discoveryTotals(data)
		summary.Text = "Colección: " .. found .. " / " .. total .. " planetas  (" .. Format.percent(found / total, 0) .. ")"
		setTotal(found / total, "")
		Kit.clear(grid)
		local order = 0
		for _, def in ipairs(Defs.Planets.List) do
			local discovered = data.Discovered[def.Id] == true
			local sysOk = systemFilter == 0 or Defs.Galaxy.Order[systemFilter] == def.System
			local stateOk = stateFilter == 1 or (stateFilter == 2 and discovered) or (stateFilter == 3 and not discovered)
			local rarityOk = rarityFilter == 0 or Defs.Rarities.Order[rarityFilter] == def.Rarity
			if sysOk and stateOk and rarityOk then
				order = order + 1
				local card = Kit.planetCard(grid, { Id = def.Id, V = "none", E = false, Silhouette = not discovered }, {
					Size = UDim2.fromOffset(112, 138), ShowRate = discovered,
					OnClick = function()
						selected = def.Id
						showDetail()
					end,
				})
				card.Name = "Entry_" .. def.Id
				card.LayoutOrder = order
			end
		end
		showDetail()
	end

	local systemNames = { "Todos" }
	for _, sysId in ipairs(Defs.Galaxy.Order) do
		table.insert(systemNames, (string.gsub(Defs.Galaxy.ById[sysId].Name, " System", "")))
	end
	Kit.tabs(body, systemNames, function(index)
		systemFilter = index - 1
		refresh()
	end, { Size = UDim2.new(1, -300, 0, 34), Position = UDim2.fromOffset(0, 50), Width = 82 })
	local stateButton, rarityButton
	stateButton = Kit.button(body, STATE_NAMES[1], "ghost", { Size = UDim2.fromOffset(150, 28), Position = UDim2.new(1, -620, 0, 0), TextSize = 12 }, function()
		stateFilter = stateFilter % 3 + 1
		stateButton.Text = STATE_NAMES[stateFilter]
		refresh()
	end)
	stateButton.Name = "StateFilter"
	rarityButton = Kit.button(body, "Rareza: todas", "ghost", { Size = UDim2.fromOffset(160, 28), Position = UDim2.new(1, -464, 0, 0), TextSize = 12 }, function()
		rarityFilter = (rarityFilter + 1) % (#Defs.Rarities.Order + 1)
		rarityButton.Text = rarityFilter == 0 and "Rareza: todas" or ("Rareza: " .. Defs.Rarities.ById[Defs.Rarities.Order[rarityFilter]].Name)
		refresh()
	end)
	rarityButton.Name = "RarityFilter"

	State.onAny(function(changed)
		if frame.Visible and (changed.Discovered or changed.SecretsFound) then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
