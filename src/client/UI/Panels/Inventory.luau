-- InventoryUI + PlanetInspectUI: lista de instancias con filtros, estado colocado/no colocado, y ficha
-- del planeta seleccionado con sus acciones (colocar, retirar, bloquear, evolucionar, vender).
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "InventoryUI", Size = UDim2.fromOffset(960, 580), Title = "Inventario", Icon = "🎒",
		OnClose = function() ctx.UI.close() end })

	local filter = 1 -- 1 todos, 2 libres, 3 en orbita
	local selected = nil
	local sellMode = false
	local sellSet = {}
	local placeSlot = nil -- slot elegido desde el panel de orbitas
	local cards = {} -- [uid] = { Card, Signature }

	local refresh, showInspect

	local toolbar = Kit.frame(body, { Name = "Toolbar", Size = UDim2.new(1, -290, 0, 36) })
	local _, selectTab = Kit.tabs(toolbar, { "Todos", "Libres", "En órbita" }, function(index)
		filter = index
		refresh()
	end, { Size = UDim2.fromOffset(330, 36), Width = 104 })
	local countLabel = Kit.label(toolbar, "", { Size = UDim2.fromOffset(110, 36), Position = UDim2.new(1, -250, 0, 0), TextSize = 14,
		AlignX = Enum.TextXAlignment.Right, Color = C.TextDim })
	local sellToggle
	local grid = Kit.scroll(body, { Size = UDim2.new(1, -290, 1, -86), Position = UDim2.fromOffset(0, 44), Grid = UDim2.fromOffset(118, 150), Padding = 8 })
	local hintLabel = Kit.label(body, "", { Size = UDim2.new(1, -290, 0, 34), Position = UDim2.new(0, 0, 1, -36), TextSize = 13, Color = C.TextDim,
		Wrap = true, Font = F.Body })
	local sellButton = Kit.button(body, "", "danger", { Size = UDim2.fromOffset(250, 36), Position = UDim2.new(1, -540, 1, -36), TextSize = 13 })
	sellButton.Visible = false

	local side = Kit.box(body, C.PanelLight, 0.2, { Name = "Inspect", Size = UDim2.new(0, 278, 1, 0), Position = UDim2.new(1, -278, 0, 0) }, 12)
	Kit.stroke(side, C.Cyan, 1, 0.5)
	local sideBody = Kit.frame(side, { Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10) })

	local function isPlaced(uid)
		return Progression.findPlaced(State.Data, uid) ~= nil
	end

	local function sellTotal()
		local total, n = 0, 0
		for uid in pairs(sellSet) do
			local inst = State.Data.Planets[uid]
			if inst then
				total = total + Progression.sellValue(inst)
				n = n + 1
			end
		end
		return total, n
	end

	local function updateSellButton()
		local total, n = sellTotal()
		sellButton.Visible = sellMode
		sellButton.Text = "Vender " .. n .. " por ⚡ " .. Format.number(total)
		Kit.setEnabled(sellButton, n > 0)
		sellToggle.Text = sellMode and "Cancelar venta" or "Vender varios"
		Kit.setStyle(sellToggle, sellMode and "danger" or "ghost")
	end

	local function place(uid, slot)
		local result = ctx.UI.request("EquipPlanet", uid, State.Data.ActiveSystem, slot)
		if result.Ok then
			if ctx.Audio then ctx.Audio.play("success") end
			ctx.UI.toast("Planeta colocado en la órbita " .. slot, "info")
			placeSlot = nil
			if ctx.State.inOwnUniverse() then ctx.UI.close() end
		end
	end

	-- selector de slot del sistema activo
	local function pickSlot(uid)
		local data = State.Data
		local system = Defs.Galaxy.ById[data.ActiveSystem]
		local shade = Kit.frame(frame, { Name = "SlotPicker", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Dark, BackgroundTransparency = 0.35,
			Active = true, ZIndex = 20 })
		Kit.corner(shade, 16)
		local box = Kit.box(shade, C.Panel, 0, { Size = UDim2.fromOffset(520, 300), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21 }, 14)
		Kit.stroke(box, C.Cyan, 2, 0)
		Kit.label(box, "Elige una órbita de " .. system.Name, { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(14, 8), TextSize = 17,
			Props = { ZIndex = 22 } })
		local holder = Kit.frame(box, { Size = UDim2.new(1, -28, 0, 190), Position = UDim2.fromOffset(14, 50), ZIndex = 22 })
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(116, 88)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		local owned = data.Slots[data.ActiveSystem] or 0
		for i = 1, Defs.Config.Economy.SlotsPerSystem do
			local occupant = data.Placed[data.ActiveSystem] and data.Placed[data.ActiveSystem][Defs.Galaxy.slotKey(i)]
			local text
			if i > owned then
				text = "Órbita " .. i .. "\n🔒 Bloqueada"
			elseif occupant and data.Planets[occupant] then
				text = "Órbita " .. i .. "\n" .. Defs.Planets.ById[data.Planets[occupant].Id].Name .. "\n(reemplazar)"
			else
				text = "Órbita " .. i .. "\n+ Libre"
			end
			local b = Kit.button(holder, text, (i <= owned and not occupant) and "green" or "ghost", { TextSize = 12,
				Props = { LayoutOrder = i, ZIndex = 23, Name = "Slot" .. i } }, function()
				shade:Destroy()
				place(uid, i)
			end)
			Kit.setEnabled(b, i <= owned and occupant ~= uid)
		end
		Kit.button(box, "Cancelar", "ghost", { Size = UDim2.fromOffset(140, 36), Position = UDim2.new(0.5, -70, 1, -46), Props = { ZIndex = 23 } },
			function() shade:Destroy() end)
	end

	showInspect = function()
		Kit.clear(sideBody)
		local data = State.Data
		local inst = selected and data.Planets[selected]
		if not inst then
			selected = nil
			Kit.label(sideBody, "Selecciona un planeta para ver su ficha y sus acciones.", { Size = UDim2.new(1, 0, 0, 80), TextSize = 14,
				Wrap = true, Color = C.TextDim, Font = F.Body, AlignX = Enum.TextXAlignment.Center })
			return
		end
		local uid = selected
		local def = Defs.Planets.ById[inst.Id]
		local rarity = Defs.Rarities.ById[def.Rarity]
		local variant = Defs.Variants.get(inst.V)
		local placedSystem, placedSlot = Progression.findPlaced(data, uid)
		Kit.viewport(sideBody, inst.Id, inst.V, inst.E, { Size = UDim2.new(1, 0, 0, 150) })
		Kit.label(sideBody, Defs.Planets.displayName(def, inst.E), { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 150), TextSize = 21,
			Font = F.Black, AlignX = Enum.TextXAlignment.Center, Color = rarity.Color })
		local sub = Kit.rarityText(def.Rarity) .. " · " .. def.TypeLabel
		Kit.label(sideBody, sub, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 178), TextSize = 12, AlignX = Enum.TextXAlignment.Center })
		local rateText = "⚡ " .. Format.rate(Progression.planetRate(inst))
		if variant.Id ~= "none" then rateText = rateText .. "  ·  " .. variant.Icon .. " " .. variant.Name .. " " .. Format.mult(variant.Multiplier) end
		if inst.E then rateText = rateText .. "  ·  Prime " .. Format.mult(Defs.Config.Evolution.ProductionMultiplier) end
		Kit.label(sideBody, rateText, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 197), TextSize = 12, AlignX = Enum.TextXAlignment.Center,
			Color = C.Energy })
		Kit.label(sideBody, def.Description, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 217), TextSize = 12, Wrap = true,
			Color = C.TextDim, Font = F.Body, AlignY = Enum.TextYAlignment.Top, AlignX = Enum.TextXAlignment.Center })
		local status = placedSystem and ("En órbita: " .. Defs.Galaxy.ById[placedSystem].Name .. ", " .. string.gsub(placedSlot, "s", "órbita "))
			or "En el inventario"
		Kit.label(sideBody, status, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 268), TextSize = 11, AlignX = Enum.TextXAlignment.Center,
			Color = placedSystem and C.Cyan or C.TextDim })

		local actions = Kit.frame(sideBody, { Name = "Actions", Size = UDim2.new(1, 0, 0, 196), Position = UDim2.new(0, 0, 1, -196) })
		Kit.listLayout(actions, 6, false)
		local full = UDim2.new(1, 0, 0, 34)
		if placedSystem then
			Kit.button(actions, "Retirar de la órbita", "ghost", { Size = full, TextSize = 13, Props = { LayoutOrder = 1, Name = "Unequip" } }, function()
				local index = tonumber(string.match(placedSlot, "%d+"))
				ctx.UI.request("UnequipPlanet", placedSystem, index)
			end)
		else
			Kit.button(actions, placeSlot and ("Colocar en la órbita " .. placeSlot) or "Colocar en órbita", "primary",
				{ Size = full, TextSize = 13, Props = { LayoutOrder = 1, Name = "Equip" } }, function()
					if placeSlot then place(uid, placeSlot) else pickSlot(uid) end
				end)
		end
		Kit.button(actions, inst.L and "🔓 Desbloquear" or "🔒 Bloquear (proteger)", "ghost", { Size = full, TextSize = 13,
			Props = { LayoutOrder = 2, Name = "Lock" } }, function()
			ctx.UI.request("LockPlanet", uid, not inst.L)
		end)
		if not inst.E then
			local cost = Progression.evolutionCost(def)
			local fodder = Progression.evolutionFodder(data, uid)
			local can = #fodder >= cost.Copies and data.Energy >= cost.Energy and data.Stardust >= cost.Stardust
			local evolve = Kit.button(actions, "Evolucionar a Prime\n" .. #fodder .. "/" .. cost.Copies .. " copias · ⚡" .. Format.number(cost.Energy)
				.. " · ✨" .. cost.Stardust, "gold", { Size = UDim2.new(1, 0, 0, 44), TextSize = 12, Props = { LayoutOrder = 3, Name = "Evolve" } }, function()
				ctx.UI.confirm({ Title = "Evolucionar", Icon = "🌟", Confirm = "Evolucionar", Style = "gold",
					Text = "Se consumirán " .. cost.Copies .. " copias normales de " .. def.Name .. ", " .. Format.number(cost.Energy)
						.. " de Energy y " .. cost.Stardust .. " de Stardust. " .. def.Name .. " pasará a ser " .. def.Name
						.. " Prime (producción " .. Format.mult(Defs.Config.Evolution.ProductionMultiplier) .. ").",
					OnConfirm = function()
						local result = ctx.UI.request("EvolvePlanet", uid)
						if result.Ok then
							ctx.UI.toast("¡" .. def.Name .. " evolucionó a " .. def.Name .. " Prime!", "reward")
							if ctx.Audio then ctx.Audio.play("fanfare") end
						end
					end })
			end)
			Kit.setEnabled(evolve, can)
		end
		local sell = Kit.button(actions, "Vender por ⚡ " .. Format.number(Progression.sellValue(inst)), "danger", { Size = full, TextSize = 13,
			Props = { LayoutOrder = 4, Name = "Sell" } }, function()
			ctx.UI.confirm({ Title = "Vender planeta", Icon = "💱", Confirm = "Vender", Style = "danger",
				Text = "¿Vender " .. Defs.Planets.displayName(def, inst.E) .. " por " .. Format.number(Progression.sellValue(inst))
					.. " de Energy? Esta acción no se puede deshacer.",
				OnConfirm = function()
					ctx.UI.request("SellPlanets", { uid })
				end })
		end)
		Kit.setEnabled(sell, not inst.L and not placedSystem)
	end

	refresh = function()
		local data = State.Data
		local list = {}
		for uid, inst in pairs(data.Planets) do
			local placed = isPlaced(uid)
			if filter == 1 or (filter == 2 and not placed) or (filter == 3 and placed) then
				table.insert(list, { Uid = uid, Inst = inst, Placed = placed, Def = Defs.Planets.ById[inst.Id] })
			end
		end
		table.sort(list, function(a, b)
			local ra, rb = Defs.Rarities.ById[a.Def.Rarity].Order, Defs.Rarities.ById[b.Def.Rarity].Order
			if ra ~= rb then return ra > rb end
			local pa, pb = Progression.planetRate(a.Inst), Progression.planetRate(b.Inst)
			if pa ~= pb then return pa > pb end
			return a.Uid < b.Uid
		end)
		local keep = {}
		for order, item in ipairs(list) do
			local uid = item.Uid
			local signature = item.Inst.Id .. "|" .. item.Inst.V .. "|" .. tostring(item.Inst.E) .. "|" .. tostring(item.Inst.L) .. "|"
				.. tostring(item.Placed)
			local entry = cards[uid]
			if not entry or entry.Signature ~= signature then
				if entry then entry.Card:Destroy() end
				local card = Kit.planetCard(grid, { Id = item.Inst.Id, V = item.Inst.V, E = item.Inst.E, L = item.Inst.L, Placed = item.Placed }, {
					OnClick = function()
						if sellMode then
							local inst = State.Data.Planets[uid]
							if inst and not inst.L and not isPlaced(uid) then
								sellSet[uid] = not sellSet[uid] or nil
								refresh()
							else
								ctx.UI.toast("Ese planeta está bloqueado o en órbita.", "error")
							end
						else
							selected = uid
							refresh()
						end
					end,
				})
				card.Name = "Card_" .. uid
				entry = { Card = card, Signature = signature }
				cards[uid] = entry
			end
			entry.Card.LayoutOrder = order
			local edge = entry.Card:FindFirstChild("Edge")
			if edge then
				local highlighted = (sellMode and sellSet[uid]) or (not sellMode and selected == uid)
				edge.Thickness = highlighted and 3.5 or 1.5
				edge.Color = (sellMode and sellSet[uid]) and C.Red or (highlighted and C.Text or Defs.Rarities.ById[item.Def.Rarity].Color)
			end
			keep[uid] = true
		end
		for uid, entry in pairs(cards) do
			if not keep[uid] then
				entry.Card:Destroy()
				cards[uid] = nil
			end
		end
		for uid in pairs(sellSet) do
			if not data.Planets[uid] then sellSet[uid] = nil end
		end
		countLabel.Text = Progression.inventoryCount(data) .. " / " .. Progression.inventoryCapacity(data)
		if placeSlot then
			hintLabel.Text = "Elige un planeta para la órbita " .. placeSlot .. " de " .. Defs.Galaxy.ById[data.ActiveSystem].Name .. "."
		elseif sellMode then
			hintLabel.Text = "Toca los planetas que quieras vender."
		else
			hintLabel.Text = "Los duplicados sirven para evolucionar (Prime), intercambiar o vender."
		end
		updateSellButton()
		showInspect()
	end

	sellToggle = Kit.button(toolbar, "Vender varios", "ghost", { Size = UDim2.fromOffset(130, 34), Position = UDim2.new(1, -130, 0, 1), TextSize = 13 },
		function()
			sellMode = not sellMode
			sellSet = {}
			refresh()
		end)
	sellToggle.Name = "SellMode"
	sellButton.Activated:Connect(function()
		if sellButton:GetAttribute("Disabled") then return end
		local total, n = sellTotal()
		local uids = {}
		for uid in pairs(sellSet) do
			table.insert(uids, uid)
		end
		ctx.UI.confirm({ Title = "Vender planetas", Icon = "💱", Confirm = "Vender " .. n, Style = "danger",
			Text = "¿Vender " .. n .. " planetas por " .. Format.number(total) .. " de Energy? Esta acción no se puede deshacer.",
			OnConfirm = function()
				local result = ctx.UI.request("SellPlanets", uids)
				if result.Ok then
					sellSet = {}
					sellMode = false
					refresh()
				end
			end })
	end)

	State.onAny(function(changed)
		if frame.Visible and (changed.Planets or changed.Placed or changed.Slots or changed.ActiveSystem or changed.Upgrades) then
			refresh()
		end
	end)

	return {
		Frame = frame,
		OnOpen = function(args)
			sellMode = false
			sellSet = {}
			placeSlot = args.PlaceSlot
			if args.Select and State.Data.Planets[args.Select] then
				selected = args.Select
			end
			if placeSlot then
				filter = 2
				selectTab(2, true)
			end
			refresh()
			if args.Place and selected and not isPlaced(selected) then
				pickSlot(selected)
			end
		end,
		OnClose = function()
			placeSlot = nil
		end,
		Refresh = refresh,
	}
end
