-- Simulador minimo del runtime de Roblox para Lua 5.4.
-- Valida contra el API dump oficial: clases, propiedades (tipo, solo lectura, seguridad),
-- metodos, eventos y enums. Permite ejecutar el codigo del juego (servidor + clientes) sin Studio.
local SIM_ROOT = ...
local API = dofile(SIM_ROOT .. "/tools/sim/data/api.lua")
local D = dofile(SIM_ROOT .. "/tools/sim/datatypes.lua")
local CLASSES, ENUMS = API.classes, API.enums

local SIM = {
	now = 0,
	epoch = 1795046400, -- reloj de pared simulado (os.time) = epoch + now
	frameStep = 1 / 20,
	context = "server",
	errors = {},
	warnings = {},
	quiet = false,
	isStudio = true,
	D = D,
	API = API,
}

local unpack, pack = table.unpack, table.pack

--------------------------------------------------------------------------- typeof
local function typeof(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" then
			local ty = rawget(mt, "__type")
			if ty then return ty end
		end
	end
	return t
end
SIM.typeof = typeof

--------------------------------------------------------------------------- planificador
local threadCtx = setmetatable({}, { __mode = "k" })
local ready = {}
local timers = {}
local seq = 0

local function reportError(co, err)
	local tb = debug.traceback(co, tostring(err))
	table.insert(SIM.errors, tb)
	if not SIM.quiet then io.stderr:write("[SIM ERROR] " .. tb .. "\n") end
end

local function resumeThread(co, ...)
	if coroutine.status(co) ~= "suspended" then return false end
	local prev = SIM.context
	SIM.context = threadCtx[co] or prev
	local ok, err = coroutine.resume(co, ...)
	SIM.context = prev
	if not ok then reportError(co, err) end
	return ok
end

local function toThread(fn, ctx)
	local co
	if type(fn) == "thread" then
		co = fn
	elseif type(fn) == "function" then
		co = coroutine.create(fn)
	else
		error("se esperaba funcion o thread, llego " .. type(fn), 3)
	end
	if not threadCtx[co] then threadCtx[co] = ctx or SIM.context end
	return co
end

local function spawnIn(ctx, fn, ...)
	local co = toThread(fn, ctx)
	resumeThread(co, ...)
	return co
end
SIM.spawnIn = spawnIn

local function addTimer(time, co, args)
	seq = seq + 1
	local rec = { time = time, seq = seq, co = co, args = args }
	local lo, hi = 1, #timers + 1
	while lo < hi do
		local mid = (lo + hi) // 2
		local m = timers[mid]
		if m.time < time or (m.time == time and m.seq < seq) then lo = mid + 1 else hi = mid end
	end
	table.insert(timers, lo, rec)
	return rec
end

local task = {}
function task.spawn(fn, ...) return spawnIn(nil, fn, ...) end
function task.defer(fn, ...)
	local co = toThread(fn)
	table.insert(ready, { co, pack(...) })
	return co
end
function task.delay(t, fn, ...)
	if type(t) ~= "number" then error("task.delay: tiempo invalido", 2) end
	local co = toThread(fn)
	addTimer(SIM.now + math.max(t, 0), co, pack(...))
	return co
end
function task.wait(t)
	t = t or 0
	if type(t) ~= "number" then error("task.wait: tiempo invalido", 2) end
	if not coroutine.isyieldable() then
		SIM.advance(math.max(t, SIM.frameStep))
		return t
	end
	local start = SIM.now
	addTimer(SIM.now + math.max(t, SIM.frameStep), coroutine.running(), nil)
	coroutine.yield()
	return SIM.now - start
end
function task.cancel(co)
	if type(co) ~= "thread" then error("task.cancel: se esperaba thread", 2) end
	if coroutine.status(co) == "suspended" then coroutine.close(co) end
end
function task.desynchronize() end
function task.synchronize() end

local function runReady()
	local guard = 0
	while #ready > 0 do
		guard = guard + 1
		if guard > 100000 then error("SIM: bucle infinito de task.defer") end
		local item = table.remove(ready, 1)
		resumeThread(item[1], unpack(item[2], 1, item[2].n))
	end
end

local frameSignals = {} -- señales por frame (Heartbeat, RenderStepped, ...)
SIM._nextFrame = SIM.frameStep

function SIM.advance(dt)
	local target = SIM.now + dt
	runReady()
	while true do
		local nt = timers[1] and timers[1].time or math.huge
		local t = math.min(nt, SIM._nextFrame)
		if t > target then break end
		SIM.now = t
		while timers[1] and timers[1].time <= t do
			local rec = table.remove(timers, 1)
			if rec.args then
				resumeThread(rec.co, unpack(rec.args, 1, rec.args.n))
			else
				resumeThread(rec.co)
			end
			runReady()
		end
		if SIM._nextFrame <= t then
			local step = SIM.frameStep
			SIM._nextFrame = SIM._nextFrame + step
			for _, sig in ipairs(frameSignals) do
				if sig._name == "Stepped" then sig:_fire(SIM.now, step) else sig:_fire(step) end
			end
			runReady()
		end
	end
	SIM.now = target
end

--------------------------------------------------------------------------- señales
local Signal = { __type = "RBXScriptSignal" }
Signal.__index = Signal
local Connection = { __type = "RBXScriptConnection" }
Connection.__index = Connection
function Connection:Disconnect()
	self.Connected = false
	local conns = self._sig._conns
	for i, c in ipairs(conns) do
		if c == self then table.remove(conns, i) break end
	end
end
local function newSignal(name, ctxRule)
	return setmetatable({ _conns = {}, _waiters = {}, _name = name, _ctxRule = ctxRule }, Signal)
end
SIM.newSignal = newSignal
local function checkCtx(self)
	local rule = self._ctxRule
	if rule == "server" and SIM.context ~= "server" then
		error(self._name .. " solo se puede usar en el servidor", 3)
	elseif rule == "client" and SIM.context == "server" then
		error(self._name .. " solo se puede usar en el cliente", 3)
	end
end
function Signal:Connect(fn)
	if type(fn) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
	checkCtx(self)
	local c = setmetatable({ _sig = self, _fn = fn, _ctx = SIM.context, Connected = true }, Connection)
	table.insert(self._conns, c)
	return c
end
Signal.ConnectParallel = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	checkCtx(self)
	if not coroutine.isyieldable() then error("Signal:Wait() fuera de una corrutina", 2) end
	table.insert(self._waiters, coroutine.running())
	return coroutine.yield()
end
function Signal:_fire(...)
	if #self._conns > 0 then
		local snapshot = { unpack(self._conns) }
		for _, c in ipairs(snapshot) do
			if c.Connected then spawnIn(c._ctx, c._fn, ...) end
		end
	end
	if #self._waiters > 0 then
		local w = self._waiters
		self._waiters = {}
		for _, co in ipairs(w) do resumeThread(co, ...) end
	end
end
function Signal:_hasListeners() return #self._conns > 0 or #self._waiters > 0 end

--------------------------------------------------------------------------- Enum
local EnumItem = { __type = "EnumItem" }
EnumItem.__index = function(self, k)
	if k == "IsA" then return function(_, name) return name == "EnumItem" end end
	error(("%s is not a valid member of EnumItem"):format(tostring(k)), 2)
end
EnumItem.__tostring = function(self) return "Enum." .. self.EnumType._name .. "." .. self.Name end
local EnumType = { __type = "Enum" }
EnumType.__index = function(self, k)
	local item = rawget(self, "_items")[k]
	if item then return item end
	if k == "GetEnumItems" then
		return function() local l = {} for _, it in pairs(self._items) do table.insert(l, it) end
			table.sort(l, function(a, b) return a.Value < b.Value end) return l end
	elseif k == "FromName" then
		return function(_, name) return self._items[name] end
	elseif k == "FromValue" then
		return function(_, value) for _, it in pairs(self._items) do if it.Value == value then return it end end return nil end
	end
	error(("%s is not a valid member of \"Enum.%s\""):format(tostring(k), self._name), 2)
end
EnumType.__tostring = function(self) return "Enum." .. self._name end
local enumCache = {}
local function getEnum(name)
	local e = enumCache[name]
	if e then return e end
	local def = ENUMS[name]
	if not def then return nil end
	e = setmetatable({ _name = name, _items = {} }, EnumType)
	for itemName, value in pairs(def) do
		e._items[itemName] = setmetatable({ Name = itemName, Value = value, EnumType = e }, EnumItem)
	end
	enumCache[name] = e
	return e
end
local Enum = setmetatable({}, {
	__type = "Enums",
	__index = function(_, k)
		local e = getEnum(k)
		if not e then error(("%s is not a valid member of \"Enum\""):format(tostring(k)), 2) end
		return e
	end,
})
local function lowestEnumItem(name)
	local e = getEnum(name)
	if not e then return nil end
	local best
	for _, it in pairs(e._items) do
		if not best or it.Value < best.Value then best = it end
	end
	return best
end

--------------------------------------------------------------------------- reflexion de clases
local chainCache = {}
local function classChain(cls)
	local c = chainCache[cls]
	if c then return c end
	c = {}
	local cur = cls
	while cur and CLASSES[cur] do
		table.insert(c, cur)
		cur = CLASSES[cur].super
	end
	chainCache[cls] = c
	return c
end
local function isA(cls, target)
	for _, c in ipairs(classChain(cls)) do
		if c == target then return true end
	end
	return false
end
SIM.isA = isA
local memberCache = {}
local NONE = {}
local function memberInfo(cls, key)
	local mc = memberCache[cls]
	if not mc then mc = {} memberCache[cls] = mc end
	local hit = mc[key]
	if hit ~= nil then
		if hit == NONE then return nil end
		return hit
	end
	for _, c in ipairs(classChain(cls)) do
		local def = CLASSES[c]
		local found
		if def.props[key] then found = { kind = "prop", info = def.props[key], owner = c }
		elseif def.methods[key] then found = { kind = "method", info = def.methods[key], owner = c }
		elseif def.events[key] ~= nil then found = { kind = "event", public = def.events[key], owner = c }
		elseif def.callbacks[key] then found = { kind = "callback", owner = c } end
		if found then mc[key] = found return found end
	end
	mc[key] = NONE
	return nil
end

--------------------------------------------------------------------------- valores por defecto
local Vector3, Vector2, CFrame, Color3, UDim, UDim2 = D.Vector3, D.Vector2, D.CFrame, D.Color3, D.UDim, D.UDim2
local WHITE = Color3.new(1, 1, 1)
local DEFAULTS = {
	Instance = { Archivable = true },
	BasePart = { Size = Vector3.new(4, 1, 2), CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true,
		Color = Color3.fromRGB(163, 162, 165), Material = "Plastic", Massless = false, Locked = false },
	Part = { Shape = "Block" },
	GuiObject = { Visible = true, BackgroundColor3 = WHITE, BorderSizePixel = 1, ZIndex = 1, Active = false,
		Interactable = true, Selectable = false },
	GuiButton = { AutoButtonColor = true, Selectable = true, Active = true },
	TextLabel = { Text = "Label", TextSize = 14, TextColor3 = Color3.new(0, 0, 0), LineHeight = 1, TextStrokeTransparency = 1 },
	TextButton = { Text = "Button", TextSize = 14, TextColor3 = Color3.new(0, 0, 0), LineHeight = 1, TextStrokeTransparency = 1 },
	TextBox = { Text = "TextBox", TextSize = 14, ClearTextOnFocus = true, TextEditable = true },
	ImageLabel = { ImageColor3 = WHITE }, ImageButton = { ImageColor3 = WHITE },
	LayerCollector = { Enabled = true, ResetOnSpawn = true },
	ScreenGui = { DisplayOrder = 0, IgnoreGuiInset = false },
	BillboardGui = { Active = false, MaxDistance = math.huge },
	SurfaceGui = { PixelsPerStud = 50 },
	UIStroke = { Thickness = 1, Color = Color3.new(0, 0, 0), Enabled = true },
	UIGradient = { Enabled = true },
	UIScale = { Scale = 1 },
	UIAspectRatioConstraint = { AspectRatio = 1 },
	Humanoid = { WalkSpeed = 16, Health = 100, MaxHealth = 100, JumpPower = 50, JumpHeight = 7.2, AutoRotate = true },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, RollOffMaxDistance = 10000 },
	SoundGroup = { Volume = 1 },
	Camera = { FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080), CameraType = "Custom" },
	ParticleEmitter = { Enabled = true, Rate = 20, TimeScale = 1 },
	Beam = { Enabled = true, Segments = 10, Width0 = 1, Width1 = 1 },
	Trail = { Enabled = true },
	Light = { Enabled = true, Brightness = 1, Color = WHITE },
	PointLight = { Range = 8 }, SpotLight = { Range = 16, Angle = 90 }, SurfaceLight = { Range = 16, Angle = 90 },
	ProximityPrompt = { Enabled = true, MaxActivationDistance = 10, HoldDuration = 0, RequiresLineOfSight = true,
		ActionText = "Interact", KeyboardKeyCode = "E" },
	Players = { MaxPlayers = 12, RespawnTime = 5, CharacterAutoLoads = true },
	Lighting = { Brightness = 3, ClockTime = 14, GlobalShadows = true },
	Workspace = { Gravity = 196.2, FallenPartsDestroyHeight = -500 },
	Decal = { Color3 = WHITE }, Texture = { StudsPerTileU = 2, StudsPerTileV = 2 },
	SpecialMesh = { Scale = Vector3.new(1, 1, 1), VertexColor = Vector3.new(1, 1, 1), MeshType = "Head" },
	DataModelMesh = { Scale = Vector3.new(1, 1, 1), VertexColor = Vector3.new(1, 1, 1) },
	Tween = { PlaybackState = "Begin" },
	Model = { WorldPivot = false },
	ValueBase = {},
	NumberValue = { Value = 0 }, IntValue = { Value = 0 }, BoolValue = { Value = false }, StringValue = { Value = "" },
	Atmosphere = { Density = 0.395 },
	Sky = { StarCount = 3000, CelestialBodiesShown = true },
	BloomEffect = { Enabled = true }, ColorCorrectionEffect = { Enabled = true, TintColor = WHITE },
	ScrollingFrame = { ScrollingEnabled = true, ScrollBarThickness = 12, CanvasSize = UDim2.new(0, 0, 2, 0) },
	UIListLayout = { FillDirection = "Vertical" },
	Highlight = { Enabled = true, FillTransparency = 0.5 },
	Player = { UserId = 0 },
	RunService = {},
	UserInputService = { MouseEnabled = true, KeyboardEnabled = true, TouchEnabled = false, GamepadEnabled = false,
		MouseIconEnabled = true },
	ViewportFrame = { ImageColor3 = WHITE, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.fromRGB(140, 140, 140) },
	CanvasGroup = { GroupTransparency = 0, GroupColor3 = WHITE },
	Attachment = {},
	WeldConstraint = { Enabled = true },
}
local function typeDefault(info)
	local c, t = info.c, info.t
	if c == "P" then
		if t == "bool" then return false elseif t == "string" then return "" else return 0 end
	elseif c == "E" then
		return lowestEnumItem(t)
	elseif c == "C" then
		return nil
	end
	if t == "Vector3" then return Vector3.zero elseif t == "Vector2" then return Vector2.zero
	elseif t == "CFrame" then return CFrame.identity elseif t == "Color3" then return Color3.new(0, 0, 0)
	elseif t == "UDim2" then return UDim2.new(0, 0, 0, 0) elseif t == "UDim" then return UDim.new(0, 0)
	elseif t == "ContentId" or t == "ProtectedString" or t == "BinaryString" then return ""
	elseif t == "NumberRange" then return D.NumberRange.new(0, 0)
	elseif t == "NumberSequence" then return D.NumberSequence.new(0)
	elseif t == "ColorSequence" then return D.ColorSequence.new(WHITE)
	elseif t == "Rect" then return D.Rect.new(0, 0, 0, 0)
	elseif t == "BrickColor" then return D.BrickColor.new("Medium stone grey")
	elseif t == "Font" then return SIM.Font.fromEnum(Enum.Font.SourceSans)
	end
	return nil
