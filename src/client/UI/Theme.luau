-- Theme: paleta, tipografias y medidas de la interfaz holografica (paneles oscuros, bordes luminosos).
local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(10, 14, 34),
	PanelLight = Color3.fromRGB(20, 27, 58),
	Row = Color3.fromRGB(24, 32, 66),
	RowHover = Color3.fromRGB(34, 46, 92),
	Cyan = Color3.fromRGB(70, 215, 255),
	Blue = Color3.fromRGB(60, 120, 255),
	Violet = Color3.fromRGB(150, 90, 255),
	Magenta = Color3.fromRGB(255, 80, 210),
	Gold = Color3.fromRGB(255, 200, 80),
	Green = Color3.fromRGB(90, 230, 140),
	Red = Color3.fromRGB(255, 85, 95),
	Text = Color3.fromRGB(240, 245, 255),
	TextDim = Color3.fromRGB(160, 175, 210),
	Dark = Color3.fromRGB(4, 6, 18),
	Energy = Color3.fromRGB(255, 210, 70),
	Stardust = Color3.fromRGB(200, 170, 255),
	Cores = Color3.fromRGB(110, 235, 255),
}

Theme.Fonts = {
	Title = Enum.Font.Michroma,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Black = Enum.Font.GothamBlack,
}

Theme.Corner = 12
Theme.Stroke = 2

-- estilos de boton: { color superior, color inferior, borde }
Theme.Buttons = {
	primary = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(88, 42, 190), Color3.fromRGB(205, 165, 255) },
	cyan = { Color3.fromRGB(60, 190, 255), Color3.fromRGB(26, 96, 200), Color3.fromRGB(160, 230, 255) },
	gold = { Color3.fromRGB(255, 200, 70), Color3.fromRGB(205, 120, 20), Color3.fromRGB(255, 232, 150) },
	green = { Color3.fromRGB(80, 220, 130), Color3.fromRGB(26, 140, 80), Color3.fromRGB(170, 255, 200) },
	danger = { Color3.fromRGB(255, 95, 105), Color3.fromRGB(175, 34, 54), Color3.fromRGB(255, 170, 175) },
	ghost = { Color3.fromRGB(34, 44, 88), Color3.fromRGB(20, 27, 58), Color3.fromRGB(90, 120, 200) },
	disabled = { Color3.fromRGB(62, 66, 84), Color3.fromRGB(40, 43, 58), Color3.fromRGB(90, 95, 115) },
}

return Theme
