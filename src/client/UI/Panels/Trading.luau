-- TradingUI: Galactic Trading. Invitar/aceptar, oferta de ambos jugadores con atributos, rareza y
-- variantes, estado de "Listo", periodo de revision y confirmacion final de los dos.
return function(ctx, parent)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Kit, State, Defs, Format, Progression, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Progression, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "TradingUI", Size = UDim2.fromOffset(960, 580), Title = "Galactic Market", Icon = "🔁",
		OnClose = function() ctx.UI.close() end })
	local Trade = ctx.Trade
	local confirmButton = nil
	local reviewLabel = nil

	local function lobby()
		Kit.label(body, "INVITACIONES RECIBIDAS", { Size = UDim2.new(0.5, -8, 0, 22), TextSize = 12, Font = F.Title, Color = C.Gold })
		local incoming = Kit.scroll(body, { Size = UDim2.new(0.5, -8, 1, -30), Position = UDim2.fromOffset(0, 28), Padding = 6 })
		local count = 0
		for index, request in ipairs(Trade.Requests) do
			if request.Expires > os.clock() then
				count = count + 1
				local row = Kit.box(incoming, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 56), LayoutOrder = index, Name = "Request_" .. request.From }, 10)
				Kit.label(row, "🤝 " .. request.Name, { Size = UDim2.new(1, -220, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 15 })
				Kit.button(row, "Aceptar", "green", { Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, -206, 0, 10), TextSize = 13,
					Props = { Name = "Accept" } }, function()
					Trade.removeRequest(request.From)
					ctx.UI.request("RespondTrade", request.From, true)
				end)
				Kit.button(row, "Rechazar", "ghost", { Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, -104, 0, 10), TextSize = 13,
					Props = { Name = "Decline" } }, function()
					Trade.removeRequest(request.From)
					ctx.UI.request("RespondTrade", request.From, false)
					ctx.UI.refresh("Trading")
				end)
			end
		end
		if count == 0 then
			Kit.label(incoming, "No tienes invitaciones pendientes.", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13, Color = C.TextDim, Font = F.Body })
		end

		Kit.label(body, "JUGADORES EN EL SERVIDOR", { Size = UDim2.new(0.5, -8, 0, 22), Position = UDim2.new(0.5, 8, 0, 0), TextSize = 12,
			Font = F.Title, Color = C.Cyan })
		local players = Kit.scroll(body, { Size = UDim2.new(0.5, -8, 1, -30), Position = UDim2.new(0.5, 8, 0, 28), Padding = 6 })
		local others = 0
		for index, other in ipairs(Players:GetPlayers()) do
			if other ~= Players.LocalPlayer then
				others = others + 1
				local row = Kit.box(players, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 56), LayoutOrder = index, Name = "Player_" .. other.UserId }, 10)
				Kit.label(row, "🧑‍🚀 " .. other.DisplayName, { Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 15 })
				Kit.button(row, "Invitar", "primary", { Size = UDim2.fromOffset(120, 36), Position = UDim2.new(1, -130, 0, 10), TextSize = 13,
					Props = { Name = "Invite" } }, function(button)
					local result = ctx.UI.request("RequestTrade", other.UserId)
					if result.Ok then
						ctx.UI.toast("Invitación enviada a " .. other.DisplayName, "info")
						button.Text = "Enviada ✔"
						Kit.setEnabled(button, false)
					end
				end)
			end
		end
		if others == 0 then
			Kit.label(players, "No hay otros jugadores con quien intercambiar ahora mismo.", { Size = UDim2.new(1, 0, 0, 36), TextSize = 13,
				Color = C.TextDim, Font = F.Body })
		end
	end

	local function offerColumn(title, side, x, removable)
		local box = Kit.box(body, C.Row, 0.15, { Size = UDim2.new(0.5, -6, 0, 250), Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0) }, 12)
		Kit.stroke(box, side.Confirmed and C.Green or (side.Ready and C.Gold or C.Cyan), 2, 0.2)
		Kit.label(box, title, { Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(12, 6), TextSize = 14, Font = F.Title })
		local status = side.Confirmed and "✔ CONFIRMADO" or (side.Ready and "● LISTO" or "Eligiendo...")
		Kit.label(box, status, { Size = UDim2.fromOffset(140, 26), Position = UDim2.new(1, -150, 0, 6), TextSize = 12,
			AlignX = Enum.TextXAlignment.Right, Color = side.Confirmed and C.Green or (side.Ready and C.Gold or C.TextDim) })
		local grid = Kit.scroll(box, { Size = UDim2.new(1, -16, 1, -42), Position = UDim2.fromOffset(8, 36), Grid = UDim2.fromOffset(96, 126), Padding = 6 })
		for index, item in ipairs(side.Offer) do
			local card = Kit.planetCard(grid, { Id = item.Id, V = item.V, E = item.E }, { Size = UDim2.fromOffset(96, 126),
				OnClick = removable and function()
					ctx.UI.request("TradeAction", "remove", item.Uid)
				end or nil })
			card.LayoutOrder = index
			card.Name = "Offer_" .. item.Uid
		end
		if #side.Offer == 0 then
			Kit.label(grid, removable and "Añade planetas desde tu inventario (abajo)." or "Aún no ofrece nada.", { Size = UDim2.new(1, 0, 0, 30),
				TextSize = 12, Color = C.TextDim, Font = F.Body })
		end
	end

	local function tradeView(trade)
		offerColumn("TU OFERTA", trade.You, 0, true)
		offerColumn("OFERTA DE " .. string.upper(trade.Them.Name), trade.Them, 0.5, false)
		Kit.label(body, "TU INVENTARIO (toca para ofrecer; máx. " .. Defs.Config.Trade.MaxItemsPerSide .. ")", { Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 256), TextSize = 11, Font = F.Title, Color = C.Cyan })
		local strip = Kit.scroll(body, { Size = UDim2.new(1, 0, 0, 136), Position = UDim2.fromOffset(0, 278), Horizontal = true, Padding = 6 })
		local offered = {}
		for _, item in ipairs(trade.You.Offer) do
			offered[item.Uid] = true
		end
		local list = {}
		for uid, inst in pairs(State.Data.Planets) do
			if not offered[uid] and not inst.L and not Progression.findPlaced(State.Data, uid) then
				table.insert(list, { Uid = uid, Inst = inst })
			end
		end
		table.sort(list, function(a, b)
			local ra = Defs.Rarities.ById[Defs.Planets.ById[a.Inst.Id].Rarity].Order
			local rb = Defs.Rarities.ById[Defs.Planets.ById[b.Inst.Id].Rarity].Order
			if ra ~= rb then return ra > rb end
			return a.Uid < b.Uid
		end)
		for index, item in ipairs(list) do
			if index > 60 then break end
			local card = Kit.planetCard(strip, { Id = item.Inst.Id, V = item.Inst.V, E = item.Inst.E }, { Size = UDim2.fromOffset(96, 126),
				OnClick = function()
					ctx.UI.request("TradeAction", "add", item.Uid)
				end })
			card.LayoutOrder = index
			card.Name = "Mine_" .. item.Uid
		end

		reviewLabel = Kit.label(body, "", { Size = UDim2.new(1, -520, 0, 44), Position = UDim2.new(0, 0, 1, -46), TextSize = 13, Wrap = true,
			Color = C.TextDim, Font = F.Body })
		Kit.button(body, "Cancelar", "danger", { Size = UDim2.fromOffset(140, 44), Position = UDim2.new(1, -500, 1, -46), TextSize = 14,
			Props = { Name = "Cancel" } }, function()
			ctx.UI.request("TradeAction", "cancel")
		end)
		Kit.button(body, trade.You.Ready and "Cambiar oferta" or "Listo", trade.You.Ready and "ghost" or "cyan", { Size = UDim2.fromOffset(160, 44),
			Position = UDim2.new(1, -350, 1, -46), TextSize = 14, Props = { Name = "Ready" } }, function()
			ctx.UI.request("TradeAction", trade.You.Ready and "unready" or "ready")
		end)
		confirmButton = Kit.button(body, "CONFIRMAR", "green", { Size = UDim2.fromOffset(180, 44), Position = UDim2.new(1, -180, 1, -46), TextSize = 15,
			Font = F.Black, Props = { Name = "Confirm" } }, function()
			ctx.UI.request("ConfirmTrade")
		end)
		Kit.setEnabled(confirmButton, false)
	end

	local function refresh()
		Kit.clear(body)
		confirmButton = nil
		reviewLabel = nil
		if Trade.Current then tradeView(Trade.Current) else lobby() end
	end

	RunService.Heartbeat:Connect(function()
		local trade = Trade.Current
		if not frame.Visible or not trade or not confirmButton or not reviewLabel then return end
		if trade.Stage == "review" then
			local remaining = (trade.ReviewEndsAt or 0) - State.serverTime()
			if trade.You.Confirmed then
				reviewLabel.Text = "Has confirmado. Esperando a " .. trade.Them.Name .. "..."
				Kit.setEnabled(confirmButton, false)
			elseif remaining > 0 then
				reviewLabel.Text = "Revisa bien ambas ofertas. Podrás confirmar en " .. math.ceil(remaining) .. " s."
				Kit.setEnabled(confirmButton, false)
			else
				reviewLabel.Text = "Confirmación final: el intercambio se completa cuando ambos confirméis."
				Kit.setEnabled(confirmButton, true)
			end
		else
			reviewLabel.Text = "Cuando los dos marquéis Listo empezará la revisión. Cambiar una oferta reinicia las confirmaciones."
			Kit.setEnabled(confirmButton, false)
		end
	end)

	State.on("Planets", function()
		if frame.Visible and Trade.Current then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
