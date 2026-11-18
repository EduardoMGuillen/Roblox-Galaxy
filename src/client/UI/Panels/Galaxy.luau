-- GalaxyUI: los cinco sistemas con su estado (bloqueado / listo para desbloquear / desbloqueado),
-- requisitos, progreso y contenido que introducen. Permite desbloquear y viajar entre sistemas.
return function(ctx, parent)
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "GalaxyUI", Size = UDim2.fromOffset(980, 560), Title = "Sistemas de tu universo", Icon = "🌌",
		OnClose = function() ctx.UI.close() end })
	local row = Kit.frame(body, { Size = UDim2.fromScale(1, 1) })
	Kit.listLayout(row, 10, true)

	local function refresh()
		Kit.clear(row)
		local data = State.Data
		local rate = State.rate()
		for index, def in ipairs(Defs.Galaxy.List) do
			local state, checks = Progression.systemState(data, def.Id, rate)
			local active = data.ActiveSystem == def.Id
			local card = Kit.box(row, C.Row, 0.1, { Size = UDim2.new(0.2, -8, 1, 0), LayoutOrder = index, Name = "System_" .. def.Id }, 12)
			Kit.stroke(card, active and C.Text or def.Theme.Accent, active and 3 or 1.5, state == "locked" and 0.6 or 0)
			local header = Kit.box(card, def.Theme.Accent, 0.15, { Size = UDim2.new(1, -12, 0, 74), Position = UDim2.fromOffset(6, 6) }, 10)
			Kit.gradient(header, def.Theme.Star, def.Theme.Accent, 90)
			Kit.label(header, string.format("%02d", index), { Size = UDim2.fromOffset(40, 24), Position = UDim2.fromOffset(8, 4), TextSize = 14,
				Font = F.Title, Color = C.Dark })
			Kit.label(header, string.upper(def.Name), { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(8, 26), TextSize = 13,
				Font = F.Title, Color = C.Dark })
			Kit.label(header, def.Subtitle, { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(8, 50), TextSize = 11, Color = C.Dark,
				Font = F.Body })
			local badgeText = (state == "unlocked" and (active and "● ACTIVO" or "✔ DESBLOQUEADO")) or (state == "ready" and "★ LISTO") or "🔒 BLOQUEADO"
			local badgeColor = (state == "unlocked" and C.Green) or (state == "ready" and C.Gold) or C.Red
			Kit.label(card, badgeText, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 84), TextSize = 12, Color = badgeColor })
			Kit.label(card, "Producción " .. Format.mult(def.Multiplier), { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 104),
				TextSize = 14, Color = C.Energy })
			Kit.label(card, def.Introduces, { Size = UDim2.new(1, -16, 0, 62), Position = UDim2.fromOffset(8, 126), TextSize = 11, Wrap = true,
				Color = C.TextDim, Font = F.Body, AlignY = Enum.TextYAlignment.Top })

			local info = Kit.frame(card, { Size = UDim2.new(1, -16, 0, 190), Position = UDim2.fromOffset(8, 192) })
			Kit.listLayout(info, 5, false)
			if state == "unlocked" then
				local found, total = Progression.discoveredInSystem(data, def.Id)
				local barCollection, setCollection = Kit.progress(info, { Size = UDim2.new(1, 0, 0, 20), Color = C.Violet })
				barCollection.LayoutOrder = 1
				setCollection(found / total, "Colección " .. found .. "/" .. total)
				local placed = Progression.placedCount(data, def.Id)
				local slots = data.Slots[def.Id] or 0
				local barSlots, setSlots = Kit.progress(info, { Size = UDim2.new(1, 0, 0, 20), Color = C.Cyan })
				barSlots.LayoutOrder = 2
				setSlots(placed / Defs.Config.Economy.SlotsPerSystem, "Órbitas " .. placed .. "/" .. slots .. " (máx. 8)")
				local breakdown = data._Production and data._Production.Systems[def.Id]
				Kit.label(info, "⚡ " .. Format.rate(breakdown and breakdown.Total or 0) .. " antes de mejoras", { Size = UDim2.new(1, 0, 0, 18),
					TextSize = 11, Color = C.TextDim, Font = F.Body, Props = { LayoutOrder = 3 } })
				local reward = def.Reward
				Kit.label(info, (data.CollectionsClaimed[def.Id] and "✔ " or "🎁 ") .. "Colección completa: +" .. reward.Stardust .. " ✨ y +"
					.. math.floor(reward.ProductionBonus * 100) .. "% producción", { Size = UDim2.new(1, 0, 0, 34), TextSize = 11, Wrap = true,
					Color = data.CollectionsClaimed[def.Id] and C.Green or C.TextDim, Font = F.Body, Props = { LayoutOrder = 4 } })
			else
				for i, check in ipairs(checks) do
					local bar, set = Kit.progress(info, { Size = UDim2.new(1, 0, 0, 16), Color = check.Ok and C.Green or C.Gold })
					bar.LayoutOrder = i * 2 - 1
					set(check.Goal > 0 and check.Current / check.Goal or 0, (check.Ok and "✔ " or "") .. Format.number(check.Current) .. " / "
						.. Format.number(check.Goal))
					Kit.label(info, check.Text, { Size = UDim2.new(1, 0, 0, 28), TextSize = 10, Wrap = true, Color = check.Ok and C.Green or C.TextDim,
						Font = F.Body, AlignY = Enum.TextYAlignment.Top, Props = { LayoutOrder = i * 2 } })
				end
			end

			local buttonSize = UDim2.new(1, -16, 0, 40)
			local buttonPos = UDim2.new(0, 8, 1, -48)
			if state == "unlocked" then
				local b = Kit.button(card, active and "Estás aquí" or "Viajar", active and "ghost" or "cyan", { Size = buttonSize, Position = buttonPos,
					TextSize = 14, Props = { Name = "Travel" } }, function()
					local result = ctx.UI.request("SetActiveSystem", def.Id)
					if result.Ok then
						if ctx.Audio then ctx.Audio.play("portal") end
						if not State.inOwnUniverse() then ctx.UI.request("Teleport", "universe") end
						ctx.UI.close()
					end
				end)
				Kit.setEnabled(b, not active)
			else
				local cost = Progression.systemEnergyCost(def.Id)
				local b = Kit.button(card, state == "ready" and ("Desbloquear\n⚡ " .. Format.number(cost)) or "Bloqueado", "gold",
					{ Size = buttonSize, Position = buttonPos, TextSize = 13, Props = { Name = "Unlock" } }, function()
						local result = ctx.UI.request("UnlockSystem", def.Id)
						if result.Ok and ctx.Audio then ctx.Audio.play("fanfare") end
					end)
				Kit.setEnabled(b, state == "ready")
			end
		end
	end

	local last = 0
	State.onAny(function(changed)
		if not frame.Visible then return end
		if changed.Systems or changed.ActiveSystem or changed.Slots or changed.Placed or changed.Discovered or changed.Ascensions
			or changed.CollectionsClaimed or (changed.Energy and os.clock() - last > 2) then
			last = os.clock()
			refresh()
		end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