end
local function defaultFor(cls, key, info)
	for _, c in ipairs(classChain(cls)) do
		local d = DEFAULTS[c]
		if d and d[key] ~= nil then
			local v = d[key]
			if info.c == "E" and type(v) == "string" then return getEnum(info.t)._items[v] end
			if v == false and info.c ~= "P" then return nil end
			return v
		end
	end
	return typeDefault(info)
end

local function checkType(info, value, cls, key)
	local c, t = info.c, info.t
	local ok
	if c == "P" then
		if t == "bool" then ok = type(value) == "boolean"
		elseif t == "string" then ok = type(value) == "string" or type(value) == "number"
		else ok = type(value) == "number" and value == value end
	elseif c == "E" then
		ok = typeof(value) == "EnumItem" and value.EnumType._name == t
	elseif c == "C" then
		ok = value == nil or (typeof(value) == "Instance" and isA(rawget(value, "__class"), t))
	else
		if t == "ContentId" or t == "ProtectedString" or t == "BinaryString" then ok = type(value) == "string"
		else ok = typeof(value) == t end
	end
	if not ok then
		local got = typeof(value)
		if got == "EnumItem" then got = tostring(value) end
		if got == "Instance" then got = rawget(value, "__class") end
		error(("tipo invalido para %s.%s: se esperaba %s, llego %s"):format(cls, key, t, got), 3)
	end
