-- TradeController: recibe del servidor el estado del intercambio (invitaciones, ofertas, cierre) y
-- abre/actualiza la TradingUI. El cliente nunca transfiere nada: solo muestra y solicita.
local TradeController = {}

local Trade = { Current = nil, Requests = {} }

function Trade.removeRequest(fromUserId)
	for i = #Trade.Requests, 1, -1 do
		if Trade.Requests[i].From == fromUserId then table.remove(Trade.Requests, i) end
	end
end

function TradeController.init(ctx)
	ctx.Trade = Trade
	ctx.State.remotes():WaitForChild("TradeUpdate").OnClientEvent:Connect(function(update)
		if update.Stage == "request" then
			Trade.removeRequest(update.From)
			table.insert(Trade.Requests, { From = update.From, Name = update.Name, Expires = os.clock() + (update.Timeout or 30) })
			ctx.UI.toast("🤝 " .. update.Name .. " quiere intercambiar contigo", "info")
			if ctx.Audio then ctx.Audio.play("notify") end
			if not ctx.UI.isOpen() or ctx.UI.isOpen("Trading") then
				ctx.UI.open("Trading")
			end
		elseif update.Stage == "closed" then
			Trade.Current = nil
			ctx.UI.toast(update.Reason or "Intercambio cerrado.", update.Completed and "reward" or "info")
			if update.Completed and ctx.Audio then ctx.Audio.play("success") end
			ctx.UI.refresh("Trading")
		else
			local isNew = Trade.Current == nil
			Trade.Current = update
			if isNew then
				ctx.UI.open("Trading")
			else
				ctx.UI.refresh("Trading")
			end
		end
	end)
end

return TradeController
