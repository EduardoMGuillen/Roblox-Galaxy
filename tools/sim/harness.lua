-- Arnes de pruebas: monta el arbol del proyecto en el simulador y expone utilidades (SIM.*).
local SIM_ROOT = ...
local SIM = assert(loadfile(SIM_ROOT .. "/tools/sim/roblox.lua"))(SIM_ROOT)
SIM = assert(loadfile(SIM_ROOT .. "/tools/sim/services.lua"))(SIM)
local Instance, task = SIM.Instance, SIM.task
local Methods = SIM.Methods
local game = SIM.game

local function readFile(path)
	local f = assert(io.open(SIM_ROOT .. "/" .. path, "r"), "no se pudo abrir " .. path)
	local s = f:read("a")
	f:close()
	return s
end
SIM.readFile = readFile

-- Monta ReplicatedStorage/ServerScriptService/... segun tools/sim/data/tree.lua (generado por build.py)
function SIM.loadProject()
	local tree = dofile(SIM_ROOT .. "/tools/sim/data/tree.lua")
	local byPath = {}
	local count = 0
	for _, entry in ipairs(tree) do
		local path = entry.path
		local key = table.concat(path, "/")
		local inst
		if #path == 1 then
			inst = SIM.getService(path[1])
		else
			local parent = byPath[table.concat(path, "/", 1, #path - 1)]
			if SIM.CLASSES[entry.class] and SIM.CLASSES[entry.class].tags.Service then
				inst = SIM.rawNew(entry.class)
			elseif entry.class == "StarterPlayerScripts" or entry.class == "StarterCharacterScripts" then
				inst = SIM.rawNew(entry.class)
			else
				inst = Instance.new(entry.class)
			end
			rawget(inst, "__props").Name = path[#path]
			SIM.setParent(inst, parent)
		end
		if entry.file then
			rawset(inst, "__source", readFile(entry.file))
			rawset(inst, "__srcname", entry.file)
			count = count + 1
		end
		byPath[key] = inst
	end
	return count
end

-- Comprueba la sintaxis de todos los scripts; devuelve lista de errores
function SIM.checkAllSyntax()
	local tree = dofile(SIM_ROOT .. "/tools/sim/data/tree.lua")
	local errs = {}
	for _, entry in ipairs(tree) do
		if entry.file then
			local ok, err = SIM.checkSyntax(readFile(entry.file), entry.file)
			if not ok then errs[#errs + 1] = tostring(err) end
		end
	end
	return errs
end

local function runScriptsUnder(root, cls, ctx)
	for _, d in ipairs(Methods.Instance.GetDescendants(root)) do
		if rawget(d, "__class") == cls and rawget(d, "__source") and not d.Disabled then
			SIM.runScript(d, ctx)
		end
	end
end

function SIM.start()
	runScriptsUnder(SIM.getService("ServerScriptService"), "Script", "server")
	SIM.runReady()
end

function SIM.addPlayer(userId, name)
	local players = SIM.getService("Players")
	local p = SIM.rawNew("Player")
	local pp = rawget(p, "__props")
	pp.Name = name
	pp.UserId = userId
	pp.DisplayName = name
	pp.AccountAge = 100
	local gui = SIM.rawNew("PlayerGui")
	rawget(gui, "__props").Name = "PlayerGui"
	SIM.setParent(gui, p)
	local ps = SIM.rawNew("PlayerScripts")
	rawget(ps, "__props").Name = "PlayerScripts"
	SIM.setParent(ps, p)
	local bp = SIM.rawNew("Backpack")
	rawget(bp, "__props").Name = "Backpack"
	SIM.setParent(bp, p)
	SIM.playersById[userId] = p
	SIM.setParent(p, players)
	local prev = SIM.context
	SIM.context = "server"
	SIM.fireIf(players, "PlayerAdded", p)
	SIM.context = prev
	if players.CharacterAutoLoads then SIM.spawnCharacter(p) end
	-- copiar StarterGui y StarterPlayerScripts, y arrancar los LocalScripts en el contexto del cliente
	local sps = Methods.Instance.FindFirstChild(SIM.getService("StarterPlayer"), "StarterPlayerScripts")
	if sps then
		for _, c in ipairs(Methods.Instance.GetChildren(sps)) do
			local copy = Methods.Instance.Clone(c)
			SIM.setParent(copy, ps)
		end
	end
	for _, c in ipairs(Methods.Instance.GetChildren(SIM.getService("StarterGui"))) do
		SIM.setParent(Methods.Instance.Clone(c), gui)
	end
	runScriptsUnder(ps, "LocalScript", "client:" .. userId)
	runScriptsUnder(gui, "LocalScript", "client:" .. userId)
	SIM.runReady()
	return p
end

function SIM.removePlayer(p)
	local players = SIM.getService("Players")
	if rawget(p, "__parent") ~= players then return end
	local prev = SIM.context
	SIM.context = "server"
	SIM.fireIf(players, "PlayerRemoving", p)
	SIM.context = prev
	SIM.runReady()
	SIM.playersById[p.UserId] = nil
	local char = rawget(p, "__props").Character
	if char then Methods.Instance.Destroy(char) end
	-- detener hilos del cliente: desconectar sus señales por frame es suficiente para las pruebas
	local ctx = "client:" .. p.UserId
	local rs = SIM.getService("RunService")
	for _, sig in pairs(rawget(rs, "__signals")) do
		for i = #sig._conns, 1, -1 do
			if sig._conns[i]._ctx == ctx then sig._conns[i].Connected = false table.remove(sig._conns, i) end
		end
	end
	SIM.deadContexts = SIM.deadContexts or {}
	SIM.deadContexts[ctx] = true
	Methods.Instance.Destroy(p)
end

-- Cierra el servidor: ejecuta callbacks de BindToClose
function SIM.shutdown()
	for _, p in pairs(SIM.playersById) do SIM.removePlayer(p) end
	for _, fn in ipairs(SIM.closeCallbacks) do
		SIM.spawnIn("server", fn, 0)
	end
	SIM.advance(40)
end

-- Ejecuta fn en un contexto (servidor o cliente) y espera a que termine
function SIM.run(ctx, fn, ...)
	if type(ctx) ~= "string" then ctx = "client:" .. ctx.UserId end
	local done, res = false, nil
	local args = table.pack(...)
	SIM.spawnIn(ctx, function()
		res = table.pack(fn(table.unpack(args, 1, args.n)))
		done = true
	end)
	local guard = 0
	while not done and guard < 4000 do
		SIM.advance(SIM.frameStep)
		guard = guard + 1
		if #SIM.errors > 0 and not done and guard > 5 and SIM.failFast then break end
	end
	if not done then
		error("SIM.run: la funcion no termino (posible error o espera infinita). Ultimo error:\n"
			.. tostring(SIM.errors[#SIM.errors]), 2)
	end
	return table.unpack(res, 1, res.n)
end

-- Interaccion de UI
function SIM.click(button)
	assert(SIM.typeof(button) == "Instance" and SIM.isA(rawget(button, "__class"), "GuiButton"), "SIM.click requiere GuiButton")
	local input = { UserInputType = SIM.Enum.UserInputType.MouseButton1, UserInputState = SIM.Enum.UserInputState.End,
		Position = SIM.D.Vector3.new(0, 0, 0), KeyCode = SIM.Enum.KeyCode.Unknown }
	SIM.fireIf(button, "MouseButton1Down", 0, 0)
	SIM.fireIf(button, "MouseButton1Up", 0, 0)
	SIM.fireIf(button, "MouseButton1Click")
	SIM.fireIf(button, "Activated", input, 1)
	SIM.runReady()
end
function SIM.trigger(prompt, player)
	SIM.fireIf(prompt, "Triggered", player)
	SIM.runReady()
end
function SIM.findAll(root, pred)
	local out = {}
	for _, d in ipairs(Methods.Instance.GetDescendants(root)) do
		if pred(d) then out[#out + 1] = d end
	end
	return out
end
function SIM.isVisible(gui)
	local cur = gui
	while cur do
		local cls = rawget(cur, "__class")
		if SIM.isA(cls, "GuiObject") and cur.Visible == false then return false end
		if SIM.isA(cls, "LayerCollector") and cur.Enabled == false then return false end
		cur = rawget(cur, "__parent")
	end
	return true
end
function SIM.assertNoErrors(label)
	if #SIM.errors > 0 then
		error(("%s: %d error(es) en el simulador; primero:\n%s"):format(label or "sim", #SIM.errors, SIM.errors[1]), 2)
	end
end
function SIM.clearErrors() SIM.errors = {} SIM.warnings = {} end

return SIM