end

--------------------------------------------------------------------------- Instance
local Instance = {}
local InstanceMT = { __type = "Instance" }
local Methods = {} -- Methods[Class][name] = fn
local Getters = {} -- Getters[Class][prop] = fn(inst)
local Setters = {} -- Setters[Class][prop] = fn(inst, value)
SIM.Methods, SIM.Getters, SIM.Setters = Methods, Getters, Setters

local function lookup(tbl, cls, key)
	for _, c in ipairs(classChain(cls)) do
		local m = tbl[c]
		if m and m[key] ~= nil then return m[key] end
	end
	return nil
end

local function fullName(inst)
	local parts = {}
	local cur = inst
	while cur do
		table.insert(parts, 1, rawget(cur, "__props").Name)
		cur = rawget(cur, "__parent")
		if cur and rawget(cur, "__class") == "DataModel" then break end
	end
	return table.concat(parts, ".")
end
SIM.fullName = fullName

local function getSignal(inst, key, ctxRule)
	local sigs = rawget(inst, "__signals")
	local s = sigs[key]
	if not s then
		s = newSignal(rawget(inst, "__class") .. "." .. key, ctxRule)
		sigs[key] = s
	end
	return s
end
SIM.getSignal = getSignal
local function fireIf(inst, key, ...)
	local s = rawget(inst, "__signals")[key]
	if s and s:_hasListeners() then s:_fire(...) end
