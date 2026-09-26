local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local Library: any = {}
Library.Version  = "1.0.0"
Library.Flags    = {}
Library.Elements = {}
Library.Registry = {}
Library.Windows  = {}

Library.Theme = {
	Accent      = Color3.fromRGB(138, 108, 255),
	Background  = Color3.fromRGB(14, 14, 18),
	Surface     = Color3.fromRGB(22, 22, 28),
	SurfaceAlt  = Color3.fromRGB(30, 30, 38),
	SurfaceHigh = Color3.fromRGB(40, 40, 50),
	Outline     = Color3.fromRGB(48, 48, 60),
	Text        = Color3.fromRGB(238, 238, 245),
	TextDim     = Color3.fromRGB(148, 148, 165),
	Good        = Color3.fromRGB(90, 210, 140),
	Warn        = Color3.fromRGB(235, 190, 90),
	Bad         = Color3.fromRGB(235, 90, 90),
	Font        = Enum.Font.Gotham,
	FontMedium  = Enum.Font.GothamMedium,
	FontBold    = Enum.Font.GothamBold,
	Radius      = 8,
}

-- Snapshot of default colors so a "reset" is possible
Library.DefaultTheme = {}
for k, v in pairs(Library.Theme) do Library.DefaultTheme[k] = v end

-- Registry of instances whose properties follow the theme
Library._themed = setmetatable({}, { __mode = "k" })

-- Global toggle keybind (changeable from the config tab)
Library.ToggleKeybind = "RightShift"
Library._keybindListening = false

local function new(class, props)
	local inst = Instance.new(class)
	local parent
	local themed
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
			-- Auto-detect theme colors so RefreshTheme can repaint live
			if typeof(v) == "Color3" then
				for tk, tv in pairs(Library.Theme) do
					if typeof(tv) == "Color3" and tv == v then
						if not themed then themed = {} end
						table.insert(themed, { Prop = k, Key = tk })
						break
					end
				end
			end
		end
	end
	if themed then Library._themed[inst] = themed end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or Library.Theme.Radius), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color or Library.Theme.Outline,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function padding(parent, t, r, b, l)
	t = t or 0; r = r or t; b = b or t; l = l or r
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l),
		Parent = parent,
	})
end

local function tween(inst, props, time, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(
		time or 0.15,
		style or Enum.EasingStyle.Quad,
		dir or Enum.EasingDirection.Out
	), props)
	t:Play()
	return t
end

local function createScreenGui(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name or "PrismUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999

	local ok = pcall(function()
		if typeof(gethui) == "function" then
			gui.Parent = gethui()
		elseif typeof(syn) == "table" and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = game:GetService("CoreGui")
		else
			gui.Parent = game:GetService("CoreGui")
		end
	end)
	if not ok then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	return gui
end

local function addRow(section, height)
	section._order = (section._order or 0) + 1
	return new("Frame", {
		Parent = section.Container,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 30),
		LayoutOrder = section._order,
	})
end

