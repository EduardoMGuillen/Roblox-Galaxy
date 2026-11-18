-- MissionUI: objetivos diarios, semanales y de evento con progreso, recompensa y reclamacion.
return function(ctx, parent)
	local Kit, State, Defs, Format, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "MissionUI", Size = UDim2.fromOffset(760, 520), Title = "Misiones", Icon = "🏆",
		OnClose = function() ctx.UI.close() end })
	local tab = 1
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 46), Padding = 8 })
	local footer = Kit.label(body, "", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), TextSize = 12, Color = C.TextDim,
		Font = F.Body })

	local function row(order, text, progress, goal, reward, claimed, onClaim)
		local box = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 78), LayoutOrder = order, Name = "Mission" .. order }, 10)
		Kit.label(box, text, { Size = UDim2.new(1, -200, 0, 24), Position = UDim2.fromOffset(12, 8), TextSize = 15 })
		Kit.label(box, "Recompensa: " .. reward, { Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(12, 32), TextSize = 12,
			Color = C.Stardust })
		local _, set = Kit.progress(box, { Size = UDim2.new(1, -200, 0, 16), Position = UDim2.fromOffset(12, 54), Color = progress >= goal and C.Green or C.Cyan })
		set(goal > 0 and progress / goal or 0, Format.number(math.floor(progress)) .. " / " .. Format.number(goal))
		local done = progress >= goal
		local button = Kit.button(box, claimed and "✔ Reclamada" or (done and "Reclamar" or "En curso"), done and not claimed and "green" or "ghost",
			{ Size = UDim2.fromOffset(160, 44), Position = UDim2.new(1, -172, 0, 17), TextSize = 14, Props = { Name = "Claim" } }, onClaim)
		Kit.setEnabled(button, done and not claimed)
	end

	local function refresh()
		Kit.clear(list)
		local m = State.Data.Missions
		local now = State.serverTime()
		if tab <= 2 then
			local scope = tab == 1 and "daily" or "weekly"
			local missions = tab == 1 and m.Daily or m.Weekly
			for i, mission in ipairs(missions) do
				local template = Defs.Missions.ById[mission.Id]
				local text = template and string.format(template.Text, Format.number(mission.Goal)) or mission.Id
				row(i, text, mission.Progress, mission.Goal, "✨ " .. mission.Stardust .. "  +  ⚡ " .. Format.number(mission.Energy), mission.Claimed,
					function()
						local result = ctx.UI.request("ClaimMission", scope, i)
						if result.Ok then
							ctx.UI.toast("Misión completada: +" .. result.Data.Stardust .. " ✨ y +" .. Format.number(result.Data.Energy) .. " ⚡", "reward")
							if ctx.Audio then ctx.Audio.play("success") end
						end
					end)
			end
			local period = tab == 1 and 86400 or 604800
			local elapsed = tab == 1 and (now % 86400) or ((now + 3 * 86400) % 604800)
			footer.Text = "Se renuevan en " .. Format.duration(period - elapsed) .. ". No pierdes nada si un día no juegas."
		else
			local event = State.Data._Event
			if event and event.Id and now < (event.EndsAt or 0) then
				local def = Defs.Events.ById[event.Id]
				row(1, def.Icon .. " " .. string.format(def.Objective.Text, def.Objective.Goal), m.EventProgress or 0, def.Objective.Goal,
					"✨ " .. def.RewardStardust, m.EventClaimed == true, function()
						local result = ctx.UI.request("ClaimMission", "event", 1)
						if result.Ok then
							ctx.UI.toast("Objetivo de evento completado: +" .. result.Data.Stardust .. " ✨", "reward")
						end
					end)
				footer.Text = def.Name .. " termina en " .. Format.clock(event.EndsAt - now) .. "."
			else
				Kit.label(list, "No hay ningún evento activo ahora mismo.", { Size = UDim2.new(1, 0, 0, 40), TextSize = 14, Color = C.TextDim,
					AlignX = Enum.TextXAlignment.Center })
				local nextDef = event and Defs.Events.ById[event.NextId]
				footer.Text = nextDef and ("Próximo evento: " .. nextDef.Name .. " en " .. Format.clock(math.max(0, event.NextStartsAt - now))) or ""
			end
		end
	end

	Kit.tabs(body, { "Diarias", "Semanales", "Evento" }, function(index)
		tab = index
		refresh()
	end, { Size = UDim2.fromOffset(400, 36), Width = 124 })

	State.onAny(function(changed)
		if frame.Visible and (changed.Missions or changed._Event) then refresh() end
	end)

	return { Frame = frame, OnOpen = refresh, Refresh = refresh }
end