end
SIM.fireIf = fireIf

local EVENT_CTX = {
	["RemoteEvent.OnServerEvent"] = "server", ["RemoteEvent.OnClientEvent"] = "client",
	["UnreliableRemoteEvent.OnServerEvent"] = "server", ["UnreliableRemoteEvent.OnClientEvent"] = "client",
	["RunService.RenderStepped"] = "client", ["RunService.PreRender"] = "client",
}
local FRAME_EVENTS = { Heartbeat = true, RenderStepped = true, Stepped = true, PreRender = true,
	PreSimulation = true, PostSimulation = true, PreAnimation = true }

InstanceMT.__index = function(inst, key)
	local cls = rawget(inst, "__class")
	if key == "Parent" then return rawget(inst, "__parent") end
	if key == "ClassName" then return cls end
	local props = rawget(inst, "__props")
	local getter = lookup(Getters, cls, key)
	if getter then return getter(inst) end
	local v = props[key]
	if v ~= nil then return v end
	local mi = memberInfo(cls, key)
	if mi then
		if mi.kind == "prop" then
			if mi.info.rsec then error(("no se puede leer %s.%s (seguridad)"):format(cls, key), 2) end
			return defaultFor(cls, key, mi.info)
		elseif mi.kind == "method" then
			if mi.info.sec then error(("%s:%s requiere permisos elevados"):format(cls, key), 2) end
			local impl = lookup(Methods, cls, key)
			if impl then return impl end
			return function() error(("SIM: metodo %s:%s no implementado en el simulador"):format(cls, key), 2) end
		elseif mi.kind == "event" then
			if not mi.public then error(("evento %s.%s requiere permisos elevados"):format(cls, key), 2) end
			local s = getSignal(inst, key, EVENT_CTX[mi.owner .. "." .. key])
			if cls == "RunService" and FRAME_EVENTS[key] and not s._registered then
				s._registered = true
				s._name = key
				table.insert(frameSignals, s)
			end
			return s
		elseif mi.kind == "callback" then
			return nil
		end
	end
	if type(key) == "string" then
		for _, child in ipairs(rawget(inst, "__children")) do
			if rawget(child, "__props").Name == key then return child end
		end
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(key), cls, fullName(inst)), 2)
end

