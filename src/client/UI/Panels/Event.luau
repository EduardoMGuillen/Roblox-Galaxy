-- Event Terminal: evento activo, temporizador (tiempo de servidor), descripcion, objetivo, recompensa
-- y proximo evento programado.
return function(ctx, parent)
	local RunService = game:GetService("RunService")
	local Kit, State, Defs, Format, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "EventUI", Size = UDim2.fromOffset(680, 520), Title = "Event Terminal", Icon = "☄️",
		OnClose = function() ctx.UI.close() end })
	local timerLabel = nil
	local currentKey = nil

	local function activeEvent()
		local event = State.Data._Event
		if event and event.Id and State.serverTime() < (event.EndsAt or 0) then
			return Defs.Events.ById[event.Id], event
		end
		return nil, event
	end

	local function refresh()
		Kit.clear(body)
		timerLabel = nil
		local def, event = activeEvent()
		currentKey = def and def.Id or "none"
		local y = 0
		if def then
			local box = Kit.box(body, C.Row, 0.1, { Size = UDim2.new(1, 0, 0, 190) }, 12)
			Kit.stroke(box, def.Color, 2, 0)
			Kit.label(box, def.Icon, { Size = UDim2.fromOffset(90, 90), Position = UDim2.fromOffset(10, 8), TextSize = 56, AlignX = Enum.TextXAlignment.Center })
			Kit.label(box, string.upper(def.Name), { Size = UDim2.new(1, -260, 0, 32), Position = UDim2.fromOffset(104, 12), TextSize = 22, Font = F.Title,
				Color = def.Color })
			Kit.label(box, def.Description, { Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(104, 46), TextSize = 13, Wrap = true,
				Color = C.TextDim, Font = F.Body, AlignY = Enum.TextYAlignment.Top })
			timerLabel = Kit.label(box, "", { Size = UDim2.fromOffset(140, 32), Position = UDim2.new(1, -152, 0, 12), TextSize = 22, Font = F.Black,
				AlignX = Enum.TextXAlignment.Right, Color = C.Gold })
			local m = State.Data.Missions
			local progress = m.EventProgress or 0
			local goal = def.Objective.Goal
			Kit.label(box, "Objetivo: " .. string.format(def.Objective.Text, goal) .. "   ·   Recompensa: ✨ " .. def.RewardStardust,
				{ Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 104), TextSize = 13 })
			local _, set = Kit.progress(box, { Size = UDim2.new(1, -200, 0, 20), Position = UDim2.fromOffset(12, 134), Color = progress >= goal and C.Green or def.Color })
			set(progress / goal, progress .. " / " .. goal)
			local claim = Kit.button(box, m.EventClaimed and "✔ Reclamado" or "Reclamar", "green", { Size = UDim2.fromOffset(160, 40),
				Position = UDim2.new(1, -172, 0, 124), TextSize = 14, Props = { Name = "Claim" } }, function()
				local result = ctx.UI.request("ClaimMission", "event", 1)
				if result.Ok then
					ctx.UI.toast("Objetivo de evento completado: +" .. result.Data.Stardust .. " ✨", "reward")
				end
			end)
			Kit.setEnabled(claim, progress >= goal and not m.EventClaimed)
			y = 202
		else
			local box = Kit.box(body, C.Row, 0.1, { Size = UDim2.new(1, 0, 0, 96) }, 12)
			Kit.label(box, "No hay ningún evento activo.", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 12), TextSize = 17 })
			local nextDef = event and Defs.Events.ById[event.NextId]
			if nextDef then
				Kit.label(box, "Próximo: " .. nextDef.Icon .. " " .. nextDef.Name, { Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(12, 50),
					TextSize = 15, Color = nextDef.Color })
				timerLabel = Kit.label(box, "", { Size = UDim2.fromOffset(160, 32), Position = UDim2.new(1, -172, 0, 46), TextSize = 22, Font = F.Black,
					AlignX = Enum.TextXAlignment.Right, Color = C.Cyan })
			end
			y = 108
		end
		Kit.label(body, "CALENDARIO DE EVENTOS CÓSMICOS", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, y), TextSize = 12, Font = F.Title,
			Color = C.Cyan })
		for i, e in ipairs(Defs.Events.List) do
			local row = Kit.box(body, C.Row, 0.25, { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, y + 26 + (i - 1) * 52) }, 8)
			Kit.label(row, e.Icon .. "  " .. e.Name, { Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(12, 0), TextSize = 14, Color = e.Color })
			Kit.label(row, e.Description, { Size = UDim2.new(1, -230, 1, 0), Position = UDim2.fromOffset(216, 0), TextSize = 11, Wrap = true,
				Color = C.TextDim, Font = F.Body })
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not frame.Visible then return end
		accumulator = accumulator + dt
		if accumulator < 0.25 then return end
		accumulator = 0
		local def, event = activeEvent()
		local key = def and def.Id or "none"
		if key ~= currentKey then
			refresh()
			return
		end
		if timerLabel and event then
			local now = State.serverTime()
			timerLabel.Text = Format.clock(def and (event.EndsAt - now) or math.max(0, event.NextStartsAt - now))
		end
	end)

	State.onAny(function(changed)
		if frame.Visible and (changed.Missions or changed._Event) then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
