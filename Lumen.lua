-- LumenMini v1.0 | compact glass UI | tabs on top | banner | PC + mobile
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local Mini = {
	Version = "1.0.0",
	Flags = {},
	Options = {},
	Windows = {},
	DefaultImage = "rbxthumb://type=Asset&id=97098047308546&w=420&h=420",
}

local rgb = Color3.fromRGB
local T = {
	Bg = rgb(16, 20, 36),
	Panel = rgb(24, 30, 52),
	Card = rgb(30, 38, 64),
	Text = rgb(244, 247, 255),
	Sub = rgb(168, 178, 204),
	Off = rgb(66, 78, 116),
	Line = Color3.new(1, 1, 1),
	Accent = rgb(76, 130, 230),
	Green = rgb(72, 182, 128),
	Gold = rgb(214, 174, 72),
	Red = rgb(204, 78, 86),
}

------------------------------------------------------------------
-- helpers
------------------------------------------------------------------
local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Tween(i, props, t, style, dir)
	local tw = TweenService:Create(i, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function Corner(r)
	return New("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function Pad(l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
	})
end

local function List(pad, hor)
	return New("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = hor and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		VerticalAlignment = hor and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
	})
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function safe(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[LumenMini] " .. tostring(err))
	end
end

local function round(n, inc)
	inc = inc or 1
	local r = math.floor(n / inc + 0.5) * inc
	return tonumber(string.format("%.10g", r))
end

local function guiParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	local ok2, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and core and pcall(function()
		local f = Instance.new("Folder")
		f.Parent = core
		f:Destroy()
	end) then
		return core
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function fsOK()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureFolder()
	pcall(function()
		if makefolder and isfolder and not isfolder("LumenMini") then
			makefolder("LumenMini")
		end
	end)
end

local function safeName(n)
	return (tostring(n):gsub("[^%w_%-]", "_"))
end

-- web images (github blob links are converted to raw links); needs writefile + getcustomasset
local function webImage(url, cb)
	url = tostring(url):gsub("^https?://github%.com/([^/]+)/([^/]+)/blob/", "https://raw.githubusercontent.com/%1/%2/")
	task.spawn(function()
		local getAsset = getcustomasset or getsynasset
		if type(getAsset) ~= "function" or not fsOK() then
			warn("[LumenMini] This executor cannot load web images; use an asset id instead")
			return
		end
		local h = 5381
		for i = 1, #url do
			h = (h * 33 + string.byte(url, i)) % 4294967296
		end
		local path = "LumenMini/img_" .. h .. ".png"
		local ok, err = pcall(function()
			if not isfile(path) then
				ensureFolder()
				writefile(path, game:HttpGet(url))
			end
			cb(getAsset(path))
		end)
		if not ok then
			warn("[LumenMini] Image failed: " .. tostring(err))
		end
	end)
end

local function applyImage(label, src)
	local url = tostring(src)
	if type(src) == "number" or tonumber(url) then
		label.Image = "rbxassetid://" .. url
	elseif url:find("^https?://") then
		webImage(url, function(a)
			label.Image = a
		end)
	else
		label.Image = url
	end
end

local function enc(v)
	return v
end

function Mini:SaveConfig(name)
	if not fsOK() then
		return false
	end
	ensureFolder()
	local d = {}
	for k, v in pairs(Mini.Flags) do
		d[k] = enc(v)
	end
	return (pcall(writefile, "LumenMini/" .. safeName(name) .. ".json", HttpService:JSONEncode(d)))
end

function Mini:LoadConfig(name)
	local path = "LumenMini/" .. safeName(name) .. ".json"
	if not fsOK() or not isfile(path) then
		return false
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(d) ~= "table" then
		return false
	end
	for k, v in pairs(d) do
		local o = Mini.Options[k]
		if o and o.Set then
			pcall(o.Set, o, v)
		end
	end
	return true
end

function Mini:Notify(n)
	local w = Mini.Windows[#Mini.Windows]
	if w then
		w:Notify(n)
	end
end

------------------------------------------------------------------
-- window
------------------------------------------------------------------
function Mini:CreateWindow(cfg)
	cfg = cfg or {}
	local W = { Tabs = {} }
	local lp = Players.LocalPlayer
	local conns, accents, renders = {}, {}, {}

	local function conn(c)
		conns[#conns + 1] = c
		return c
	end

	-- register a property that follows the accent color
	local function acc(inst, prop)
		inst[prop] = T.Accent
		accents[#accents + 1] = { inst, prop }
		return inst
	end

	local parent = guiParent()
	if cfg.Name then
		for _, g in ipairs(parent:GetChildren()) do
			if g:GetAttribute("LumenMini") == cfg.Name then
				g:Destroy()
			end
		end
	end

	local Gui = New("ScreenGui", {
		Name = "LM_" .. tostring(math.random(100000, 999999)),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
		Parent = parent,
	})
	Gui:SetAttribute("LumenMini", cfg.Name or "Mini")
	W.Gui = Gui

	local function Label(par, t, size, font, color, pos, sz, align)
		return New("TextLabel", {
			BackgroundTransparency = 1,
			Position = pos or UDim2.fromOffset(10, 0),
			Size = sz or UDim2.new(1, -20, 1, 0),
			Font = font or Enum.Font.GothamMedium,
			TextSize = size or 11,
			TextColor3 = color or T.Text,
			TextXAlignment = align or Enum.TextXAlignment.Left,
			Text = t,
			Parent = par,
		})
	end

	local WIN_W = cfg.Size and cfg.Size.X or 270
	local WIN_H = cfg.Size and cfg.Size.Y or 330
	local BANNER_H = 62
	local TAB_Y = 8 + BANNER_H + 6
	local CONTENT_Y = TAB_Y + 28 + 6
	local hidden, minimized, userScale = true, false, 1
	local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift

	local Main = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		Parent = Gui,
	}, { Corner(14) })
	local mstroke = New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1.4,
		Transparency = 0.55,
		Parent = Main,
	})
	acc(mstroke, "Color")

	local Scale = New("UIScale", { Parent = Main })

	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
		local m = touch and 20 or 40
		return math.min((cfg.Scale or 1) * userScale, (vp.X - m) / WIN_W, (vp.Y - m) / WIN_H)
	end
	Scale.Scale = fit() * 0.92
	if workspace.CurrentCamera then
		conn(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not hidden then
				Scale.Scale = fit()
			end
		end))
	end

	-- banner (the picture) with name pill and buttons
	local Banner = New("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, BANNER_H),
		BackgroundColor3 = T.Panel,
		BorderSizePixel = 0,
		Parent = Main,
	}, { Corner(10) })
	local BannerImg = New("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Parent = Banner,
	}, { Corner(10) })
	local bsrc = cfg.Banner
	if bsrc == nil then
		bsrc = Mini.DefaultImage
	end
	if bsrc then
		applyImage(BannerImg, bsrc)
	end
	function W:SetBanner(src)
		if src then
			applyImage(BannerImg, src)
		else
			BannerImg.Image = ""
		end
	end

	if cfg.Name then
		New("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 6, 1, -6),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = T.Text,
			Text = tostring(cfg.Name) .. (cfg.Subtitle and ("  |  " .. tostring(cfg.Subtitle)) or ""),
			Parent = Banner,
		}, { Corner(9), Pad(8, 0, 8, 0) })
	end

	local function smallBtn(label, xOff)
		local b = New("TextButton", {
			Position = UDim2.new(1, xOff, 0, 6),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = T.Text,
			Text = label,
			AutoButtonColor = false,
			Parent = Banner,
		}, { Corner(10) })
		b.MouseEnter:Connect(function()
			Tween(b, { BackgroundTransparency = 0.1 }, 0.12)
		end)
		b.MouseLeave:Connect(function()
			Tween(b, { BackgroundTransparency = 0.35 }, 0.12)
		end)
		return b
	end
	local CloseBtn = smallBtn("x", -26)
	local MinBtn = smallBtn("-", -50)

	-- tab strip (top)
	local TabStrip = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, TAB_Y),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = Main,
	}, { List(4, true) })

	local Pages = New("Frame", {
		Position = UDim2.fromOffset(8, CONTENT_Y),
		Size = UDim2.new(1, -16, 1, -(CONTENT_Y + 8)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = Main,
	})

	-- dragging (drag the banner)
	local dragging, dm, dp = false, nil, nil
	conn(Banner.InputBegan:Connect(function(i)
		if isPress(i) and i.Position.X < MinBtn.AbsolutePosition.X - 4 then
			dragging, dm, dp = true, i.Position, Main.Position
		end
	end))
	conn(UIS.InputChanged:Connect(function(i)
		if dragging and isMove(i) then
			local d = i.Position - dm
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
			Main.Position = UDim2.new(
				dp.X.Scale,
				math.clamp(dp.X.Offset + d.X, -vp.X * dp.X.Scale + 40, vp.X * (1 - dp.X.Scale) - 40),
				dp.Y.Scale,
				math.clamp(dp.Y.Offset + d.Y, -vp.Y * dp.Y.Scale + 30, vp.Y * (1 - dp.Y.Scale) - 30)
			)
		end
	end))
	conn(UIS.InputEnded:Connect(function(i)
		if isPress(i) then
			dragging = false
		end
	end))

	------------------------------------------------------------------
	-- notifications (compact toasts, top center)
	------------------------------------------------------------------
	local Toasts = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(240, 300),
		BackgroundTransparency = 1,
		Parent = Gui,
	}, { List(6) })

	function W:Notify(n)
		if type(n) ~= "table" then
			n = { Content = tostring(n) }
		end
		local col = ({ Success = T.Green, Warning = T.Gold, Error = T.Red })[n.Type] or T.Accent
		local content = n.Content or ""
		local ok, size = pcall(function()
			return TextService:GetTextSize(content, 10, Enum.Font.Gotham, Vector2.new(206, 600))
		end)
		local bodyH = content == "" and 0 or ((ok and size.Y or 14) + 2)
		local wrap = New("Frame", {
			Size = UDim2.new(1, 0, 0, 28 + bodyH),
			BackgroundTransparency = 1,
			Parent = Toasts,
		})
		local c = New("Frame", {
			Position = UDim2.fromOffset(0, -20),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = T.Panel,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = wrap,
		}, { Corner(9) })
		local st = New("UIStroke", { Color = col, Thickness = 1.2, Transparency = 1, Parent = c })
		local bar = New("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(0, 3, 1, -12),
			BackgroundColor3 = col,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = c,
		}, { Corner(2) })
		local t1 = Label(c, n.Title or "Notice", 11, Enum.Font.GothamBold, T.Text, UDim2.fromOffset(16, 5), UDim2.new(1, -22, 0, 16))
		t1.TextTransparency = 1
		local t2
		if content ~= "" then
			t2 = Label(c, content, 10, Enum.Font.Gotham, T.Sub, UDim2.fromOffset(16, 21), UDim2.new(1, -22, 0, bodyH))
			t2.TextWrapped = true
			t2.TextYAlignment = Enum.TextYAlignment.Top
			t2.TextTransparency = 1
		end
		local function fade(a)
			Tween(c, { BackgroundTransparency = a and 0.05 or 1, Position = a and UDim2.new() or UDim2.fromOffset(0, -20) }, 0.25)
			Tween(st, { Transparency = a and 0.3 or 1 }, 0.25)
			Tween(bar, { BackgroundTransparency = a and 0 or 1 }, 0.25)
			Tween(t1, { TextTransparency = a and 0 or 1 }, 0.25)
			if t2 then
				Tween(t2, { TextTransparency = a and 0 or 1 }, 0.25)
			end
		end
		fade(true)
		task.delay(n.Duration or 3, function()
			if wrap.Parent then
				fade(false)
				task.delay(0.3, function()
					wrap:Destroy()
				end)
			end
		end)
	end

	------------------------------------------------------------------
	-- elements
	------------------------------------------------------------------
	local function attach(host, container)
		local function card(h)
			local f = New("Frame", {
				Size = UDim2.new(1, 0, 0, h),
				BackgroundColor3 = T.Card,
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = container,
			}, { Corner(8) })
			New("UIStroke", {
				Color = T.Line,
				Transparency = 0.88,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = f,
			})
			return f
		end

		local function hitbox(f, h)
			local b = New("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Size = h and UDim2.new(1, 0, 0, h) or UDim2.fromScale(1, 1),
				Parent = f,
			})
			b.MouseEnter:Connect(function()
				Tween(f, { BackgroundTransparency = 0.1 }, 0.12)
			end)
			b.MouseLeave:Connect(function()
				Tween(f, { BackgroundTransparency = 0.25 }, 0.12)
			end)
			return b
		end

		local function base(f, o)
			o.Frame = f
			function o:Destroy()
				f:Destroy()
			end
			function o:SetVisible(v)
				f.Visible = v
			end
			return o
		end

		local function reg(flag, obj, val)
			if flag then
				Mini.Flags[flag] = val
				Mini.Options[flag] = obj
			end
		end

		local function dragArea(hitF, ref, onMove)
			local active = false
			local function setScroll(v)
				local sc = container:IsA("ScrollingFrame") and container or container:FindFirstAncestorOfClass("ScrollingFrame")
				if sc then
					sc.ScrollingEnabled = v
				end
			end
			local function upd(i)
				local p, s = ref.AbsolutePosition, ref.AbsoluteSize
				onMove(math.clamp((i.Position.X - p.X) / math.max(s.X, 1), 0, 1))
			end
			conn(hitF.InputBegan:Connect(function(i)
				if isPress(i) then
					active = true
					setScroll(false)
					upd(i)
				end
			end))
			conn(UIS.InputChanged:Connect(function(i)
				if active and isMove(i) then
					upd(i)
				end
			end))
			conn(UIS.InputEnded:Connect(function(i)
				if active and isPress(i) then
					active = false
					setScroll(true)
				end
			end))
		end

		function host:CreateSection(title)
			local f = New("Frame", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Parent = container,
			})
			local bar = New("Frame", {
				Position = UDim2.fromOffset(2, 4),
				Size = UDim2.fromOffset(3, 12),
				BorderSizePixel = 0,
				Parent = f,
			}, { Corner(2) })
			acc(bar, "BackgroundColor3")
			Label(f, string.upper(title or "Section"), 10, Enum.Font.GothamBold, T.Sub, UDim2.fromOffset(12, 0), UDim2.new(1, -14, 1, 0))
			return base(f, {})
		end

		function host:CreateLabel(t)
			local f = card(26)
			local l = Label(f, tostring(t), 10, Enum.Font.Gotham, T.Sub)
			return base(f, {
				Set = function(_, v)
					l.Text = tostring(v)
				end,
			})
		end

		function host:CreateParagraph(c)
			c = c or {}
			local f = card(0)
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.Size = UDim2.new(1, 0, 0, 0)
			Pad(10, 8, 10, 8).Parent = f
			List(3).Parent = f
			local t = New("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = T.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = c.Title or "",
				Parent = f,
			})
			local b = New("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = T.Sub,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = c.Content or "",
				Parent = f,
			})
			return base(f, {
				Set = function(_, n)
					t.Text = n.Title or t.Text
					b.Text = n.Content or b.Text
				end,
			})
		end

		function host:CreateDivider()
			local d = New("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = T.Line,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				Parent = container,
			})
			return base(d, {})
		end

		function host:CreateImage(c)
			c = c or {}
			local h = c.Height or 90
			local f = card(h + 12)
			local img = New("ImageLabel", {
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0, h),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType[c.ScaleType or "Fit"] or Enum.ScaleType.Fit,
				Parent = f,
			}, { Corner(6) })
			if c.Image then
				applyImage(img, c.Image)
			end
			return base(f, {
				Set = function(_, src)
					applyImage(img, src)
				end,
			})
		end

		function host:CreateButton(c)
			c = c or {}
			local f = card(c.Description and 42 or 30)
			if c.Description then
				Label(f, c.Name or "Button", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 5), UDim2.new(1, -34, 0, 16))
				Label(f, c.Description, 10, Enum.Font.Gotham, T.Sub, UDim2.fromOffset(10, 22), UDim2.new(1, -34, 0, 14)).TextTruncate = Enum.TextTruncate.AtEnd
			else
				Label(f, c.Name or "Button", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 0), UDim2.new(1, -34, 1, 0))
			end
			Label(f, ">", 14, Enum.Font.GothamMedium, T.Sub, UDim2.new(1, -22, 0, 0), UDim2.fromOffset(14, c.Description and 42 or 30), Enum.TextXAlignment.Center)
			local b = hitbox(f)
			local function fire()
				Tween(f, { BackgroundColor3 = T.Accent }, 0.08).Completed:Connect(function()
					Tween(f, { BackgroundColor3 = T.Card }, 0.25)
				end)
				safe(c.Callback)
			end
			b.MouseButton1Click:Connect(fire)
			return base(f, { Fire = fire })
		end

		function host:CreateToggle(c)
			c = c or {}
			local h = c.Description and 42 or 30
			local f = card(h)
			if c.Description then
				Label(f, c.Name or "Toggle", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 5), UDim2.new(1, -56, 0, 16))
				Label(f, c.Description, 10, Enum.Font.Gotham, T.Sub, UDim2.fromOffset(10, 22), UDim2.new(1, -56, 0, 14)).TextTruncate = Enum.TextTruncate.AtEnd
			else
				Label(f, c.Name or "Toggle", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 0), UDim2.new(1, -56, 1, 0))
			end
			local track = New("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(34, 18),
				BorderSizePixel = 0,
				Parent = f,
			}, { Corner(9) })
			local knob = New("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = track,
			}, { Corner(6) })
			local b = hitbox(f)
			local o = { CurrentValue = c.CurrentValue == true }
			local function render(instant)
				local d = instant and 0 or 0.18
				Tween(track, { BackgroundColor3 = o.CurrentValue and T.Accent or T.Off }, d)
				Tween(knob, { Position = o.CurrentValue and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, d)
			end
			renders[#renders + 1] = function()
				render(true)
			end
			function o:Set(v, silent)
				o.CurrentValue = v and true or false
				if c.Flag then
					Mini.Flags[c.Flag] = o.CurrentValue
				end
				render()
				if not silent then
					safe(c.Callback, o.CurrentValue)
				end
			end
			function o:Get()
				return o.CurrentValue
			end
			b.MouseButton1Click:Connect(function()
				o:Set(not o.CurrentValue)
			end)
			reg(c.Flag, o, o.CurrentValue)
			render(true)
			if o.CurrentValue then
				safe(c.Callback, true)
			end
			return base(f, o)
		end

		function host:CreateSlider(c)
			c = c or {}
			local min = c.Range and c.Range[1] or 0
			local max = c.Range and c.Range[2] or 100
			local inc = c.Increment or 1
			local f = card(44)
			Label(f, c.Name or "Slider", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 3), UDim2.new(0.6, 0, 0, 18))
			local val = Label(f, "", 10, Enum.Font.GothamMedium, T.Sub, UDim2.new(0.4, -10, 0, 3), UDim2.new(0.6, 0, 0, 18), Enum.TextXAlignment.Right)
			local track = New("Frame", {
				Position = UDim2.new(0, 10, 1, -15),
				Size = UDim2.new(1, -20, 0, 6),
				BackgroundColor3 = T.Off,
				BorderSizePixel = 0,
				Parent = f,
			}, { Corner(3) })
			local fill = New("Frame", {
				Size = UDim2.fromScale(0, 1),
				BorderSizePixel = 0,
				Parent = track,
			}, { Corner(3) })
			acc(fill, "BackgroundColor3")
			New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = fill,
			}, { Corner(6) })
			local o = { CurrentValue = c.CurrentValue or min }
			function o:Set(v, silent)
				v = math.clamp(round(v, inc), min, max)
				o.CurrentValue = v
				Tween(fill, { Size = UDim2.fromScale(max > min and (v - min) / (max - min) or 0, 1) }, 0.06)
				val.Text = tostring(v) .. (c.Suffix and (" " .. c.Suffix) or "")
				if c.Flag then
					Mini.Flags[c.Flag] = v
				end
				if not silent then
					safe(c.Callback, v)
				end
			end
			function o:Get()
				return o.CurrentValue
			end
			local area = New("TextButton", {
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Position = UDim2.new(0, 0, 1, -28),
				Size = UDim2.new(1, 0, 0, 28),
				Parent = f,
			})
			dragArea(area, track, function(x)
				local nv = math.clamp(round(min + (max - min) * x, inc), min, max)
				if nv ~= o.CurrentValue then
					o:Set(nv)
				end
			end)
			reg(c.Flag, o, o.CurrentValue)
			o:Set(o.CurrentValue, true)
			return base(f, o)
		end

		function host:CreateDropdown(c)
			c = c or {}
			local multi = c.MultipleOptions == true
			local f = card(30)
			Label(f, c.Name or "Dropdown", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 0), UDim2.new(0.5, -10, 0, 30))
			local cur = Label(f, "", 10, Enum.Font.Gotham, T.Sub, UDim2.new(0.5, -26, 0, 0), UDim2.new(0.5, 0, 0, 30), Enum.TextXAlignment.Right)
			cur.TextTruncate = Enum.TextTruncate.AtEnd
			local arrow = Label(f, "v", 11, Enum.Font.GothamMedium, T.Sub, UDim2.new(1, -20, 0, 0), UDim2.fromOffset(14, 30), Enum.TextXAlignment.Center)
			local list = New("ScrollingFrame", {
				Position = UDim2.fromOffset(4, 32),
				Size = UDim2.new(1, -8, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = f,
			}, { List(2) })
			local head = hitbox(f, 30)

			local o = { Open = false, Options = c.Options or {} }
			local sel, buttons = {}, {}
			if type(c.CurrentOption) == "table" then
				for _, v in ipairs(c.CurrentOption) do
					sel[v] = true
				end
			elseif c.CurrentOption ~= nil then
				sel[c.CurrentOption] = true
			end

			local function value()
				if multi then
					local t = {}
					for _, op in ipairs(o.Options) do
						if sel[op] then
							t[#t + 1] = op
						end
					end
					return t
				end
				for _, op in ipairs(o.Options) do
					if sel[op] then
						return op
					end
				end
				return nil
			end

			local function style()
				local v = value()
				if multi then
					cur.Text = #v == 0 and "None" or table.concat(v, ", ")
				else
					cur.Text = v ~= nil and tostring(v) or "None"
				end
				for op, b in pairs(buttons) do
					b.TextColor3 = sel[op] and T.Accent or T.Text
				end
			end
			renders[#renders + 1] = style

			local function layout()
				local lh = math.min(#o.Options * 28, 112)
				Tween(f, { Size = UDim2.new(1, 0, 0, o.Open and (30 + lh + 8) or 30) }, 0.2)
				Tween(list, { Size = UDim2.new(1, -8, 0, o.Open and lh or 0) }, 0.2)
				Tween(arrow, { Rotation = o.Open and 180 or 0 }, 0.2)
			end

			local function commit(silent)
				style()
				local v = value()
				if c.Flag then
					Mini.Flags[c.Flag] = v
				end
				if not silent then
					safe(c.Callback, v)
				end
			end

			local function build()
				for _, b in pairs(buttons) do
					b:Destroy()
				end
				buttons = {}
				for i, op in ipairs(o.Options) do
					local b = New("TextButton", {
						LayoutOrder = i,
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(1, 1, 1),
						Text = tostring(op),
						Font = Enum.Font.GothamMedium,
						TextSize = 10,
						TextColor3 = T.Text,
						AutoButtonColor = false,
						Parent = list,
					}, { Corner(6) })
					b.MouseEnter:Connect(function()
						Tween(b, { BackgroundTransparency = 0.9 }, 0.1)
					end)
					b.MouseLeave:Connect(function()
						Tween(b, { BackgroundTransparency = 1 }, 0.1)
					end)
					b.MouseButton1Click:Connect(function()
						if multi then
							sel[op] = (not sel[op]) or nil
						else
							sel = { [op] = true }
							o.Open = false
							layout()
						end
						commit()
					end)
					buttons[op] = b
				end
				commit(true)
			end

			function o:Set(v, silent)
				sel = {}
				if type(v) == "table" then
					for _, x in ipairs(v) do
						sel[x] = true
					end
				elseif v ~= nil then
					sel[v] = true
				end
				commit(silent)
			end
			function o:Refresh(opts)
				o.Options = opts
				sel = {}
				build()
				layout()
			end
			function o:Get()
				return value()
			end
			function o:Close()
				if o.Open then
					o.Open = false
					layout()
				end
			end

			head.MouseButton1Click:Connect(function()
				o.Open = not o.Open
				layout()
			end)

			build()
			reg(c.Flag, o, value())
			return base(f, o)
		end

		function host:CreateInput(c)
			c = c or {}
			local f = card(32)
			Label(f, c.Name or "Input", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 0), UDim2.new(0.4, 0, 1, 0))
			local box = New("TextBox", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0.55, 0, 0, 24),
				BackgroundColor3 = T.Panel,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = T.Text,
				PlaceholderColor3 = T.Sub,
				PlaceholderText = c.PlaceholderText or "Type here...",
				ClearTextOnFocus = false,
				Text = tostring(c.CurrentValue or ""),
				Parent = f,
			}, { Corner(6), Pad(6, 0, 6, 0) })
			local o = { CurrentValue = tostring(c.CurrentValue or "") }
			box.FocusLost:Connect(function()
				local v = box.Text
				if c.Numeric then
					local n = tonumber(v)
					if n == nil then
						box.Text = o.CurrentValue
						return
					end
					v = tostring(n)
				end
				o.CurrentValue = v
				box.Text = v
				if c.Flag then
					Mini.Flags[c.Flag] = v
				end
				safe(c.Callback, v)
				if c.RemoveTextAfterFocusLost then
					box.Text = ""
				end
			end)
			function o:Set(t, silent)
				t = tostring(t)
				o.CurrentValue = t
				box.Text = t
				if c.Flag then
					Mini.Flags[c.Flag] = t
				end
				if not silent then
					safe(c.Callback, t)
				end
			end
			function o:Get()
				return o.CurrentValue
			end
			reg(c.Flag, o, o.CurrentValue)
			return base(f, o)
		end

		function host:CreateKeybind(c)
			c = c or {}
			local f = card(30)
			Label(f, c.Name or "Keybind", 11, Enum.Font.GothamMedium, T.Text, UDim2.fromOffset(10, 0), UDim2.new(1, -90, 1, 0))
			local b = New("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(64, 22),
				BackgroundColor3 = T.Panel,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextColor3 = T.Sub,
				Text = "None",
				Parent = f,
			}, { Corner(6) })
			local h = hitbox(f)
			local o = { CurrentKeybind = nil }
			local listening = false
			local function toKey(v)
				if typeof(v) == "EnumItem" then
					return v
				end
				if type(v) == "string" and Enum.KeyCode[v] then
					return Enum.KeyCode[v]
				end
				return nil
			end
			function o:Set(v, silent)
				local k = toKey(v)
				o.CurrentKeybind = k
				b.Text = k and k.Name or "None"
				if c.Flag then
					Mini.Flags[c.Flag] = k and k.Name or nil
				end
				if not silent then
					safe(c.OnChange, k)
				end
			end
			function o:Get()
				return o.CurrentKeybind
			end
			h.MouseButton1Click:Connect(function()
				listening = true
				b.Text = "..."
			end)
			conn(UIS.InputBegan:Connect(function(i, gpe)
				if i.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end
				if listening then
					listening = false
					if i.KeyCode == Enum.KeyCode.Escape then
						o:Set(nil)
					else
						o:Set(i.KeyCode)
					end
					return
				end
				if not gpe and o.CurrentKeybind and i.KeyCode == o.CurrentKeybind then
					safe(c.Callback, o.CurrentKeybind)
				end
			end))
			o:Set(c.CurrentKeybind, true)
			reg(c.Flag, o, o.CurrentKeybind and o.CurrentKeybind.Name or nil)
			return base(f, o)
		end
	end

	------------------------------------------------------------------
	-- tabs
	------------------------------------------------------------------
	function W:SelectTab(tab)
		if W.ActiveTab == tab then
			return
		end
		local old = W.ActiveTab
		if old then
			old.Page.Visible = false
			Tween(old.Button, { BackgroundTransparency = 1, TextColor3 = T.Sub }, 0.15)
		end
		W.ActiveTab = tab
		if old then
			local oi, ni = 0, 0
			for i, t in ipairs(W.Tabs) do
				if t == old then
					oi = i
				end
				if t == tab then
					ni = i
				end
			end
			tab.Page.Position = UDim2.fromOffset(ni >= oi and 20 or -20, 0)
			Tween(tab.Page, { Position = UDim2.new() }, 0.25, Enum.EasingStyle.Quint)
		end
		tab.Page.Visible = true
		Tween(tab.Button, { BackgroundTransparency = 0.15, TextColor3 = T.Text }, 0.15)
	end

	function W:CreateTab(name, icon)
		local hasImg = type(icon) == "number"
		local btn = New("TextButton", {
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = T.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = T.Sub,
			Text = (not hasImg and icon) and (tostring(icon) .. " " .. tostring(name)) or tostring(name),
			LayoutOrder = #W.Tabs + 1,
			Parent = TabStrip,
		}, { Corner(8), Pad(hasImg and 26 or 10, 0, 10, 0) })
		acc(btn, "BackgroundColor3")
		if hasImg then
			New("ImageLabel", {
				Position = UDim2.fromOffset(-18, 5),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. icon,
				Parent = btn,
			})
		end

		local page = New("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = Pages,
		}, { List(5), Pad(0, 2, 4, 6) })
		acc(page, "ScrollBarImageColor3")

		local tab = { Name = tostring(name), Button = btn, Page = page }
		attach(tab, page)
		btn.MouseButton1Click:Connect(function()
			W:SelectTab(tab)
		end)
		W.Tabs[#W.Tabs + 1] = tab
		if W.ActiveTab == nil then
			W:SelectTab(tab)
		end
		return tab
	end

	-- built-in settings tab: accent, UI size, configs
	function W:CreateConfigTab(name)
		local tab = W:CreateTab(name or "Settings")
		tab:CreateSection("Look")
		local ACCENTS = {
			Blue = rgb(76, 130, 230),
			Purple = rgb(150, 100, 235),
			Pink = rgb(230, 100, 170),
			Cyan = rgb(60, 190, 220),
			Green = T.Green,
			Gold = T.Gold,
			Red = T.Red,
		}
		tab:CreateDropdown({
			Name = "Accent color",
			Options = { "Blue", "Purple", "Pink", "Cyan", "Green", "Gold", "Red" },
			CurrentOption = "Blue",
			Callback = function(v)
				if v and ACCENTS[v] then
					W:SetAccent(ACCENTS[v])
				end
			end,
		})
		tab:CreateSlider({
			Name = "UI size",
			Range = { 60, 140 },
			Increment = 5,
			Suffix = "%",
			CurrentValue = 100,
			Callback = function(v)
				userScale = v / 100
				if not hidden then
					Tween(Scale, { Scale = fit() }, 0.15)
				end
			end,
		})
		tab:CreateSection("Config")
		local cname = "default"
		tab:CreateInput({
			Name = "Name",
			CurrentValue = "default",
			Callback = function(v)
				cname = v
			end,
		})
		tab:CreateButton({
			Name = "Save config",
			Callback = function()
				local ok = Mini:SaveConfig(cname)
				W:Notify({ Title = ok and "Saved" or "Failed", Content = cname, Type = ok and "Success" or "Error" })
			end,
		})
		tab:CreateButton({
			Name = "Load config",
			Callback = function()
				local ok = Mini:LoadConfig(cname)
				W:Notify({ Title = ok and "Loaded" or "Not found", Content = cname, Type = ok and "Success" or "Error" })
			end,
		})
		tab:CreateButton({
			Name = "Destroy UI",
			Callback = function()
				W:Destroy()
			end,
		})
		return tab
	end

	------------------------------------------------------------------
	-- window control
	------------------------------------------------------------------
	function W:Show()
		if not hidden then
			return
		end
		hidden = false
		Main.Visible = true
		Scale.Scale = fit() * 0.92
		Tween(Scale, { Scale = fit() }, 0.25, Enum.EasingStyle.Back)
	end

	function W:Hide()
		if hidden then
			return
		end
		hidden = true
		Tween(Scale, { Scale = fit() * 0.92 }, 0.15)
		task.delay(0.15, function()
			if hidden then
				Main.Visible = false
			end
		end)
	end

	function W:Toggle()
		if hidden then
			W:Show()
		else
			W:Hide()
		end
	end

	function W:SetAccent(col)
		T.Accent = col
		for i = #accents, 1, -1 do
			local a = accents[i]
			if a[1] and a[1].Parent then
				a[1][a[2]] = col
			else
				table.remove(accents, i)
			end
		end
		for _, fn in ipairs(renders) do
			pcall(fn)
		end
		if W.ActiveTab then
			W.ActiveTab.Button.BackgroundColor3 = col
		end
	end

	function W:Destroy()
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		for i, w in ipairs(Mini.Windows) do
			if w == W then
				table.remove(Mini.Windows, i)
				break
			end
		end
		Gui:Destroy()
	end

	CloseBtn.MouseButton1Click:Connect(function()
		W:Hide()
	end)

	MinBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		TabStrip.Visible = not minimized
		Pages.Visible = not minimized
		Tween(Main, { Size = UDim2.fromOffset(WIN_W, minimized and (TAB_Y - 4) or WIN_H) }, 0.22)
	end)

	conn(UIS.InputBegan:Connect(function(i, gpe)
		if not gpe and i.KeyCode == toggleKey then
			W:Toggle()
		end
	end))

	-- floating open button (works with touch and mouse, drag to move)
	do
		local fb = New("TextButton", {
			Position = UDim2.new(0, 10, 0.5, -19),
			Size = UDim2.fromOffset(38, 38),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = T.Panel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 200,
			Parent = Gui,
		}, { Corner(19) })
		local fs = New("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 2,
			Parent = fb,
		})
		acc(fs, "Color")
		local fsrc = cfg.ButtonImage
		if fsrc == nil then
			fsrc = Mini.DefaultImage
		end
		if fsrc then
			local fi = New("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 201,
				Parent = fb,
			}, { Corner(19) })
			applyImage(fi, fsrc)
		else
			fb.Text = string.sub(cfg.Name or "L", 1, 1)
			fb.Font = Enum.Font.GothamBold
			fb.TextSize = 16
			fb.TextColor3 = T.Accent
		end
		local down, moved, sm, sp = false, false, nil, nil
		fb.InputBegan:Connect(function(i)
			if isPress(i) then
				down, moved, sm, sp = true, false, i.Position, fb.Position
			end
		end)
		conn(UIS.InputChanged:Connect(function(i)
			if down and isMove(i) then
				local d = i.Position - sm
				if d.Magnitude > 8 then
					moved = true
				end
				if moved then
					local cam = workspace.CurrentCamera
					local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
					fb.Position = UDim2.new(
						0,
						math.clamp(sp.X.Offset + d.X, 0, vp.X - 38),
						sp.Y.Scale,
						math.clamp(sp.Y.Offset + d.Y, -vp.Y * sp.Y.Scale, vp.Y * (1 - sp.Y.Scale) - 38)
					)
				end
			end
		end))
		conn(UIS.InputEnded:Connect(function(i)
			if down and isPress(i) then
				down = false
				if not moved then
					W:Toggle()
				end
			end
		end))
	end

	Mini.Windows[#Mini.Windows + 1] = W
	task.defer(function()
		W:Show()
	end)

	return W
end

return Mini