local setParent

InstanceMT.__newindex = function(inst, key, value)
	local cls = rawget(inst, "__class")
	if key == "Parent" then
		if value ~= nil and typeof(value) ~= "Instance" then error("Parent debe ser Instance o nil", 2) end
		if rawget(inst, "__destroyed") then
			error(("The Parent property of %s is locked (instancia destruida)"):format(rawget(inst, "__props").Name), 2)
		end
		setParent(inst, value)
		return
	end
	local mi = memberInfo(cls, key)
	if not mi or (mi.kind ~= "prop" and mi.kind ~= "callback") then
		error(("%s is not a valid member of %s \"%s\" (asignacion)"):format(tostring(key), cls, fullName(inst)), 2)
	end
	local props = rawget(inst, "__props")
	if mi.kind == "callback" then
		if value ~= nil and type(value) ~= "function" then error(cls .. "." .. key .. " debe ser una funcion", 2) end
		props[key] = value
		return
	end
	local info = mi.info
	if info.ro then error(("no se puede asignar %s.%s: solo lectura"):format(cls, key), 2) end
	if info.ns then error(("no se puede asignar %s.%s: NotScriptable"):format(cls, key), 2) end
	if info.wsec then error(("no se puede asignar %s.%s: requiere permisos elevados"):format(cls, key), 2) end
	if value == nil and info.c ~= "C" then error(("no se puede asignar nil a %s.%s"):format(cls, key), 2) end
	checkType(info, value, cls, key)
	if info.c == "P" and info.t == "string" and type(value) == "number" then value = tostring(value) end
	local setter = lookup(Setters, cls, key)
	local old = props[key]
	if setter then
		setter(inst, value)
	else
		props[key] = value
	end
	if old ~= value then
		local sigs = rawget(inst, "__signals")
		if next(sigs) then
			fireIf(inst, "Changed", key)
			fireIf(inst, "prop:" .. key)
		end
	end
