-- Format: utilidades de formato de numeros y tiempo para la interfaz.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

-- 1234567 -> "1.23M"
function Format.number(n)
	if type(n) ~= "number" or n ~= n then return "0" end
	local neg = n < 0
	if neg then n = -n end
	local out
	if n < 1000 then
		if n >= 100 or n == math.floor(n) then
			out = string.format("%d", math.floor(n + 0.0001))
		else
			out = string.format("%.1f", n)
		end
	else
		local idx = 1
		while n >= 1000 and idx < #SUFFIXES do
			n = n / 1000
			idx = idx + 1
		end
		if n >= 100 then
			out = string.format("%d", math.floor(n)) .. SUFFIXES[idx]
		elseif n >= 10 then
			out = string.format("%.1f", math.floor(n * 10) / 10) .. SUFFIXES[idx]
		else
			out = string.format("%.2f", math.floor(n * 100) / 100) .. SUFFIXES[idx]
		end
	end
	if neg then out = "-" .. out end
	return out
end

function Format.rate(n)
	return Format.number(n) .. "/s"
end

-- 1234567 -> "1,234,567"
function Format.commas(n)
	local s = string.format("%d", math.floor(n))
	local out = s
	while true do
		local replaced
		out, replaced = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return out
end

-- 3725 -> "1h 02m"
function Format.duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

-- 754 -> "12:34"
function Format.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- 0.125 -> "12.5%"
function Format.percent(fraction, decimals)
	local pct = fraction * 100
	if decimals == nil then
		if pct >= 10 or pct == math.floor(pct) then decimals = pct == math.floor(pct) and 0 or 1
		elseif pct >= 1 then decimals = 1
		elseif pct >= 0.1 then decimals = 2
		else decimals = 3 end
	end
	return string.format("%." .. decimals .. "f%%", pct)
end

-- 1.5 -> "x1.5"
function Format.mult(m)
	if m == math.floor(m) then return "x" .. string.format("%d", m) end
	return "x" .. string.format("%.2f", m):gsub("0+$", "")
end

return Format
