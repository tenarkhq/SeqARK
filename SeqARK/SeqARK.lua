-- SeqARK: one-button sequences. Each key press casts the next step of a sequence, the way a
-- castsequence macro would, but every step is a whole macro of its own.
--
-- How it works: each sequence is one hidden secure button. Its steps are stored on the button
-- as attributes (m1, m2, ...). A secure snippet runs before every click, puts the current
-- step's macro text on the button and moves the step pointer on; the button then runs that
-- macro. Nothing is cached or translated: the buttons are built again from the sequence text
-- at login, on a spec change and with /seqark rebuild, and leaving combat starts every
-- sequence from step 1 again.
--
-- The icon: the window's Icon button (or /seqark icon ST) makes a macro that only shows the
-- sequence's spell, to put on the action bar slot of the same key.
--
-- The window: /seqark, the minimap button or the game's addon menu opens it. Class and spec on
-- the left, the chosen spec's sequences on the right.
--
-- The key: a click on a sequence's key field in the window and a key press binds it (or
-- /seqark bind ST 5). It is an override binding (SetOverrideBindingClick, not
-- saved by the game, set again at every build), so it wins over the action bar binding of that
-- key while SeqARK runs and the key is the action bar's again once it is cleared. With the
-- game's "cast on key down" setting on, the key presses a small relay button on key down,
-- which clicks the sequence button; with the setting off, the key clicks it on release.
--
-- Sequence text (the import format):
--   SeqARK 1                       first line, the format version
--   name ST                        letters, digits and _ ; one ST per spec; the button is SeqARK_<name>
--   title Single target            shown in the window
--   spec 70                        specialization ID the sequence is for
--   icon {53385}                   optional: the spell the icon macro shows (else the first step's)
--   before /startattack            a macro line put in front of every step (any number)
--   step /cast [nomod] {85256}     one step: one macro line (any number of steps)
-- {12345} is replaced by the name of that spell in the game's language. Lines starting with #
-- are notes.

local addonName = ...

local PREFIX = '|cffe6b84dSeqARK|r '
local MACRO_LIMIT = 255

local function Print(msg) print(PREFIX .. msg) end

-- Retribution, Templar: the step orders measured in SimC. The four lines in front of each step:
-- target and auto attack; CTRL + mouseover heals a living ally with Word of Glory or brings a
-- dead one back with Intercession, CTRL alone heals yourself; Hammer of Light goes out first
-- whenever it is up (it replaces Wake of Ashes while it is).
local RET_BEFORE = [[
before /targetenemy [noharm][dead]
before /startattack
before /cast [mod:ctrl,@mouseover,dead,exists] {391054}; [mod:ctrl,@mouseover,help,nodead] {85673}; [mod:ctrl] {85673}
before /cast [known:{427453}] {255937}
]]

local BUILTIN = {
	ST = [[
SeqARK 1
name ST
title Retribution single target, Avenging Wrath and trinkets on steps
spec 70
icon {85256}
]] .. RET_BEFORE .. [[
step /cast [nomod] {85256}
step /cast [combat] {31884}
step /cast [nomod] {343527}
step /cast [nomod] {255937}
step /cast [nomod] {85256}
step /cast [nomod] {255937}
step /use [combat] 13
step /cast [nomod] {85256}
step /cast [nomod] {255937}
step /cast [nomod] {184575}
step /cast [nomod] {375576}
step /use [combat] 14
step /cast [nomod] {20271}
step /cast [nomod] {184575}
step /cast [nomod] {343527}
]],
	AE = [[
SeqARK 1
name AE
title Retribution AoE (2+ targets), Avenging Wrath and trinkets on steps
spec 70
icon {53385}
]] .. RET_BEFORE .. [[
step /cast [nomod] {255937}
step /cast [nomod] {184575}
step /cast [nomod] {53385}
step /cast [combat] {31884}
step /cast [nomod] {375576}
step /cast [nomod] {184575}
step /cast [nomod] {20271}
step /use [combat] 13
step /cast [nomod] {53385}
step /cast [nomod] {255937}
step /cast [nomod] {343527}
step /use [combat] 14
step /cast [nomod] {53385}
]],
	STNOCD = [[
SeqARK 1
name STNOCD
title Retribution single target, Avenging Wrath and trinkets by hand
spec 70
icon {85256}
]] .. RET_BEFORE .. [[
step /cast [nomod] {85256}
step /cast [nomod] {343527}
step /cast [nomod] {255937}
step /cast [nomod] {85256}
step /cast [nomod] {255937}
step /cast [nomod] {85256}
step /cast [nomod] {255937}
step /cast [nomod] {184575}
step /cast [nomod] {375576}
step /cast [nomod] {20271}
step /cast [nomod] {184575}
step /cast [nomod] {343527}
]],
	AENOCD = [[
SeqARK 1
name AENOCD
title Retribution AoE (2+ targets), Avenging Wrath and trinkets by hand
spec 70
icon {53385}
]] .. RET_BEFORE .. [[
step /cast [nomod] {255937}
step /cast [nomod] {184575}
step /cast [nomod] {53385}
step /cast [nomod] {375576}
step /cast [nomod] {184575}
step /cast [nomod] {20271}
step /cast [nomod] {53385}
step /cast [nomod] {255937}
step /cast [nomod] {343527}
step /cast [nomod] {53385}
]],
}
local ORDER = { 'ST', 'AE', 'STNOCD', 'AENOCD' }

-- Reads a sequence text. Returns the sequence or nil and the reason.
local function Parse(text)
	local seq = { before = {}, steps = {} }
	local started = false
	local n = 0
	for raw in (text .. '\n'):gmatch('(.-)\r?\n') do
		n = n + 1
		local line = raw:match('^%s*(.-)%s*$')
		if line ~= '' and line:sub(1, 1) ~= '#' then
			local key, rest = line:match('^(%S+)%s*(.*)$')
			if not started then
				if key ~= 'SeqARK' or rest ~= '1' then return nil, 'the first line must be "SeqARK 1"' end
				started = true
			elseif key == 'name' then seq.name = rest
			elseif key == 'title' then seq.title = rest
			elseif key == 'spec' then seq.spec = tonumber(rest)
			elseif key == 'icon' then
				seq.icon = rest:match('^{(%d+)}$')
				if not seq.icon then return nil, 'line ' .. n .. ': the icon line needs one spell id, like icon {53385}' end
			elseif key == 'before' then table.insert(seq.before, rest)
			elseif key == 'step' then table.insert(seq.steps, rest)
			else return nil, 'line ' .. n .. ' is not known: ' .. line end
		end
	end
	if not started then return nil, 'the text is empty' end
	if not seq.name or not seq.name:match('^[%w_]+$') then return nil, 'the name may have letters, digits and _ only' end
	if not seq.spec then return nil, 'the spec line is missing' end
	if #seq.steps == 0 then return nil, 'there is no step line' end
	return seq
end

-- {12345} becomes the spell's name. Returns the text and the first ID that has no name yet.
local function Resolve(text)
	local missing
	local out = text:gsub('{(%d+)}', function(id)
		local name = C_Spell.GetSpellName(tonumber(id))
		if not name then
			missing = missing or id
			return '{' .. id .. '}'
		end
		return name
	end)
	return out, missing
end

-- Sequences are kept per specialization: "70:ST" is Retribution's ST, so every spec can have
-- its own ST. An imported sequence replaces the built-in one with the same spec and name.
local function Key(spec, name) return spec .. ':' .. name end

-- Every sequence, read: key -> { seq, text, imported, replaces }. Texts that do not read are
-- in the second table (key -> reason).
local function All()
	local all, bad = {}, {}
	for _, text in pairs(BUILTIN) do
		local seq = Parse(text)
		all[Key(seq.spec, seq.name)] = { seq = seq, text = text }
	end
	for key, text in pairs(SeqARKDB.sequences) do
		local seq, err = Parse(text)
		if seq then
			local builtin = all[key]
			all[key] = { seq = seq, text = text, imported = true, replaces = builtin ~= nil }
		else
			bad[key] = err
		end
	end
	return all, bad
end

local header = CreateFrame('Frame', nil, nil, 'SecureHandlerBaseTemplate')
-- The keys belong to SeqARK only while you are on foot. On a mount, in a vehicle or with an
-- override bar (skyriding, quests) the keys go back to the action bar, which then holds the
-- mount's or vehicle's buttons. A secure state driver does the switch, so it also works in
-- combat; the keys and their buttons are kept as attributes for it (key1/target1, ...).
local RELEASE = '[mounted][vehicleui][overridebar][possessbar] off; on'
local owner = CreateFrame('Frame', nil, nil, 'SecureHandlerStateTemplate')
owner:SetAttribute('_onstate-seqark', [[
	self:ClearBindings()
	if newstate == 'off' then return end
	for i = 1, self:GetAttribute('keycount') or 0 do
		self:SetBindingClick(true, self:GetAttribute('key' .. i), self:GetAttribute('target' .. i), 'LeftButton')
	end
]])
RegisterStateDriver(owner, 'seqark', RELEASE)
local buttons, relays, info = {}, {}, {}

-- Runs in the secure environment before each click; the button then runs the macro text.
-- The button acts on the release half only, so each key press moves exactly one step: the
-- relay's click arrives as a release, and a key bound straight to the button sends a press
-- (not registered) and a release.
--
-- On a mount the press does nothing and the step stays: a cast would take you off the mount.
-- (The keys are the action bar's there anyway; this covers a click from elsewhere.)
local PRE_CLICK = [[
	if SecureCmdOptionParse('[mounted][vehicleui][overridebar][possessbar] 1') then return false end
	local count = self:GetAttribute('count') or 0
	if count == 0 then return false end
	local step = self:GetAttribute('step') or 1
	if step > count then step = 1 end
	self:SetAttribute('macrotext', self:GetAttribute('m' .. step))
	self:SetAttribute('step', step % count + 1)
]]

local function Button(name)
	local button = buttons[name]
	if button then return button end
	button = CreateFrame('Button', 'SeqARK_' .. name, nil, 'SecureActionButtonTemplate')
	button:SetAttribute('type', 'macro')
	button:SetAttribute('useOnKeyDown', false)
	button:RegisterForClicks('AnyUp')
	header:WrapScript(button, 'OnClick', PRE_CLICK)
	buttons[name] = button
	-- The key-down relay: clicks the sequence button the moment the key goes down.
	local relay = CreateFrame('Button', 'SeqARK_' .. name .. '_Key', nil, 'SecureActionButtonTemplate')
	relay:SetAttribute('type', 'click')
	relay:SetAttribute('clickbutton', button)
	relay:SetAttribute('useOnKeyDown', true)
	relay:RegisterForClicks('AnyDown')
	relays[name] = relay
	return button
end

-- The keys from /seqark bind, per character and specialization.
local function Keys(spec)
	SeqARKCharDB.keys[spec] = SeqARKCharDB.keys[spec] or {}
	return SeqARKCharDB.keys[spec]
end

local function CurrentSpec()
	local index = GetSpecialization and GetSpecialization()
	return index and GetSpecializationInfo(index)
end

-- Puts the override bindings on the keys of this spec's sequences (on foot; see RELEASE).
local function ApplyKeys(spec)
	ClearOverrideBindings(owner)
	local count = 0
	if spec then
		local keyDown = GetCVarBool('ActionButtonUseKeyDown')
		for name, key in pairs(Keys(spec)) do
			if info[name] then
				count = count + 1
				local target = keyDown and relays[name] or buttons[name]
				owner:SetAttribute('key' .. count, key)
				owner:SetAttribute('target' .. count, target:GetName())
			end
		end
	end
	owner:SetAttribute('keycount', count)
	if SecureCmdOptionParse(RELEASE) ~= 'on' then return end
	for i = 1, count do
		SetOverrideBindingClick(owner, true, owner:GetAttribute('key' .. i), owner:GetAttribute('target' .. i), 'LeftButton')
	end
end

local pending, retried = false, false
local Refresh -- the window's list, set further down
local Launcher -- the minimap button, set further down

-- Builds this spec's buttons from their texts. Out of combat only: the attributes are protected.
local function Build(quiet)
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local spec = CurrentSpec()
	local waiting = false
	wipe(info)
	-- Every button starts empty, also the one of a sequence deleted since the last build.
	for _, button in pairs(buttons) do
		for i = 1, (button:GetAttribute('count') or 0) do button:SetAttribute('m' .. i, nil) end
		button:SetAttribute('count', 0)
		button:SetAttribute('step', 1)
	end
	local all, bad = All()
	for key, err in pairs(bad) do Print(key .. ': ' .. err) end
	for _, entry in pairs(all) do
		local seq = entry.seq
		if seq.spec == spec then
			local button = Button(seq.name)
			local before = table.concat(seq.before, '\n')
			for i, step in ipairs(seq.steps) do
				local macro, missing = Resolve(before ~= '' and before .. '\n' .. step or step)
				if missing then waiting = true end
				if #macro > MACRO_LIMIT and not quiet then
					Print(seq.name .. ' step ' .. i .. ' is ' .. #macro .. ' characters; the game reads ' .. MACRO_LIMIT .. '.')
				end
				button:SetAttribute('m' .. i, macro)
			end
			button:SetAttribute('count', #seq.steps)
			info[seq.name] = seq
		end
	end
	ApplyKeys(spec)
	-- Spell names can still be loading right after login: one more try a little later.
	if waiting and not retried then
		retried = true
		C_Timer.After(3, function() Build(true) end)
	elseif waiting then
		Print('some spells have no name yet; /seqark rebuild tries again.')
	end
	Refresh()
end

-- Leaving combat starts every sequence from step 1.
local function ResetSteps()
	for _, button in pairs(buttons) do button:SetAttribute('step', 1) end
end

local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
events:RegisterEvent('CVAR_UPDATE')
events:SetScript('OnEvent', function(_, event, arg)
	if event == 'ADDON_LOADED' then
		if arg == addonName then
			SeqARKDB = SeqARKDB or {}
			SeqARKDB.sequences = SeqARKDB.sequences or {}
			SeqARKCharDB = SeqARKCharDB or {}
			SeqARKCharDB.keys = SeqARKCharDB.keys or {}
			-- 0.4 and older kept the imported sequences by name only.
			local old = {}
			for key, text in pairs(SeqARKDB.sequences) do
				if not key:find(':', 1, true) then old[key] = text end
			end
			for key, text in pairs(old) do
				SeqARKDB.sequences[key] = nil
				local seq = Parse(text)
				if seq then SeqARKDB.sequences[Key(seq.spec, seq.name)] = text end
			end
		end
	elseif event == 'PLAYER_LOGIN' then
		Build()
		Launcher()
	elseif event == 'PLAYER_REGEN_ENABLED' then
		if pending then Build(true) end
		ResetSteps()
	elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
		retried = false
		Build()
	elseif event == 'CVAR_UPDATE' and arg == 'ActionButtonUseKeyDown' then
		-- The key goes to the relay or straight to the button: set again out of combat.
		if InCombatLockdown() then pending = true else ApplyKeys(CurrentSpec()) end
	end
end)

local ICON = [[Interface\AddOns\SeqARK\Icon]]

local function SpecInfo(spec)
	local _, specName, _, _, _, classFile, className = GetSpecializationInfoByID(spec)
	return specName, classFile, className
end

-- A spec of this character's class: its keys can be set here.
local function OwnClass(spec)
	local _, classFile = SpecInfo(spec)
	return classFile ~= nil and classFile == select(2, UnitClass('player'))
end

-- Puts a sequence on a key, or takes its key off (key nil). Out of combat only: the override
-- bindings are protected. A key holds one sequence per spec; it leaves the one that had it.
local function SetKey(spec, name, key)
	if InCombatLockdown() or not spec then return false end
	local keys = Keys(spec)
	if key then
		for other, used in pairs(keys) do
			if used == key then keys[other] = nil end
		end
	end
	keys[name] = key
	ApplyKeys(CurrentSpec())
	return true
end

-- Imports a sequence text. Returns the sequence, or nil and the reason nothing was imported.
local function Import(text)
	local seq, err = Parse(text)
	if not seq then return nil, err end
	if not SpecInfo(seq.spec) then return nil, 'the game has no specialization with the id ' .. seq.spec end
	for id in text:gmatch('{(%d+)}') do
		if not C_Spell.GetSpellName(tonumber(id)) then return nil, 'the game has no spell with the id ' .. id end
	end
	if InCombatLockdown() then return nil, 'not in combat; import again afterwards' end
	SeqARKDB.sequences[Key(seq.spec, seq.name)] = text
	Build()
	local specName, _, className = SpecInfo(seq.spec)
	Print(seq.name .. ' imported for ' .. className .. ' ' .. specName .. ', ' .. #seq.steps .. (#seq.steps == 1 and ' step.' or ' steps.'))
	return seq
end

-- Deletes an imported sequence. Returns nil, or the reason it was not deleted.
local function Delete(spec, name)
	local key = Key(spec, name)
	if not SeqARKDB.sequences[key] then return name .. ' is not an imported sequence' end
	if InCombatLockdown() then return 'not in combat' end
	SeqARKDB.sequences[key] = nil
	local builtin = All()[key]
	Build()
	Print(name .. ' deleted' .. (builtin and ', the built-in one is back.' or '.'))
end

-- Makes (or updates) the sequence's icon macro and puts it on the cursor, to be dropped on an
-- action bar slot. The macro only shows the spell (#showtooltip); it runs nothing, the key is
-- SeqARK's. A character macro, named after the sequence and its spec. Returns the macro's
-- name, or nil and the reason.
local ICON_QUESTION = 134400 -- with #showtooltip the macro shows the spell's own icon
local function IconMacro(seq)
	if InCombatLockdown() then return nil, 'not in combat' end
	local id = seq.icon or seq.steps[1]:match('{(%d+)}')
	local spell = id and C_Spell.GetSpellName(tonumber(id))
	local body = spell and '#showtooltip ' .. spell or ''
	local macroName = (seq.name .. ' ' .. (SpecInfo(seq.spec) or '')):sub(1, 16)
	local index = GetMacroIndexByName(macroName)
	if index and index > 0 then
		EditMacro(index, macroName, ICON_QUESTION, body)
	else
		local _, characterMacros = GetNumMacros()
		if characterMacros >= (MAX_CHARACTER_MACROS or 30) then return nil, 'the character macro list is full' end
		index = CreateMacro(macroName, ICON_QUESTION, body, true)
		if not index or index == 0 then return nil, 'the game did not make the macro' end
	end
	PickupMacro(index)
	return macroName
end

-- The window -------------------------------------------------------------------------------
-- Flat and dark like SlimARK-UI, but on its own: SeqARK needs no other addon.

local FONT = STANDARD_TEXT_FONT
local C = {
	body = { 0.071, 0.075, 0.094 },
	head = { 0.063, 0.067, 0.082 },
	side = { 0.055, 0.059, 0.071 },
	button = { 0.090, 0.094, 0.114 },
	selected = { 0.114, 0.118, 0.141 },
	field = { 0.047, 0.051, 0.063 },
	outer = { 0.169, 0.176, 0.208 },
	line = { 0.290, 0.298, 0.337 },
	black = { 0, 0, 0 },
	gold = { 0.949, 0.722, 0.290 },
	ink = { 0.102, 0.078, 0.031 },
	text = { 0.929, 0.910, 0.871 },
	soft = { 0.729, 0.710, 0.659 },
	dim = { 0.435, 0.424, 0.400 },
	red = { 1, 0.541, 0.478 },
	errorBack = { 0.165, 0.078, 0.078 },
	errorText = { 1, 0.706, 0.659 },
}

local function Fill(frame, color, layer, sublevel)
	local tex = frame:CreateTexture(nil, layer or 'BACKGROUND', nil, sublevel)
	tex:SetAllPoints()
	tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return tex
end

-- A one pixel line on each side; :Color() recolors it.
local function Edge(frame, color)
	local edge = {}
	for _, side in ipairs({ 'TOP', 'BOTTOM', 'LEFT', 'RIGHT' }) do
		local tex = frame:CreateTexture(nil, 'BORDER')
		if side == 'TOP' or side == 'BOTTOM' then
			tex:SetPoint(side .. 'LEFT')
			tex:SetPoint(side .. 'RIGHT')
			tex:SetHeight(1)
		else
			tex:SetPoint('TOP' .. side)
			tex:SetPoint('BOTTOM' .. side)
			tex:SetWidth(1)
		end
		edge[#edge + 1] = tex
	end
	function edge:Color(c)
		for _, tex in ipairs(self) do tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
	end
	edge:Color(color)
	return edge
end

local function Text(parent, size, color)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(FONT, size, '')
	fs:SetTextColor(color[1], color[2], color[3])
	fs:SetJustifyH('LEFT')
	fs:SetWordWrap(false)
	return fs
end

local function Btn(parent, label, width, height, kind)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, height)
	Fill(button, kind == 'gold' and C.gold or C.button)
	Edge(button, C.black)
	local color = kind == 'gold' and C.ink or kind == 'danger' and C.red or C.text
	local fs = Text(button, kind == 'gold' and 14 or 13, color)
	fs:SetPoint('CENTER')
	button:SetFontString(fs)
	button:SetText(label)
	Fill(button, { 1, 1, 1, 0.07 }, 'HIGHLIGHT')
	return button
end

-- A movable window with the gold top line, a title band and a close button; Esc closes it.
local function Panel(name, width, height)
	local frame = CreateFrame('Frame', name, UIParent)
	frame:SetSize(width, height)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata('DIALOG')
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	local outer = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
	outer:SetPoint('TOPLEFT', -2, 2)
	outer:SetPoint('BOTTOMRIGHT', 2, -2)
	outer:SetColorTexture(C.outer[1], C.outer[2], C.outer[3])
	Fill(frame, C.body)
	Edge(frame, C.black)
	local gold = frame:CreateTexture(nil, 'ARTWORK')
	gold:SetPoint('TOPLEFT', 1, -1)
	gold:SetPoint('TOPRIGHT', -1, -1)
	gold:SetHeight(2)
	gold:SetColorTexture(C.gold[1], C.gold[2], C.gold[3])
	local head = CreateFrame('Frame', nil, frame)
	head:SetPoint('TOPLEFT', 1, -3)
	head:SetPoint('TOPRIGHT', -1, -3)
	head:SetHeight(32)
	Fill(head, C.head)
	local line = head:CreateTexture(nil, 'BORDER')
	line:SetPoint('BOTTOMLEFT')
	line:SetPoint('BOTTOMRIGHT')
	line:SetHeight(1)
	line:SetColorTexture(0, 0, 0)
	head:EnableMouse(true)
	head:RegisterForDrag('LeftButton')
	head:SetScript('OnDragStart', function() frame:StartMoving() end)
	head:SetScript('OnDragStop', function() frame:StopMovingOrSizing() end)
	frame.title = Text(head, 17, C.text)
	frame.title:SetPoint('LEFT', 14, 0)
	local close = Btn(head, 'x', 20, 20)
	close:SetPoint('RIGHT', -8, 0)
	close:SetScript('OnClick', function() frame:Hide() end)
	tinsert(UISpecialFrames, name)
	return frame
end

local Select -- shows a spec in the main window, set further down

-- The paste window: import a sequence text, or show one to copy.
local paste
local function Paste(entry)
	if not paste then
		paste = Panel('SeqARKPaste', 560, 390)
		paste:SetFrameStrata('FULLSCREEN_DIALOG')
		paste.note = Text(paste, 13, C.soft)
		paste.note:SetPoint('TOPLEFT', 15, -45)
		local box = CreateFrame('Frame', nil, paste)
		box:SetPoint('TOPLEFT', 15, -66)
		box:SetPoint('TOPRIGHT', -15, -66)
		box:SetHeight(236)
		Fill(box, C.field)
		Edge(box, C.line)
		local scroll = CreateFrame('ScrollFrame', nil, box)
		scroll:SetPoint('TOPLEFT', 8, -8)
		scroll:SetPoint('BOTTOMRIGHT', -8, 8)
		local edit = CreateFrame('EditBox', nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(ChatFontNormal)
		edit:SetTextColor(C.text[1], C.text[2], C.text[3])
		edit:SetWidth(508)
		edit:SetHeight(220)
		scroll:SetScrollChild(edit)
		edit:SetScript('OnEscapePressed', function() paste:Hide() end)
		-- Keeps the cursor in sight while typing or pasting.
		edit:SetScript('OnCursorChanged', function(_, _, y, _, h)
			local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
			y = -y
			if y < top then
				scroll:SetVerticalScroll(y)
			elseif y + h > top + height then
				scroll:SetVerticalScroll(y + h - height)
			end
		end)
		edit:SetScript('OnTextChanged', function(self, byUser)
			if not byUser then return end
			if paste.exported then
				-- An exported text stays as it is; it is there to be copied.
				self:SetText(paste.exported)
				self:HighlightText()
			else
				paste.err:Hide()
			end
		end)
		scroll:EnableMouseWheel(true)
		scroll:SetScript('OnMouseWheel', function(self, delta)
			local range = self:GetVerticalScrollRange()
			self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 30)))
		end)
		box:EnableMouse(true)
		box:SetScript('OnMouseDown', function() edit:SetFocus() end)
		paste.edit = edit
		local err = CreateFrame('Frame', nil, paste)
		err:SetPoint('TOPLEFT', 15, -310)
		err:SetPoint('TOPRIGHT', -15, -310)
		err:SetHeight(28)
		Fill(err, C.errorBack)
		Edge(err, C.black)
		local bar = err:CreateTexture(nil, 'ARTWORK')
		bar:SetPoint('TOPLEFT')
		bar:SetPoint('BOTTOMLEFT')
		bar:SetWidth(3)
		bar:SetColorTexture(C.red[1], C.red[2], C.red[3])
		err.text = Text(err, 13, C.errorText)
		err.text:SetPoint('LEFT', 12, 0)
		err.text:SetPoint('RIGHT', -8, 0)
		paste.err = err
		paste.import = Btn(paste, 'Import', 90, 28, 'gold')
		paste.import:SetPoint('BOTTOMRIGHT', -15, 12)
		paste.import:SetScript('OnClick', function()
			local seq, reason = Import(edit:GetText())
			if seq then
				paste:Hide()
				-- The window shows the spec the sequence went to.
				if Select then Select(seq.spec) end
			else
				err.text:SetText('Nothing was imported: ' .. reason .. '.')
				err:Show()
			end
		end)
		paste.cancel = Btn(paste, 'Cancel', 80, 28)
		paste.cancel:SetScript('OnClick', function() paste:Hide() end)
	end
	paste.err:Hide()
	paste.cancel:ClearAllPoints()
	if entry then
		paste.exported = entry.text
		paste.title:SetText('SeqARK export: ' .. entry.seq.name)
		paste.note:SetText('Ctrl+C copies the text. Paste it into SeqARK on another character to import it.')
		paste.import:Hide()
		paste.cancel:SetText('Close')
		paste.cancel:SetPoint('BOTTOMRIGHT', -15, 12)
	else
		paste.exported = nil
		paste.title:SetText('SeqARK import')
		paste.note:SetText('Paste one SeqARK text. A sequence with the same spec and name replaces the old one.')
		paste.import:Show()
		paste.cancel:SetText('Cancel')
		paste.cancel:SetPoint('RIGHT', paste.import, 'LEFT', -8, 0)
	end
	paste.edit:SetText(paste.exported or '')
	paste:Show()
	paste.edit:SetFocus()
	if paste.exported then paste.edit:HighlightText() end
end

-- The main window: Class / Spec on the left, the chosen spec's sequences on the right.
local main, capture
local rows, tree = {}, {}
local selected -- the spec shown on the right
local capturing -- { spec, name } of the key field waiting for a key
local notice -- a one-off message in place of the hint line
local SIDE = 190 -- width of the Class / Spec list
local LEFT = SIDE + 16 -- left edge of the sequence list
local ROW_H, ROW_GAP, FIRST_ROW = 44, 3, -96
local COL_STEPS, COL_SOURCE, COL_KEY = 206, 254, 366
local IGNORED = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true, PRINTSCREEN = true,
}

local function StopCapture()
	capturing = nil
	if capture then capture:EnableKeyboard(false) end
end

local function Waiting(spec, name)
	return capturing ~= nil and capturing.spec == spec and capturing.name == name
end

local function ShowKey(field, key, waiting, own)
	field:SetEnabled(own)
	if not own then
		field.edge:Color(C.outer)
		field.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		field.label:SetText('Other class')
	elseif waiting then
		field.edge:Color(C.gold)
		field.label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		field.label:SetText('Press a key...')
	elseif key then
		field.edge:Color(C.line)
		field.label:SetTextColor(C.text[1], C.text[2], C.text[3])
		field.label:SetText(key)
	else
		field.edge:Color(C.outer)
		field.label:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
		field.label:SetText('Click to bind')
	end
end

-- The Class / Spec list: classes and specs that have sequences, and the current spec always.
-- This character's class comes first, the others by name.
local function Classes(all)
	local counts = {}
	for _, entry in pairs(all) do counts[entry.seq.spec] = (counts[entry.seq.spec] or 0) + 1 end
	local current = CurrentSpec()
	if current then counts[current] = counts[current] or 0 end
	local list, byFile = {}, {}
	for spec, count in pairs(counts) do
		local specName, classFile, className = SpecInfo(spec)
		classFile = classFile or 'UNKNOWN'
		local class = byFile[classFile]
		if not class then
			class = { file = classFile, name = className or 'Unknown', specs = {} }
			byFile[classFile] = class
			list[#list + 1] = class
		end
		class.specs[#class.specs + 1] = { id = spec, name = specName or ('Spec ' .. spec), count = count }
	end
	local own = select(2, UnitClass('player'))
	table.sort(list, function(a, b)
		if (a.file == own) ~= (b.file == own) then return a.file == own end
		return a.name < b.name
	end)
	for _, class in ipairs(list) do
		table.sort(class.specs, function(a, b) return a.name < b.name end)
	end
	return list
end

local function TreeLine(i)
	local line = tree[i]
	if line then return line end
	line = CreateFrame('Button', nil, main)
	line:SetHeight(28)
	line.bg = Fill(line, C.selected)
	line.bar = line:CreateTexture(nil, 'ARTWORK')
	line.bar:SetPoint('TOPLEFT')
	line.bar:SetPoint('BOTTOMLEFT')
	line.bar:SetWidth(3)
	line.bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3])
	line.hl = Fill(line, { 1, 1, 1, 0.05 }, 'HIGHLIGHT')
	line.label = Text(line, 15, C.text)
	line.count = Text(line, 13, C.soft)
	line.count:SetPoint('RIGHT', -12, 0)
	line:SetScript('OnClick', function(self)
		if self.spec then Select(self.spec) end
	end)
	tree[i] = line
	return line
end

-- Draws the Class / Spec list. Returns how far down it goes.
local function DrawTree(classes)
	local y, n = -40, 0
	local current = CurrentSpec()
	for _, class in ipairs(classes) do
		n = n + 1
		local line = TreeLine(n)
		line.spec = nil
		line:SetHeight(24)
		line:ClearAllPoints()
		line:SetPoint('TOPLEFT', 1, y)
		line:SetWidth(SIDE)
		line.bg:Hide()
		line.bar:Hide()
		line.hl:Hide()
		line:EnableMouse(false)
		local color = C_ClassColor and C_ClassColor.GetClassColor(class.file)
		line.label:SetFont(FONT, 13, '')
		line.label:SetText(string.upper(class.name))
		line.label:ClearAllPoints()
		line.label:SetPoint('BOTTOMLEFT', 12, 3)
		if color then
			line.label:SetTextColor(color.r, color.g, color.b)
		else
			line.label:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
		end
		line.count:SetText('')
		line:Show()
		y = y - 24
		for _, spec in ipairs(class.specs) do
			n = n + 1
			line = TreeLine(n)
			line.spec = spec.id
			line:SetHeight(28)
			line:ClearAllPoints()
			line:SetPoint('TOPLEFT', 1, y)
			line:SetWidth(SIDE)
			local isSelected = spec.id == selected
			line.bg:SetShown(isSelected)
			line.bar:SetShown(isSelected)
			line.hl:Show()
			line:EnableMouse(true)
			line.label:SetFont(FONT, 15, '')
			line.label:ClearAllPoints()
			line.label:SetPoint('LEFT', 24, 0)
			line.label:SetPoint('RIGHT', line.count, 'LEFT', -6, 0)
			line.label:SetText(spec.name .. (spec.id == current and ' |cffbab5a8- current|r' or ''))
			local c = isSelected and C.gold or C.text
			line.label:SetTextColor(c[1], c[2], c[3])
			line.count:SetText(spec.count)
			line:Show()
			y = y - 28
		end
	end
	for i = n + 1, #tree do tree[i]:Hide() end
	return y
end

local function OnKeyField(spec, name, mouse)
	notice = nil
	if InCombatLockdown() then
		StopCapture()
		notice = 'Keys can be set out of combat only.'
	elseif mouse == 'RightButton' then
		StopCapture()
		SetKey(spec, name, nil)
	elseif Waiting(spec, name) then
		StopCapture()
	else
		capturing = { spec = spec, name = name }
		capture:EnableKeyboard(true)
	end
	Refresh()
end

local function NewRow(i)
	local row = CreateFrame('Frame', nil, main)
	row:SetHeight(ROW_H)
	Fill(row, C.button)
	Edge(row, C.black)
	row.name = Text(row, 16, C.text)
	row.name:SetPoint('TOPLEFT', 10, -7)
	row.title = Text(row, 12, C.soft)
	row.title:SetPoint('TOPLEFT', 10, -26)
	row.title:SetWidth(COL_STEPS - 18)
	row.steps = Text(row, 15, C.text)
	row.steps:SetPoint('LEFT', COL_STEPS, 0)
	row.source = Text(row, 13, C.soft)
	row.replaces = Text(row, 11, C.soft)
	row.replaces:SetPoint('TOPLEFT', row.source, 'BOTTOMLEFT', 0, -2)
	row.replaces:SetText('replaces the built-in one')
	local field = CreateFrame('Button', nil, row)
	field:SetSize(120, 26)
	field:SetPoint('LEFT', COL_KEY, 0)
	field:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	Fill(field, C.field)
	field.edge = Edge(field, C.line)
	Fill(field, { 1, 1, 1, 0.05 }, 'HIGHLIGHT')
	field.label = Text(field, 14, C.text)
	field.label:SetPoint('LEFT', 8, 0)
	field.label:SetPoint('RIGHT', -8, 0)
	field:SetScript('OnClick', function(_, mouse) OnKeyField(row.entry.seq.spec, row.entry.seq.name, mouse) end)
	row.key = field
	row.delete = Btn(row, 'Delete', 58, 26, 'danger')
	row.delete:SetPoint('RIGHT', -10, 0)
	row.delete:SetScript('OnClick', function()
		StopCapture()
		local reason = Delete(row.entry.seq.spec, row.entry.seq.name)
		notice = reason and 'Not deleted: ' .. reason .. '.' or nil
		Refresh()
	end)
	row.export = Btn(row, 'Export', 58, 26)
	row.export:SetScript('OnClick', function() Paste(row.entry) end)
	row.icon = Btn(row, 'Icon', 46, 26)
	row.icon:SetPoint('RIGHT', row.export, 'LEFT', -6, 0)
	row.icon:SetScript('OnClick', function()
		StopCapture()
		local macro, reason = IconMacro(row.entry.seq)
		if macro then
			notice = 'The ' .. macro .. ' macro is on your cursor: drop it on the action bar slot of the same key.'
		else
			notice = 'No icon macro: ' .. reason .. '.'
		end
		Refresh()
	end)
	rows[i] = row
	return row
end

function Refresh()
	if not main or not main:IsShown() then return end
	local all = All()
	local classes = Classes(all)
	-- The chosen spec stays while it is listed; otherwise the current one.
	local listed = false
	for _, class in ipairs(classes) do
		for _, spec in ipairs(class.specs) do
			if spec.id == selected then listed = true end
		end
	end
	if not listed then selected = CurrentSpec() or (classes[1] and classes[1].specs[1].id) end
	local treeBottom = DrawTree(classes)

	local spec = selected
	local specName, _, className = SpecInfo(spec or 0)
	main.spec:SetText(specName and (className .. ' - ' .. specName) or 'No specialization')
	local own = spec ~= nil and OwnClass(spec)
	local keys = own and Keys(spec) or {}
	local entries = {}
	for _, entry in pairs(all) do
		if entry.seq.spec == spec then entries[#entries + 1] = entry end
	end
	local rank = {}
	for i, name in ipairs(ORDER) do rank[name] = i end
	table.sort(entries, function(a, b)
		local ra, rb = rank[a.seq.name] or 99, rank[b.seq.name] or 99
		if ra ~= rb then return ra < rb end
		return a.seq.name < b.seq.name
	end)

	local y = FIRST_ROW
	for i, entry in ipairs(entries) do
		local row = rows[i] or NewRow(i)
		local seq = entry.seq
		row.entry = entry
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', LEFT, y)
		row:SetPoint('TOPRIGHT', -15, y)
		row.name:SetText(seq.name)
		row.title:SetText(seq.title or '')
		row.steps:SetText(#seq.steps)
		local color = entry.imported and C.gold or C.soft
		row.source:SetText(entry.imported and 'Imported' or 'Built in')
		row.source:SetTextColor(color[1], color[2], color[3])
		row.source:ClearAllPoints()
		row.source:SetPoint('LEFT', COL_SOURCE, entry.replaces and 6 or 0)
		row.replaces:SetShown(entry.replaces == true)
		ShowKey(row.key, keys[seq.name], Waiting(seq.spec, seq.name), own)
		row.delete:SetShown(entry.imported == true)
		row.export:ClearAllPoints()
		if entry.imported then
			row.export:SetPoint('RIGHT', row.delete, 'LEFT', -6, 0)
		else
			row.export:SetPoint('RIGHT', -10, 0)
		end
		row:Show()
		y = y - ROW_H - ROW_GAP
	end
	for i = #entries + 1, #rows do rows[i]:Hide() end
	main.empty:SetShown(#entries == 0)
	if #entries == 0 then y = y - 40 end
	local listHeight = -y - ROW_GAP + 52
	local treeHeight = -treeBottom + 70 -- room for the note under the list
	main:SetHeight(math.max(listHeight, treeHeight, 300))

	if notice then
		main.hint:SetText(notice)
	elseif capturing then
		main.hint:SetText('Press the key for ' .. capturing.name .. ' now (Shift, Ctrl, Alt work too). Esc cancels.')
	elseif not own then
		main.hint:SetText('Keys are set on a character of this class. Export and delete work here.')
	else
		main.hint:SetText('Click a key field and press the key. Right-click it to clear the key.')
	end
end

function Select(spec)
	StopCapture()
	notice = nil
	selected = spec
	Refresh()
end

local function Header(label, x)
	local fs = Text(main, 12, C.soft)
	fs:SetPoint('TOPLEFT', LEFT + x, -74)
	fs:SetText(label)
	return fs
end

local function OpenMain()
	if not main then
		main = Panel('SeqARKMain', 900, 300)
		main.title:SetText('SeqARK')
		local side = main:CreateTexture(nil, 'BACKGROUND', nil, 1)
		side:SetPoint('TOPLEFT', 1, -36)
		side:SetPoint('BOTTOMLEFT', 1, 1)
		side:SetWidth(SIDE)
		side:SetColorTexture(C.side[1], C.side[2], C.side[3])
		local sideLine = main:CreateTexture(nil, 'BORDER')
		sideLine:SetPoint('TOPLEFT', SIDE + 1, -36)
		sideLine:SetPoint('BOTTOMLEFT', SIDE + 1, 1)
		sideLine:SetWidth(1)
		sideLine:SetColorTexture(0, 0, 0)
		local sideNote = main:CreateFontString(nil, 'OVERLAY')
		sideNote:SetFont(FONT, 12, '')
		sideNote:SetTextColor(C.soft[1], C.soft[2], C.soft[3])
		sideNote:SetJustifyH('LEFT')
		sideNote:SetPoint('BOTTOMLEFT', 13, 12)
		sideNote:SetWidth(SIDE - 24)
		sideNote:SetText('Only classes and specs with sequences are listed, and your current spec always.')
		main.spec = Text(main, 15, C.gold)
		main.spec:SetPoint('TOPLEFT', LEFT, -45)
		local saved = Text(main, 13, C.soft)
		saved:SetPoint('TOPRIGHT', -15, -47)
		saved:SetText('Keys are saved per character and specialization')
		Header('SEQUENCE', 10)
		Header('STEPS', COL_STEPS)
		Header('SOURCE', COL_SOURCE)
		Header('KEY', COL_KEY)
		local line = main:CreateTexture(nil, 'BORDER')
		line:SetPoint('TOPLEFT', LEFT, -92)
		line:SetPoint('TOPRIGHT', -15, -92)
		line:SetHeight(1)
		line:SetColorTexture(0, 0, 0)
		main.empty = Text(main, 13, C.soft)
		main.empty:SetPoint('TOPLEFT', LEFT + 10, -108)
		main.empty:SetText('No sequence for this specialization yet. Import one.')
		main.hint = Text(main, 13, C.soft)
		main.hint:SetPoint('BOTTOMLEFT', LEFT, 19)
		main.hint:SetPoint('RIGHT', -120, 0)
		local import = Btn(main, 'Import...', 90, 28, 'gold')
		import:SetPoint('BOTTOMRIGHT', -15, 12)
		import:SetScript('OnClick', function()
			StopCapture()
			notice = nil
			Refresh()
			Paste()
		end)
		-- Takes the next key press while a key field waits for one.
		capture = CreateFrame('Frame', nil, main)
		capture:SetScript('OnKeyDown', function(_, key)
			if IGNORED[key] then return end
			local wait = capturing
			StopCapture()
			if wait and key ~= 'ESCAPE' then
				local combo = (IsAltKeyDown() and 'ALT-' or '') .. (IsControlKeyDown() and 'CTRL-' or '')
					.. (IsShiftKeyDown() and 'SHIFT-' or '') .. key
				if not SetKey(wait.spec, wait.name, combo) then notice = 'Keys can be set out of combat only.' end
			end
			Refresh()
		end)
		main:SetScript('OnHide', function()
			StopCapture()
			notice = nil
		end)
	end
	selected = CurrentSpec()
	main:Show()
	Refresh()
end

local function ToggleMain()
	if main and main:IsShown() then main:Hide() else OpenMain() end
end

-- Entering combat ends a key capture: the bindings cannot change until it is over.
local combat = CreateFrame('Frame')
combat:RegisterEvent('PLAYER_REGEN_DISABLED')
combat:SetScript('OnEvent', function()
	if capturing then
		StopCapture()
		Refresh()
	end
end)

-- The minimap button, through LibDBIcon when another addon has loaded it (SlimARK-UI puts
-- those buttons in its minimap column), and the game's addon menu at the minimap.
function Launcher()
	local broker = LibStub and LibStub('LibDataBroker-1.1', true)
	local icons = LibStub and LibStub('LibDBIcon-1.0', true)
	if not broker or not icons or icons:IsRegistered('SeqARK') then return end
	local version = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, 'Version') or ''
	local object = broker:NewDataObject('SeqARK', {
		type = 'launcher',
		text = 'SeqARK',
		icon = ICON,
		OnClick = function() ToggleMain() end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine('SeqARK ' .. version)
			tooltip:AddLine('Click: open the window', 1, 1, 1)
		end,
	})
	if not object then return end
	SeqARKDB.minimap = SeqARKDB.minimap or {}
	icons:Register('SeqARK', object, SeqARKDB.minimap)
end

function SeqARK_OnAddonCompartmentClick()
	ToggleMain()
end

local function List()
	local any = false
	local spec = CurrentSpec()
	local keys = spec and Keys(spec) or {}
	for _, name in ipairs(ORDER) do
		local seq = info[name]
		if seq then
			any = true
			Print(name .. ': ' .. (seq.title or '') .. ' - ' .. #seq.steps .. ' steps, key: ' .. (keys[name] or 'none'))
		end
	end
	for name, seq in pairs(info) do
		if not BUILTIN[name] then
			any = true
			Print(name .. ': ' .. (seq.title or '') .. ' - ' .. #seq.steps .. (#seq.steps == 1 and ' step' or ' steps') .. ', key: ' .. (keys[name] or 'none'))
		end
	end
	if not any then Print('no sequence for this specialization.') end
	Print('/seqark opens the window. Also: /seqark list, bind NAME KEY, unbind NAME, icon NAME, import, export NAME, delete NAME, rebuild')
end

SLASH_SEQARK1 = '/seqark'
SlashCmdList.SEQARK = function(msg)
	local cmd, arg = (msg or ''):match('^%s*(%S*)%s*(.-)%s*$')
	cmd = cmd:lower()
	local spec = CurrentSpec()
	if cmd == '' then
		ToggleMain()
	elseif cmd == 'list' then
		List()
	elseif cmd == 'import' then
		Paste()
	elseif cmd == 'export' or cmd == 'delete' or cmd == 'icon' then
		-- These work on the current spec's sequences, by name.
		local entry = spec and All()[Key(spec, arg)]
		if not entry then
			Print('there is no sequence called ' .. arg .. ' for this specialization.')
		elseif cmd == 'export' then
			Paste(entry)
		elseif cmd == 'delete' then
			local reason = Delete(spec, arg)
			if reason then Print('not deleted: ' .. reason .. '.') end
		else
			local macro, reason = IconMacro(entry.seq)
			if macro then
				Print('the ' .. macro .. ' macro is on your cursor: drop it on the action bar slot of the same key.')
			else
				Print('no icon macro: ' .. reason .. '.')
			end
		end
	elseif cmd == 'bind' or cmd == 'unbind' then
		local name, key = arg:match('^(%S+)%s*(%S*)$')
		if not name or not info[name] then
			Print('there is no sequence called ' .. (name or '') .. ' for this specialization.')
			return
		end
		if cmd == 'bind' and key == '' then
			Print('which key? For example: /seqark bind ' .. name .. ' 5')
			return
		end
		key = cmd == 'bind' and key:upper() or nil
		if not SetKey(spec, name, key) then
			Print('not in combat.')
		elseif key then
			Print(name .. ' is on ' .. key .. '. The action bar button of ' .. key .. ' does not run while SeqARK holds the key.')
		else
			Print(name .. ' has no key now.')
		end
		Refresh()
	elseif cmd == 'rebuild' then
		retried = false
		Build()
		Print('rebuilt.')
	else
		List()
	end
end