end
InstanceMT.__tostring = function(inst) return rawget(inst, "__props").Name end

local function rawNew(cls)
	return setmetatable({
		__class = cls, __props = { Name = cls }, __children = {}, __signals = {}, __attrs = {}, __tags = {},
	}, InstanceMT)
end
SIM.rawNew = rawNew

setParent = function(inst, parent)
	local old = rawget(inst, "__parent")
	if old == parent then return end
	if parent then
		local cur = parent
		while cur do
			if cur == inst then error("Attempt to set parent creating circular reference", 3) end
			cur = rawget(cur, "__parent")
		end
		if rawget(parent, "__destroyed") then error("no se puede parentar a una instancia destruida: " .. fullName(parent), 3) end
	end
	if old then
		local ch = rawget(old, "__children")
		for i, c in ipairs(ch) do
			if c == inst then table.remove(ch, i) break end
		end
		fireIf(old, "ChildRemoved", inst)
		local a = old
		while a do
			fireIf(a, "DescendantRemoving", inst)
			a = rawget(a, "__parent")
		end
	end
	rawset(inst, "__parent", parent)
	if parent then
		table.insert(rawget(parent, "__children"), inst)
		fireIf(parent, "ChildAdded", inst)
		local a = parent
		while a do
			local s = rawget(a, "__signals").DescendantAdded
			if s and s:_hasListeners() then
				s:_fire(inst)
				for _, d in ipairs(Methods.Instance.GetDescendants(inst)) do s:_fire(d) end
			end
			a = rawget(a, "__parent")
		end
	end
	fireIf(inst, "AncestryChanged", inst, parent)
	if SIM.onParentChanged then SIM.onParentChanged(inst, parent, old) end
end
SIM.setParent = setParent

function Instance.new(cls, parent)
	if type(cls) ~= "string" then error("Instance.new: nombre de clase invalido", 2) end
	local def = CLASSES[cls]
	if not def then error(("Unable to create an Instance of type \"%s\""):format(cls), 2) end
	if def.tags.NotCreatable or def.tags.Service then
		error(("Unable to create an Instance of type \"%s\" (NotCreatable)"):format(cls), 2)
	end
	local inst = rawNew(cls)
	if isA(cls, "BasePart") then rawget(inst, "__props").CFrame = CFrame.identity end
	if parent ~= nil then
		if typeof(parent) ~= "Instance" then error("Instance.new: parent invalido", 2) end
		setParent(inst, parent)
	end
	return inst
end

local IM = {}
Methods.Instance = IM
local function selfCheck(inst, name)
	if typeof(inst) ~= "Instance" then
		error(("Expected ':' not '.' calling member function %s"):format(name), 3)
	end
