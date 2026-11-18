-- ClientState: copia local (solo lectura) del estado autorizado por el servidor.
-- Recibe el perfil completo al entrar y parches incrementales despues. La interfaz se suscribe a
-- claves de primer nivel ("Energy", "Planets", "_Production"...). El cliente nunca decide resultados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local State = {}

State.Data = {}
State.Universes = {} -- [userId] = vista publica del universo
State.Leaderboards = {}
State.Ready = false

local remotes = nil
local listeners = {} -- [clave] = { fn, ... }
local anyListeners = {}
local universeListeners = {}
local leaderboardListeners = {}
local energyClock = 0

function State.remotes()
	return remotes
end

-- Llama a una peticion del servidor. Siempre devuelve una tabla { Ok, Data, Error }.
function State.call(name, ...)
	local remote = remotes and remotes:FindFirstChild(name)
	if not remote then
		return { Ok = false, Error = "Acción no disponible." }
	end
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { Ok = false, Error = "Sin respuesta del servidor." }
	end
	return result
end

function State.on(key, fn)
	if not listeners[key] then listeners[key] = {} end
	table.insert(listeners[key], fn)
end

function State.onAny(fn)
	table.insert(anyListeners, fn)
end

function State.onUniverse(fn)
	table.insert(universeListeners, fn)
end

function State.onLeaderboard(fn)
	table.insert(leaderboardListeners, fn)
end

local function fire(list, ...)
	for _, fn in ipairs(list) do
		task.spawn(fn, ...)
	end
end

local function applyPatches(patches)
	local changed = {}
	for _, patch in ipairs(patches) do
		local path = patch.p
		local node = State.Data
		for i = 1, #path - 1 do
			local key = path[i]
			if type(node[key]) ~= "table" then node[key] = {} end
			node = node[key]
		end
		node[path[#path]] = patch.v
		changed[path[1]] = true
		if path[1] == "Energy" then energyClock = os.clock() end
	end
	for key in pairs(changed) do
		if listeners[key] then fire(listeners[key], State.Data[key]) end
	end
	fire(anyListeners, changed)
end

-- Energy mostrada: interpola entre ticks del servidor usando la produccion actual
function State.displayEnergy()
	local data = State.Data
	local energy = data.Energy or 0
	local production = data._Production
	if production and production.Total > 0 then
		energy = energy + production.Total * math.min(1.2, os.clock() - energyClock)
	end
	return energy
end

function State.rate()
	local production = State.Data._Production
	return production and production.Total or 0
end

function State.serverTime()
	return Workspace:GetServerTimeNow()
end

-- Ubicacion actual: "hub" o "u:<userId>"
function State.location()
	local session = State.Data._Session
	return session and session.Location or "hub"
end

-- userId del propietario del universo en el que esta el jugador, o nil si esta en el Hub
function State.locationOwner()
	local id = string.match(State.location(), "^u:(%d+)$")
	return id and tonumber(id) or nil
end

function State.inOwnUniverse()
	return State.locationOwner() == Players.LocalPlayer.UserId
end

function State.init()
	ReplicatedStorage:WaitForChild("ServerReady")
	remotes = ReplicatedStorage:WaitForChild("Remotes")

	remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(patches)
		if State.Ready then applyPatches(patches) end
	end)
	remotes:WaitForChild("UniverseUpdate").OnClientEvent:Connect(function(view)
		State.Universes[view.Owner] = view
		fire(universeListeners, view.Owner, view)
	end)
	remotes:WaitForChild("UniverseRemoved").OnClientEvent:Connect(function(userId)
		State.Universes[userId] = nil
		fire(universeListeners, userId, nil)
	end)
	remotes:WaitForChild("LeaderboardUpdate").OnClientEvent:Connect(function(boards)
		State.Leaderboards = boards
		fire(leaderboardListeners, boards)
	end)

	-- esperar a que el servidor cargue el perfil
	local result = nil
	while true do
		result = State.call("GetState")
		if result.Ok then break end
		task.wait(0.5)
	end
	for key, value in pairs(result.Data.Profile) do
		State.Data[key] = value
	end
	for key, value in pairs(result.Data.Derived) do
		State.Data[key] = value
	end
	energyClock = os.clock()
	State.Ready = true

	local universes = State.call("GetUniverses")
	if universes.Ok then
		for _, view in ipairs(universes.Data) do
			State.Universes[view.Owner] = view
		end
	end
	local boards = State.call("GetLeaderboard")
	if boards.Ok then State.Leaderboards = boards.Data end
end

return State
