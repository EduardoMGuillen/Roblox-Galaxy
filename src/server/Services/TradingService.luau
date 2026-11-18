-- TradingService: Galactic Trading seguro. Invitacion -> ofertas -> ambos "Listo" -> periodo de
-- revision -> confirmacion final de ambos -> el servidor revalida propiedad/estado y transfiere.
-- Cualquier cambio de oferta reinicia las confirmaciones. Se cancela si un jugador se va.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config

local TradingService = {}
local S = nil

local trades = {} -- [player] = trade
local requests = {} -- [target] = { [fromUserId] = expira (os.clock) }

function TradingService.isTrading(player)
	return trades[player] ~= nil
end

local function sides(trade, player)
	if trade.A.Player == player then return trade.A, trade.B end
	return trade.B, trade.A
end

local function items(side)
	local profile = S.PlayerService.profile(side.Player)
	local out = {}
	for _, uid in ipairs(side.Offer) do
		local inst = profile and profile.Planets[uid]
		if inst then
			table.insert(out, { Uid = uid, Id = inst.Id, V = inst.V, E = inst.E })
		end
	end
	return out
end

local function push(trade)
	for _, side in ipairs({ trade.A, trade.B }) do
		local mine, theirs = sides(trade, side.Player)
		Net.fire("TradeUpdate", side.Player, {
			Stage = trade.Stage,
			ReviewEndsAt = trade.ReviewEndsAt,
			You = { Offer = items(mine), Ready = mine.Ready, Confirmed = mine.Confirmed },
			Them = { UserId = theirs.Player.UserId, Name = theirs.Player.DisplayName, Offer = items(theirs),
				Ready = theirs.Ready, Confirmed = theirs.Confirmed },
		})
	end
end

local function releaseBusy(side)
	local session = S.PlayerService.get(side.Player)
	if session then
		for _, uid in ipairs(side.Offer) do
			session.Busy[uid] = nil
		end
	end
end

local function endTrade(trade, reason, completed)
	releaseBusy(trade.A)
	releaseBusy(trade.B)
	trades[trade.A.Player] = nil
	trades[trade.B.Player] = nil
	for _, side in ipairs({ trade.A, trade.B }) do
		Net.fire("TradeUpdate", side.Player, { Stage = "closed", Reason = reason, Completed = completed == true })
	end
end

local function resetConfirmations(trade)
	trade.Stage = "offer"
	trade.ReviewEndsAt = nil
	trade.A.Ready, trade.B.Ready = false, false
	trade.A.Confirmed, trade.B.Confirmed = false, false
end

