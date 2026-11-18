-- Servicios, clases con comportamiento y entorno global del simulador.
local SIM = ...
local D = SIM.D
local Methods, Getters, Setters = SIM.Methods, SIM.Getters, SIM.Setters
local Instance, Enum, task, typeof = SIM.Instance, SIM.Enum, SIM.task, SIM.typeof
local rawNew, setParent, setInternal, getSignal, fireIf = SIM.rawNew, SIM.setParent, SIM.setInternal, SIM.getSignal, SIM.fireIf
local isA = SIM.isA
local Vector3, Vector2, CFrame, Color3, UDim2 = D.Vector3, D.Vector2, D.CFrame, D.Color3, D.UDim2
local unpack, pack = table.unpack, table.pack

local function M(cls)
	Methods[cls] = Methods[cls] or {}
	return Methods[cls]
end
local function props(inst) return rawget(inst, "__props") end
local function class(inst) return rawget(inst, "__class") end

--------------------------------------------------------------------------- tipos extra
local FontMT = { __type = "Font" }
FontMT.__index = FontMT
FontMT.__eq = function(a, b) return a.Family == b.Family and a.Weight == b.Weight and a.Style == b.Style end
local function makeFont(family, weight, style)
	if type(family) ~= "string" then error("Font.new: family debe ser string", 3) end
	weight = weight or Enum.FontWeight.Regular
	style = style or Enum.FontStyle.Normal
	if typeof(weight) ~= "EnumItem" or weight.EnumType ~= Enum.FontWeight then error("Font.new: weight debe ser Enum.FontWeight", 3) end
	if typeof(style) ~= "EnumItem" or style.EnumType ~= Enum.FontStyle then error("Font.new: style debe ser Enum.FontStyle", 3) end
	return setmetatable({ Family = family, Weight = weight, Style = style, Bold = weight.Value >= 600 }, FontMT)
end
SIM.Font = {
	new = function(family, weight, style) return makeFont(family, weight, style) end,
	fromEnum = function(e)
		if typeof(e) ~= "EnumItem" or e.EnumType ~= Enum.Font then error("Font.fromEnum requiere Enum.Font", 2) end
		return makeFont("rbxasset://fonts/families/" .. e.Name .. ".json")
	end,
	fromName = function(name, weight, style) return makeFont("rbxasset://fonts/families/" .. name .. ".json", weight, style) end,
	fromId = function(id, weight, style) return makeFont("rbxassetid://" .. tostring(id), weight, style) end,
}

local TweenInfoMT = { __type = "TweenInfo" }
TweenInfoMT.__index = TweenInfoMT
local TweenInfo = {
	new = function(time, style, dir, repeatCount, reverses, delayTime)
		time = time or 1
		if type(time) ~= "number" then error("TweenInfo.new: time debe ser number", 2) end
		style = style or Enum.EasingStyle.Quad
		dir = dir or Enum.EasingDirection.Out
		if typeof(style) ~= "EnumItem" or style.EnumType ~= Enum.EasingStyle then error("TweenInfo.new: EasingStyle invalido", 2) end
		if typeof(dir) ~= "EnumItem" or dir.EnumType ~= Enum.EasingDirection then error("TweenInfo.new: EasingDirection invalido", 2) end
		if repeatCount ~= nil and type(repeatCount) ~= "number" then error("TweenInfo.new: repeatCount invalido", 2) end
		if reverses ~= nil and type(reverses) ~= "boolean" then error("TweenInfo.new: reverses invalido", 2) end
		if delayTime ~= nil and type(delayTime) ~= "number" then error("TweenInfo.new: delayTime invalido", 2) end
		return setmetatable({ Time = time, EasingStyle = style, EasingDirection = dir, RepeatCount = repeatCount or 0,
			Reverses = reverses or false, DelayTime = delayTime or 0 }, TweenInfoMT)
	end,
}

local RaycastParamsMT = { __type = "RaycastParams" }
RaycastParamsMT.__index = RaycastParamsMT
function RaycastParamsMT:AddToFilter(x)
	if typeof(x) == "Instance" then table.insert(self.FilterDescendantsInstances, x) else
		for _, i in ipairs(x) do table.insert(self.FilterDescendantsInstances, i) end
	end
end
local RaycastParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude,
			IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false }, RaycastParamsMT)
	end,
}
local OverlapParamsMT = { __type = "OverlapParams" }
OverlapParamsMT.__index = OverlapParamsMT
OverlapParamsMT.AddToFilter = RaycastParamsMT.AddToFilter
local OverlapParams = {
	new = function()
		return setmetatable({ FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude,
			MaxParts = 0, CollisionGroup = "Default", RespectCanCollide = false }, OverlapParamsMT)
	end,
}

-- Random determinista
local RandomMT = { __type = "Random" }
RandomMT.__index = RandomMT
local function rndNext(self)
	local x = self.state
	x = x ~ (x << 13)
	x = x ~ (x >> 7)
	x = x ~ (x << 17)
	self.state = x
	return ((x >> 11) & 0x1FFFFFFFFFFFFF) / 9007199254740992.0
end
function RandomMT:NextNumber(a, b)
	local r = rndNext(self)
	if a == nil then return r end
	if type(a) ~= "number" or type(b) ~= "number" then error("Random:NextNumber(min, max) invalido", 2) end
	return a + (b - a) * r
end
function RandomMT:NextInteger(a, b)
	if type(a) ~= "number" or type(b) ~= "number" then error("Random:NextInteger(min, max) invalido", 2) end
	if math.floor(a) ~= a or math.floor(b) ~= b then error("Random:NextInteger requiere enteros", 2) end
	if b < a then error("Random:NextInteger: max < min", 2) end
	return math.floor(a + math.floor(rndNext(self) * (b - a + 1)))
end
function RandomMT:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local a = self:NextNumber(0, math.pi * 2)
	local r = math.sqrt(1 - z * z)
	return Vector3.new(r * math.cos(a), r * math.sin(a), z)
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone() return setmetatable({ state = self.state }, RandomMT) end
local randomCounter = 0
local Random = {
	new = function(seed)
		if seed == nil then
			randomCounter = randomCounter + 1
			seed = 88172645463325252 + randomCounter * 7919 + (SIM.seed or 0)
		end
		if type(seed) ~= "number" then error("Random.new: semilla invalida", 2) end
		local s = math.floor(seed) * 2654435761 + 88172645463325252
		if s == 0 then s = 1 end
		local r = setmetatable({ state = s }, RandomMT)
		rndNext(r) rndNext(r)
		return r
	end,
}