local function rowLabel(row, text, theme)
	return new("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 0, 18),
		Position = UDim2.fromOffset(0, 0),
		Font = theme.FontMedium,
		Text = text or "",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local Element = {}
Element.__index = Element

function Element.new(config)
	config = config or {}
	local self = setmetatable({}, Element)
	self.Flag = config.Flag
	self.Callbacks = {}
	self.Value = nil
	if config.OnChanged then table.insert(self.Callbacks, config.OnChanged) end
	return self
end

function Element:OnChanged(fn) table.insert(self.Callbacks, fn) return self end

function Element:Fire(value)
	self.Value = value
	if self.Flag then Library.Flags[self.Flag] = value end
	for _, fn in ipairs(self.Callbacks) do task.spawn(fn, value) end
end

local function finishElement(el, config)
	if config and config.Flag then
		Library.Elements[config.Flag] = el
		Library.Flags[config.Flag] = el.Value
	end
	return el
end

function Library:RegisterElement(name, constructor, aliases)
	assert(type(name) == "string")
	assert(type(constructor) == "function")
	Library.Registry[name] = constructor
	if aliases then for _, a in ipairs(aliases) do Library.Registry[a] = constructor end end
end

local Window = {}
Window.__index = Window

function Library:CreateWindow(config)
	config = config or {}
	local theme = Library.Theme
	local gui = createScreenGui(config.Name or "PrismUI")

	local self = setmetatable({}, Window)
	self.Gui = gui
	self.Tabs = {}
	self.ActiveTab = nil
	self.Connections = {}

	local main = new("Frame", {
		Name = "Window", Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = config.Size or UDim2.fromOffset(640, 440),
		BackgroundColor3 = theme.Background, BorderSizePixel = 0,
	})
	corner(main, 12)
	stroke(main, theme.Outline, 1)
	self.Instance = main
	self.MainFrame = main

	local topbar = new("Frame", {
		Name = "Topbar", Parent = main,
		Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
	})
	new("Frame", {
		Parent = topbar, Position = UDim2.new(0, 12, 1, -1),
		Size = UDim2.new(1, -24, 0, 1),
		BackgroundColor3 = theme.Outline, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	})
	corner(new("Frame", {
		Parent = topbar, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = theme.Accent, BorderSizePixel = 0,
	}), 4)
	new("TextLabel", {
		Parent = topbar, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = theme.FontBold,
		Text = config.Title or config.Name or "Prism",
		TextColor3 = theme.Text, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local function makeTopButton(xOffset, colorOnHover)
		local b = new("TextButton", {
			Parent = topbar, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = theme.Surface, BackgroundTransparency = 0.3,
			Text = "", AutoButtonColor = false,
		})
		corner(b, 6)
		return b, colorOnHover
	end

	local minimizeBtn, minHover = makeTopButton(-46, theme.SurfaceHigh)
	local minBar = new("Frame", {
		Parent = minimizeBtn,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 1.5),
		BackgroundColor3 = theme.TextDim,
		BorderSizePixel = 0,
	})
	corner(minBar, 1)

	local closeBtn, closeHover = makeTopButton(-12, theme.Bad)
	local xLine1 = new("Frame", {
		Parent = closeBtn,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 1.5),
		BackgroundColor3 = theme.TextDim,
		BorderSizePixel = 0,
		Rotation = 45,
	})
	corner(xLine1, 1)
	local xLine2 = new("Frame", {
		Parent = closeBtn,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 1.5),
		BackgroundColor3 = theme.TextDim,
		BorderSizePixel = 0,
		Rotation = -45,
	})
	corner(xLine2, 1)

	minimizeBtn.MouseEnter:Connect(function()
		tween(minimizeBtn, { BackgroundColor3 = theme.SurfaceHigh }, 0.12)
		minBar.BackgroundColor3 = theme.Text
	end)
	minimizeBtn.MouseLeave:Connect(function()
		tween(minimizeBtn, { BackgroundColor3 = theme.Surface }, 0.12)
		minBar.BackgroundColor3 = theme.TextDim
	end)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, { BackgroundColor3 = theme.Bad }, 0.12)
		xLine1.BackgroundColor3 = theme.Text
		xLine2.BackgroundColor3 = theme.Text
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, { BackgroundColor3 = theme.Surface }, 0.12)
		xLine1.BackgroundColor3 = theme.TextDim
		xLine2.BackgroundColor3 = theme.TextDim
	end)

	local sidebar = new("Frame", {
		Name = "Sidebar", Parent = main,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(0, 150, 1, -42),
		BackgroundTransparency = 1,
	})
	padding(sidebar, 10, 8, 10, 8)

	local sidebarList = new("Frame", { Parent = sidebar, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	new("UIListLayout", { Parent = sidebarList, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

	local content = new("Frame", {
		Name = "Content", Parent = main,
		Position = UDim2.fromOffset(150, 42),
		Size = UDim2.new(1, -150, 1, -42),
		BackgroundTransparency = 1,
	})

	self.Sidebar = sidebarList
	self.Content = content

	local dragging, dragStart, startPos
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	topbar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))

	local minimized = false
	local fullSize = main.Size

	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			fullSize = main.Size
			sidebar.Visible = false
			content.Visible = false
			tween(main, { Size = UDim2.new(fullSize.X.Scale, fullSize.X.Offset, 0, 42) }, 0.18)
		else
			sidebar.Visible = true
			content.Visible = true
			tween(main, { Size = fullSize }, 0.18)
		end
	end)
	closeBtn.MouseButton1Click:Connect(function() self:Destroy() end)

	table.insert(Library.Windows, self)
	return self
end

function Window:Destroy()
	for _, c in ipairs(self.Connections) do
		if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
	end
	self.Connections = {}
	if self.Gui then self.Gui:Destroy() end
	for i, w in ipairs(Library.Windows) do
		if w == self then table.remove(Library.Windows, i) break end
	end
end

local Tab = {}
Tab.__index = Tab

function Window:Tab(name, icon)
	if type(name) == "table" then name, icon = name.Name, name.Icon end
	name = name or "Tab"

	local theme = Library.Theme
	local window = self
	local tab = setmetatable({}, Tab)
	tab.Window = window
	tab.Name = name
	tab._order = 0
	tab.SubTabs = {}
	tab.ActiveSubTab = nil

	local button = new("TextButton", {
		Parent = window.Sidebar,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = theme.Surface, BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false,
		LayoutOrder = #window.Tabs + 1,
	})
	corner(button, 6)

	local indicator = new("Frame", {
		Parent = button, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = theme.Accent, BorderSizePixel = 0,
	})
	corner(indicator, 2)

	if icon and (string.find(icon, "rbxasset") or string.find(icon, "http")) then
		new("ImageLabel", {
			Parent = button, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Image = icon, ImageColor3 = theme.TextDim,
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		new("TextLabel", {
			Parent = button, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Font = theme.FontBold,
			Text = icon or "", TextColor3 = theme.TextDim, TextSize = 13,
		})
	end

	local label = new("TextLabel", {
		Parent = button, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 36, 0.5, 0),
		Size = UDim2.new(1, -44, 1, 0),
		BackgroundTransparency = 1,
		Font = theme.FontMedium,
		Text = name, TextColor3 = theme.TextDim, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local pageContainer = new("Frame", {
		Parent = window.Content, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Visible = false,
	})

	local directScroll = new("ScrollingFrame", {
		Parent = pageContainer, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Outline,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	new("UIListLayout", { Parent = directScroll, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	padding(directScroll, 4, 12, 16, 12)

	local subBar = new("Frame", {
		Parent = pageContainer, Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1, Visible = false,
	})
	new("UIListLayout", {
		Parent = subBar, Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	padding(subBar, 4, 14, 4, 14)

	local subPages = new("Frame", {
		Parent = pageContainer,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1, Visible = false,
	})

	tab.Button = button
	tab.Label = label
	tab.Indicator = indicator
	tab.Page = pageContainer
	tab.DirectScroll = directScroll
	tab.SubBar = subBar
	tab.SubPages = subPages

	button.MouseEnter:Connect(function()
		if window.ActiveTab ~= tab then
			tween(button, { BackgroundTransparency = 0.5, BackgroundColor3 = theme.Surface }, 0.12)
			tween(label, { TextColor3 = theme.Text }, 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		if window.ActiveTab ~= tab then
			tween(button, { BackgroundTransparency = 1 }, 0.12)
			tween(label, { TextColor3 = theme.TextDim }, 0.12)
		end
	end)
	button.MouseButton1Click:Connect(function() tab:Select() end)

	table.insert(window.Tabs, tab)
	if not window.ActiveTab then tab:Select() end
	return tab
end

function Tab:SetActive(active)
	local theme = Library.Theme
	self.Page.Visible = active
	if active then
		tween(self.Button, { BackgroundTransparency = 0.15, BackgroundColor3 = theme.SurfaceAlt }, 0.15)
		tween(self.Label, { TextColor3 = theme.Text }, 0.15)
		tween(self.Indicator, { Size = UDim2.fromOffset(3, 16) }, 0.2)
	else
		tween(self.Button, { BackgroundTransparency = 1 }, 0.15)
		tween(self.Label, { TextColor3 = theme.TextDim }, 0.15)
		tween(self.Indicator, { Size = UDim2.fromOffset(3, 0) }, 0.2)
	end
end

function Tab:Select()
	if self.Window.ActiveTab == self then return end
	self.Window.ActiveTab = self
	for _, t in ipairs(self.Window.Tabs) do t:SetActive(t == self) end
end

function Window:SelectTab(name)
	for _, t in ipairs(self.Tabs) do
		if t.Name == name then t:Select() return t end
	end
	return nil
end

local Section = {}
Section.__index = function(tbl, key)
	local method = rawget(Section, key)
	if method then return method end
	local ctor = Library.Registry[key]
	if ctor then
		return function(section, config) return ctor(section, config) end
	end
	return nil
end

local function makeSection(page, owner, sname, order, window)
	local theme = Library.Theme
	local section = setmetatable({}, Section)
	section.Page = page
	section.Window = window
	section.Tab = owner
	section._order = order or 0

	local frame = new("Frame", {
		Parent = page, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Surface, BorderSizePixel = 0,
		LayoutOrder = section._order,
	})
	corner(frame, 10)
	stroke(frame, theme.Outline, 1, 0.3)
	padding(frame, 10, 12, 12, 12)
	new("UIListLayout", { Parent = frame, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	if sname then
		new("TextLabel", {
			Parent = frame, Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1, Font = theme.FontBold,
			Text = sname, TextColor3 = theme.Text, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1000,
		})
	end

	local container = new("Frame", {
		Parent = frame, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = -999,
	})
	new("UIListLayout", { Parent = container, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

	section.Instance = frame
	section.Container = container
	return section
end

function Tab:Section(name, _side)
	if #self.SubTabs > 0 and self.ActiveSubTab then
		return self.ActiveSubTab:Section(name)
	end
	self._order = (self._order or 0) + 1
	return makeSection(self.DirectScroll, self, name, self._order, self.Window)
end

function Tab:SubTab(name)
	name = name or "Sub"
	local theme = Library.Theme

	if #self.SubTabs == 0 then
		self.DirectScroll.Visible = false
		self.SubBar.Visible = true
		self.SubPages.Visible = true
	end

	local sub = { Tab = self, Window = self.Window, Name = name, _order = 0 }

	local btn = new("TextButton", {
		Parent = self.SubBar, Size = UDim2.new(0, 96, 0, 24),
		BackgroundColor3 = theme.Surface, BackgroundTransparency = 0.5,
		Text = name, Font = theme.FontMedium, TextSize = 12,
		TextColor3 = theme.TextDim, AutoButtonColor = false,
		LayoutOrder = #self.SubTabs + 1,
	})
	corner(btn, 6)

	local page = new("ScrollingFrame", {
		Parent = self.SubPages, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Outline,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	})
	new("UIListLayout", { Parent = page, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	padding(page, 4, 12, 16, 12)

	sub.Button = btn
	sub.Page = page

	function sub:Section(sname, _side)
		self._order = (self._order or 0) + 1
		return makeSection(self.Page, self, sname, self._order, self.Window)
	end

	function sub:SetActive(active)
		self.Page.Visible = active
		if active then
			tween(self.Button, { BackgroundColor3 = theme.SurfaceAlt, BackgroundTransparency = 0.1, TextColor3 = theme.Text }, 0.12)
		else
			tween(self.Button, { BackgroundColor3 = theme.Surface, BackgroundTransparency = 0.5, TextColor3 = theme.TextDim }, 0.12)
		end
	end

	function sub:Select()
		if self.Tab.ActiveSubTab == self then return end
		self.Tab.ActiveSubTab = self
		for _, s in ipairs(self.Tab.SubTabs) do s:SetActive(s == self) end
	end

	btn.MouseButton1Click:Connect(function() sub:Select() end)
	btn.MouseEnter:Connect(function()
		if self.ActiveSubTab ~= sub then
			tween(btn, { BackgroundTransparency = 0.3, TextColor3 = theme.Text }, 0.1)
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.ActiveSubTab ~= sub then
			tween(btn, { BackgroundTransparency = 0.5, TextColor3 = theme.TextDim }, 0.1)
		end
	end)

	table.insert(self.SubTabs, sub)
	if not self.ActiveSubTab then sub:Select() end
	return sub
end

--=====================================================================
-- ELEMENTS
--=====================================================================

Library:RegisterElement("Toggle", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local value = config.Default == true

	local row = addRow(section, 30)
	rowLabel(row, config.Name or "Toggle", theme)

	local switch = new("TextButton", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = value and theme.Accent or theme.SurfaceHigh,
		Text = "", AutoButtonColor = false,
	})
	corner(switch, 10)

	local knob = new("Frame", {
		Parent = switch, AnchorPoint = Vector2.new(0, 0.5),
		Position = value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	})
	corner(knob, 8)

	local function render(animate)
		local on = value == true
		local kg = { Position = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }
		local bg = { BackgroundColor3 = on and theme.Accent or theme.SurfaceHigh }
		if animate then tween(knob, kg, 0.15); tween(switch, bg, 0.15)
		else knob.Position = kg.Position; switch.BackgroundColor3 = bg.BackgroundColor3 end
	end

	el.Value = value
	el.Instance = row
	function el:Set(v, silent) value = v and true or false; render(true); if not silent then self:Fire(value) end end
	function el:Get() return value end

	switch.MouseButton1Click:Connect(function()
		value = not value
		render(true)
		el:Fire(value)
	end)
	render(false)
	return finishElement(el, config)
end)

Library:RegisterElement("Button", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local row = addRow(section, 30)

	local btn = new("TextButton", {
		Parent = row, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.SurfaceAlt,
		Text = config.Name or "Button",
		Font = theme.FontMedium, TextSize = 13,
		TextColor3 = theme.Text, AutoButtonColor = false,
	})
	corner(btn, 6)
	stroke(btn, theme.Outline, 1, 0.4)

	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = theme.SurfaceHigh }, 0.12) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = theme.SurfaceAlt }, 0.12) end)
	btn.MouseButton1Click:Connect(function()
		tween(btn, { BackgroundColor3 = theme.Accent }, 0.08)
		task.delay(0.1, function() tween(btn, { BackgroundColor3 = theme.SurfaceHigh }, 0.15) end)
		if config.Callback then task.spawn(config.Callback) end
		el:Fire(true)
	end)

	el.Instance = row
	el.Button = btn
	return finishElement(el, config)
end)

Library:RegisterElement("Slider", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)

	local min, max = config.Min or 0, config.Max or 100
	local decimals = config.Decimals or 0
	local suffix = config.Suffix or ""
	local value = math.clamp(config.Default or min, min, max)

	local row = addRow(section, 42)
	rowLabel(row, config.Name or "Slider", theme)

	local valueLabel = new("TextLabel", {
		Parent = row, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.4, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = theme.Font, Text = tostring(value) .. suffix,
		TextColor3 = theme.TextDim, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local track = new("Frame", {
		Parent = row, Position = UDim2.new(0, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = theme.SurfaceHigh, BorderSizePixel = 0,
	})
	corner(track, 3)

	local fill = new("Frame", {
		Parent = track, Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Accent, BorderSizePixel = 0,
	})
	corner(fill, 3)

	local knob = new("Frame", {
		Parent = track, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	})
	corner(knob, 6)

	local hit = new("TextButton", {
		Parent = row, Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1, Text = "",
	})

	local function render()
		local pct = (max == min) and 0 or (value - min) / (max - min)
		fill.Size = UDim2.fromScale(pct, 1)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		local shown = decimals > 0 and string.format("%." .. decimals .. "f", value) or tostring(math.floor(value + 0.5))
		valueLabel.Text = shown .. suffix
	end

	local function fromInput(input)
		local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		rel = math.clamp(rel, 0, 1)
		local raw = min + (max - min) * rel
		if decimals > 0 then
			local m = 10 ^ decimals
			raw = math.floor(raw * m + 0.5) / m
		else
			raw = math.floor(raw + 0.5)
		end
		el:Set(raw)
	end

	local dragging = false
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end)
	local c1 = UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			fromInput(input)
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	el.Instance = row
	el._conns = { c1, c2 }
	el.Value = value
	function el:Set(v, silent) value = math.clamp(tonumber(v) or min, min, max); render(); if not silent then self:Fire(value) end end
	function el:Get() return value end
	render()
	return finishElement(el, config)
end)

Library:RegisterElement("Dropdown", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)

	local options = config.Options or {}
	local multi = config.Multi == true
	local maxVisible = config.MaxVisible or 6
	local ROW_H, OPT_H = 30, 26

	local value
	if multi then
		value = type(config.Default) == "table" and table.clone(config.Default) or {}
	else
		value = config.Default
	end

	local row = new("Frame", {
		Parent = section.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_H), ClipsDescendants = false,
	})
	section._order = (section._order or 0) + 1
	row.LayoutOrder = section._order

	local header = new("TextButton", {
		Parent = row, Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundTransparency = 1, Text = "",
	})
	rowLabel(header, config.Name or "Dropdown", theme)

	local valueLabel = new("TextLabel", {
		Parent = header, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = theme.Font, Text = "",
		TextColor3 = theme.TextDim, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local arrow = new("TextLabel", {
		Parent = header, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Font = theme.FontBold, Text = "v",
		TextColor3 = theme.TextDim, TextSize = 12,
	})

	local list = new("Frame", {
		Parent = row, Position = UDim2.fromOffset(0, ROW_H + 2),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = theme.SurfaceAlt, BorderSizePixel = 0,
		ClipsDescendants = true, Visible = false,
	})
	corner(list, 6)
	stroke(list, theme.Outline, 1, 0.5)
	new("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	padding(list, 4, 4, 4, 4)

	local optionButtons = {}
	local expanded = false

	local function computeListHeight() return math.min(#options, maxVisible) * (OPT_H + 2) + 8 end
	local function updateDisplay()
		if multi then
			if #value == 0 then valueLabel.Text = config.Placeholder or "None"
			elseif #value <= 2 then valueLabel.Text = table.concat(value, ", ")
			else valueLabel.Text = tostring(#value) .. " selected" end
		else
			valueLabel.Text = value or (config.Placeholder or "None")
		end
	end

	local function renderOptions()
		for opt, btn in pairs(optionButtons) do
			local selected = multi and table.find(value, opt) ~= nil or (value == opt)
			btn.BackgroundColor3 = selected and theme.Accent or theme.Surface
			btn.TextColor3 = selected and Color3.new(1, 1, 1) or theme.Text
		end
	end

	local function buildOptions()
		for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		optionButtons = {}
		for i, opt in ipairs(options) do
			local btn = new("TextButton", {
				Parent = list, Size = UDim2.new(1, 0, 0, OPT_H),
				BackgroundColor3 = theme.Surface,
				Text = tostring(opt), Font = theme.Font, TextSize = 12,
				TextColor3 = theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false, LayoutOrder = i,
			})
			corner(btn, 5)
			padding(btn, 0, 8, 0, 8)

			btn.MouseEnter:Connect(function()
				if not (multi and table.find(value, opt)) and value ~= opt then
					tween(btn, { BackgroundColor3 = theme.SurfaceHigh }, 0.1)
				end
			end)
			btn.MouseLeave:Connect(function() renderOptions() end)

			btn.MouseButton1Click:Connect(function()
				if multi then
					local idx = table.find(value, opt)
					if idx then table.remove(value, idx) else table.insert(value, opt) end
					renderOptions()
					updateDisplay()
					el:Fire(table.clone(value))
				else
					value = opt
					renderOptions()
					updateDisplay()
					el:Fire(value)
					el:SetExpanded(false)
				end
			end)
			optionButtons[opt] = btn
		end
		renderOptions()
	end

	local function setExpanded(state)
		expanded = state
		local h = computeListHeight()
		if expanded then
			list.Visible = true
			tween(list, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
			tween(row, { Size = UDim2.new(1, 0, 0, ROW_H + 2 + h) }, 0.18)
			tween(arrow, { Rotation = 180 }, 0.18)
		else
			tween(list, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
			tween(row, { Size = UDim2.new(1, 0, 0, ROW_H) }, 0.15)
			tween(arrow, { Rotation = 0 }, 0.15)
			task.delay(0.16, function() if not expanded then list.Visible = false end end)
		end
	end

	header.MouseButton1Click:Connect(function() setExpanded(not expanded) end)

	el.Instance = row
	el.Value = value
	el.SetExpanded = setExpanded

	function el:Set(v, silent)
		value = v
		if multi and type(value) ~= "table" then value = {} end
		updateDisplay()
		renderOptions()
		if not silent then self:Fire(multi and table.clone(value) or value) end
	end
	function el:Get() return multi and table.clone(value) or value end
	function el:SetOptions(newOptions)
		options = newOptions or {}
		buildOptions()
		updateDisplay()
		if expanded then
			local h = computeListHeight()
			list.Size = UDim2.new(1, 0, 0, h)
			row.Size = UDim2.new(1, 0, 0, ROW_H + 2 + h)
		end
	end

	buildOptions()
	updateDisplay()
	return finishElement(el, config)
end)

Library:RegisterElement("Input", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local value = tostring(config.Default or "")

	local row = addRow(section, 30)
	rowLabel(row, config.Name or "Input", theme)

	local box = new("Frame", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 24),
		BackgroundColor3 = theme.SurfaceAlt, BorderSizePixel = 0,
	})
	corner(box, 6)
	stroke(box, theme.Outline, 1, 0.5)

	local textbox = new("TextBox", {
		Parent = box, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Font = theme.Font,
		Text = value, TextSize = 12, TextColor3 = theme.Text,
		PlaceholderText = config.Placeholder or "Enter...",
		PlaceholderColor3 = theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	})
	padding(textbox, 0, 8, 0, 8)

	textbox.Focused:Connect(function() tween(box, { BackgroundColor3 = theme.SurfaceHigh }, 0.12) end)
	textbox.FocusLost:Connect(function(enterPressed)
		tween(box, { BackgroundColor3 = theme.SurfaceAlt }, 0.12)
		value = textbox.Text
		if config.OnEnter and not enterPressed then return end
		el:Fire(value)
	end)

	el.Instance = row
	el.TextBox = textbox
	el.Value = value
	function el:Set(v, silent) value = tostring(v or ""); textbox.Text = value; if not silent then self:Fire(value) end end
	function el:Get() return value end
	return finishElement(el, config)
end)

Library:RegisterElement("Keybind", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local value = config.Default or "None"
	local listening = false

	local row = addRow(section, 30)
	rowLabel(row, config.Name or "Keybind", theme)

	local btn = new("TextButton", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(80, 24),
		BackgroundColor3 = theme.SurfaceAlt,
		Text = tostring(value), Font = theme.FontMedium, TextSize = 12,
		TextColor3 = theme.TextDim, AutoButtonColor = false,
	})
	corner(btn, 6)
	stroke(btn, theme.Outline, 1, 0.5)

	local function render() btn.Text = tostring(value) end

	btn.MouseButton1Click:Connect(function()
		listening = true
		Library._keybindListening = true
		btn.Text = "..."
		btn.TextColor3 = theme.Accent
	end)

	local conn = UserInputService.InputBegan:Connect(function(input, gpe)
		if not listening then return end
		local name
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if UserInputService:GetFocusedTextBox() then return end
			name = input.KeyCode.Name
		elseif input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			if gpe then return end
			name = input.UserInputType.Name
		end
		if name then
			listening = false
			Library._keybindListening = false
			btn.TextColor3 = theme.TextDim
			el:Set(name)
		end
	end)

	el.Instance = row
	el.Value = value
	el._conns = { conn }
	function el:Set(v, silent) value = v; render(); if not silent then self:Fire(value) end end
	function el:Get() return value end
	render()
	return finishElement(el, config)
end)

Library:RegisterElement("ColorPicker", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)

	local color = config.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = Color3.toHSV(color)

	local row = addRow(section, 30)
	rowLabel(row, config.Name or "Color", theme)

	local swatch = new("TextButton", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 20),
		BackgroundColor3 = color, Text = "", AutoButtonColor = false,
	})
	corner(swatch, 5)
	stroke(swatch, theme.Outline, 1)

	local popup, svSquare, svMarker, hueBar, hueMarker, preview, hexBox
	local built, opened = false, false

	local function updateMarkers()
		if not built then return end
		svMarker.Position = UDim2.new(s, 0, 1 - v, 0)
		hueMarker.Position = UDim2.new(h, 0, 0.5, 0)
	end

	local function updateColor(fire)
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		if built then
			preview.BackgroundColor3 = color
			svSquare.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			if not hexBox:IsFocused() then
				hexBox.Text = string.format("%02X%02X%02X",
					math.floor(color.R * 255 + 0.5),
					math.floor(color.G * 255 + 0.5),
					math.floor(color.B * 255 + 0.5))
			end
		end
		if fire ~= false then el:Fire(color) end
	end

	local function build()
		built = true
		local gui = section.Window.Gui

		-- Smaller, sleeker popup
		popup = new("Frame", {
			Parent = gui, Size = UDim2.fromOffset(180, 160),
			BackgroundColor3 = theme.Surface, BorderSizePixel = 0,
			Visible = false, ZIndex = 950,
		})
		corner(popup, 8)
		stroke(popup, theme.Outline, 1)
		padding(popup, 8, 8, 8, 8)

		-- Smaller SV square (80px tall instead of 120px)
		svSquare = new("Frame", {
			Parent = popup, Size = UDim2.new(1, 0, 0, 80),
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			BorderSizePixel = 0, ZIndex = 1,
		})
		corner(svSquare, 6)

		-- FIXED: Left side is white (opaque), right side is pure hue (transparent)
		new("UIGradient", {
			Parent = svSquare,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), -- Left: opaque white
				NumberSequenceKeypoint.new(1, 1), -- Right: transparent (shows pure hue)
			}),
		})

		local blackOverlay = new("Frame", {
			Parent = svSquare, Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0, ZIndex = 2,
		})
		corner(blackOverlay, 6)
		new("UIGradient", {
			Parent = blackOverlay,
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(0, 0, 0)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), -- Top: transparent (bright)
				NumberSequenceKeypoint.new(1, 0), -- Bottom: opaque black
			}),
		})

		svMarker = new("Frame", {
			Parent = svSquare, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(s, 0, 1 - v, 0),
			Size = UDim2.fromOffset(8, 8),
			BackgroundTransparency = 1, ZIndex = 5,
		})
		corner(svMarker, 4)
		stroke(svMarker, Color3.new(1, 1, 1), 2)

		-- Adjusted hue bar position and height
		hueBar = new("Frame", {
			Parent = popup, Position = UDim2.fromOffset(0, 90),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, ZIndex = 1,
		})
		corner(hueBar, 6)
		new("UIGradient", {
			Parent = hueBar,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			}),
		})

		hueMarker = new("Frame", {
			Parent = hueBar, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(h, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 12),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0, ZIndex = 5,
		})
		corner(hueMarker, 3)
		stroke(hueMarker, theme.Background, 2)

		-- Adjusted preview and hex box positions
		preview = new("Frame", {
			Parent = popup, Position = UDim2.fromOffset(0, 112),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = color, BorderSizePixel = 0,
		})
		corner(preview, 5)
		stroke(preview, theme.Outline, 1)

		hexBox = new("TextBox", {
			Parent = popup, Position = UDim2.fromOffset(28, 112),
			Size = UDim2.new(1, -28, 0, 20),
			BackgroundColor3 = theme.SurfaceAlt,
			Font = theme.Font, Text = "FFFFFF", TextSize = 11,
			TextColor3 = theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
		})
		corner(hexBox, 5)
		stroke(hexBox, theme.Outline, 1, 0.5)
		padding(hexBox, 0, 6, 0, 6)

		hexBox.FocusLost:Connect(function()
			local hex = hexBox.Text:gsub("#", "")
			if #hex == 6 then
				local r = tonumber(hex:sub(1, 2), 16)
				local g = tonumber(hex:sub(3, 4), 16)
				local b = tonumber(hex:sub(5, 6), 16)
				if r and g and b then
					color = Color3.fromRGB(r, g, b)
					h, s, v = Color3.toHSV(color)
					updateMarkers()
					updateColor()
				end
			end
			updateColor(false)
		end)

		local draggingSV, draggingHue

		local function svFromInput(input)
			local rx = math.clamp((input.Position.X - svSquare.AbsolutePosition.X) / math.max(svSquare.AbsoluteSize.X, 1), 0, 1)
			local ry = math.clamp((input.Position.Y - svSquare.AbsolutePosition.Y) / math.max(svSquare.AbsoluteSize.Y, 1), 0, 1)
			s = rx
			v = 1 - ry
			updateMarkers()
			updateColor()
		end

		local function hueFromInput(input)
			local rx = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
			h = rx
			updateMarkers()
			updateColor()
		end

		svSquare.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingSV = true
				svFromInput(input)
			end
		end)
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingHue = true
				hueFromInput(input)
			end
		end)

		local c1 = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if draggingSV then svFromInput(input) end
			if draggingHue then hueFromInput(input) end
		end)
		local c2 = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingSV = false
				draggingHue = false
			end
		end)
		local c3 = UserInputService.InputBegan:Connect(function(input, gpe)
			if not opened or gpe then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			task.defer(function()
				if not opened then return end
				local pos = input.Position
				local p, sz = popup.AbsolutePosition, popup.AbsoluteSize
				if pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y then return end
				local sp, ss = swatch.AbsolutePosition, swatch.AbsoluteSize
				if pos.X >= sp.X and pos.X <= sp.X + ss.X and pos.Y >= sp.Y and pos.Y <= sp.Y + ss.Y then return end
				el:SetOpen(false)
			end)
		end)
		el._conns = { c1, c2, c3 }
	end

	function el:SetOpen(state)
		if not built then build() end
		opened = state
		if opened then
			local pos = swatch.AbsolutePosition
			local size = swatch.AbsoluteSize
			-- Updated popup width/height for positioning
			local pw, ph = 180, 160
			local x = pos.X + size.X - pw
			local y = pos.Y + size.Y + 6
			local viewport = workspace.CurrentCamera.ViewportSize
			x = math.clamp(x, 8, math.max(8, viewport.X - pw - 8))
			if y + ph > viewport.Y - 8 then y = pos.Y - ph - 6 end
			if y < 8 then y = 8 end
			popup.Position = UDim2.fromOffset(x, y)
			popup.Visible = true
		else
			popup.Visible = false
		end
	end

	swatch.MouseButton1Click:Connect(function() el:SetOpen(not opened) end)

	el.Instance = row
	el.Value = color
	function el:Set(c, silent)
		color = c
		h, s, v = Color3.toHSV(color)
		updateMarkers()
		updateColor(false)
		if not silent then self:Fire(color) end
	end
	function el:Get() return color end
	updateColor(false)
	return finishElement(el, config)
