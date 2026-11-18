-- UniverseService: asigna una parcela (universo personal) a cada jugador, gestiona los viajes
-- Hub <-> universo y las visitas de solo lectura, y publica la vista publica de cada universo.
-- Solo se construye la estructura fija de la parcela; los cinco sistemas se activan dentro de ella.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Progression = require(Shared.Progression)
local Layout = require(Shared.UniverseLayout)
local Net = require(script.Parent.Parent.Net)
local UniverseBuilder = require(script.Parent.Parent.World.UniverseBuilder)
local Config = Defs.Config

local UniverseService = {}
local S = nil

local plots = {} -- [indice] = player
local plotOf = {} -- [player] = indice
local models = {} -- [player] = Model
local pending = {} -- publicaciones pendientes en este frame
local visited = {} -- [player] = { [userId] = true }

local function locationOf(userId)
	return "u:" .. tostring(userId)
end

local function ownerFromLocation(location)
	local userId = tonumber(string.match(location, "^u:(%d+)$"))
	return userId and Players:GetPlayerByUserId(userId) or nil
end

-- Vista publica (solo lectura) del universo de un jugador
function UniverseService.view(player)
	local session = S.PlayerService.get(player)
	local index = plotOf[player]
	if not session or not index then return nil end
	local profile = session.Profile
	local systemId = profile.ActiveSystem
	local planets = {}
	for slotKey, uid in pairs(profile.Placed[systemId] or {}) do
		local inst = profile.Planets[uid]
		if inst then
			planets[slotKey] = { Id = inst.Id, V = inst.V, E = inst.E, Uid = uid }
		end
	end
	local systems = {}
	for _, sysId in ipairs(Defs.Galaxy.Order) do
		if profile.Systems[sysId] then table.insert(systems, sysId) end
	end
	local found, total = Progression.discoveryTotals(profile)
	return {
		Owner = player.UserId,
		Name = player.DisplayName,
		Plot = index,
		Center = Layout.plotCenter(index),
		System = systemId,
		Slots = profile.Slots[systemId] or 0,
		Planets = planets,
		Cosmetics = { OrbitColor = profile.Cosmetics.Equipped.OrbitColor, StarAura = profile.Cosmetics.Equipped.StarAura },
		Stats = { Rate = S.ProductionService.rate(player), Ascensions = profile.Ascensions, Discovered = found,
			DiscoveredTotal = total, Systems = systems },
	}
end

-- Publica la vista a todos los clientes (agrupando varias llamadas del mismo frame)
function UniverseService.publish(player)
	if pending[player] then return end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		local view = UniverseService.view(player)
		if view then Net.fireAll("UniverseUpdate", view) end
	end)
end

function UniverseService.spawnCFrameFor(location)
	local owner = ownerFromLocation(location)
	local index = owner and plotOf[owner]
	if not index then return nil end
	return Layout.spawnCFrame(Layout.plotCenter(index), os.clock() * 7)
end

local function setLocation(player, location)
	local session = S.PlayerService.get(player)
	session.Location = location
	session.Derived._Session.Location = location
	S.PlayerService.sync(player, "_Session", "Location")
end

local function goHub(player)
	setLocation(player, "hub")
	local angle = (os.clock() * 3) % (math.pi * 2)
	local pos = Config.World.HubSpawn + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
	S.PlayerService.placeCharacter(player, CFrame.new(pos, Vector3.new(0, pos.Y, 0)))
end

local function goUniverse(player, owner)
	local location = locationOf(owner.UserId)
	local cf = UniverseService.spawnCFrameFor(location)
	if not cf then return false end
	setLocation(player, location)
	S.PlayerService.placeCharacter(player, cf)
	return true
end

local function teleport(player, destination)
	if destination == "hub" then
		goHub(player)
		return true, { Location = "hub" }
	elseif destination == "universe" then
		if not goUniverse(player, player) then return false, "Tu universo aún no está listo." end
		S.PlayerService.tutorialEvent(player, "go_universe")
		return true, { Location = locationOf(player.UserId) }
	end
	return false, "Destino desconocido."
end

local function visit(player, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not S.PlayerService.isLoaded(target) or not plotOf[target] then
		return false, "Ese universo no está disponible."
	end
	if target == player then return teleport(player, "universe") end
	if not goUniverse(player, target) then return false, "Ese universo no está disponible." end
	local seen = visited[player]
	if not seen[targetUserId] then
		seen[targetUserId] = true
		local profile = S.PlayerService.profile(player)
		profile.Stats.Visits = profile.Stats.Visits + 1
		S.MissionService.progress(player, "VisitUniverse", 1)
		S.PlayerService.notify(target, "info", player.DisplayName .. " está visitando tu universo.")
	end
	return true, { Location = locationOf(targetUserId) }
end

function UniverseService.Init(services)
	S = services
	Net.event("UniverseUpdate")
	Net.event("UniverseRemoved")

	S.PlayerService.onLoaded(function(player)
		local index = nil
		for i = 1, Config.World.PlotCount do
			if not plots[i] then
				index = i
				break
			end
		end
		if not index then
			-- no deberia ocurrir (PlotCount >= jugadores maximos): se comparte la ultima parcela
			index = Config.World.PlotCount
		end
		plots[index] = player
		plotOf[player] = index
		visited[player] = {}
		models[player] = UniverseBuilder.build(index, Layout.plotCenter(index), player.DisplayName)
		UniverseService.publish(player)
	end)

	S.PlayerService.onLeaving(function(player)
		local index = plotOf[player]
		local location = locationOf(player.UserId)
		for other, session in pairs(S.PlayerService.all()) do
			if other ~= player and session.Location == location then
				goHub(other)
				S.PlayerService.notify(other, "info", player.DisplayName .. " se fue: has vuelto al Cosmic Hub.")
			end
		end
		if index and plots[index] == player then plots[index] = nil end
		plotOf[player] = nil
		visited[player] = nil
		pending[player] = nil
		if models[player] then
			models[player]:Destroy()
			models[player] = nil
		end
		Net.fireAll("UniverseRemoved", player.UserId)
	end)

	Net.handle("Teleport", { Args = { { "string", Max = 16 } }, Cooldown = 0.8 }, teleport)
	Net.handle("VisitUniverse", { Args = { { "integer", Min = 1, Max = 1e15 } }, Cooldown = 0.8 }, visit)
	Net.handle("GetUniverses", { NoProfile = true, Cooldown = 0.5 }, function()
		local list = {}
		for player in pairs(plotOf) do
			local view = UniverseService.view(player)
			if view then table.insert(list, view) end
		end
		return true, list
	end)
end

function UniverseService.Start()
	-- refresco periodico de estadisticas publicas (produccion mostrada a visitantes)
	task.spawn(function()
		while true do
			task.wait(15)
			for player in pairs(plotOf) do
				UniverseService.publish(player)
			end
		end
	end)
end

return UniverseService
