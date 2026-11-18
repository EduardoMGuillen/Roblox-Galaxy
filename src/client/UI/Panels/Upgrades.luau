-- UpgradeUI: coste, nivel actual, siguiente mejora y efecto real. Dos pestañas: Energy y Cosmic Cores.
return function(ctx, parent)
	local Kit, State, Defs, Format, Theme = ctx.Kit, ctx.State, ctx.Defs, ctx.Format, ctx.Theme
	local C, F = Theme.Colors, Theme.Fonts
	local frame, body = Kit.panel(parent, { Name = "UpgradeUI", Size = UDim2.fromOffset(760, 540), Title = "Mejoras", Icon = "📈",
		OnClose = function() ctx.UI.close() end })
	local tab = 1
	local list = Kit.scroll(body, { Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), Padding = 8 })
	local balance = Kit.label(body, "", { Size = UDim2.fromOffset(300, 36), Position = UDim2.new(1, -300, 0, 0), TextSize = 15,
		AlignX = Enum.TextXAlignment.Right })
	local rows = {}

	local function effectText(def, level)
		local value = def.Effect(level)
		local kind = def.EffectKind
		if kind == "mult" then return Format.mult(value)
		elseif kind == "discount" then return "-" .. math.floor((1 - value) * 100 + 0.5) .. "%"
		elseif kind == "flat" then return "+" .. value
		elseif kind == "hours" then return "+" .. value .. " h"
		elseif kind == "add" then return "+" .. math.floor(value * 100 + 0.5) .. "%"
		end
		return "Nv " .. value
	end

	local function update()
		local data = State.Data
		balance.Text = tab == 1 and ("⚡ " .. Format.number(data.Energy)) or ("💠 " .. Format.number(data.Cores) .. " Cosmic Cores")
		balance.TextColor3 = tab == 1 and C.Energy or C.Cores
		for _, item in ipairs(rows) do
			local def = item.Def
			local level = Defs.Upgrades.level(data, def.Id)
			local maxed = level >= def.MaxLevel
			item.Level.Text = "Nv " .. level .. " / " .. def.MaxLevel
			item.Effect.Text = maxed and ("Efecto: " .. effectText(def, level) .. " (MÁX)")
				or ("Efecto: " .. effectText(def, level) .. "  →  " .. effectText(def, level + 1))
			if maxed then
				item.Button.Text = "MÁXIMO"
				Kit.setEnabled(item.Button, false)
			else
				local cost = def.Cost(level)
				item.Button.Text = (def.Currency == "Cores" and "💠 " or "⚡ ") .. Format.number(cost)
				Kit.setEnabled(item.Button, (def.Currency == "Cores" and data.Cores or data.Energy) >= cost)
			end
		end
	end

	local function build()
		Kit.clear(list)
		rows = {}
		local currency = tab == 1 and "Energy" or "Cores"
		for index, def in ipairs(Defs.Upgrades.List) do
			if def.Currency == currency then
				local row = Kit.box(list, C.Row, 0.1, { Size = UDim2.new(1, -6, 0, 76), LayoutOrder = index, Name = "Upgrade_" .. def.Id }, 10)
				Kit.label(row, def.Icon, { Size = UDim2.fromOffset(56, 76), Position = UDim2.fromOffset(6, 0), TextSize = 32, AlignX = Enum.TextXAlignment.Center })
				Kit.label(row, def.Name, { Size = UDim2.new(1, -330, 0, 24), Position = UDim2.fromOffset(66, 6), TextSize = 16 })
				Kit.label(row, def.Description, { Size = UDim2.new(1, -250, 0, 20), Position = UDim2.fromOffset(66, 30), TextSize = 12, Color = C.TextDim,
					Font = F.Body })
				local effect = Kit.label(row, "", { Size = UDim2.new(1, -250, 0, 20), Position = UDim2.fromOffset(66, 50), TextSize = 12, Color = C.Cyan })
				local level = Kit.label(row, "", { Size = UDim2.fromOffset(110, 22), Position = UDim2.new(1, -290, 0, 8), TextSize = 13,
					AlignX = Enum.TextXAlignment.Right, Color = C.Gold })
				local button
				button = Kit.button(row, "", def.Currency == "Cores" and "cyan" or "primary", { Size = UDim2.fromOffset(160, 48), Position = UDim2.new(1, -170, 0, 14),
					TextSize = 15, Props = { Name = "Buy" } }, function()
					local result = ctx.UI.request("PurchaseUpgrade", def.Id)
					if result.Ok and ctx.Audio then ctx.Audio.play("success") end
				end)
				table.insert(rows, { Def = def, Level = level, Effect = effect, Button = button })
			end
		end
		update()
	end

	Kit.tabs(body, { "⚡ Con Energy", "💠 Núcleos (permanentes)" }, function(index)
		tab = index
		build()
	end, { Size = UDim2.fromOffset(420, 36), Width = 200 })

	local last = 0
	State.onAny(function(changed)
		if not frame.Visible then return end
		if changed.Upgrades or changed.Cores or (changed.Energy and os.clock() - last > 0.3) then
			last = os.clock()
			update()
		end
	end)

	return { Frame = frame, OnOpen = build, Refresh = update }
end