--------------------------------------------------------------------------- JSON
local function jsonEncode(v, out)
	local t = type(v)
	if v == nil then out[#out + 1] = "null"
	elseif t == "boolean" then out[#out + 1] = tostring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("JSON: numero no finito") end
		if math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 1e15 then
			out[#out + 1] = string.format("%d", v)
		else
			out[#out + 1] = string.format("%.17g", v)
		end
	elseif t == "string" then
		out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
			return string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif t == "table" then
		local n = #v
		local count = 0
		for _ in pairs(v) do count = count + 1 end
		if count == n and n > 0 then
			out[#out + 1] = "["
			for i = 1, n do
				if i > 1 then out[#out + 1] = "," end
				jsonEncode(v[i], out)
			end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			local keys = {}
			for k in pairs(v) do
				if type(k) ~= "string" then error("JSON: clave no string (" .. type(k) .. ") en tabla tipo diccionario") end
				keys[#keys + 1] = k
			end
			table.sort(keys)
			for _, k in ipairs(keys) do
				if not first then out[#out + 1] = "," end
				first = false
				jsonEncode(k, out)
				out[#out + 1] = ":"
				jsonEncode(v[k], out)
			end
			out[#out + 1] = "}"
		end
	else
		error("JSON: tipo no serializable " .. typeof(v))
	end
end
local function jsonDecode(s)
	local pos = 1
	local function ws() pos = s:find("%S", pos) or #s + 1 end
	local parse
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == "" then error("JSON: string sin cerrar") end
			if c == '"' then pos = pos + 1 break end
			if c == "\\" then
				local n = s:sub(pos + 1, pos + 1)
				if n == "u" then
					out[#out + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16))
					pos = pos + 6
				else
					local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
					out[#out + 1] = map[n] or n
					pos = pos + 2
				end
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
		return table.concat(out)
	end
	parse = function()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
			while true do
				ws()
				local k = str()
				ws()
				pos = pos + 1
				t[k] = parse()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then break end
			end
			return t
		elseif c == "[" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
			while true do
				t[#t + 1] = parse()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then break end
			end
			return t
		elseif c == '"' then
			return str()
		elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
		elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
		elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
		else
			local numStr = s:match("^-?[%d%.eE%+%-]+", pos)
			if not numStr then error("JSON: token inesperado en " .. pos) end
			pos = pos + #numStr
			return tonumber(numStr)
		end
	end
	return parse()
end
SIM.jsonEncode = function(v) local out = {} jsonEncode(v, out) return table.concat(out) end
SIM.jsonDecode = jsonDecode

-- Copia "serializada": emula las restricciones de Remotes / DataStores.
local function netCopy(v, what, depth)
	depth = depth or 0
	if depth > 60 then error(what .. ": tabla demasiado profunda o ciclica") end
	local t = typeof(v)
	if t == "table" then
		local n = #v
		local count = 0
		for k in pairs(v) do
			count = count + 1
			if type(k) ~= "string" and not (type(k) == "number" and math.floor(k) == k and k >= 1 and k <= n) then
				error(("%s: tabla con clave no serializable (%s) - usa claves string o un array sin huecos"):format(what, tostring(k)))
			end
		end
		if n > 0 and count ~= n then
			error(what .. ": tabla mixta (array + diccionario) no se replica correctamente")
		end
		if getmetatable(v) ~= nil then error(what .. ": tabla con metatabla") end
		local out = {}
		for k, val in pairs(v) do out[k] = netCopy(val, what, depth + 1) end
		return out
	elseif t == "function" or t == "thread" or t == "userdata" then
		error(what .. ": no se puede enviar un valor de tipo " .. t)
	elseif t == "number" and what:find("DataStore") and (v ~= v or v == math.huge or v == -math.huge) then
		error(what .. ": numero no finito")
	elseif what:find("DataStore") and t ~= "string" and t ~= "number" and t ~= "boolean" and t ~= "nil" then
		error(what .. ": tipo no almacenable " .. t)
	end
	return v
end
SIM.netCopy = netCopy
local function netCopyArgs(what, ...)
	local a = pack(...)
	for i = 1, a.n do a[i] = netCopy(a[i], what) end
	return a
end

--------------------------------------------------------------------------- DataModel y servicios
local game = rawNew("DataModel")
props(game).Name = "Game"
props(game).PlaceId = 0
props(game).GameId = 0
props(game).JobId = "sim-job-1"
props(game).CreatorId = 1
props(game).PrivateServerId = ""
props(game).PrivateServerOwnerId = 0
SIM.game = game
local services = {}
local closeCallbacks = {}
SIM.closeCallbacks = closeCallbacks

local function getService(name)
	local s = services[name]
	if s then return s end
	local def = SIM.CLASSES[name]
	if not def or not def.tags.Service then error(("'%s' is not a valid Service name"):format(tostring(name)), 3) end
	s = rawNew(name)
	if name == "Workspace" then props(s).Name = "Workspace" end
	if name == "RunService" then props(s).Name = "Run Service" end
	services[name] = s
	rawset(s, "__parent", game)
	table.insert(rawget(game, "__children"), s)
	return s
end
SIM.getService = getService

local GM = M("DataModel")
function GM.GetService(g, name) return getService(name) end
function GM.FindService(g, name) return services[name] end
function GM.BindToClose(g, fn)
	if SIM.context ~= "server" then error("BindToClose solo en servidor", 2) end
	if type(fn) ~= "function" then error("BindToClose requiere funcion", 2) end
	table.insert(closeCallbacks, fn)
end
function GM.IsLoaded() return true end
M("ServiceProvider").GetService = GM.GetService
M("ServiceProvider").FindService = GM.FindService
Getters.DataModel = {
	Workspace = function() return getService("Workspace") end,
	Players = function() return getService("Players") end,
	Lighting = function() return getService("Lighting") end,
	ReplicatedStorage = function() return getService("ReplicatedStorage") end,
	ServerScriptService = function() return getService("ServerScriptService") end,
	ServerStorage = function() return getService("ServerStorage") end,
	StarterGui = function() return getService("StarterGui") end,
	StarterPlayer = function() return getService("StarterPlayer") end,
	SoundService = function() return getService("SoundService") end,
}
SIM.Getters.DataModel.workspace = Getters.DataModel.Workspace

--------------------------------------------------------------------------- BasePart / Model
local function toDeg(x) return x * 180 / math.pi end
Getters.BasePart = {
	Position = function(i) return props(i).CFrame.Position end,
	Orientation = function(i)
		local x, y, z = props(i).CFrame:ToOrientation()
		return Vector3.new(toDeg(x), toDeg(y), toDeg(z))
	end,
	Rotation = function(i)
		local x, y, z = props(i).CFrame:ToEulerAnglesXYZ()
		return Vector3.new(toDeg(x), toDeg(y), toDeg(z))
	end,
	AssemblyLinearVelocity = function(i) return props(i).AssemblyLinearVelocity or Vector3.zero end,
}
Setters.BasePart = {
	Position = function(i, v)
		local c = props(i).CFrame
		props(i).CFrame = c.Rotation + v
	end,
	Orientation = function(i, v)
		local c = props(i).CFrame
		props(i).CFrame = CFrame.new(c.Position) * CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	end,
	Rotation = function(i, v)
		local c = props(i).CFrame
		props(i).CFrame = CFrame.new(c.Position) * CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	end,
	Size = function(i, v)
		if v.X <= 0 or v.Y <= 0 or v.Z <= 0 then error("BasePart.Size con componente <= 0: " .. tostring(v), 3) end
		if v.X > 2048 or v.Y > 2048 or v.Z > 2048 then error("BasePart.Size excede 2048: " .. tostring(v), 3) end
		props(i).Size = v
	end,
	Transparency = function(i, v) props(i).Transparency = v end,
}
local BP = M("BasePart")
function BP.GetPivot(i) return props(i).CFrame * (props(i).PivotOffset or CFrame.identity) end
function BP.PivotTo(i, cf)
	if typeof(cf) ~= "CFrame" then error("PivotTo requiere CFrame", 2) end
	props(i).CFrame = cf * (props(i).PivotOffset or CFrame.identity):Inverse()
end
function BP.GetMass(i) local s = i.Size return s.X * s.Y * s.Z * 0.7 end
function BP.SetNetworkOwner() end
function BP.GetTouchingParts() return {} end
function BP.ApplyImpulse() end
function BP.GetConnectedParts() return {} end

local function modelParts(m)
	local out = {}
	for _, d in ipairs(Methods.Instance.GetDescendants(m)) do
		if isA(class(d), "BasePart") then out[#out + 1] = d end
	end
	return out
end
local function modelBounds(m)
	local parts = modelParts(m)
	if #parts == 0 then return CFrame.identity, Vector3.zero end
	local minx, miny, minz, maxx, maxy, maxz = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, p in ipairs(parts) do
		local c, s = props(p).CFrame, p.Size
		local r = math.max(s.X, s.Y, s.Z) / 2
		minx, miny, minz = math.min(minx, c.X - r), math.min(miny, c.Y - r), math.min(minz, c.Z - r)
		maxx, maxy, maxz = math.max(maxx, c.X + r), math.max(maxy, c.Y + r), math.max(maxz, c.Z + r)
	end
	return CFrame.new((minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2), Vector3.new(maxx - minx, maxy - miny, maxz - minz)
end
local MM = M("Model")
function MM.GetPivot(m)
	local pp = props(m).PrimaryPart
	if pp then return BP.GetPivot(pp) end
	local wp = props(m).WorldPivot
	if wp then return wp end
	local c = modelBounds(m)
	return c
end
function MM.PivotTo(m, cf)
	if typeof(cf) ~= "CFrame" then error("PivotTo requiere CFrame", 2) end
	local delta = cf * MM.GetPivot(m):Inverse()
	for _, p in ipairs(modelParts(m)) do
		props(p).CFrame = delta * props(p).CFrame
	end
	for _, d in ipairs(Methods.Instance.GetDescendants(m)) do
		if isA(class(d), "Model") and props(d).WorldPivot then props(d).WorldPivot = delta * props(d).WorldPivot end
	end
	if props(m).WorldPivot then props(m).WorldPivot = cf end
end
function MM.GetBoundingBox(m) return modelBounds(m) end
function MM.GetExtentsSize(m) local _, s = modelBounds(m) return s end
function MM.MoveTo(m, pos) MM.PivotTo(m, CFrame.new(pos)) end
function MM.ScaleTo(m, s) props(m).__scale = s end
function MM.GetScale(m) return props(m).__scale or 1 end
function MM.SetPrimaryPartCFrame(m, cf) MM.PivotTo(m, cf) end
M("PVInstance").GetPivot = function(i) if isA(class(i), "Model") then return MM.GetPivot(i) end return BP.GetPivot(i) end
M("PVInstance").PivotTo = function(i, cf) if isA(class(i), "Model") then return MM.PivotTo(i, cf) end return BP.PivotTo(i, cf) end

--------------------------------------------------------------------------- GUI
local function parentAbsSize(i)
	local p = rawget(i, "__parent")
	while p do
		local c = class(p)
		if isA(c, "GuiObject") then return Getters.GuiObject.AbsoluteSize(p) end
		if c == "ScreenGui" then return Vector2.new(1920, 1080) end
		if c == "SurfaceGui" then return Vector2.new(800, 600) end
		if c == "BillboardGui" then
			local s = p.Size
			return Vector2.new(s.X.Offset + s.X.Scale * 50, s.Y.Offset + s.Y.Scale * 50)
		end
		p = rawget(p, "__parent")
	end
	return Vector2.new(1920, 1080)
end
Getters.GuiObject = {
	AbsoluteSize = function(i)
		local ps = parentAbsSize(i)
		local s = i.Size
		return Vector2.new(s.X.Scale * ps.X + s.X.Offset, s.Y.Scale * ps.Y + s.Y.Offset)
	end,
	AbsolutePosition = function(i)
		local ps = parentAbsSize(i)
		local p = i.Position
		return Vector2.new(p.X.Scale * ps.X + p.X.Offset, p.Y.Scale * ps.Y + p.Y.Offset)
	end,
}
Getters.LayerCollector = { AbsoluteSize = function() return Vector2.new(1920, 1080) end }
Getters.TextLabel = { TextBounds = function(i) return Vector2.new(#tostring(props(i).Text or "") * 7, i.TextSize) end, TextFits = function() return true end }
Getters.TextButton = Getters.TextLabel
Getters.TextBox = Getters.TextLabel
Getters.ScrollingFrame = { AbsoluteCanvasSize = function(i) return Getters.GuiObject.AbsoluteSize(i) end,
	AbsoluteWindowSize = function(i) return Getters.GuiObject.AbsoluteSize(i) end }
local GO = M("GuiObject")
local function tweenStub(i, endProps, cb)
	for k, v in pairs(endProps) do i[k] = v end
	if cb then task.defer(cb, Enum.TweenStatus.Completed) end
	return true
end
function GO.TweenPosition(i, pos, _, _, _, _, cb) return tweenStub(i, { Position = pos }, cb) end
function GO.TweenSize(i, size, _, _, _, _, cb) return tweenStub(i, { Size = size }, cb) end
function GO.TweenSizeAndPosition(i, size, pos, _, _, _, _, cb) return tweenStub(i, { Size = size, Position = pos }, cb) end
local TB = M("TextBox")
function TB.CaptureFocus(i) fireIf(i, "Focused") end
function TB.ReleaseFocus(i, submitted) fireIf(i, "FocusLost", submitted or false) end
function TB.IsFocused() return false end

--------------------------------------------------------------------------- Sonido / particulas / varios
local SM = M("Sound")
function SM.Play(i) props(i).IsPlaying = true props(i).Playing = true end
function SM.Stop(i) props(i).IsPlaying = false props(i).Playing = false end
function SM.Pause(i) props(i).IsPlaying = false props(i).Playing = false end
function SM.Resume(i) props(i).IsPlaying = true props(i).Playing = true end
M("ParticleEmitter").Emit = function(i, n)
	if n ~= nil and type(n) ~= "number" then error("ParticleEmitter:Emit(count) invalido", 2) end
end
M("ParticleEmitter").Clear = function() end
M("Humanoid").MoveTo = function() end
M("Humanoid").ChangeState = function() end
M("Humanoid").GetState = function() return Enum.HumanoidStateType.Running end
M("Humanoid").TakeDamage = function(h, n) props(h).Health = math.max(0, h.Health - n) end
M("Humanoid").SetStateEnabled = function() end
M("Humanoid").UnequipTools = function() end
Getters.Humanoid = {
	RootPart = function(h)
		local m = rawget(h, "__parent")
		return m and Methods.Instance.FindFirstChild(m, "HumanoidRootPart") or nil
	end,
}
M("BindableEvent").Fire = function(i, ...)
	local a = pack(...)
	getSignal(i, "Event"):_fire(unpack(a, 1, a.n))
end
M("BindableFunction").Invoke = function(i, ...)
	local fn = props(i).OnInvoke
	if not fn then error("BindableFunction sin OnInvoke", 2) end
	return fn(...)
end
M("Debris").AddItem = function(_, inst, t)
	if typeof(inst) ~= "Instance" then error("Debris:AddItem requiere Instance", 2) end
	task.delay(t or 10, function()
		if not rawget(inst, "__destroyed") then Methods.Instance.Destroy(inst) end
	end)
end
M("ProximityPrompt").InputHoldBegin = function() end
M("ProximityPrompt").InputHoldEnd = function() end
M("Camera").WorldToViewportPoint = function(_, p) return Vector3.new(960, 540, 10), true end
M("Camera").WorldToScreenPoint = function(_, p) return Vector3.new(960, 540, 10), true end
M("Camera").ViewportPointToRay = function(c, x, y) return D.Ray.new(c.CFrame.Position, c.CFrame.LookVector) end
M("Camera").ScreenPointToRay = function(c, x, y) return D.Ray.new(c.CFrame.Position, c.CFrame.LookVector) end
M("Camera").GetPartsObscuringTarget = function() return {} end
Setters.Camera = { CFrame = function(i, v) props(i).CFrame = v end }

--------------------------------------------------------------------------- RunService
local RS = M("RunService")
function RS.IsServer() return SIM.context == "server" end
function RS.IsClient() return SIM.context ~= "server" end
function RS.IsStudio() return SIM.isStudio end
function RS.IsRunning() return true end
function RS.IsRunMode() return false end
local renderBinds = {}
function RS.BindToRenderStep(rs, name, priority, fn)
	if SIM.context == "server" then error("BindToRenderStep solo en cliente", 2) end
	if type(name) ~= "string" or type(priority) ~= "number" or type(fn) ~= "function" then error("BindToRenderStep: argumentos invalidos", 2) end
	renderBinds[SIM.context .. ":" .. name] = rs.RenderStepped:Connect(fn)
end
function RS.UnbindFromRenderStep(_, name)
	local c = renderBinds[SIM.context .. ":" .. name]
	if c then c:Disconnect() renderBinds[SIM.context .. ":" .. name] = nil end
end

--------------------------------------------------------------------------- TweenService
local TS = M("TweenService")
function TS.Create(_, inst, info, goals)
	if typeof(inst) ~= "Instance" then error("TweenService:Create: instancia invalida", 2) end
	if typeof(info) ~= "TweenInfo" then error("TweenService:Create: TweenInfo invalido", 2) end
	if type(goals) ~= "table" then error("TweenService:Create: tabla de propiedades invalida", 2) end
	for k, v in pairs(goals) do
		local mi = SIM.memberInfo(class(inst), k)
		if not mi or mi.kind ~= "prop" then error(("TweenService:Create: %s no es propiedad de %s"):format(tostring(k), class(inst)), 2) end
		local t = typeof(v)
		if t ~= "number" and t ~= "Vector3" and t ~= "Vector2" and t ~= "CFrame" and t ~= "Color3" and t ~= "UDim2"
			and t ~= "UDim" and t ~= "boolean" and t ~= "Rect" then
			error(("TweenService:Create: tipo no interpolable para %s (%s)"):format(k, t), 2)
		end
		if mi.info.c == "P" and mi.info.t ~= "bool" and t ~= "number" then error("TweenService:Create: tipo incorrecto para " .. k, 2) end
		if mi.info.c == "D" and mi.info.t ~= t then error(("TweenService:Create: %s espera %s, llego %s"):format(k, mi.info.t, t), 2) end
	end
	local tw = rawNew("Tween")
	props(tw).Instance = inst
	props(tw).TweenInfo = info
	rawset(tw, "__goals", goals)
	return tw
end
function TS.GetValue(_, alpha) return alpha end
local TW = M("Tween")
function TW.Play(tw)
	local info = props(tw).TweenInfo
	local token = {}
	rawset(tw, "__token", token)
	props(tw).PlaybackState = Enum.PlaybackState.Playing
	if info.RepeatCount < 0 then return end -- bucle infinito: no se simula
	local total = info.DelayTime + info.Time * (1 + info.RepeatCount) * (info.Reverses and 2 or 1)
	task.delay(total, function()
		if rawget(tw, "__token") ~= token then return end
		local inst = props(tw).Instance
		if not rawget(inst, "__destroyed") and not info.Reverses then
			for k, v in pairs(rawget(tw, "__goals")) do inst[k] = v end
		end
		props(tw).PlaybackState = Enum.PlaybackState.Completed
		fireIf(tw, "Completed", Enum.PlaybackState.Completed)
	end)
end
function TW.Cancel(tw)
	rawset(tw, "__token", nil)
	props(tw).PlaybackState = Enum.PlaybackState.Cancelled
	fireIf(tw, "Completed", Enum.PlaybackState.Cancelled)
end
function TW.Pause(tw) rawset(tw, "__token", nil) props(tw).PlaybackState = Enum.PlaybackState.Paused end
M("TweenBase").Play = TW.Play
M("TweenBase").Cancel = TW.Cancel
M("TweenBase").Pause = TW.Pause

--------------------------------------------------------------------------- Remotes
local function requireClient(name)
	if SIM.context == "server" then error(name .. " solo puede llamarse desde el cliente", 3) end
end
local function requireServer(name)
	if SIM.context ~= "server" then error(name .. " solo puede llamarse desde el servidor", 3) end
end
local function ctxPlayer()
	local id = tonumber(SIM.context:match("^client:(%d+)$"))
	if not id then return nil end
	return SIM.playersById[id]
end
SIM.ctxPlayer = ctxPlayer
SIM.playersById = {}
SIM.remoteLog = {}

for _, cls in ipairs({ "RemoteEvent", "UnreliableRemoteEvent" }) do
	local RE = M(cls)
	function RE.FireServer(r, ...)
		requireClient(cls .. ":FireServer")
		local a = netCopyArgs("Remote " .. r.Name, ...)
		local plr = ctxPlayer()
		local sig = getSignal(r, "OnServerEvent", "server")
		task.defer(function() sig:_fire(plr, unpack(a, 1, a.n)) end)
	end
	function RE.FireClient(r, plr, ...)
		requireServer(cls .. ":FireClient")
		if typeof(plr) ~= "Instance" or class(plr) ~= "Player" then error("FireClient: el primer argumento debe ser Player", 2) end
		local a = netCopyArgs("Remote " .. r.Name, ...)
		local sig = rawget(plr, "__remoteSignals") and rawget(plr, "__remoteSignals")[r]
		if SIM.onFireClient then SIM.onFireClient(r, plr, a) end
		if sig then task.defer(function() sig:_fire(unpack(a, 1, a.n)) end) end
	end
	function RE.FireAllClients(r, ...)
		requireServer(cls .. ":FireAllClients")
		for _, plr in pairs(SIM.playersById) do RE.FireClient(r, plr, ...) end
	end
end
-- OnClientEvent: una señal por jugador (cada cliente tiene su propia vista del remote)
Getters.RemoteEvent = {
	OnClientEvent = function(r)
		requireClient("OnClientEvent")
		local plr = ctxPlayer()
		local map = rawget(plr, "__remoteSignals")
		if not map then map = {} rawset(plr, "__remoteSignals", map) end
		local s = map[r]
		if not s then s = SIM.newSignal(r.Name .. ".OnClientEvent", "client") map[r] = s end
		return s
	end,
}
Getters.UnreliableRemoteEvent = Getters.RemoteEvent

local RF = M("RemoteFunction")
function RF.InvokeServer(r, ...)
	requireClient("InvokeServer")
	local fn = props(r).OnServerInvoke
	local plr = ctxPlayer()
	local a = netCopyArgs("Remote " .. r.Name, ...)
	if not fn then
		-- en Roblox esto se queda esperando indefinidamente
		error("InvokeServer en " .. r.Name .. " sin OnServerInvoke asignado", 2)
	end
	local caller = coroutine.running()
	local done, results = false, nil
	local waiting = false
	SIM.spawnIn("server", function()
		local res = pack(fn(plr, unpack(a, 1, a.n)))
		for i = 1, res.n do res[i] = netCopy(res[i], "Respuesta de " .. r.Name) end
		results = res
		done = true
		if waiting then SIM.resumeThread(caller) end
	end)
	if not done then
		if #SIM.errors > 0 and SIM.lastInvokeErrCount ~= #SIM.errors then
			-- el handler fallo: en Roblox InvokeServer lanzaria error en el cliente
			SIM.lastInvokeErrCount = #SIM.errors
		end
		if not coroutine.isyieldable() then
			-- llamado desde el hilo principal del test: bombear el planificador
			local guard = 0
			while not done and guard < 2000 do
				SIM.advance(SIM.frameStep)
				guard = guard + 1
			end
			if not done then error("InvokeServer " .. r.Name .. ": el servidor no respondio") end
		else
			waiting = true
			coroutine.yield()
			if not done then error("InvokeServer " .. r.Name .. ": reanudado sin respuesta") end
		end
	end
	return unpack(results, 1, results.n)
end
Setters.RemoteFunction = {
	OnServerInvoke = function(r, fn)
		requireServer("OnServerInvoke")
		props(r).OnServerInvoke = fn
	end,
}

--------------------------------------------------------------------------- DataStoreService
SIM.datastores = {}       -- nombre -> { key -> valor }
SIM.dsFail = nil          -- funcion(op, storeName, key) -> true para simular fallo
SIM.dsDisabled = false    -- true = simula Studio sin acceso a API
SIM.dsCalls = 0
local function dsCheck(op, store, key)
	requireServer("DataStore")
	SIM.dsCalls = SIM.dsCalls + 1
	if not coroutine.isyieldable() then error("DataStore " .. op .. " fuera de corrutina") end
	task.wait(0.05)
	if SIM.dsDisabled then
		error("403: Cannot write to DataStore from Studio if API access is not enabled.", 0)
	end
	if SIM.dsFail and SIM.dsFail(op, store, key) then
		error("502: API Services rejected request (simulado)", 0)
	end
	if type(key) ~= "string" or #key == 0 or #key > 50 then error("DataStore: clave invalida", 0) end
end
local function makeStore(name, ordered)
	local st = rawNew(ordered and "OrderedDataStore" or "DataStore")
	props(st).Name = name
	rawset(st, "__store", name)
	SIM.datastores[name] = SIM.datastores[name] or {}
	return st
end
local DSS = M("DataStoreService")
function DSS.GetDataStore(_, name, scope)
	requireServer("DataStoreService")
	if SIM.dsDisabled and SIM.dsThrowOnGet then error("DataStore no disponible", 0) end
	return makeStore(name .. (scope and ("/" .. scope) or ""), false)
end
function DSS.GetOrderedDataStore(_, name, scope)
	requireServer("DataStoreService")
	return makeStore("ordered:" .. name .. (scope and ("/" .. scope) or ""), true)
end
local GDS = M("GlobalDataStore")
function GDS.GetAsync(st, key)
	dsCheck("GetAsync", rawget(st, "__store"), key)
	return netCopy(SIM.datastores[rawget(st, "__store")][key], "DataStore GetAsync")
end
function GDS.SetAsync(st, key, value)
	dsCheck("SetAsync", rawget(st, "__store"), key)
	if value == nil then error("DataStore SetAsync: valor nil", 0) end
	if class(st) == "OrderedDataStore" and (type(value) ~= "number" or math.floor(value) ~= value) then
		error("OrderedDataStore solo admite enteros", 0)
	end
	SIM.datastores[rawget(st, "__store")][key] = netCopy(value, "DataStore SetAsync")
end
function GDS.UpdateAsync(st, key, fn)
	dsCheck("UpdateAsync", rawget(st, "__store"), key)
	local store = SIM.datastores[rawget(st, "__store")]
	local old = netCopy(store[key], "DataStore UpdateAsync")
	local new = fn(old, nil)
	if new ~= nil then
		store[key] = netCopy(new, "DataStore UpdateAsync")
		return netCopy(store[key], "DataStore UpdateAsync")
	end
	return nil
end
function GDS.RemoveAsync(st, key)
	dsCheck("RemoveAsync", rawget(st, "__store"), key)
	local store = SIM.datastores[rawget(st, "__store")]
	local old = store[key]
	store[key] = nil
	return old
end
function GDS.IncrementAsync(st, key, delta)
	dsCheck("IncrementAsync", rawget(st, "__store"), key)
	local store = SIM.datastores[rawget(st, "__store")]
	store[key] = (store[key] or 0) + (delta or 1)
	return store[key]
end
local ODS = M("OrderedDataStore")
function ODS.GetSortedAsync(st, ascending, pageSize, minV, maxV)
	dsCheck("GetSortedAsync", rawget(st, "__store"), "sorted")
	if type(ascending) ~= "boolean" or type(pageSize) ~= "number" then error("GetSortedAsync: argumentos invalidos", 0) end
	if pageSize > 100 or pageSize < 1 then error("GetSortedAsync: pageSize debe estar entre 1 y 100", 0) end
	local list = {}
	for k, v in pairs(SIM.datastores[rawget(st, "__store")]) do list[#list + 1] = { key = k, value = v } end
	table.sort(list, function(a, b)
		if a.value == b.value then return a.key < b.key end
		if ascending then return a.value < b.value end
		return a.value > b.value
	end)
	local page = {}
	for i = 1, math.min(pageSize, #list) do page[i] = list[i] end
	local pages = rawNew("DataStorePages")
	rawset(pages, "__page", page)
	props(pages).IsFinished = true
	return pages
end
M("Pages").GetCurrentPage = function(p) return rawget(p, "__page") end
M("Pages").AdvanceToNextPageAsync = function() error("no hay mas paginas", 0) end

--------------------------------------------------------------------------- otros servicios
local HS = M("HttpService")
local guidN = 0
function HS.GenerateGUID(_, wrap)
	guidN = guidN + 1
	local g = string.format("%08X-0000-4000-8000-%012X", (guidN * 2654435761) % 4294967296, guidN)
	if wrap == false then return g end
	return "{" .. g .. "}"
end
function HS.JSONEncode(_, v) return SIM.jsonEncode(v) end
function HS.JSONDecode(_, s) return jsonDecode(s) end

local UIS = M("UserInputService")
function UIS.GetMouseLocation() return Vector2.new(960, 540) end
function UIS.IsKeyDown() return false end
function UIS.IsMouseButtonPressed() return false end
function UIS.GetFocusedTextBox() return nil end
function UIS.GetLastInputType() return Enum.UserInputType.MouseMovement end
function UIS.GetMouseDelta() return Vector2.zero end
local CAS = M("ContextActionService")
function CAS.BindAction(_, name, fn, touchButton, ...)
	if type(name) ~= "string" or type(fn) ~= "function" or type(touchButton) ~= "boolean" then
		error("ContextActionService:BindAction: argumentos invalidos", 2)
	end
end
function CAS.UnbindAction() end
M("GuiService").GetGuiInset = function() return Vector2.new(0, 36), Vector2.zero end
M("GuiService").IsTenFootInterface = function() return false end
local SG = M("StarterGui")
function SG.SetCore(_, name, value) if type(name) ~= "string" then error("SetCore: nombre invalido", 2) end end
function SG.SetCoreGuiEnabled(_, t, enabled)
	if typeof(t) ~= "EnumItem" or t.EnumType ~= Enum.CoreGuiType or type(enabled) ~= "boolean" then
		error("SetCoreGuiEnabled: argumentos invalidos", 2)
	end
end
function SG.GetCore() return nil end
M("SoundService").PlayLocalSound = function(_, s) if typeof(s) ~= "Instance" or class(s) ~= "Sound" then error("PlayLocalSound requiere Sound", 2) end end
M("ContentProvider").PreloadAsync = function(_, list, cb)
	if type(list) ~= "table" then error("PreloadAsync requiere tabla", 2) end
	task.wait(0.05)
	if cb then
		for _, item in ipairs(list) do
			local id = typeof(item) == "Instance" and "instance" or tostring(item)
			local status = Enum.AssetFetchStatus.Success
			if SIM.failAssets and SIM.failAssets(id) then status = Enum.AssetFetchStatus.Failure end
			cb(id, status)
		end
	end
end
local MPS = M("MarketplaceService")
function MPS.UserOwnsGamePassAsync() task.wait(0.05) return false end
function MPS.PromptGamePassPurchase() end
function MPS.PromptProductPurchase() end
function MPS.GetProductInfo() task.wait(0.05) return { Name = "Producto", PriceInRobux = 0 } end
M("TextService").GetTextSize = function(_, text, size) return Vector2.new(#text * size * 0.5, size) end
M("BadgeService").AwardBadge = function() return true end
M("PolicyService").GetPolicyInfoForPlayerAsync = function()
	task.wait(0.05)
	return { ArePaidRandomItemsRestricted = false, IsSubjectToChinaPolicies = false, AllowedExternalLinkReferences = {} }
end
M("MessagingService").PublishAsync = function() task.wait(0.05) end
M("MessagingService").SubscribeAsync = function(_, topic, fn) task.wait(0.05) return { Disconnect = function() end } end
M("CollectionService").GetTagged = function(_, tag)
	local out = {}
	for _, d in ipairs(Methods.Instance.GetDescendants(game)) do
		if rawget(d, "__tags")[tag] then out[#out + 1] = d end
	end
	return out
end
M("CollectionService").AddTag = function(_, inst, tag) rawget(inst, "__tags")[tag] = true end
M("CollectionService").HasTag = function(_, inst, tag) return rawget(inst, "__tags")[tag] == true end
M("CollectionService").GetInstanceAddedSignal = function(cs, tag) return getSignal(cs, "tagAdded:" .. tag) end
M("CollectionService").GetInstanceRemovedSignal = function(cs, tag) return getSignal(cs, "tagRemoved:" .. tag) end
M("TextChannel").DisplaySystemMessage = function(_, msg) if type(msg) ~= "string" then error("DisplaySystemMessage requiere string", 2) end end
M("Lighting").GetSunDirection = function() return Vector3.new(0, 1, 0) end

-- Workspace
local WS = M("Workspace")
function WS.GetServerTimeNow() return SIM.epoch + SIM.now end
SIM.raycastHandler = nil
M("WorldRoot").Raycast = function(_, origin, dir, params)
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then error("Raycast: origen/direccion invalidos", 2) end
	if params ~= nil and typeof(params) ~= "RaycastParams" then error("Raycast: RaycastParams invalido", 2) end
	if SIM.raycastHandler then return SIM.raycastHandler(origin, dir, params) end
	return nil
end
M("WorldRoot").GetPartBoundsInBox = function() return {} end
M("WorldRoot").GetPartBoundsInRadius = function() return {} end
M("WorldRoot").GetPartsInPart = function() return {} end
Getters.Workspace = {
	CurrentCamera = function(ws)
		local cam = props(ws).CurrentCamera
		if not cam then
			cam = rawNew("Camera")
			props(cam).CFrame = CFrame.identity
			props(ws).CurrentCamera = cam
			rawset(cam, "__parent", ws)
			table.insert(rawget(ws, "__children"), cam)
		end
		return cam
	end,
	DistributedGameTime = function() return SIM.now end,
}

--------------------------------------------------------------------------- Players
local PL = M("Players")
function PL.GetPlayers()
	local out = {}
	for _, c in ipairs(rawget(getService("Players"), "__children")) do
		if class(c) == "Player" then out[#out + 1] = c end
	end
	return out
end
function PL.GetPlayerByUserId(_, id) return SIM.playersById[id] end
function PL.GetPlayerFromCharacter(_, char)
	for _, p in pairs(SIM.playersById) do
		if props(p).Character == char then return p end
	end
	return nil
end
function PL.GetUserThumbnailAsync(_, userId, ttype, size)
	if type(userId) ~= "number" then error("GetUserThumbnailAsync: userId invalido", 2) end
	if typeof(ttype) ~= "EnumItem" or ttype.EnumType ~= Enum.ThumbnailType then error("GetUserThumbnailAsync: ThumbnailType invalido", 2) end
	if typeof(size) ~= "EnumItem" or size.EnumType ~= Enum.ThumbnailSize then error("GetUserThumbnailAsync: ThumbnailSize invalido", 2) end
	task.wait(0.05)
	return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150", true
end
function PL.GetNameFromUserIdAsync(_, id) task.wait(0.05) local p = SIM.playersById[id] return p and p.Name or ("User" .. id) end
Getters.Players = { LocalPlayer = function() return ctxPlayer() end }

local PM = M("Player")
function PM.Kick(p, msg)
	requireServer("Player:Kick")
	rawset(p, "__kicked", msg or "kicked")
	task.defer(function() SIM.removePlayer(p) end)
end
function PM.LoadCharacter(p) SIM.spawnCharacter(p) end
function PM.GetMouse(p)
	local m = rawget(p, "__mouse")
	if not m then m = rawNew("PlayerMouse") rawset(p, "__mouse", m) end
	return m
end
function PM.IsFriendsWith() return false end
function PM.IsInGroup() return false end
function PM.GetRankInGroup() return 0 end
function PM.GetNetworkPing() return 0.05 end
function PM.RequestStreamAroundAsync() end
function PM.DistanceFromCharacter() return 0 end

function SIM.spawnCharacter(p)
	local old = props(p).Character
	if old then Methods.Instance.Destroy(old) end
	local char = Instance.new("Model")
	char.Name = p.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 5, 0)
	root.Parent = char
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.CFrame = CFrame.new(0, 6.5, 0)
	head.Parent = char
	local hum = Instance.new("Humanoid")
	hum.Parent = char
	char.PrimaryPart = root
	char.Parent = getService("Workspace")
	props(p).Character = char
	fireIf(p, "CharacterAdded", char)
	task.defer(function() fireIf(p, "CharacterAppearanceLoaded", char) end)
	return char
end

--------------------------------------------------------------------------- entorno global para scripts
local function luauTostring(v)
	if math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 1e15 then
		return string.format("%d", v)
	end
	return tostring(v)
end

local tableLib = {}
for k, v in pairs(table) do tableLib[k] = v end
function tableLib.find(t, value, init)
	for i = init or 1, #t do
		if t[i] == value then return i end
	end
	return nil
end
function tableLib.clone(t)
	local c = {}
	for k, v in pairs(t) do c[k] = v end
	return setmetatable(c, getmetatable(t))
end
function tableLib.create(n, value)
	local t = {}
	if value ~= nil then for i = 1, n do t[i] = value end end
	return t
end
function tableLib.clear(t) for k in pairs(t) do t[k] = nil end end
local frozen = setmetatable({}, { __mode = "k" })
function tableLib.freeze(t) frozen[t] = true return t end
function tableLib.isfrozen(t) return frozen[t] == true end
tableLib.getn = function(t) return #t end
tableLib.foreach = nil

local mathLib = {}
for _, k in ipairs({ "abs", "acos", "asin", "atan", "ceil", "cos", "deg", "exp", "floor", "fmod", "huge", "log", "max",
	"min", "modf", "pi", "rad", "random", "randomseed", "sin", "sqrt", "tan" }) do
	mathLib[k] = math[k]
end
mathLib.atan2 = function(y, x) return math.atan(y, x) end
mathLib.pow = function(a, b) return a ^ b end
mathLib.clamp = function(x, lo, hi)
	if type(x) ~= "number" or type(lo) ~= "number" or type(hi) ~= "number" then error("math.clamp: argumentos invalidos", 2) end
	if lo > hi then error("math.clamp: max debe ser >= min", 2) end
	return math.min(math.max(x, lo), hi)
end
mathLib.round = function(x) return math.floor(x + 0.5) end
mathLib.sign = function(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
mathLib.log10 = function(x) return math.log(x, 10) end
mathLib.cosh = function(x) return (math.exp(x) + math.exp(-x)) / 2 end
mathLib.sinh = function(x) return (math.exp(x) - math.exp(-x)) / 2 end
mathLib.tanh = function(x) local a, b = math.exp(x), math.exp(-x) return (a - b) / (a + b) end
mathLib.noise = function(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	return math.sin(x * 1.7 + y * 2.3 + z * 3.1) * 0.5 * math.cos(x * 0.7 - y * 1.3 + z * 0.9)
end
mathLib.random = function(a, b)
	if a == nil then return math.random() end
	if math.floor(a) ~= a or (b ~= nil and math.floor(b) ~= b) then error("math.random: argumentos deben ser enteros", 2) end
	if b == nil then return math.random(math.floor(a)) end
	return math.random(math.floor(a), math.floor(b))
end
mathLib.lerp = function(a, b, t) return a + (b - a) * t end
mathLib.map = function(x, inMin, inMax, outMin, outMax) return outMin + (x - inMin) * (outMax - outMin) / (inMax - inMin) end

local stringLib = {}
for k, v in pairs(string) do stringLib[k] = v end
stringLib.split = function(s, sep)
	sep = sep or ","
	local out = {}
	if sep == "" then
		for i = 1, #s do out[i] = s:sub(i, i) end
		return out
	end
	local start = 1
	while true do
		local a, b = s:find(sep, start, true)
		if not a then out[#out + 1] = s:sub(start) break end
		out[#out + 1] = s:sub(start, a - 1)
		start = b + 1
	end
	return out
end
-- que los metodos de string (s:split) usen la libreria extendida
getmetatable("").__index = stringLib

local osLib = {
	time = function(t)
		if t then return os.time(t) end
		return math.floor(SIM.epoch + SIM.now)
	end,
	clock = function() return SIM.now end,
	date = function(fmt, t) return os.date(fmt, t or math.floor(SIM.epoch + SIM.now)) end,
	difftime = function(a, b) return a - (b or 0) end,
}
local bit32Lib = {
	band = function(a, b) return (a & b) & 0xFFFFFFFF end, bor = function(a, b) return (a | b) & 0xFFFFFFFF end,
	bxor = function(a, b) return (a ~ b) & 0xFFFFFFFF end, lshift = function(a, n) return (a << n) & 0xFFFFFFFF end,
	rshift = function(a, n) return (a & 0xFFFFFFFF) >> n end, bnot = function(a) return (~a) & 0xFFFFFFFF end,
}
local coroutineLib = {}
for _, k in ipairs({ "create", "resume", "yield", "status", "wrap", "running", "isyieldable", "close" }) do
	coroutineLib[k] = coroutine[k]
end
local debugLib = { traceback = debug.traceback, info = function() return "sim" end, profilebegin = function() end, profileend = function() end }

local G = {
	print = function(...)
		if SIM.quiet then return end
		local a = pack(...)
		for i = 1, a.n do a[i] = luauTostring(a[i]) end
		io.stdout:write("[" .. SIM.context .. "] " .. table.concat(a, " ") .. "\n")
	end,
	warn = function(...)
		local a = pack(...)
		for i = 1, a.n do a[i] = luauTostring(a[i]) end
		local msg = table.concat(a, " ")
		table.insert(SIM.warnings, msg)
		if not SIM.quiet then io.stdout:write("[" .. SIM.context .. "][WARN] " .. msg .. "\n") end
	end,
	error = error, assert = assert, pcall = pcall, xpcall = xpcall, select = select, tostring = luauTostring,
	tonumber = tonumber, type = type, next = next, pairs = pairs, ipairs = ipairs, rawget = rawget, rawset = rawset,
	rawequal = rawequal, rawlen = rawlen, setmetatable = setmetatable, getmetatable = getmetatable,
	unpack = table.unpack, _VERSION = "Luau",
	string = stringLib, table = tableLib, math = mathLib, os = osLib, coroutine = coroutineLib, utf8 = utf8,
	bit32 = bit32Lib, debug = debugLib,
	typeof = typeof, task = task,
	tick = function() return SIM.epoch + SIM.now end,
	time = function() return SIM.now end,
	elapsedTime = function() return SIM.now end,
	wait = function(t) local e = task.wait(t or 0.03) return e, SIM.now end,
	delay = function(t, fn) task.delay(t, fn) end,
	spawn = function(fn) task.defer(fn) end,
	game = game, Game = game,
	Enum = Enum, Instance = Instance,
	Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3, UDim = D.UDim, UDim2 = UDim2,
	Rect = D.Rect, NumberRange = D.NumberRange, NumberSequence = D.NumberSequence,
	NumberSequenceKeypoint = D.NumberSequenceKeypoint, ColorSequence = D.ColorSequence,
	ColorSequenceKeypoint = D.ColorSequenceKeypoint, Ray = D.Ray, PhysicalProperties = D.PhysicalProperties,
	BrickColor = D.BrickColor, TweenInfo = TweenInfo, Font = SIM.Font, RaycastParams = RaycastParams,
	OverlapParams = OverlapParams, Random = Random,
	DateTime = D.makeDateTime(function() return SIM.epoch + SIM.now end),
	shared = {},
}
G._G = {}
setmetatable(G, { __index = function(_, k) if k == "workspace" then return getService("Workspace") end return nil end })
SIM.G = G

--------------------------------------------------------------------------- ejecucion de scripts
local moduleCache = {} -- contexto -> { [ModuleScript] = {value} | "loading" }
local envMT_cache = {}

local function makeEnv(scriptInst)
	local env = { script = scriptInst }
	return setmetatable(env, {
		__index = function(_, k)
			local v = G[k]
			if v == nil and k ~= "workspace" then
				error(("uso de variable global no definida '%s' en %s"):format(tostring(k), SIM.fullName(scriptInst)), 2)
			end
			return v
		end,
		__newindex = function(_, k)
			error(("asignacion a variable global '%s' en %s (falta 'local'?)"):format(tostring(k), SIM.fullName(scriptInst)), 2)
		end,
	})
end

local function loadSource(scriptInst)
	local src = rawget(scriptInst, "__source")
	if not src then error("script sin codigo fuente: " .. SIM.fullName(scriptInst)) end
	local env = makeEnv(scriptInst)
	local fn, err = load(src, "=" .. (rawget(scriptInst, "__srcname") or SIM.fullName(scriptInst)), "t", env)
	if not fn then error("error de sintaxis: " .. tostring(err), 0) end
	return fn, env
end

function G.require(mod)
	if typeof(mod) ~= "Instance" or class(mod) ~= "ModuleScript" then
		error("require: se esperaba un ModuleScript, llego " .. typeof(mod) .. (typeof(mod) == "Instance" and (" " .. class(mod)) or ""), 2)
	end
	local ctx = SIM.context
	local cache = moduleCache[ctx]
	if not cache then cache = {} moduleCache[ctx] = cache end
	local hit = cache[mod]
	if hit == "loading" then
		error("require ciclico detectado en " .. SIM.fullName(mod), 2)
	elseif hit then
		return hit[1]
	end
	cache[mod] = "loading"
	local fn, env = loadSource(mod)
	rawset(env, "require", G.require)
	local results = pack(fn())
	if results.n ~= 1 then
		cache[mod] = nil
		error("Module code did not return exactly one value: " .. SIM.fullName(mod), 2)
	end
	cache[mod] = { results[1] }
	return results[1]
end
SIM.moduleCache = moduleCache

function SIM.runScript(scriptInst, ctx)
	local fn = loadSource(scriptInst)
	return SIM.spawnIn(ctx, fn)
end
function SIM.checkSyntax(src, name)
	local fn, err = load(src, "=" .. name, "t", {})
	return fn ~= nil, err
end

return SIM
