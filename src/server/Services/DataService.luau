-- DataService: carga/guardado de perfiles con candado de sesion, reintentos con backoff, versionado y
-- autosave. Si la carga falla NUNCA se inicia con datos por defecto sobre datos validos: el jugador
-- es expulsado con un mensaje (o, en Studio sin acceso a API, juega en modo "solo sesion").
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Defs)
local Profile = require(Shared.Profile)
local Config = Defs.Config

local DataService = {}

local store = nil
local storeError = nil
local memory = {} -- [userId] = perfil (modo solo sesion en Studio)
local records = {} -- [player] = { Profile, SessionOnly, Saving, Released, LastSave }
local savedCallbacks = {}

DataService.SessionOnlyMode = false

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		storeError = tostring(result)
		warn("[DataService] DataStore no disponible: " .. storeError)
	end
end

local function key(userId)
	return "u_" .. tostring(userId)
end

local function retry(times, fn)
	local lastErr = nil
	for attempt = 1, times do
		local ok, a, b = pcall(fn)
		if ok then return true, a, b end
		lastErr = a
		if attempt < times then
			task.wait(math.min(8, 0.75 * 2 ^ (attempt - 1)))
		end
	end
	return false, lastErr
end

-- Carga el perfil. Devuelve perfil, info  |  nil, motivo
function DataService.load(player)
	local userId = player.UserId
	local now = os.time()
	if store == nil then
		if RunService:IsStudio() then
			DataService.SessionOnlyMode = true
			local data = Profile.reconcile(memory[userId], now)
			records[player] = { Profile = data, SessionOnly = true }
			return data, { SessionOnly = true, IsNew = memory[userId] == nil }
		end
		return nil, "El servicio de datos no está disponible."
	end

	local locked = false
	local loaded = nil
	local isNew = false
	local attempts = RunService:IsStudio() and 2 or Config.Data.LoadRetries
	local ok, err = retry(attempts, function()
		locked = false
		store:UpdateAsync(key(userId), function(old)
			if old ~= nil and type(old) ~= "table" then
				error("formato de datos inesperado")
			end
			if old and old.Lock and old.Lock.JobId ~= game.JobId and now - (old.Lock.Time or 0) < Config.Data.LockTimeout then
				locked = true
				return nil
			end
			local record = old or {}
			isNew = record.Data == nil
			record.Lock = { JobId = game.JobId, Time = os.time() }
			loaded = record.Data
			return record
		end)
		if locked then
			error("perfil bloqueado por otra sesion")
		end
	end)

	if not ok then
		if RunService:IsStudio() and not locked then
			-- Studio sin "Enable Studio Access to API Services": se juega sin guardar
			warn("[DataService] No se pudo cargar (" .. tostring(err) .. "). Modo solo sesion: NO se guardara el progreso.")
			DataService.SessionOnlyMode = true
			local data = Profile.reconcile(memory[userId], now)
			records[player] = { Profile = data, SessionOnly = true }
			return data, { SessionOnly = true, IsNew = memory[userId] == nil }
		end
		if locked then
			return nil, "Tus datos siguen abiertos en otro servidor. Espera un minuto y vuelve a entrar."
		end
		return nil, "No se pudieron cargar tus datos. Para protegerlos no se inició una partida nueva. Vuelve a intentarlo."
	end

	if player.Parent ~= Players then
		-- se fue mientras cargaba: liberar el candado
		DataService._release(userId)
		return nil, "desconectado"
	end
	local data = Profile.reconcile(loaded, now)
	records[player] = { Profile = data, SessionOnly = false, LastSave = os.clock() }
	return data, { SessionOnly = false, IsNew = isNew }
end

function DataService._release(userId)
	if store == nil then return end
	pcall(function()
		store:UpdateAsync(key(userId), function(old)
			if old and old.Lock and old.Lock.JobId == game.JobId then
				old.Lock = nil
				return old
			end
			return nil
		end)
	end)
end

function DataService.get(player)
	local rec = records[player]
	return rec and rec.Profile or nil
end

function DataService.isSessionOnly(player)
	local rec = records[player]
	return rec ~= nil and rec.SessionOnly == true
end

-- Olvida el registro en memoria (tras el guardado final, haya ido bien o no)
function DataService.forget(player)
	records[player] = nil
end

function DataService.onSaved(fn)
	table.insert(savedCallbacks, fn)
end

-- Guarda el perfil. release = true libera el candado (al salir). Devuelve true si se guardo.
function DataService.save(player, release)
	local rec = records[player]
	if not rec or rec.Lost then return false end
	local data = rec.Profile
	data.LastSave = os.time()
	if rec.SessionOnly then
		memory[player.UserId] = Profile.deepCopy(data)
		if release then records[player] = nil end
		return true
	end
	if rec.Saving then
		-- ya hay un guardado en curso: esperar a que termine para no pisarlo
		local waited = 0
		while rec.Saving and waited < 15 do
			waited = waited + task.wait(0.1)
		end
	end
	rec.Saving = true
	local snapshot = Profile.deepCopy(data)
	local stolen = false
	local ok, err = retry(Config.Data.SaveRetries, function()
		stolen = false
		store:UpdateAsync(key(player.UserId), function(old)
			if old and old.Lock and old.Lock.JobId ~= game.JobId then
				stolen = true
				return nil
			end
			local record = old or {}
			record.Data = snapshot
			record.Saved = os.time()
			if release then
				record.Lock = nil
			else
				record.Lock = { JobId = game.JobId, Time = os.time() }
			end
			return record
		end)
	end)
	rec.Saving = false
	if stolen then
		rec.Lost = true
		warn("[DataService] el candado de " .. player.Name .. " pertenece a otro servidor; se detiene el guardado")
		if player.Parent == Players then
			player:Kick("Tu sesión se abrió en otro servidor. Tus datos están a salvo.")
		end
		return false
	end
	if not ok then
		warn("[DataService] fallo al guardar " .. player.Name .. ": " .. tostring(err))
		return false
	end
	rec.LastSave = os.clock()
	for _, fn in ipairs(savedCallbacks) do
		task.spawn(fn, player, snapshot)
	end
	if release then records[player] = nil end
	return true
end

function DataService.Start()
	-- autosave escalonado
	task.spawn(function()
		while true do
			task.wait(10)
			for player, rec in pairs(records) do
				if not rec.SessionOnly and not rec.Saving and not rec.Lost and player.Parent == Players
					and os.clock() - (rec.LastSave or 0) >= Config.Data.AutosaveInterval then
					task.spawn(DataService.save, player, false)
				end
			end
		end
	end)
end

-- Guardado final de todos los jugadores (BindToClose)
function DataService.saveAll()
	local pending = 0
	for player in pairs(records) do
		pending = pending + 1
		task.spawn(function()
			DataService.save(player, true)
			pending = pending - 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		waited = waited + task.wait(0.2)
	end
end

return DataService
