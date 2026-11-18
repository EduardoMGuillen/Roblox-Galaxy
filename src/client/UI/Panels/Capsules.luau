-- CapsuleUI: tipo de capsula, precio, requisitos, PROBABILIDADES REALES y botones de apertura.
-- El resultado lo genera el servidor; aqui solo se muestra la informacion y se lanza la animacion.
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C = Theme.Colors
	local frame, body = Kit.panel(parent, { Name = "CapsuleUI", Size = UDim2.fromOffset(900, 560), Title = "Capsule Station", Icon = "💊",
		OnClose = function() ctx.UI.close() end })

	local list = Kit.scroll(body, { Size = UDim2.new(0, 250, 1, 0), Padding = 6 })
	local detail = Kit.frame(body, { Name = "Detail", Size = UDim2.new(1, -262, 1, 0), Position = UDim2.fromOffset(262, 0) })

	local selected = "starter"
	local rows = {}
	local busy = false
	local openButtons = {}
	local priceLabel, reqLabel, titleLabel, descLabel, oddsHolder, variantLabel, previewHolder

	titleLabel = Kit.label(detail, "", { Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = Theme.Fonts.Black })
	descLabel = Kit.label(detail, "", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 30), TextSize = 13, Color = C.TextDim,
		Font = Theme.Fonts.Body })
	priceLabel = Kit.label(detail, "", { Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.fromOffset(0, 54), TextSize = 19, Color = C.Energy })
	reqLabel = Kit.label(detail, "", { Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.new(0.5, 0, 0, 54), TextSize = 13,
		AlignX = Enum.TextXAlignment.Right, Color = C.TextDim })
	Kit.label(detail, "PROBABILIDADES REALES", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 86), TextSize = 12,
		Color = C.Cyan, Font = Theme.Fonts.Title })
	oddsHolder = Kit.frame(detail, { Name = "Odds", Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromOffset(0, 108) })
	Kit.listLayout(oddsHolder, 4, false)
	variantLabel = Kit.label(detail, "", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 262), TextSize = 12, Color = C.TextDim,
		Wrap = true, Font = Theme.Fonts.Body })
	previewHolder = Kit.scroll(detail, { Size = UDim2.new(1, 0, 0, 112), Position = UDim2.fromOffset(0, 300), Horizontal = true, Padding = 6 })

	local buttonRow = Kit.frame(detail, { Name = "Buttons", Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 1, -52) })
	Kit.listLayout(buttonRow, 10, true)

	local function price(def)
		local event = State.Data._Event
		local discount = 1
		if event and event.Id and State.serverTime() < (event.EndsAt or 0) then
			discount = Defs.Events.ById[event.Id].Effects.CapsuleDiscount or 1
		end
		return Progression.capsulePrice(State.Data, def, discount)
	end

	local function luck()
		local event = State.Data._Event
		local eventLuck = 1
		if event and event.Id and State.serverTime() < (event.EndsAt or 0) then
			eventLuck = Defs.Events.ById[event.Id].Effects.VariantLuck or 1
		end
		return Progression.variantLuck(State.Data, eventLuck)
	end

	local function updateButtons()
		local def = Defs.Capsules.ById[selected]
		local unlocked = State.Data.Systems[def.RequiresSystem] == true
		local unit = price(def)
		local maxBatch = Progression.maxBatch(State.Data)
		for _, item in ipairs(openButtons) do
			local count = item.Count
			local allowed = unlocked and count <= maxBatch
			item.Button.Text = "Abrir x" .. count .. "\n⚡ " .. Format.number(unit * count)
			if count > maxBatch then item.Button.Text = "x" .. count .. " 🔒\nApertura Múltiple" end
			Kit.setEnabled(item.Button, allowed and (State.Data.Energy or 0) >= unit * count and not busy)
		end
		priceLabel.Text = "⚡ " .. Format.number(unit) .. (unit < def.Price and ("  (antes " .. Format.number(def.Price) .. ")") or "")
	end

	local function showDetail()
		local def = Defs.Capsules.ById[selected]
		local unlocked = State.Data.Systems[def.RequiresSystem] == true
		titleLabel.Text = def.Name
		titleLabel.TextColor3 = def.Color
		descLabel.Text = def.Description
		reqLabel.Text = unlocked and "✔ Disponible" or ("🔒 Requiere " .. Defs.Galaxy.ById[def.RequiresSystem].Name)
		reqLabel.TextColor3 = unlocked and C.Green or C.Red
		Kit.clear(oddsHolder)
		for index, entry in ipairs(Defs.Capsules.oddsList(def, Defs.Rarities.Order)) do
			local rarity = Defs.Rarities.ById[entry.Rarity]
			local row = Kit.box(oddsHolder, C.Row, 0.2, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = index }, 6)
			Kit.label(row, Kit.rarityText(entry.Rarity), { Size = UDim2.new(0, 130, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 13, Color = rarity.Color })
			local names = {}
			for _, id in ipairs(entry.Planets) do
				table.insert(names, Defs.Planets.ById[id].Name)
			end
			Kit.label(row, table.concat(names, ", "), { Size = UDim2.new(1, -220, 1, 0), Position = UDim2.fromOffset(140, 0), TextSize = 12,
				Color = C.TextDim, Font = Theme.Fonts.Body })
			Kit.label(row, Format.percent(entry.Chance), { Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -78, 0, 0), TextSize = 14,
				AlignX = Enum.TextXAlignment.Right })
		end
		local chances = Defs.Variants.chances(luck())
		local parts = {}
		for _, id in ipairs(Defs.Variants.Order) do
			if id ~= "none" then
				local v = Defs.Variants.ById[id]
				table.insert(parts, v.Icon .. " " .. v.Name .. " " .. Format.percent(chances[id]) .. " (" .. Format.mult(v.Multiplier) .. ")")
			end
		end
		variantLabel.Text = "Variantes (probabilidad por planeta): " .. table.concat(parts, "  ·  ")
		Kit.clear(previewHolder)
		local order = 0
		for _, entry in ipairs(Defs.Capsules.oddsList(def, Defs.Rarities.Order)) do
			for _, id in ipairs(entry.Planets) do
				order = order + 1
				local card = Kit.planetCard(previewHolder, { Id = id, V = "none", E = false, Silhouette = not State.Data.Discovered[id] },
					{ Size = UDim2.fromOffset(84, 104), ShowRate = false })
				card.LayoutOrder = order
			end
		end
		for id, row in pairs(rows) do
			Kit.setStyle(row, id == selected and "cyan" or "ghost")
		end
		updateButtons()
	end

	for index, def in ipairs(Defs.Capsules.List) do
		local row = Kit.button(list, "", "ghost", { Size = UDim2.new(1, -4, 0, 62), Props = { LayoutOrder = index, Name = "Capsule_" .. def.Id } }, function()
			selected = def.Id
			showDetail()
		end)
		local dot = Kit.box(row, def.Color, 0, { Size = UDim2.fromOffset(26, 40), Position = UDim2.fromOffset(10, 11) }, 13)
		Kit.gradient(dot, Color3.new(1, 1, 1), def.CoreColor, 90)
		Kit.label(row, def.Name, { Size = UDim2.new(1, -52, 0, 24), Position = UDim2.fromOffset(46, 8), TextSize = 15 })
		Kit.label(row, "⚡ " .. Format.number(def.Price), { Size = UDim2.new(1, -52, 0, 20), Position = UDim2.fromOffset(46, 32), TextSize = 13,
			Color = C.Energy }).Name = "Price"
		rows[def.Id] = row
	end

	for index, count in ipairs(Defs.Config.Capsules.BatchSizes) do
		local button
		button = Kit.button(buttonRow, "", index == 1 and "primary" or "cyan", { Size = UDim2.fromOffset(index == 1 and 230 or 180, 52), TextSize = 14,
			Props = { LayoutOrder = index, Name = "Open" .. count } }, function()
			if busy then return end
			busy = true
			updateButtons()
			local result = ctx.UI.request("OpenCapsule", selected, count)
			if result.Ok then
				ctx.Capsule.play(result.Data)
			end
			busy = false
			updateButtons()
		end)
		table.insert(openButtons, { Button = button, Count = count })
	end

	local lastUpdate = 0
	State.on("Energy", function()
		if frame.Visible and os.clock() - lastUpdate > 0.4 then
			lastUpdate = os.clock()
			updateButtons()
		end
	end)
	State.onAny(function(changed)
		if frame.Visible and (changed.Systems or changed.Upgrades or changed._Event or changed.Discovered) then showDetail() end
	end)

	return {
		Frame = frame,
		OnOpen = function(args)
			if args.Capsule and Defs.Capsules.ById[args.Capsule] then selected = args.Capsule end
			showDetail()
		end,
		Refresh = showDetail,
	}
end
