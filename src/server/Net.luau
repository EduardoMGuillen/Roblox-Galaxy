-- Net: registro central de Remotes con validacion de argumentos, limites de frecuencia y respuesta controlada.
-- Toda peticion cliente->servidor pasa por Net.handle: el servidor nunca confia en los datos del cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = {}

local folder = nil
local lastCall = {} -- [player] = { [remoteName] = tiempo }
local burst = {} -- [player] = { windowStart, count }
local profileCheck = nil -- funcion(player) -> boolean (perfil cargado)

local BURST_WINDOW = 1
local BURST_LIMIT = 40

function Net.init(isProfileLoaded)
	profileCheck = isProfileLoaded
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
		burst[player] = nil
	end)
end

local function isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Valida un argumento contra su especificacion. Devuelve true o false, motivo.
local function validate(value, spec)
	local kind = spec[1]
	if value == nil then
		if spec.Optional then return true end
		return false, "falta argumento"
	end
	if kind == "string" then
		if type(value) ~= "string" then return false, "se esperaba texto" end
		if #value == 0 or #value > (spec.Max or 64) then return false, "longitud invalida" end
	elseif kind == "integer" then
		if not isFinite(value) or math.floor(value) ~= value then return false, "se esperaba entero" end
		if value < (spec.Min or 0) or value > (spec.Max or 1e9) then return false, "fuera de rango" end
	elseif kind == "number" then
		if not isFinite(value) then return false, "se esperaba numero" end
		if value < (spec.Min or -1e15) or value > (spec.Max or 1e15) then return false, "fuera de rango" end
	elseif kind == "boolean" then
		if type(value) ~= "boolean" then return false, "se esperaba booleano" end
	elseif kind == "stringList" then
		if type(value) ~= "table" then return false, "se esperaba lista" end
		local n = 0
		for k, v in pairs(value) do
			n = n + 1
			if type(k) ~= "number" or type(v) ~= "string" or #v == 0 or #v > (spec.MaxLength or 64) then
				return false, "lista invalida"
			end
			if n > (spec.Max or 100) then return false, "lista demasiado larga" end
		end
		if n ~= #value then return false, "lista invalida" end
	else
		return false, "especificacion desconocida"
	end
	return true
end
Net.validate = validate

local function allowed(player, name, cooldown)
	local now = os.clock()
	local b = burst[player]
	if not b or now - b.Start > BURST_WINDOW then
		b = { Start = now, Count = 0 }
		burst[player] = b
	end
	b.Count = b.Count + 1
	if b.Count > BURST_LIMIT then return false end
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[name]
	if last and now - last < cooldown then return false end
	calls[name] = now
	return true
end

-- Registra una peticion. opts = { Args = { spec... }, Cooldown = segundos, NoProfile = true si no requiere perfil }
-- handler(player, ...) -> ok(boolean), dataOrMessage
function Net.handle(name, opts, handler)
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	local argSpecs = opts.Args or {}
	local cooldown = opts.Cooldown or 0.15
	remote.OnServerInvoke = function(player, ...)
		if not allowed(player, name, cooldown) then
			return { Ok = false, Error = "Demasiado rápido, espera un momento.", Code = "rate" }
		end
		if not opts.NoProfile and not profileCheck(player) then
			return { Ok = false, Error = "Tus datos aún se están cargando.", Code = "loading" }
		end
		local args = table.pack(...)
		if args.n > #argSpecs then
			return { Ok = false, Error = "Petición inválida.", Code = "args" }
		end
		for i, spec in ipairs(argSpecs) do
			local ok = validate(args[i], spec)
			if not ok then
				return { Ok = false, Error = "Petición inválida.", Code = "args" }
			end
		end
		local success, ok, data = pcall(handler, player, table.unpack(args, 1, #argSpecs))
		if not success then
			warn("[Net] error en " .. name .. ": " .. tostring(ok))
			return { Ok = false, Error = "Error interno. Inténtalo de nuevo.", Code = "internal" }
		end
		if ok then
			return { Ok = true, Data = data }
		end
		return { Ok = false, Error = data or "No se pudo completar la acción." }
	end
	return remote
end

local events = {}
function Net.event(name)
	local e = events[name]
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		events[name] = e
	end
	return e
end

function Net.fire(name, player, ...)
	if player.Parent == Players then
		Net.event(name):FireClient(player, ...)
	end
end

function Net.fireAll(name, ...)
	Net.event(name):FireAllClients(...)
end

return Net
