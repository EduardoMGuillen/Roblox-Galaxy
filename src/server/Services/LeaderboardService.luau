-- LeaderboardService: cinco clasificaciones persistentes (OrderedDataStore) refrescadas con una
-- frecuencia controlada. Nunca consulta el OrderedDataStore por frame; si no hay DataStore
-- (Studio), usa los valores en vivo de los jugadores conectados.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config

local LeaderboardService = {}
local S = nil

LeaderboardService.Categories = {
	{ Id = "Rate", Name = "Producción (Energy/s)" },
	{ Id = "Value", Name = "Valor del universo" },
	{ Id = "Ascensions", Name = "Ascensiones" },
	{ Id = "Discoveries", Name = "Planetas descubiertos" },
	{ Id = "Rares", Name = "Planetas raros" },
}

local stores = {}
local boards = {}
local nameCache = {}
local MAX_STORED = 9e15

local function valuesFor(profile)
	local value, rares = 0, 0
	for _, inst in pairs(profile.Planets) do
		local def = Defs.Planets.ById[inst.Id]
		if def then
			local v = def.CollectionValue * Defs.Variants.get(inst.V).Multiplier
			if inst.E then v = v * Config.Evolution.ProductionMultiplier end
			value = value + v
			if Defs.Rarities.atLeast(def.Rarity, "epic") then rares = rares + 1 end
		end
	end
	local discoveries = Progression.discoveryTotals(profile)
	return {
		Rate = Progression.production(profile, 1).Total,
		Value = value,
		Ascensions = profile.Ascensions,
		Discoveries = discoveries,
		Rares = rares,
	}
end

local function nameOf(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then return player.DisplayName end
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Jugador " .. tostring(userId))
	return nameCache[userId]
end

local function refresh()
	local live = {}
	for player, session in pairs(S.PlayerService.all()) do
		live[player.UserId] = valuesFor(session.Profile)
	end
	for _, category in ipairs(LeaderboardService.Categories) do
		local entries = {}
		local store = stores[category.Id]
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, Config.Leaderboard.Size):GetCurrentPage()
			end)
			if ok and page then
				for _, item in ipairs(page) do
					local userId = tonumber(string.match(item.key, "^u_(%d+)$"))
					if userId then
						entries[userId] = item.value
					end
				end
			end
		end
		-- los jugadores conectados siempre muestran su valor en vivo
		for userId, values in pairs(live) do
			entries[userId] = values[category.Id]
		end
		local list = {}
		for userId, value in pairs(entries) do
			if value > 0 then
				table.insert(list, { UserId = userId, Value = value })
			end
		end
		table.sort(list, function(a, b)
			if a.Value == b.Value then return a.UserId < b.UserId end
			return a.Value > b.Value
		end)
		local top = {}
		for i = 1, math.min(Config.Leaderboard.Size, #list) do
			top[i] = { UserId = list[i].UserId, Name = nameOf(list[i].UserId), Value = list[i].Value }
		end
		boards[category.Id] = top
	end
	Net.fireAll("LeaderboardUpdate", boards)
end
LeaderboardService.refresh = refresh

function LeaderboardService.Init(services)
	S = services
	Net.event("LeaderboardUpdate")
	for _, category in ipairs(LeaderboardService.Categories) do
		boards[category.Id] = {}
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.Leaderboard.StorePrefix .. category.Id)
		end)
		if ok then stores[category.Id] = store end
	end
	S.DataService.onSaved(function(player, snapshot)
		local values = valuesFor(snapshot)
		for _, category in ipairs(LeaderboardService.Categories) do
			local store = stores[category.Id]
			if store then
				pcall(function()
					store:SetAsync("u_" .. tostring(player.UserId), math.floor(math.min(values[category.Id], MAX_STORED)))
				end)
			end
		end
	end)
	Net.handle("GetLeaderboard", { NoProfile = true, Cooldown = 1 }, function()
		return true, boards
	end)
end

function LeaderboardService.Start()
	task.spawn(function()
		task.wait(5)
		while true do
			local ok, err = pcall(refresh)
			if not ok then warn("[Leaderboard] " .. tostring(err)) end
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
