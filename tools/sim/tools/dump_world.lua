-- Vuelca todas las piezas del Workspace simulado a un archivo de texto (para la vista previa).
-- Uso: python3 tools/sim/run.py tools/sim/tools/dump_world.lua
local SIM = ...
SIM.loadProject()
SIM.quiet = true
SIM.start()
SIM.advance(1)
local p = SIM.addPlayer(7, "Preview")
SIM.advance(2)
SIM.assertNoErrors("dump")
local out = assert(io.open(SIM_ROOT .. "/tools/sim/data/world_dump.txt", "w"))
local ws = SIM.getService("Workspace")
local n = 0
for _, d in ipairs(SIM.Methods.Instance.GetDescendants(ws)) do
	local cls = rawget(d, "__class")
	if SIM.isA(cls, "BasePart") and not d:IsDescendantOf(rawget(p, "__props").Character or ws.CurrentCamera) then
		local shape = "Block"
		if cls == "Part" then shape = d.Shape.Name elseif cls == "WedgePart" then shape = "Wedge" end
		local gui = 0
		for _, c in ipairs(d:GetChildren()) do
			if c:IsA("SurfaceGui") then gui = 1 end
		end
		local mesh = d:FindFirstChildOfClass("SpecialMesh")
		local s = d.Size
		if mesh then
			-- la malla esferica se aproxima por una bola del radio final
			local r = mesh.Scale.X * 2
			s = Vector3.new(r, r, r)
			shape = "Ball"
		end
		local c = d.Color
		out:write(table.concat({ shape, s.X, s.Y, s.Z, table.concat({ d.CFrame:GetComponents() }, " "),
			c.R, c.G, c.B, d.Transparency, (d.Material == Enum.Material.Neon) and 1 or 0, gui }, " "), "\n")
		n = n + 1
	end
end
out:close()
print("piezas volcadas: " .. n)
