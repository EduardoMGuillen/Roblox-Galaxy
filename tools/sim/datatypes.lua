-- Tipos de datos de Roblox simulados (Vector3, CFrame, Color3, UDim2, ...) para Lua 5.4.
-- Solo se usan dentro del simulador de pruebas; el juego real usa los tipos nativos de Roblox.
local D = {}

local function class(typeName)
	local mt = { __type = typeName }
	mt.__index = mt
	return mt
end

local function isType(v, typeName)
	local mt = getmetatable(v)
	return type(mt) == "table" and rawget(mt, "__type") == typeName
end
D.isType = isType

local function num(v, what)
	if type(v) ~= "number" then
		error(("se esperaba number para %s, llego %s"):format(what or "argumento", type(v)), 3)
	end
	return v
end

---------------------------------------------------------------- Vector3
local Vector3 = class("Vector3")
local function v3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, Vector3)
end
local function isV3(v) return isType(v, "Vector3") end
Vector3.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(self.X / m, self.Y / m, self.Z / m)
	end
	local f = rawget(Vector3, k)
	if f == nil then error(("%s is not a valid member of Vector3"):format(tostring(k)), 2) end
	return f
end
Vector3.__newindex = function(_, k) error("Vector3 es inmutable: no se puede asignar " .. tostring(k), 2) end
Vector3.__add = function(a, b)
	if not (isV3(a) and isV3(b)) then error("Vector3 + requiere dos Vector3", 2) end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3.__sub = function(a, b)
	if not (isV3(a) and isV3(b)) then error("Vector3 - requiere dos Vector3", 2) end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	if isV3(a) and isV3(b) then return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
	error("Vector3 * operando invalido", 2)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if isV3(a) and isV3(b) then return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
	error("Vector3 / operando invalido", 2)
end
Vector3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__tostring = function(a) return ("%g, %g, %g"):format(a.X, a.Y, a.Z) end
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function Vector3.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function Vector3.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
D.Vector3 = setmetatable({
	new = function(x, y, z) return v3(num(x or 0, "X"), num(y or 0, "Y"), num(z or 0, "Z")) end,
	zero = v3(0, 0, 0), one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1),
}, { __index = function(_, k) error(tostring(k) .. " is not a valid member of Vector3 (libreria)", 2) end })

---------------------------------------------------------------- Vector2
local Vector2 = class("Vector2")
local function v2(x, y) return setmetatable({ X = x, Y = y }, Vector2) end
Vector2.__index = function(self, k)
	if k == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
	if k == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y)
		return v2(self.X / m, self.Y / m)
	end
	local f = rawget(Vector2, k)
	if f == nil then error(("%s is not a valid member of Vector2"):format(tostring(k)), 2) end
	return f
end
Vector2.__newindex = function(_, k) error("Vector2 es inmutable", 2) end
Vector2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
Vector2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
Vector2.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.X, a * b.Y) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
Vector2.__div = function(a, b)
	if type(b) == "number" then return v2(a.X / b, a.Y / b) end
	return v2(a.X / b.X, a.Y / b.Y)
