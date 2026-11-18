-- Teletransporte y Universe Showcase: volver al Hub, ir a tu universo o visitar (solo lectura) el de otro jugador.
return function(ctx, parent)
	local Players = game:GetService("Players")
	local Kit, State, Defs, Format, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "TeleportUI", Size = UDim2.fromOffset(640, 520), Title = "Portal Room", Icon = "🌀",
		OnClose = function() ctx.UI.close() end })

	local function go(destination)
		local result = ctx.UI.request("Teleport", destination)
		if result.Ok then
			if ctx.Audio then ctx.Audio.play("portal") end
			ctx.UI.close()
		end
	end
	Kit.button(body, "🏠  Cosmic Hub", "cyan", { Size = UDim2.new(0.5, -6, 0, 56), TextSize = 17, Props = { Name = "Hub" } }, function() go("hub") end)
	Kit.button(body, "🌌  Mi universo", "primary", { Size = UDim2.new(0.5, -6, 0, 56), Position = UDim2.new(0.5, 6, 0, 0), TextSize = 17,
		Props = { Name = "Universe" } }, function() go("universe") end)
	Kit.label(body, "UNIVERSOS DE OTROS JUGADORES (solo lectura)", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 68), TextSize = 12,
		Font = F.Title, Color = C.Cyan })
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -96), Position = UDim2.fromOffset(0, 94), Padding = 6 })

	local function refresh()
		Kit.clear(list)
		local me = Players.LocalPlayer.UserId
		local order = 0
		for userId, view in pairs(State.Universes) do
			if userId ~= me then
				order = order + 1
				local row = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 62), LayoutOrder = order, Name = "Universe_" .. userId }, 10)
				Kit.label(row, "🪐 " .. view.Name, { Size = UDim2.new(1, -190, 0, 24), Position = UDim2.fromOffset(12, 6), TextSize = 16 })
				Kit.label(row, "⚡ " .. Format.rate(view.Stats.Rate) .. "  ·  👑 " .. view.Stats.Ascensions .. "  ·  📖 " .. view.Stats.Discovered .. "/"
					.. view.Stats.DiscoveredTotal .. "  ·  " .. Defs.Galaxy.ById[view.System].Name, { Size = UDim2.new(1, -190, 0, 20),
					Position = UDim2.fromOffset(12, 32), TextSize = 12, Color = C.TextDim, Font = F.Body })
				Kit.button(row, "Visitar", "cyan", { Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -162, 0, 11), TextSize = 14,
					Props = { Name = "Visit" } }, function()
					local result = ctx.UI.request("VisitUniverse", userId)
					if result.Ok then
						if ctx.Audio then ctx.Audio.play("portal") end
						ctx.UI.close()
					end
				end)
			end
		end
		if order == 0 then
			Kit.label(list, "No hay otros jugadores en este servidor ahora mismo.", { Size = UDim2.new(1, 0, 0, 40), TextSize = 13, Color = C.TextDim,
				AlignX = Enum.TextXAlignment.Center, Font = F.Body })
		end
	end

	State.onUniverse(function()
		if frame.Visible then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