end
function IM.GetChildren(inst)
	selfCheck(inst, "GetChildren")
	return { unpack(rawget(inst, "__children")) }
end
function IM.GetDescendants(inst)
	selfCheck(inst, "GetDescendants")
	local out = {}
	local function walk(i)
		for _, c in ipairs(rawget(i, "__children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(inst)
	return out
end
function IM.FindFirstChild(inst, name, recursive)
	selfCheck(inst, "FindFirstChild")
	if type(name) ~= "string" then error("FindFirstChild: nombre invalido (" .. type(name) .. ")", 2) end
	for _, c in ipairs(rawget(inst, "__children")) do
		if rawget(c, "__props").Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(IM.GetDescendants(inst)) do
			if rawget(c, "__props").Name == name then return c end
		end
	end
	return nil
end
function IM.FindFirstChildOfClass(inst, cls)
	selfCheck(inst, "FindFirstChildOfClass")
	if not CLASSES[cls] then error("FindFirstChildOfClass: clase desconocida " .. tostring(cls), 2) end
	for _, c in ipairs(rawget(inst, "__children")) do
		if rawget(c, "__class") == cls then return c end
	end
	return nil
end
function IM.FindFirstChildWhichIsA(inst, cls, recursive)
	selfCheck(inst, "FindFirstChildWhichIsA")
	if not CLASSES[cls] then error("FindFirstChildWhichIsA: clase desconocida " .. tostring(cls), 2) end
	local list = recursive and IM.GetDescendants(inst) or rawget(inst, "__children")
	for _, c in ipairs(list) do
		if isA(rawget(c, "__class"), cls) then return c end
	end
	return nil
end
function IM.FindFirstAncestor(inst, name)
	local cur = rawget(inst, "__parent")
	while cur do
		if rawget(cur, "__props").Name == name then return cur end
		cur = rawget(cur, "__parent")
	end
	return nil
end
function IM.FindFirstAncestorOfClass(inst, cls)
	local cur = rawget(inst, "__parent")
	while cur do
		if rawget(cur, "__class") == cls then return cur end
		cur = rawget(cur, "__parent")
	end
	return nil
end
function IM.FindFirstAncestorWhichIsA(inst, cls)
	local cur = rawget(inst, "__parent")
	while cur do
		if isA(rawget(cur, "__class"), cls) then return cur end
		cur = rawget(cur, "__parent")
	end
	return nil
end
function IM.WaitForChild(inst, name, timeout)
	selfCheck(inst, "WaitForChild")
	if type(name) ~= "string" then error("WaitForChild: nombre invalido", 2) end
	local c = IM.FindFirstChild(inst, name)
	if c then return c end
	if not coroutine.isyieldable() then
		error(("WaitForChild(%q) en %s: no existe y no se puede esperar fuera de corrutina"):format(name, fullName(inst)), 2)
	end
	local start = SIM.now
	local limit = timeout or 30
	while SIM.now - start < limit do
		task.wait(0.1)
		c = IM.FindFirstChild(inst, name)
		if c then return c end
	end
	if timeout then return nil end
	error(("Infinite yield possible on '%s:WaitForChild(\"%s\")'"):format(fullName(inst), name), 2)
end
function IM.IsA(inst, cls)
	selfCheck(inst, "IsA")
	if not CLASSES[cls] then error("IsA: clase desconocida " .. tostring(cls), 2) end
	return isA(rawget(inst, "__class"), cls)
end
function IM.IsDescendantOf(inst, other)
	if other == nil then return false end
	local cur = rawget(inst, "__parent")
	while cur do
		if cur == other then return true end
		cur = rawget(cur, "__parent")
	end
	return false
end
function IM.IsAncestorOf(inst, other) return other ~= nil and IM.IsDescendantOf(other, inst) end
function IM.GetFullName(inst) return fullName(inst) end
function IM.ClearAllChildren(inst)
	for _, c in ipairs(IM.GetChildren(inst)) do IM.Destroy(c) end
end
function IM.Destroy(inst)
	selfCheck(inst, "Destroy")
	if rawget(inst, "__destroyed") then return end
	fireIf(inst, "Destroying")
	setParent(inst, nil)
	rawset(inst, "__destroyed", true)
	for _, c in ipairs(IM.GetChildren(inst)) do IM.Destroy(c) end
	for _, s in pairs(rawget(inst, "__signals")) do
		s._conns = {}
	end
end
IM.Remove = IM.Destroy
local function cloneRec(inst, map)
	local copy = rawNew(rawget(inst, "__class"))
	map[inst] = copy
	local p = rawget(copy, "__props")
	for k, v in pairs(rawget(inst, "__props")) do p[k] = v end
	for k, v in pairs(rawget(inst, "__attrs")) do rawget(copy, "__attrs")[k] = v end
	for k, v in pairs(rawget(inst, "__tags")) do rawget(copy, "__tags")[k] = v end
	rawset(copy, "__source", rawget(inst, "__source"))
	rawset(copy, "__srcname", rawget(inst, "__srcname"))
	for _, c in ipairs(rawget(inst, "__children")) do
		if rawget(c, "__props").Archivable ~= false then
			local cc = cloneRec(c, map)
			rawset(cc, "__parent", copy)
			table.insert(rawget(copy, "__children"), cc)
		end
	end
	return copy
end
function IM.Clone(inst)
	selfCheck(inst, "Clone")
	if rawget(inst, "__props").Archivable == false then return nil end
	local map = {}
	local copy = cloneRec(inst, map)
	for _, c in pairs(map) do
		local p = rawget(c, "__props")
		for k, v in pairs(p) do
			if typeof(v) == "Instance" and map[v] then p[k] = map[v] end
		end
	end
	return copy
end
local ATTR_TYPES = { string = true, boolean = true, number = true, Vector3 = true, Vector2 = true, Color3 = true,
	CFrame = true, UDim = true, UDim2 = true, NumberRange = true, NumberSequence = true, ColorSequence = true,
	BrickColor = true, Rect = true, Font = true, EnumItem = true, ["nil"] = true }
function IM.SetAttribute(inst, name, value)
	selfCheck(inst, "SetAttribute")
	if type(name) ~= "string" or #name == 0 or #name > 100 or name:find("[^%w_]") then
		error("nombre de atributo invalido: " .. tostring(name), 2)
	end
	if not ATTR_TYPES[typeof(value)] then error("tipo de atributo no soportado: " .. typeof(value), 2) end
	local attrs = rawget(inst, "__attrs")
	if attrs[name] == value then return end
	attrs[name] = value
	fireIf(inst, "AttributeChanged", name)
	fireIf(inst, "attr:" .. name)
end
function IM.GetAttribute(inst, name)
	selfCheck(inst, "GetAttribute")
	return rawget(inst, "__attrs")[name]
end
function IM.GetAttributes(inst)
	local t = {}
	for k, v in pairs(rawget(inst, "__attrs")) do t[k] = v end
	return t
end
function IM.GetAttributeChangedSignal(inst, name) return getSignal(inst, "attr:" .. name) end
function IM.GetPropertyChangedSignal(inst, name)
	selfCheck(inst, "GetPropertyChangedSignal")
	local mi = memberInfo(rawget(inst, "__class"), name)
	if not mi or mi.kind ~= "prop" then
		error(("%s is not a valid property name (GetPropertyChangedSignal en %s)"):format(tostring(name), rawget(inst, "__class")), 2)
	end
	return getSignal(inst, "prop:" .. name)
end
function IM.AddTag(inst, tag) rawget(inst, "__tags")[tag] = true end
function IM.RemoveTag(inst, tag) rawget(inst, "__tags")[tag] = nil end
function IM.HasTag(inst, tag) return rawget(inst, "__tags")[tag] == true end
function IM.GetTags(inst)
	local t = {}
	for k in pairs(rawget(inst, "__tags")) do table.insert(t, k) end
	return t
end

-- helpers para asignar propiedades de solo lectura desde el propio simulador
local function setInternal(inst, key, value)
	local props = rawget(inst, "__props")
	local old = props[key]
	props[key] = value
	if old ~= value then
		fireIf(inst, "Changed", key)
		fireIf(inst, "prop:" .. key)
	end
end
SIM.setInternal = setInternal

SIM.Instance = Instance
SIM.Enum = Enum
SIM.task = task
SIM.Signal = Signal
SIM.classChain = classChain
SIM.memberInfo = memberInfo
SIM.CLASSES = CLASSES
SIM.runReady = runReady
SIM.resumeThread = resumeThread
SIM.threadCtx = threadCtx
SIM.reportError = reportError
return SIM
