-- Tienda cosmetica: personalizacion del universo con Stardust (ganado jugando). No afecta al balance.
return function(ctx, parent)
	local Kit, State, Defs, Format, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "ShopUI", Size = UDim2.fromOffset(760, 520), Title = "Tienda cosmética", Icon = "🛒",
		OnClose = function() ctx.UI.close() end })
	local tab = 1
	local balance = Kit.label(body, "", { Size = UDim2.fromOffset(260, 36), Position = UDim2.new(1, -260, 0, 0), TextSize = 16,
		AlignX = Enum.TextXAlignment.Right, Color = C.Stardust })
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -74), Position = UDim2.fromOffset(0, 46), Padding = 6 })
	Kit.label(body, "Los cosméticos solo cambian el aspecto de tu universo. El Stardust se gana con misiones, eventos y colecciones.",
		{ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), TextSize = 11, Color = C.TextDim, Font = F.Body })

	local function refresh()
		Kit.clear(list)
		local data = State.Data
		balance.Text = "✨ " .. Format.number(data.Stardust) .. " Stardust"
		local category = Defs.Cosmetics.Categories[tab]
		for index, def in ipairs(Defs.Cosmetics.ByCategory[category.Id]) do
			local owned = data.Cosmetics.Owned[def.Id] == true
			local equipped = data.Cosmetics.Equipped[category.Id] == def.Id
			local row = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 58), LayoutOrder = index, Name = "Cosmetic_" .. def.Id }, 10)
			local swatch = Kit.box(row, def.Color or C.Cyan, 0, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(10, 10) }, 19)
			Kit.stroke(swatch, C.Text, 1.5, 0.3)
			Kit.label(row, def.Name, { Size = UDim2.new(1, -260, 0, 24), Position = UDim2.fromOffset(60, 6), TextSize = 15 })
			Kit.label(row, def.Description or ("Color " .. string.lower(def.Name) .. " para tus órbitas."), { Size = UDim2.new(1, -260, 0, 18),
				Position = UDim2.fromOffset(60, 30), TextSize = 12, Color = C.TextDim, Font = F.Body })
			local text = equipped and "✔ Equipado" or (owned and "Equipar" or ("✨ " .. def.Price))
			local button = Kit.button(row, text, equipped and "ghost" or (owned and "cyan" or "primary"), { Size = UDim2.fromOffset(160, 40),
				Position = UDim2.new(1, -172, 0, 9), TextSize = 14, Props = { Name = "Action" } }, function()
				if owned then
					ctx.UI.request("EquipCosmetic", def.Id)
				else
					local result = ctx.UI.request("BuyCosmetic", def.Id)
					if result.Ok then
						if ctx.Audio then ctx.Audio.play("success") end
						ctx.UI.request("EquipCosmetic", def.Id)
					end
				end
			end)
			Kit.setEnabled(button, not equipped and (owned or data.Stardust >= def.Price))
		end
	end

	local names = {}
	for _, category in ipairs(Defs.Cosmetics.Categories) do
		table.insert(names, category.Name)
	end
	Kit.tabs(body, names, function(index)
		tab = index
		refresh()
	end, { Size = UDim2.fromOffset(420, 36), Width = 190 })

	State.onAny(function(changed)
		if frame.Visible and (changed.Cosmetics or changed.Stardust) then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