end)

Library:RegisterElement("Label", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local row = addRow(section, 20)
	new("TextLabel", {
		Parent = row, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Font = theme.FontMedium,
		Text = config.Text or config.Name or "Label",
		TextColor3 = config.Color or theme.Text,
		TextSize = config.Size or 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	el.Instance = row
	el.Value = config.Text
	return finishElement(el, config)
end)

Library:RegisterElement("Paragraph", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local row = addRow(section, 20)
	row.AutomaticSize = Enum.AutomaticSize.Y

	local label = new("TextLabel", {
		Parent = row, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Font = theme.Font,
		Text = config.Text or config.Name or "",
		TextColor3 = config.Color or theme.TextDim,
		TextSize = config.Size or 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	el.Instance = row
	el.Label = label
	el.Value = config.Text
	function el:Set(text, silent) label.Text = tostring(text or ""); if not silent then self:Fire(text) end end
	function el:Get() return label.Text end
	return finishElement(el, config)
end)

Library:RegisterElement("Divider", function(section, config)
	config = config or {}
	local theme = Library.Theme
	local el = Element.new(config)
	local row = addRow(section, 9)
	new("Frame", {
		Parent = row, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Outline, BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	el.Instance = row
	return finishElement(el, config)
end)

Library:RegisterElement("Space", function(section, config)
	config = config or {}
	local el = Element.new(config)
	local row = addRow(section, config.Height or 6)
	el.Instance = row
	return finishElement(el, config)
end)

--=====================================================================
-- NOTIFICATIONS
--=====================================================================
local TYPE_COLORS = {
	Info    = function() return Library.Theme.Accent end,
	Success = function() return Library.Theme.Good end,
	Warning = function() return Library.Theme.Warn end,
	Error   = function() return Library.Theme.Bad end,
}

function Library:Notify(config)
	if type(config) == "string" then config = { Content = config } end
	config = config or {}
	local theme = Library.Theme

	if not Library._notifyGui or not Library._notifyGui.Parent then
		local gui = createScreenGui("PrismUINotifications")
		local holder = new("Frame", {
			Parent = gui, Name = "Holder",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.new(0, 280, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		})
		new("UIListLayout", { Parent = holder, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		Library._notifyGui = gui
		Library._notifyHolder = holder
	end

	local holder = Library._notifyHolder
	local accent = (TYPE_COLORS[config.Type or "Info"] or TYPE_COLORS.Info)()

	local outer = new("Frame", {
		Parent = holder, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ClipsDescendants = false,
	})
	local inner = new("Frame", {
		Parent = outer, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, 20, 0, 0),
		BackgroundColor3 = theme.Surface, BorderSizePixel = 0,
	})
	corner(inner, 8)
	stroke(inner, theme.Outline, 1, 0.3)
	padding(inner, 10, 12, 10, 14)

	new("Frame", {
		Parent = inner, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -8, 0.5, 0),
		Size = UDim2.fromOffset(3, 26),
		BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 2,
	})
	new("UIListLayout", { Parent = inner, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })

	if config.Title then
		new("TextLabel", {
			Parent = inner, Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1, Font = theme.FontBold,
			Text = config.Title, TextColor3 = theme.Text, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1,
		})
	end
	if config.Content then
		new("TextLabel", {
			Parent = inner, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Font = theme.Font,
			Text = config.Content, TextColor3 = theme.TextDim, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, LayoutOrder = 2,
		})
	end

	tween(inner, { Position = UDim2.new(0, 0, 0, 0) }, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	task.delay(config.Duration or 4, function()
		if not inner.Parent then return end
		tween(inner, { Position = UDim2.new(1, 20, 0, 0) }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.24)
		outer:Destroy()
	end)
	return outer
end

--=====================================================================
-- THEME MANAGEMENT
--=====================================================================
function Library:RefreshTheme()
	for inst, entries in pairs(Library._themed) do
		if typeof(inst) == "Instance" and inst.Parent then
			for _, e in ipairs(entries) do
				local v = Library.Theme[e.Key]
				if v ~= nil then inst[e.Prop] = v end
			end
		end
	end
end

function Library:SetThemeColor(key, color)
	if Library.Theme[key] ~= nil then
		Library.Theme[key] = color
		self:RefreshTheme()
	end
end

function Library:ResetTheme()
	for k, v in pairs(Library.DefaultTheme) do
		Library.Theme[k] = v
	end
	self:RefreshTheme()
end

-- Toggle all windows visible / hidden
function Library:ToggleWindows()
	for _, w in ipairs(Library.Windows) do
		if w.MainFrame then
			w.MainFrame.Visible = not w.MainFrame.Visible
		end
	end
end

-- Global hotkey listener
-- For keyboard: ignore gpe (right shift is shift lock and would set gpe=true),
-- but still skip while a textbox is focused.
-- For mouse buttons: keep the gpe check so clicking UI doesn't toggle the window.
UserInputService.InputBegan:Connect(function(input, gpe)
	if Library._keybindListening then return end

	local name
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if UserInputService:GetFocusedTextBox() then return end
		name = input.KeyCode.Name
	elseif input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
		or input.UserInputType == Enum.UserInputType.MouseButton3 then
		if gpe then return end
		name = input.UserInputType.Name
	end

	if name and name == Library.ToggleKeybind then
		Library:ToggleWindows()
	end
end)

--=====================================================================
-- SERIALIZATION + CONFIG MANAGER
--=====================================================================
function Library:Serialize(value)
	local t = typeof(value)
	if t == "Color3" then
		return string.format("Color3.fromRGB(%d, %d, %d)",
			math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
	elseif t == "EnumItem" then
		return string.format("Enum.%s.%s", tostring(value.EnumType), value.Name)
	elseif t == "table" then
		local parts = {}
		for k, v in pairs(value) do
			parts[#parts + 1] = string.format("[%s] = %s", Library:Serialize(k), Library:Serialize(v))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	end
	return "nil"
end

function Library:LoadConfig(filename)
	local str
	if typeof(readfile) == "function" then
		local ok, res = pcall(readfile, filename or "prism_config.txt")
		if not ok then return false end
		str = res
	else
		return false
	end
	local fn = typeof(loadstring) == "function" and loadstring or nil
	if not fn then return false end
	local chunk = fn(str)
	if not chunk then return false end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then return false end
	for flag, value in pairs(data) do
		Library.Flags[flag] = value
		local el = Library.Elements[flag]
		if el and el.Set then
			pcall(function() el:Set(value, true) end)
		end
	end
	-- Re-apply theme + toggle keybind (silent Sets don't fire callbacks)
	Library:_ApplySpecialFlags()
	return true
end

function Library:_ApplySpecialFlags()
	for key, val in pairs(Library.Theme) do
		if typeof(val) == "Color3" then
			local v = Library.Flags["__theme_" .. key]
			if typeof(v) == "Color3" then
				Library.Theme[key] = v
			end
		end
	end
	local tk = Library.Flags["__ui_toggle_key"]
	if typeof(tk) == "string" and tk ~= "" then
		Library.ToggleKeybind = tk
	end
	Library:RefreshTheme()
end

Library.ConfigFolder = "prism_configs"
Library.AutoLoadFile = "prism_configs/.autoload"

local function hasFileAPI()
	return typeof(writefile) == "function"
		and typeof(readfile) == "function"
		and typeof(isfile) == "function"
		and typeof(delfile) == "function"
		and typeof(isfolder) == "function"
		and typeof(makefolder) == "function"
		and typeof(listfiles) == "function"
end

local function ensureFolder()
	if not hasFileAPI() then return false end
	if not isfolder(Library.ConfigFolder) then makefolder(Library.ConfigFolder) end
	return true
end

function Library:ListConfigs()
	if not ensureFolder() then return {} end
	local out = {}
	local ok, files = pcall(listfiles, Library.ConfigFolder)
	if not ok or type(files) ~= "table" then return out end
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.cfg$")
		if name and name ~= "" and name:sub(1, 1) ~= "." then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function Library:ConfigExists(name)
	if not hasFileAPI() or not name or name == "" then return false end
	return isfile(Library.ConfigFolder .. "/" .. name .. ".cfg")
end

function Library:SaveConfigNamed(name)
	if not hasFileAPI() then return false, "no file API" end
	if not name or name == "" then return false, "empty name" end
	ensureFolder()
	local data = {}
	for flag, value in pairs(Library.Flags) do data[flag] = value end
	local str = "return " .. Library:Serialize(data)
	local ok, err = pcall(writefile, Library.ConfigFolder .. "/" .. name .. ".cfg", str)
	if not ok then return false, err end
	return true
end

function Library:LoadConfigNamed(name)
	if not name or name == "" then return false end
	if not Library:ConfigExists(name) then return false end
	return Library:LoadConfig(Library.ConfigFolder .. "/" .. name .. ".cfg")
end

function Library:DeleteConfig(name)
	if not hasFileAPI() or not name or name == "" then return false end
	local path = Library.ConfigFolder .. "/" .. name .. ".cfg"
	if not isfile(path) then return false end
	return pcall(delfile, path)
end

function Library:GetAutoLoad()
	if not hasFileAPI() then return nil end
	if not isfile(Library.AutoLoadFile) then return nil end
	local ok, name = pcall(readfile, Library.AutoLoadFile)
	if not ok or type(name) ~= "string" then return nil end
	name = name:gsub("%s+", "")
	if name == "" then return nil end
	return name
end

function Library:SetAutoLoad(name)
	if not hasFileAPI() then return end
	ensureFolder()
	if not name or name == "" then
		if isfile(Library.AutoLoadFile) then pcall(delfile, Library.AutoLoadFile) end
	else
		pcall(writefile, Library.AutoLoadFile, name)
	end
end

function Library:ApplyAutoLoad()
	local name = Library:GetAutoLoad()
	if name and Library:ConfigExists(name) then return Library:LoadConfigNamed(name) end
	return false
end

--=====================================================================
-- CONFIG TAB
--=====================================================================
function Library:BuildConfigTab(tab)
	local theme = Library.Theme
	local fileAPI = hasFileAPI()

	---------------------------------------------------------------
	-- THEME CUSTOMIZATION (ACCENT ONLY)
	---------------------------------------------------------------
	local themeKeys = { "Accent" }

	local secTheme = tab:Section("UI Theme")
	secTheme:Paragraph({
		Text = "Click the swatch to pick a new accent color. Changes apply live.",
	})

	for _, key in ipairs(themeKeys) do
		secTheme:ColorPicker({
			Name = key,
			Flag = "__theme_" .. key,
			Default = Library.Theme[key],
			OnChanged = function(color)
				Library.Theme[key] = color
				Library:RefreshTheme()
			end,
		})
	end

	secTheme:Button({
		Name = "Reset Accent to Default",
		Callback = function()
			for _, key in ipairs(themeKeys) do
				local el = Library.Elements["__theme_" .. key]
				if el then
					el:Set(Library.DefaultTheme[key]) -- fires OnChanged -> updates Theme + refresh
				else
					Library.Theme[key] = Library.DefaultTheme[key]
				end
			end
			Library:RefreshTheme()
			Library:Notify({ Title = "Theme", Content = "Default accent restored.", Type = "Info" })
		end,
	})

	---------------------------------------------------------------
	-- UI HOTKEY
	---------------------------------------------------------------
	local secHotkey = tab:Section("UI Hotkey")
	secHotkey:Keybind({
		Name = "Toggle UI Keybind",
		Flag = "__ui_toggle_key",
		Default = Library.ToggleKeybind,
		OnChanged = function(key)
			if typeof(key) == "string" and key ~= "" then
				Library.ToggleKeybind = key
			end
		end,
	})
	secHotkey:Paragraph({
		Text = "Press this key to show or hide the UI. Default: RightShift.",
	})

	---------------------------------------------------------------
	-- SAVE / LOAD / AUTO / MANAGE
	---------------------------------------------------------------
	local function configOptions()
		local opts = { "None" }
		for _, name in ipairs(Library:ListConfigs()) do table.insert(opts, name) end
		return opts
	end

	local refreshAll

	local secSave = tab:Section("Save Configuration")
	local nameInput = secSave:Input({ Name = "Config name", Placeholder = "my_config" })

	secSave:Button({
		Name = "Save",
		Callback = function()
			local name = tostring(nameInput:Get() or ""):gsub("%s+", "_"):gsub("[^%w_%-%.]", "")
			if name == "" then
				Library:Notify({ Title = "Save failed", Content = "Enter a name first.", Type = "Warning" })
				return
			end
			local ok, err = Library:SaveConfigNamed(name)
			if ok then
				Library:Notify({ Title = "Saved", Content = "Config '" .. name .. "' saved.", Type = "Success" })
				if refreshAll then refreshAll() end
			else
				Library:Notify({ Title = "Save failed", Content = tostring(err or "unknown"), Type = "Error" })
			end
		end,
	})

	local secLoad = tab:Section("Load Configuration")
	local loadDropdown = secLoad:Dropdown({
		Name = "Select config", Options = configOptions(), Default = "None", MaxVisible = 5,
	})

	secLoad:Button({
		Name = "Load Selected",
		Callback = function()
			local name = loadDropdown:Get()
			if not name or name == "None" then
				Library:Notify({ Title = "Load failed", Content = "No config selected.", Type = "Warning" })
				return
			end
			if Library:LoadConfigNamed(name) then
				Library:Notify({ Title = "Loaded", Content = "Config '" .. name .. "' applied.", Type = "Success" })
			else
				Library:Notify({ Title = "Load failed", Content = "Could not read '" .. name .. "'.", Type = "Error" })
			end
		end,
	})

	local secAuto = tab:Section("Auto Load on Startup")
	local autoCurrent = Library:GetAutoLoad()
	if autoCurrent and not Library:ConfigExists(autoCurrent) then
		autoCurrent = nil
		Library:SetAutoLoad(nil)
	end

	local autoDropdown = secAuto:Dropdown({
		Name = "Auto-load config",
		Options = configOptions(),
		Default = autoCurrent or "None",
		MaxVisible = 5,
		OnChanged = function(value)
			if value == "None" then
				Library:SetAutoLoad(nil)
				Library:Notify({ Title = "Auto-load", Content = "Disabled.", Type = "Info" })
			else
				Library:SetAutoLoad(value)
				Library:Notify({ Title = "Auto-load", Content = "Will load '" .. value .. "' on startup.", Type = "Success" })
			end
		end,
	})

	secAuto:Paragraph({
		Text = "The selected config is applied automatically the next time the script runs. Call Library:ApplyAutoLoad() after building your UI.",
	})

	local secManage = tab:Section("Manage Configs")
	local deleteDropdown = secManage:Dropdown({
		Name = "Select to delete", Options = configOptions(), Default = "None", MaxVisible = 5,
	})

	local confirming = false
	secManage:Button({
		Name = "Delete Selected",
		Callback = function()
			local name = deleteDropdown:Get()
			if not name or name == "None" then
				Library:Notify({ Title = "Delete", Content = "Select a config first.", Type = "Warning" })
				return
			end
			if not confirming then
				confirming = true
				Library:Notify({ Title = "Confirm delete", Content = "Click again to delete '" .. name .. "'.", Type = "Warning", Duration = 3 })
				task.delay(3, function() confirming = false end)
				return
			end
			confirming = false
			if Library:DeleteConfig(name) then
				if Library:GetAutoLoad() == name then Library:SetAutoLoad(nil) end
				Library:Notify({ Title = "Deleted", Content = "'" .. name .. "' removed.", Type = "Success" })
				if refreshAll then refreshAll() end
			else
				Library:Notify({ Title = "Delete failed", Content = "File not found.", Type = "Error" })
			end
		end,
	})

	secManage:Button({
		Name = "Refresh list",
		Callback = function()
			if refreshAll then refreshAll() end
			Library:Notify({ Title = "Refreshed", Content = "Config list updated.", Type = "Info", Duration = 2 })
		end,
	})

	refreshAll = function()
		local opts = configOptions()
		loadDropdown:SetOptions(opts)
		deleteDropdown:SetOptions(opts)
		autoDropdown:SetOptions(opts)
	end

	if not fileAPI then
		tab:Section("Warning"):Paragraph({
			Text = "Your executor does not expose file functions. Configs will not persist.",
			Color = theme.Bad,
		})
	end

	return { Refresh = refreshAll }
end

--=====================================================================
-- UTILITIES
--=====================================================================
function Library:GetFlag(flag) return Library.Flags[flag] end

function Library:SetFlag(flag, value)
	local el = Library.Elements[flag]
	if el and el.Set then el:Set(value) else Library.Flags[flag] = value end
end

function Library:OnFlagChanged(flag, callback)
	local el = Library.Elements[flag]
	if el then el:OnChanged(callback) else return nil end
end

function Library:Unload()
	for _, w in ipairs(table.clone(Library.Windows)) do w:Destroy() end
	Library.Windows = {}
	Library.Flags = {}
	Library.Elements = {}
	Library._themed = setmetatable({}, { __mode = "k" })
	if Library._notifyGui then
		Library._notifyGui:Destroy()
		Library._notifyGui = nil
	end
end

return Library