end
Vector2.__unm = function(a) return v2(-a.X, -a.Y) end
Vector2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2.__tostring = function(a) return ("%g, %g"):format(a.X, a.Y) end
function Vector2.Lerp(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
function Vector2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
D.Vector2 = setmetatable({
	new = function(x, y) return v2(num(x or 0, "X"), num(y or 0, "Y")) end,
	zero = v2(0, 0), one = v2(1, 1), xAxis = v2(1, 0), yAxis = v2(0, 1),
}, { __index = function(_, k) error(tostring(k) .. " is not a valid member of Vector2 (libreria)", 2) end })

---------------------------------------------------------------- CFrame
-- Almacena posicion (x,y,z) y matriz de rotacion en orden de filas m[1..9] = r00 r01 r02 r10 ... r22
local CFrame = class("CFrame")
local function cf(x, y, z, m)
	return setmetatable({ x = x, y = y, z = z, m = m }, CFrame)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matMul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function matVec(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z
end
local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
local function fromColumns(r, u, b) -- columnas: Right, Up, Back(-Look)
	return { r.X, u.X, b.X, r.Y, u.Y, b.Y, r.Z, u.Z, b.Z }
end
local function rotX(a) local c, s = math.cos(a), math.sin(a) return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function rotY(a) local c, s = math.cos(a), math.sin(a) return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rotZ(a) local c, s = math.cos(a), math.sin(a) return { c, -s, 0, s, c, 0, 0, 0, 1 } end

local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at)
	if look.Magnitude == 0 then return cf(at.X, at.Y, at.Z, IDENT) end
	look = look.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(v3(1, 0, 0))
		if right.Magnitude < 1e-6 then right = look:Cross(v3(0, 0, 1)) end
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return cf(at.X, at.Y, at.Z, fromColumns(right, up2, -look))
end

CFrame.__index = function(self, k)
	if k == "Position" or k == "p" then return v3(self.x, self.y, self.z) end
	if k == "X" then return self.x elseif k == "Y" then return self.y elseif k == "Z" then return self.z end
	local m = rawget(self, "m")
	if k == "LookVector" then return v3(-m[3], -m[6], -m[9]) end
	if k == "RightVector" or k == "XVector" then return v3(m[1], m[4], m[7]) end
	if k == "UpVector" or k == "YVector" then return v3(m[2], m[5], m[8]) end
	if k == "ZVector" then return v3(m[3], m[6], m[9]) end
	if k == "Rotation" then return cf(0, 0, 0, m) end
	local f = rawget(CFrame, k)
	if f == nil then error(("%s is not a valid member of CFrame"):format(tostring(k)), 2) end
	return f
end
CFrame.__newindex = function(_, k) error("CFrame es inmutable", 2) end
CFrame.__mul = function(a, b)
	if not isType(a, "CFrame") then error("CFrame * : el operando izquierdo debe ser CFrame", 2) end
	if isType(b, "CFrame") then
		local px, py, pz = matVec(a.m, b.x, b.y, b.z)
		return cf(a.x + px, a.y + py, a.z + pz, matMul(a.m, b.m))
	elseif isV3(b) then
		local px, py, pz = matVec(a.m, b.X, b.Y, b.Z)
		return v3(a.x + px, a.y + py, a.z + pz)
	end
	error("CFrame * operando invalido (" .. type(b) .. ")", 2)
end
CFrame.__add = function(a, b)
	if not (isType(a, "CFrame") and isV3(b)) then error("CFrame + Vector3 esperado", 2) end
	return cf(a.x + b.X, a.y + b.Y, a.z + b.Z, a.m)
end
CFrame.__sub = function(a, b)
	if not (isType(a, "CFrame") and isV3(b)) then error("CFrame - Vector3 esperado", 2) end
	return cf(a.x - b.X, a.y - b.Y, a.z - b.Z, a.m)
end
CFrame.__eq = function(a, b)
	if a.x ~= b.x or a.y ~= b.y or a.z ~= b.z then return false end
	for i = 1, 9 do if a.m[i] ~= b.m[i] then return false end end
	return true
end
CFrame.__tostring = function(a)
	return ("%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g"):format(a.x, a.y, a.z, table.unpack(a.m))
end
function CFrame.Inverse(a)
	local t = transpose(a.m)
	local px, py, pz = matVec(t, -a.x, -a.y, -a.z)
	return cf(px, py, pz, t)
end
function CFrame.ToWorldSpace(a, b) return a * b end
function CFrame.ToObjectSpace(a, b) return a:Inverse() * b end
function CFrame.PointToWorldSpace(a, p) return a * p end
function CFrame.PointToObjectSpace(a, p) return a:Inverse() * p end
function CFrame.VectorToWorldSpace(a, v) local x, y, z = matVec(a.m, v.X, v.Y, v.Z) return v3(x, y, z) end
function CFrame.VectorToObjectSpace(a, v) local x, y, z = matVec(transpose(a.m), v.X, v.Y, v.Z) return v3(x, y, z) end
function CFrame.GetComponents(a) return a.x, a.y, a.z, table.unpack(a.m) end
CFrame.components = CFrame.GetComponents
function CFrame.Lerp(a, b, t)
	local m = {}
	for i = 1, 9 do m[i] = a.m[i] + (b.m[i] - a.m[i]) * t end
	-- re-ortonormalizar (aproximacion suficiente para pruebas)
	local r = v3(m[1], m[4], m[7])
	local u = v3(m[2], m[5], m[8])
	if r.Magnitude < 1e-9 or u.Magnitude < 1e-9 then
		m = t < 0.5 and a.m or b.m
	else
		r = r.Unit
		local bk = r:Cross(u)
		if bk.Magnitude < 1e-9 then
			m = t < 0.5 and a.m or b.m
		else
			bk = bk.Unit
			u = bk:Cross(r)
			m = fromColumns(r, u, bk)
		end
	end
	return cf(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, m)
end
function CFrame.ToEulerAnglesYXZ(a)
	local m = a.m
	local x = math.asin(math.max(-1, math.min(1, -m[6])))
	local y, z
	if math.abs(m[6]) < 0.99999 then
		y = math.atan(m[3], m[9])
		z = math.atan(m[4], m[5])
	else
		y = math.atan(-m[7], m[1])
		z = 0
	end
	return x, y, z
end
CFrame.ToOrientation = CFrame.ToEulerAnglesYXZ
function CFrame.ToEulerAnglesXYZ(a)
	local m = a.m
	local y = math.asin(math.max(-1, math.min(1, m[3])))
	local x = math.atan(-m[6], m[9])
	local z = math.atan(-m[2], m[1])
	return x, y, z
end
function CFrame.Orthonormalize(a) return a end

local function cfNew(...)
	local n = select("#", ...)
	local a, b, c = ...
	if n == 0 then return cf(0, 0, 0, IDENT) end
	if n == 1 then
		if not isV3(a) then error("CFrame.new(Vector3) esperado, llego " .. type(a), 2) end
		return cf(a.X, a.Y, a.Z, IDENT)
	elseif n == 2 then
		if not (isV3(a) and isV3(b)) then error("CFrame.new(pos, lookAt) requiere dos Vector3", 2) end
		return lookAt(a, b)
	elseif n == 3 then
		return cf(num(a, "x"), num(b, "y"), num(c, "z"), IDENT)
	elseif n == 12 then
		local t = { ... }
		return cf(t[1], t[2], t[3], { table.unpack(t, 4, 12) })
	end
	error("CFrame.new: numero de argumentos no soportado (" .. n .. ")", 2)
end
D.CFrame = setmetatable({
	new = cfNew,
	identity = cf(0, 0, 0, IDENT),
	Angles = function(rx, ry, rz) return cf(0, 0, 0, matMul(matMul(rotX(num(rx)), rotY(num(ry))), rotZ(num(rz)))) end,
	fromEulerAnglesXYZ = function(rx, ry, rz) return cf(0, 0, 0, matMul(matMul(rotX(rx), rotY(ry)), rotZ(rz))) end,
	fromEulerAnglesYXZ = function(rx, ry, rz) return cf(0, 0, 0, matMul(matMul(rotY(ry), rotX(rx)), rotZ(rz))) end,
	fromOrientation = function(rx, ry, rz) return cf(0, 0, 0, matMul(matMul(rotY(ry), rotX(rx)), rotZ(rz))) end,
	lookAt = function(at, target, up)
		if not (isV3(at) and isV3(target)) then error("CFrame.lookAt requiere Vector3", 2) end
		return lookAt(at, target, up)
	end,
	lookAlong = function(at, dir, up) return lookAt(at, at + dir, up) end,
	fromMatrix = function(pos, vx, vy, vz)
		vz = vz or vx:Cross(vy).Unit
		return cf(pos.X, pos.Y, pos.Z, fromColumns(vx, vy, vz))
	end,
	fromAxisAngle = function(axis, angle)
		local u = axis.Unit
		local c, s = math.cos(angle), math.sin(angle)
		local t = 1 - c
		local x, y, z = u.X, u.Y, u.Z
		return cf(0, 0, 0, {
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c,
		})
	end,
}, { __index = function(_, k) error(tostring(k) .. " is not a valid member of CFrame (libreria)", 2) end })

---------------------------------------------------------------- Color3
local Color3 = class("Color3")
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
Color3.__index = function(_, k)
	local f = rawget(Color3, k)
	if f == nil then error(("%s is not a valid member of Color3"):format(tostring(k)), 2) end
	return f
end
Color3.__newindex = function() error("Color3 es inmutable", 2) end
Color3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3.__tostring = function(a) return ("%g, %g, %g"):format(a.R, a.G, a.B) end
function Color3.Lerp(a, b, t)
	if not isType(b, "Color3") then error("Color3:Lerp requiere Color3", 2) end
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function Color3.ToHSV(a)
	local r, g, b = a.R, a.G, a.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, (mx == 0) and 0 or d / mx, mx
end
function Color3.ToHex(a)
	return ("%02x%02x%02x"):format(math.floor(a.R * 255 + 0.5), math.floor(a.G * 255 + 0.5), math.floor(a.B * 255 + 0.5))
end
D.Color3 = setmetatable({
	new = function(r, g, b) return c3(num(r or 0), num(g or 0), num(b or 0)) end,
	fromRGB = function(r, g, b)
		num(r, "r") num(g, "g") num(b, "b")
		if r > 255 or g > 255 or b > 255 or r < 0 or g < 0 or b < 0 then
			error(("Color3.fromRGB fuera de rango: %s,%s,%s"):format(r, g, b), 2)
		end
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		num(h) num(s) num(v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p)
		elseif i == 2 then return c3(p, v, t) elseif i == 3 then return c3(p, q, v)
		elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}, { __index = function(_, k) error(tostring(k) .. " is not a valid member of Color3 (libreria)", 2) end })

---------------------------------------------------------------- UDim / UDim2
local UDim = class("UDim")
local function ud(s, o) return setmetatable({ Scale = s, Offset = o }, UDim) end
UDim.__index = function(_, k) error(("%s is not a valid member of UDim"):format(tostring(k)), 2) end
UDim.__add = function(a, b) return ud(a.Scale + b.Scale, a.Offset + b.Offset) end
UDim.__sub = function(a, b) return ud(a.Scale - b.Scale, a.Offset - b.Offset) end
UDim.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UDim.__tostring = function(a) return ("%g, %g"):format(a.Scale, a.Offset) end
D.UDim = { new = function(s, o) return ud(num(s or 0), num(o or 0)) end }

local UDim2 = class("UDim2")
local function ud2(x, y) return setmetatable({ X = x, Y = y, Width = x, Height = y }, UDim2) end
UDim2.__index = function(_, k)
	local f = rawget(UDim2, k)
	if f == nil then error(("%s is not a valid member of UDim2"):format(tostring(k)), 2) end
	return f
end
UDim2.__newindex = function() error("UDim2 es inmutable", 2) end
UDim2.__add = function(a, b) return ud2(a.X + b.X, a.Y + b.Y) end
UDim2.__sub = function(a, b) return ud2(a.X - b.X, a.Y - b.Y) end
UDim2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UDim2.__tostring = function(a) return ("{%s}, {%s}"):format(tostring(a.X), tostring(a.Y)) end
function UDim2.Lerp(a, b, t)
	return ud2(ud(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t),
		ud(a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t))
end
D.UDim2 = setmetatable({
	new = function(a, b, c, d)
		if isType(a, "UDim") then
			if not isType(b, "UDim") then error("UDim2.new(UDim, UDim) esperado", 2) end
			return ud2(a, b)
		end
		return ud2(ud(num(a or 0, "xScale"), num(b or 0, "xOffset")), ud(num(c or 0, "yScale"), num(d or 0, "yOffset")))
	end,
	fromScale = function(x, y) return ud2(ud(num(x), 0), ud(num(y), 0)) end,
	fromOffset = function(x, y) return ud2(ud(0, num(x)), ud(0, num(y))) end,
}, { __index = function(_, k) error(tostring(k) .. " is not a valid member of UDim2 (libreria)", 2) end })

---------------------------------------------------------------- Rect
local Rect = class("Rect")
D.Rect = {
	new = function(a, b, c, d)
		local mn, mx
		if isType(a, "Vector2") then mn, mx = a, b else mn, mx = v2(a or 0, b or 0), v2(c or 0, d or 0) end
		return setmetatable({ Min = mn, Max = mx, Width = mx.X - mn.X, Height = mx.Y - mn.Y }, Rect)
	end,
}

---------------------------------------------------------------- NumberRange / secuencias
local NumberRange = class("NumberRange")
NumberRange.__eq = function(a, b) return a.Min == b.Min and a.Max == b.Max end
D.NumberRange = {
	new = function(a, b)
		num(a, "min")
		b = b or a
		if b < a then error("NumberRange: max < min", 2) end
		return setmetatable({ Min = a, Max = b }, NumberRange)
	end,
}

local NSK = class("NumberSequenceKeypoint")
D.NumberSequenceKeypoint = {
	new = function(t, v, e)
		num(t, "time") num(v, "value")
		if t < 0 or t > 1 then error("NumberSequenceKeypoint: time fuera de [0,1]", 2) end
		return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSK)
	end,
}
local function checkKeypoints(kps, typeName)
	if #kps < 2 then error(typeName .. ": se requieren al menos 2 keypoints", 3) end
	if #kps > 20 then error(typeName .. ": maximo 20 keypoints", 3) end
	if kps[1].Time ~= 0 then error(typeName .. ": el primer keypoint debe tener Time = 0", 3) end
	if kps[#kps].Time ~= 1 then error(typeName .. ": el ultimo keypoint debe tener Time = 1", 3) end
	for i = 2, #kps do
		if kps[i].Time < kps[i - 1].Time then error(typeName .. ": keypoints deben estar en orden ascendente", 3) end
	end
end
local NumberSequence = class("NumberSequence")
D.NumberSequence = {
	new = function(a, b)
		local kps
		if type(a) == "number" then
			kps = { D.NumberSequenceKeypoint.new(0, a), D.NumberSequenceKeypoint.new(1, b or a) }
		elseif type(a) == "table" then
			for _, k in ipairs(a) do
				if not isType(k, "NumberSequenceKeypoint") then error("NumberSequence.new: se esperaba lista de NumberSequenceKeypoint", 2) end
			end
			kps = a
			checkKeypoints(kps, "NumberSequence")
		else
			error("NumberSequence.new: argumento invalido", 2)
		end
		return setmetatable({ Keypoints = kps }, NumberSequence)
	end,
}
local CSK = class("ColorSequenceKeypoint")
D.ColorSequenceKeypoint = {
	new = function(t, c)
		num(t, "time")
		if not isType(c, "Color3") then error("ColorSequenceKeypoint.new(time, Color3)", 2) end
		if t < 0 or t > 1 then error("ColorSequenceKeypoint: time fuera de [0,1]", 2) end
		return setmetatable({ Time = t, Value = c }, CSK)
	end,
}
local ColorSequence = class("ColorSequence")
D.ColorSequence = {
	new = function(a, b)
		local kps
		if isType(a, "Color3") then
			if b ~= nil and not isType(b, "Color3") then error("ColorSequence.new(Color3, Color3)", 2) end
			kps = { D.ColorSequenceKeypoint.new(0, a), D.ColorSequenceKeypoint.new(1, b or a) }
		elseif type(a) == "table" then
			for _, k in ipairs(a) do
				if not isType(k, "ColorSequenceKeypoint") then error("ColorSequence.new: se esperaba lista de ColorSequenceKeypoint", 2) end
			end
			kps = a
			checkKeypoints(kps, "ColorSequence")
		else
			error("ColorSequence.new: argumento invalido", 2)
		end
		return setmetatable({ Keypoints = kps }, ColorSequence)
	end,
}

---------------------------------------------------------------- Otros
local Ray = class("Ray")
D.Ray = { new = function(o, d) return setmetatable({ Origin = o or v3(0, 0, 0), Direction = d or v3(0, 0, -1) }, Ray) end }

local PhysicalProperties = class("PhysicalProperties")
D.PhysicalProperties = {
	new = function(density, friction, elasticity, fw, ew)
		return setmetatable({ Density = density, Friction = friction or 0.3, Elasticity = elasticity or 0.5,
			FrictionWeight = fw or 1, ElasticityWeight = ew or 1 }, PhysicalProperties)
	end,
}

local BrickColor = class("BrickColor")
local BRICK = {
	["White"] = { 1, 242, 243, 243 }, ["Black"] = { 26, 27, 42, 53 }, ["Really black"] = { 1003, 17, 17, 17 },
	["Medium stone grey"] = { 194, 163, 162, 165 }, ["Bright red"] = { 21, 196, 40, 28 },
	["Bright blue"] = { 23, 13, 105, 172 }, ["Bright yellow"] = { 24, 245, 205, 48 },
	["Bright green"] = { 37, 75, 151, 75 }, ["Really red"] = { 1004, 255, 0, 0 },
	["Institutional white"] = { 1001, 248, 248, 248 }, ["Cyan"] = { 1013, 4, 175, 236 },
}
D.BrickColor = {
	new = function(a, g, b)
		local name, rec = "Medium stone grey", nil
		if type(a) == "string" then
			name = a
			rec = BRICK[a]
			if not rec then error("BrickColor desconocido en simulador: " .. a, 2) end
		else
			rec = BRICK[name]
		end
		return setmetatable({ Name = name, Number = rec[1], Color = c3(rec[2] / 255, rec[3] / 255, rec[4] / 255),
			r = rec[2] / 255, g = rec[3] / 255, b = rec[4] / 255 }, BrickColor)
	end,
}

local DateTime = class("DateTime")
D.makeDateTime = function(nowFn)
	local function make(ts)
		local o = setmetatable({ UnixTimestamp = math.floor(ts), UnixTimestampMillis = math.floor(ts * 1000) }, DateTime)
		return o
	end
	function DateTime.ToUniversalTime(self)
		local t = os.date("!*t", self.UnixTimestamp)
		return { Year = t.year, Month = t.month, Day = t.day, Hour = t.hour, Minute = t.min, Second = t.sec, Millisecond = 0 }
	end
	function DateTime.FormatUniversalTime(self, fmt, _locale) return os.date("!%Y-%m-%d %H:%M:%S", self.UnixTimestamp) end
	DateTime.FormatLocalTime = DateTime.FormatUniversalTime
	function DateTime.ToIsoDate(self) return os.date("!%Y-%m-%dT%H:%M:%SZ", self.UnixTimestamp) end
	return {
		now = function() return make(nowFn()) end,
		fromUnixTimestamp = function(ts) return make(num(ts)) end,
		fromUnixTimestampMillis = function(ms) return make(num(ms) / 1000) end,
	}
end

return D
