-- PlayerService: ciclo de vida del jugador, sesion en memoria, replicacion de estado al cliente,
-- aparicion del personaje, tutorial y ajustes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Format = require(Shared.Util.Format)
local Net = require(script.Parent.Parent.Net)
local Config = Defs.Config

local PlayerService = {}
local S = nil

local sessions = {}
local loadedCallbacks = {}
local leavingCallbacks = {}

function PlayerService.get(player)
	return sessions[player]
end

function PlayerService.profile(player)
	local s = sessions[player]
	return s and s.Profile or nil
end

function PlayerService.isLoaded(player)
	return sessions[player] ~= nil
end

function PlayerService.all()
	return sessions
end

function PlayerService.onLoaded(fn)
	table.insert(loadedCallbacks, fn)
end

function PlayerService.onLeaving(fn)
	table.insert(leavingCallbacks, fn)
end

---------------------------------------------------------------- replicacion de estado
local function resolve(session, path)
	local node = session.Profile
	if string.sub(path[1], 1, 1) == "_" then node = session.Derived end
	for _, k in ipairs(path) do
		if type(node) ~= "table" then return nil end
		node = node[k]
	end
	return node
end

local function flush(player)
	local session = sessions[player]
	if not session then return end
	session.FlushScheduled = false
	local patches = {}
	for _, path in pairs(session.Pending) do
		table.insert(patches, { p = path, v = resolve(session, path) })
	end
	session.Pending = {}
	if #patches > 0 then
		Net.fire("StateUpdate", player, patches)
	end
end

-- Marca una ruta del perfil (o de Derived si empieza por "_") para enviarla al cliente en este frame.
function PlayerService.sync(player, ...)
	local session = sessions[player]
	if not session then return end
	local path = { ... }
	session.Pending[table.concat(path, "/")] = path
	if not session.FlushScheduled then
		session.FlushScheduled = true
		task.defer(flush, player)
	end
end

function PlayerService.setDerived(player, key, value)
	local session = sessions[player]
	if not session then return end
	session.Derived[key] = value
	PlayerService.sync(player, key)
end

function PlayerService.notify(player, kind, text, extra)
	Net.fire("Notify", player, { Kind = kind, Text = text, Extra = extra })
end

---------------------------------------------------------------- personaje
local function spawnCFrame(player)
	local session = sessions[player]
	if session and session.Location ~= "hub" and S.UniverseService then
		local cf = S.UniverseService.spawnCFrameFor(session.Location)
		if cf then return cf end
	end
	local angle = (player.UserId % 12) / 12 * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
	local pos = Config.World.HubSpawn + offset
	return CFrame.new(pos, Vector3.new(0, pos.Y, 0))
end

function PlayerService.placeCharacter(player, cf)
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cf)
	return true
end

local function onCharacterAdded(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid then return end
	task.wait()
	PlayerService.placeCharacter(player, spawnCFrame(player))
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Parent == Players and sessions[player] then
			player:LoadCharacter()
		end
	end)
end

---------------------------------------------------------------- tutorial
function PlayerService.tutorialEvent(player, stepName)
	local profile = PlayerService.profile(player)
	if not profile then return end
	local steps = Config.TutorialSteps
	local index = table.find(steps, stepName)
	-- completar un paso posterior tambien da por hechos los anteriores (el jugador se adelanto)
	if not index or profile.Tutorial > index then return end
	local wasDone = steps[profile.Tutorial] == "done"
	profile.Tutorial = index + 1
	PlayerService.sync(player, "Tutorial")
	if not wasDone and steps[profile.Tutorial] == "done" then
		S.EconomyService.add(player, "Stardust", 25, "tutorial")
		PlayerService.notify(player, "reward", "¡Tutorial completado! +25 Stardust")
	end
end

---------------------------------------------------------------- leaderstats
local function createLeaderstats(player, profile)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local energy = Instance.new("StringValue")
	energy.Name = "Energy"
	energy.Value = Format.number(profile.Energy)
	energy.Parent = folder
	local asc = Instance.new("IntValue")
	asc.Name = "Ascensiones"
	asc.Value = profile.Ascensions
	asc.Parent = folder
	folder.Parent = player
end

function PlayerService.updateLeaderstats(player)
	local profile = PlayerService.profile(player)
	local folder = player:FindFirstChild("leaderstats")
	if not profile or not folder then return end
	local energy = folder:FindFirstChild("Energy")
	if energy then energy.Value = Format.number(profile.Energy) end
	local asc = folder:FindFirstChild("Ascensiones")
	if asc then asc.Value = profile.Ascensions end
end

---------------------------------------------------------------- ciclo de vida
local function onPlayerAdded(player)
	local profile, info = S.DataService.load(player)
	if not profile then
		if info ~= "desconectado" and player.Parent == Players then
			player:Kick(info)
		end
		return
	end
	local session = {
		Player = player,
		Profile = profile,
		Derived = { _Session = { SessionOnly = info.SessionOnly, Location = "hub", IsNew = info.IsNew } },
		Busy = {},
		Pending = {},
		Location = "hub",
		JoinClock = os.clock(),
		LastCapsule = 0,
	}
	sessions[player] = session
	for _, fn in ipairs(loadedCallbacks) do
		local ok, err = pcall(fn, player, session, info)
		if not ok then warn("[PlayerService] error en onLoaded: " .. tostring(err)) end
	end
	createLeaderstats(player, profile)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Parent == Players then
		player:LoadCharacter()
	end
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	if not session then return end
	for _, fn in ipairs(leavingCallbacks) do
		local ok, err = pcall(fn, player, session)
		if not ok then warn("[PlayerService] error en onLeaving: " .. tostring(err)) end
	end
	session.Profile.Stats.PlayTime = session.Profile.Stats.PlayTime + (os.clock() - session.JoinClock)
	sessions[player] = nil
	S.DataService.save(player, true)
	S.DataService.forget(player)
end

function PlayerService.Init(services)
	S = services
	Net.event("StateUpdate")
	Net.event("Notify")

	Net.handle("GetState", { NoProfile = true, Cooldown = 0.2 }, function(player)
		local session = sessions[player]
		if not session then return false, "loading" end
		return true, { Profile = session.Profile, Derived = session.Derived, ServerTime = os.time() }
	end)

	Net.handle("TutorialAck", { Args = { { "string", Max = 32 } }, Cooldown = 0.3 }, function(player, stepName)
		if stepName ~= "welcome" and stepName ~= "watch_production" then return false, "Paso inválido." end
		PlayerService.tutorialEvent(player, stepName)
		return true
	end)

	Net.handle("SkipTutorial", { Cooldown = 1 }, function(player)
		local profile = PlayerService.profile(player)
		if profile.Tutorial < #Config.TutorialSteps then
			profile.Tutorial = #Config.TutorialSteps
			PlayerService.sync(player, "Tutorial")
		end
		return true
	end)

	Net.handle("UpdateSetting", { Args = { { "string", Max = 32 }, { "boolean" } }, Cooldown = 0.1 }, function(player, key, value)
		if Config.DefaultSettings[key] == nil then return false, "Ajuste desconocido." end
		local profile = PlayerService.profile(player)
		profile.Settings[key] = value
		PlayerService.sync(player, "Settings", key)
		return true
	end)
end

function PlayerService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