local function request(player, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then return false, "Jugador no disponible." end
	if not S.PlayerService.isLoaded(target) then return false, "Ese jugador aún está cargando." end
	if trades[player] then return false, "Ya estás en un intercambio." end
	if trades[target] then return false, "Ese jugador ya está en un intercambio." end
	local list = requests[target]
	if not list then
		list = {}
		requests[target] = list
	end
	list[player.UserId] = os.clock() + Config.Trade.RequestTimeout
	Net.fire("TradeUpdate", target, { Stage = "request", From = player.UserId, Name = player.DisplayName,
		Timeout = Config.Trade.RequestTimeout })
	return true
end

local function respond(player, fromUserId, accept)
	local list = requests[player]
	local expires = list and list[fromUserId]
	if not expires then return false, "Esa invitación ya no existe." end
	list[fromUserId] = nil
	local from = Players:GetPlayerByUserId(fromUserId)
	if not accept then
		if from then S.PlayerService.notify(from, "info", player.DisplayName .. " rechazó tu invitación de intercambio.") end
		return true
	end
	if expires < os.clock() then return false, "La invitación caducó." end
	if not from or not S.PlayerService.isLoaded(from) then return false, "Ese jugador ya no está." end
	if trades[player] or trades[from] then return false, "Uno de los dos ya está en un intercambio." end
	local trade = {
		A = { Player = from, Offer = {}, Ready = false, Confirmed = false },
		B = { Player = player, Offer = {}, Ready = false, Confirmed = false },
		Stage = "offer",
	}
	trades[from] = trade
	trades[player] = trade
	push(trade)
	return true
end

local function validOffer(player, uid)
	local profile = S.PlayerService.profile(player)
	local inst = profile and profile.Planets[uid]
	if not inst then return false, "Ese planeta no es tuyo." end
	if inst.L then return false, "Desbloquea el planeta antes de ofrecerlo." end
	if Progression.findPlaced(profile, uid) then return false, "Retira el planeta de su órbita antes de ofrecerlo." end
	return true
end

local function execute(trade)
	local a, b = trade.A, trade.B
	local profileA = S.PlayerService.profile(a.Player)
	local profileB = S.PlayerService.profile(b.Player)
	if not profileA or not profileB then
		endTrade(trade, "Un jugador se desconectó.")
		return false
	end
	-- revalidar propiedad y estado justo antes de transferir
	for _, side in ipairs({ a, b }) do
		local seen = {}
		for _, uid in ipairs(side.Offer) do
			if seen[uid] or not validOffer(side.Player, uid) then
				endTrade(trade, "La oferta dejó de ser válida.")
				return false
			end
			seen[uid] = true
		end
	end
	local afterA = Progression.inventoryCount(profileA) - #a.Offer + #b.Offer
	local afterB = Progression.inventoryCount(profileB) - #b.Offer + #a.Offer
	if afterA > Progression.inventoryCapacity(profileA) or afterB > Progression.inventoryCapacity(profileB) then
		endTrade(trade, "Uno de los inventarios no tiene espacio.")
		return false
	end
	-- transferencia (sin yields entre la validacion y el final)
	local offerA, offerB = a.Offer, b.Offer
	releaseBusy(a)
	releaseBusy(b)
	a.Offer, b.Offer = {}, {}
	S.InventoryService.transfer(a.Player, b.Player, offerA)
	S.InventoryService.transfer(b.Player, a.Player, offerB)
	for _, side in ipairs({ a, b }) do
		local profile = S.PlayerService.profile(side.Player)
		profile.Stats.Trades = profile.Stats.Trades + 1
		S.MissionService.progress(side.Player, "CompleteTrade", 1)
	end
	endTrade(trade, "Intercambio completado.", true)
	task.spawn(S.DataService.save, a.Player, false)
	task.spawn(S.DataService.save, b.Player, false)
	return true
end

local function action(player, name, uid)
	local trade = trades[player]
	if not trade then return false, "No estás en un intercambio." end
	local mine = sides(trade, player)
	if name == "cancel" then
		endTrade(trade, player.DisplayName .. " canceló el intercambio.")
		return true
	elseif name == "add" then
		if not uid then return false, "Falta el planeta." end
		if #mine.Offer >= Config.Trade.MaxItemsPerSide then return false, "Máximo " .. Config.Trade.MaxItemsPerSide .. " planetas por oferta." end
		for _, offered in ipairs(mine.Offer) do
			if offered == uid then return false, "Ya ofreciste ese planeta." end
		end
		local ok, reason = validOffer(player, uid)
		if not ok then return false, reason end
		table.insert(mine.Offer, uid)
		S.PlayerService.get(player).Busy[uid] = true
		resetConfirmations(trade)
	elseif name == "remove" then
		local index = uid and table.find(mine.Offer, uid)
		if not index then return false, "Ese planeta no está en tu oferta." end
		table.remove(mine.Offer, index)
		S.PlayerService.get(player).Busy[uid] = nil
		resetConfirmations(trade)
	elseif name == "ready" then
		if trade.Stage ~= "offer" then return false, "La oferta ya está en revisión." end
		mine.Ready = true
		if trade.A.Ready and trade.B.Ready then
			trade.Stage = "review"
			trade.ReviewEndsAt = os.time() + Config.Trade.ReviewSeconds
		end
	elseif name == "unready" then
		resetConfirmations(trade)
	else
		return false, "Acción desconocida."
	end
	push(trade)
	return true
end

local function confirm(player)
	local trade = trades[player]
	if not trade then return false, "No estás en un intercambio." end
	if trade.Stage ~= "review" then return false, "Ambos jugadores deben marcar Listo primero." end
	if os.time() < trade.ReviewEndsAt then return false, "Revisa la oferta unos segundos antes de confirmar." end
	local mine = sides(trade, player)
	mine.Confirmed = true
	if trade.A.Confirmed and trade.B.Confirmed then
		execute(trade)
	else
		push(trade)
	end
	return true
end

function TradingService.Init(services)
	S = services
	Net.event("TradeUpdate")
	Net.handle("RequestTrade", { Args = { { "integer", Min = 1, Max = 1e15 } }, Cooldown = 2 }, request)
	Net.handle("RespondTrade", { Args = { { "integer", Min = 1, Max = 1e15 }, { "boolean" } }, Cooldown = 0.3 }, respond)
	Net.handle("TradeAction", { Args = { { "string", Max = 12 }, { "string", Max = 16, Optional = true } }, Cooldown = 0.1 }, action)
	Net.handle("ConfirmTrade", { Cooldown = 0.3 }, confirm)
	S.PlayerService.onLeaving(function(player)
		local trade = trades[player]
		if trade then endTrade(trade, player.DisplayName .. " se desconectó.") end
		requests[player] = nil
	end)
end

function TradingService.Start() end

return TradingService
