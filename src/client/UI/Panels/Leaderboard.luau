-- Leaderboard: cinco clasificaciones persistentes (se refrescan periodicamente en el servidor).
return function(ctx, parent)
	local Kit, State, Format, Theme = ctx.Kit, ctx.State, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "LeaderboardUI", Size = UDim2.fromOffset(700, 540), Title = "Leaderboard", Icon = "🏅",
		OnClose = function() ctx.UI.close() end })
	local CATEGORIES = {
		{ "Rate", "Producción", function(v) return "⚡ " .. Format.rate(v) end },
		{ "Value", "Valor", function(v) return Format.number(v) end },
		{ "Ascensions", "Ascensiones", function(v) return "👑 " .. Format.number(v) end },
		{ "Discoveries", "Descubiertos", function(v) return "📖 " .. Format.number(v) end },
		{ "Rares", "Raros", function(v) return "✦ " .. Format.number(v) end },
	}
	local tab = 1
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), Padding = 5 })

	local function refresh()
		Kit.clear(list)
		local category = CATEGORIES[tab]
		local board = State.Leaderboards[category[1]] or {}
		for rank, entry in ipairs(board) do
			local row = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 40), LayoutOrder = rank }, 8)
			local color = (rank == 1 and C.Gold) or (rank == 2 and Color3.fromRGB(200, 210, 230)) or (rank == 3 and Color3.fromRGB(220, 150, 90)) or C.TextDim
			Kit.label(row, "#" .. rank, { Size = UDim2.fromOffset(50, 40), Position = UDim2.fromOffset(10, 0), TextSize = 17, Font = F.Black, Color = color })
			Kit.label(row, entry.Name, { Size = UDim2.new(1, -260, 1, 0), Position = UDim2.fromOffset(64, 0), TextSize = 15 })
			Kit.label(row, category[3](entry.Value), { Size = UDim2.fromOffset(180, 40), Position = UDim2.new(1, -190, 0, 0), TextSize = 15,
				AlignX = Enum.TextXAlignment.Right, Color = C.Cyan })
		end
		if #board == 0 then
			Kit.label(list, "Aún no hay datos en esta clasificación.", { Size = UDim2.new(1, 0, 0, 40), TextSize = 13, Color = C.TextDim,
				AlignX = Enum.TextXAlignment.Center, Font = F.Body })
		end
	end

	local names = {}
	for _, category in ipairs(CATEGORIES) do
		table.insert(names, category[2])
	end
	Kit.tabs(body, names, function(index)
		tab = index
		refresh()
	end, { Size = UDim2.new(1, 0, 0, 36), Width = 126 })

	State.onLeaderboard(function()
		if frame.Visible then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
