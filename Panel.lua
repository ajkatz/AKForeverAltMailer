-- Panel: the preview beside the mail window. For each alt, what goes to it - icon, name, count, and why on
-- hovering - then what stays and why, and one button that sends it all (or, on a client that wants a click per
-- mail, the next mail). A right-click on an item puts it on your keep list: never mailed again. "Receivers"
-- opens the list of who takes what, where a click picks another alt.
--
-- It appears when a mailbox opens and goes when it closes - or when it sees the mail window gone, whatever the
-- events said; the X sends it away until the next mailbox. Nothing is written onto Blizzard's mail frame: the
-- panel is only anchored beside it, and only asks it whether it is shown.
local _, ns = ...

local Panel = {}
ns.Panel = Panel

local WIDTH, PAD, ROW, GAP = 300, 8, 16, 3
local MAX_ROWS = 18
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local GOLD, DIM, WHITE = "|cffffd100", "|cff999999", "|cffffffff"

local panel, title, note, closeButton, sendButton, receiversButton, keptLine, modeLine, emptyLine
local rows, headers = {}, {}
local receiversFrame, receiverRows = nil, {}
local dismissed = false -- the X: away until the next mailbox
Panel.rows, Panel.headers, Panel.receiverRows = rows, headers, receiverRows

local function classColor(class)
    local colors = type(RAID_CLASS_COLORS) == "table" and class and RAID_CLASS_COLORS[class] or nil
    return colors and colors.colorStr and ("|c" .. colors.colorStr) or WHITE
end

local function label(entry)
    return classColor(entry and entry.class) .. ns.Roster.Label(entry) .. "|r"
end

local function line(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetWidth(WIDTH - 2 * PAD)
    return fs
end

------------------------------------------------------------------------
-- Item rows
------------------------------------------------------------------------
local function showRowTooltip(row)
    local stack = row.stack
    if not stack then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if stack.link then
        pcall(GameTooltip.SetHyperlink, GameTooltip, stack.link)
    else
        GameTooltip:SetText(stack.name or ("item " .. stack.itemID))
    end
    local verdict = stack.verdict or {}
    if verdict.action == "send" then
        GameTooltip:AddLine("To " .. ns.Roster.Label(ns.Roster:Get(verdict.receiver)) .. ": " .. (verdict.reason or ""), 0.56, 0.82, 0.42, true)
    elseif verdict.reason then
        GameTooltip:AddLine("Stays: " .. verdict.reason, 0.7, 0.7, 0.7, true)
    end
    GameTooltip:AddLine("Right-click: never mail this item", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function itemRow(index)
    local row = rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", "AKForeverAltMailerRow" .. index, panel)
    row:SetSize(WIDTH - 2 * PAD, ROW)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW - 2, ROW - 2)
    row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", showRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.stack then
            ns.db.keep[self.stack.itemID] = true
            ns:Print((self.stack.name or ("item " .. self.stack.itemID)) .. " is on your keep list: never mailed. '/aam unkeep' lists and frees them.")
            ns:Log("keep_added", self.stack.itemID)
            Panel:Refresh()
        end
    end)
    rows[index] = row
    return row
end

local function headerLine(index)
    local fs = headers[index]
    if not fs then
        fs = line(panel, "GameFontNormalSmall")
        headers[index] = fs
    end
    return fs
end

------------------------------------------------------------------------
-- The send button's words
------------------------------------------------------------------------
function Panel.ButtonText(plan)
    local Mailer = ns.Mailer
    local session = Mailer.session
    if Mailer.pending and not Mailer.pending.blocked then
        return "Sending " .. ((session and session.sent or 0) + 1) .. " of " .. (session and session.total or "?") .. "...", false
    end
    if session and not session.done and session.waiting == "click" then
        return "Send next (" .. (session.sent + 1) .. " of " .. math.max(session.total, session.sent + 1) .. ")", true
    end
    if plan.mails == 0 then
        return "Nothing to mail", false
    end
    return "Send " .. plan.mails .. " mail" .. (plan.mails == 1 and "" or "s") .. " (" .. ns.FormatMoney(plan.postage) .. ")", true
end

local function modeText()
    local mode = ns.Mailer:Mode()
    if mode == "chain" then
        return "one click sends everything"
    elseif mode == "click" then
        return "this client wants one click per mail"
    end
    return "first run: one click, and the addon learns whether the rest go on their own"
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
function Panel:Refresh()
    if not panel or not panel:IsShown() then
        return
    end
    local plan = ns.Plan.Build()
    self.plan = plan
    local y = -PAD - 22
    note:SetText(plan.mails > 0 and (plan.mails .. " mail" .. (plan.mails == 1 and "" or "s") .. ", " .. plan.attachments .. " item" .. (plan.attachments == 1 and "" or "s") .. ", postage " .. ns.FormatMoney(plan.postage)) or "")
    local used, headerUsed = 0, 0
    local hidden = 0
    for _, group in ipairs(plan.receivers) do
        headerUsed = headerUsed + 1
        local header = headerLine(headerUsed)
        header:SetText(GOLD .. "To|r " .. label(group.entry) .. DIM .. "  " .. #group.mails .. " mail" .. (#group.mails == 1 and "" or "s") .. "|r")
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
        header:Show()
        y = y - ROW
        for _, stack in ipairs(group.stacks) do
            if used < MAX_ROWS then
                used = used + 1
                local row = itemRow(used)
                row.stack = stack
                row.icon:SetTexture(stack.icon)
                row.text:SetText((stack.name or ("item " .. stack.itemID)) .. (stack.count > 1 and (DIM .. " x" .. stack.count .. "|r") or ""))
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
                row:Show()
                y = y - ROW
            else
                hidden = hidden + 1
            end
        end
        y = y - GAP
    end
    for index = used + 1, #rows do
        rows[index].stack = nil
        rows[index]:Hide()
    end
    for index = headerUsed + 1, #headers do
        headers[index]:Hide()
    end
    if #plan.receivers == 0 then
        local known = #ns.Roster:Reachable()
        emptyLine:SetText(known <= 1 and "Nothing to mail yet: log in on each of your alts once, so the addon knows their professions."
            or "Nothing here for your alts.")
        emptyLine:ClearAllPoints()
        emptyLine:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
        emptyLine:Show()
        y = y - ROW * 2
    elseif hidden > 0 then
        emptyLine:SetText(DIM .. "+" .. hidden .. " more|r")
        emptyLine:ClearAllPoints()
        emptyLine:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 10, y)
        emptyLine:Show()
        y = y - ROW
    else
        emptyLine:Hide()
    end
    -- what stays, the commonest reasons first
    local reasons = {}
    for reason, count in pairs(plan.kept) do
        reasons[#reasons + 1] = { reason = reason, count = count }
    end
    table.sort(reasons, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.reason < b.reason end)
    local parts = {}
    for i = 1, math.min(3, #reasons) do
        parts[#parts + 1] = reasons[i].count .. " " .. reasons[i].reason
    end
    keptLine:SetText(#parts > 0 and (DIM .. "Stays: " .. table.concat(parts, "; ") .. (#reasons > 3 and " ..." or "") .. "|r") or "")
    keptLine:ClearAllPoints()
    keptLine:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
    y = y - ROW - GAP
    local text, enabled = Panel.ButtonText(plan)
    sendButton:SetText(text)
    sendButton:SetEnabled(enabled)
    sendButton:ClearAllPoints()
    sendButton:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
    receiversButton:ClearAllPoints()
    receiversButton:SetPoint("LEFT", sendButton, "RIGHT", 6, 0)
    y = y - 26
    modeLine:SetText(DIM .. modeText() .. "|r")
    modeLine:ClearAllPoints()
    modeLine:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
    y = y - ROW
    panel:SetHeight(-y + PAD)
    if receiversFrame and receiversFrame:IsShown() then
        self:RefreshReceivers()
    end
end

------------------------------------------------------------------------
-- Receivers: who takes what; a click picks the next alt, a right-click goes back to automatic
------------------------------------------------------------------------
local function receiverRow(index)
    local row = receiverRows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", "AKForeverAltMailerReceiver" .. index, receiversFrame)
    row:SetSize(WIDTH - 2 * PAD, ROW)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnClick", function(self, button)
        if not self.profession then
            return
        end
        if button == "RightButton" then
            ns.db.receivers[self.profession] = nil
            ns:Fire("ROSTER_CHANGED")
        else
            ns.Roster:CycleReceiver(self.profession)
        end
        Panel:Refresh()
        Panel:RefreshReceivers()
    end)
    row:SetScript("OnEnter", function(self)
        if not self.profession then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.profession)
        if self.profession == "Banker" then
            GameTooltip:AddLine("Gets what no other alt takes, when it is tradeable and worth something: green or better, a recipe, or a gold at a vendor.", 1, 1, 1, true)
            GameTooltip:AddLine("Click: the next character. Right-click: no banker.", 0.5, 0.5, 0.5, true)
            GameTooltip:Show()
            return
        end
        for _, c in ipairs(ns.Roster:Candidates(self.profession)) do
            GameTooltip:AddDoubleLine(ns.Roster.Label(c.entry), tostring(c.skill), 1, 1, 1, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine("Click: the next alt. Right-click: automatic (the highest skill).", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    receiverRows[index] = row
    return row
end

function Panel:RefreshReceivers()
    if not receiversFrame then
        return
    end
    local y = -PAD - 18
    local used = 0
    for _, profession in ipairs(ns.Data.PROFESSIONS) do
        if ns.Data.GOODS[profession] then
            local candidates = ns.Roster:Candidates(profession)
            used = used + 1
            local row = receiverRow(used)
            row.profession = profession
            local entry, why = ns.Roster:ReceiverFor(profession)
            local picked = ns.db.receivers[profession] ~= nil
            local what = profession .. (profession == "Enchanting" and " (and gear to disenchant)" or "")
            if entry then
                row.text:SetText(GOLD .. what .. "|r: " .. label(entry) .. DIM .. (picked and "  (your pick)" or "  (automatic)") .. "|r")
            else
                row.text:SetText(GOLD .. what .. "|r: " .. DIM .. (#candidates == 0 and "nobody yet" or why) .. "|r")
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", receiversFrame, "TOPLEFT", PAD, y)
            row:Show()
            y = y - ROW
        end
    end
    -- the banker: picked only
    used = used + 1
    local bankRow = receiverRow(used)
    bankRow.profession = "Banker"
    local banker, bankWhy = ns.Roster:Banker()
    local bankNone = ns.db.receivers.Banker and bankWhy or "none - click to pick one" -- a pick mail cannot reach says so
    bankRow.text:SetText(GOLD .. "Banker (tradeable valuables)|r: " .. (banker and label(banker) or (DIM .. bankNone .. "|r")))
    bankRow:ClearAllPoints()
    bankRow:SetPoint("TOPLEFT", receiversFrame, "TOPLEFT", PAD, y)
    bankRow:Show()
    y = y - ROW
    for index = used + 1, #receiverRows do
        receiverRows[index]:Hide()
    end
    receiversFrame:SetHeight(-y + PAD)
end

function Panel:ToggleReceivers()
    if not receiversFrame then
        receiversFrame = CreateFrame("Frame", "AKForeverAltMailerReceivers", panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
        receiversFrame:SetWidth(WIDTH)
        receiversFrame:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -2)
        if type(receiversFrame.SetBackdrop) == "function" then
            receiversFrame:SetBackdrop(BACKDROP)
            receiversFrame:SetBackdropColor(0.05, 0.05, 0.12, 0.95)
        end
        local heading = receiversFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", receiversFrame, "TOPLEFT", PAD, -PAD)
        heading:SetText("Receivers")
        receiversFrame:Hide()
    end
    receiversFrame:SetShown(not receiversFrame:IsShown())
    if receiversFrame:IsShown() then
        self:RefreshReceivers()
    end
end

------------------------------------------------------------------------
-- Showing and docking
------------------------------------------------------------------------
-- the mail window gone - its X, Escape, another window in its place - takes the panel with it. Asked five times
-- a second while the panel shows (a hidden frame runs no OnUpdate), and only once the mail window has been seen:
-- it shows a moment after the mailbox opens.
local WATCH_EVERY = 0.2
local watchElapsed, sawMailFrame = 0, false

local function watchMailFrame(_, elapsed)
    watchElapsed = watchElapsed + (elapsed or 0)
    if watchElapsed < WATCH_EVERY then
        return
    end
    watchElapsed = 0
    local mail = _G.MailFrame
    if type(mail) ~= "table" or type(mail.IsShown) ~= "function" then
        return
    end
    if ns.Read(mail.IsShown, mail) then
        sawMailFrame = true
        return
    end
    if not sawMailFrame then
        return
    end
    if ns.Mailer.open then
        ns.Mailer:Closed("mail window hidden")
    end
    Panel:Hide()
end

local function create()
    panel = CreateFrame("Frame", "AKForeverAltMailerPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetWidth(WIDTH)
    panel:SetHeight(120)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    if type(panel.SetBackdrop) == "function" then
        panel:SetBackdrop(BACKDROP)
        panel:SetBackdropColor(0.05, 0.05, 0.12, 0.92)
    end
    panel:SetScript("OnUpdate", function(self, elapsed)
        ns.SafeCall(watchMailFrame, self, elapsed)
    end)
    closeButton = CreateFrame("Button", "AKForeverAltMailerClose", panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function()
        dismissed = true
        panel:Hide()
    end)
    title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    title:SetText("AltMailer")
    note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("LEFT", title, "RIGHT", 8, 0)
    emptyLine = line(panel, "GameFontDisableSmall")
    emptyLine:SetWordWrap(true)
    keptLine = line(panel, "GameFontDisableSmall")
    modeLine = line(panel, "GameFontDisableSmall")
    sendButton = CreateFrame("Button", "AKForeverAltMailerSend", panel, "UIPanelButtonTemplate")
    sendButton:SetSize(200, 22)
    sendButton:SetScript("OnClick", function()
        ns.Mailer:Click()
        Panel:Refresh()
    end)
    receiversButton = CreateFrame("Button", "AKForeverAltMailerReceiversButton", panel, "UIPanelButtonTemplate")
    receiversButton:SetSize(WIDTH - 2 * PAD - 206, 22)
    receiversButton:SetText("Receivers")
    receiversButton:SetScript("OnClick", function()
        Panel:ToggleReceivers()
    end)
    panel:Hide()
end

local function place()
    panel:ClearAllPoints()
    local mail = _G.MailFrame
    if ns:GetOption("dock") and type(mail) == "table" and mail.IsShown and (ns.Read(mail.IsShown, mail)) then
        panel:SetPoint("TOPLEFT", mail, "TOPRIGHT", 6, -12)
        Panel.docked = true
    else
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -120)
        Panel.docked = false
    end
end

function Panel:Show()
    if not panel then
        create()
    end
    watchElapsed, sawMailFrame = 0, false
    place()
    panel:Show()
    self:Refresh()
end

function Panel:Hide()
    if panel then
        panel:Hide()
    end
    if receiversFrame then
        receiversFrame:Hide()
    end
end

function Panel:IsShown()
    return panel ~= nil and panel:IsShown()
end

ns:Listen("MAILBOX_OPENED", function()
    dismissed = false
    C_Timer.After(0, function() ns.SafeCall(Panel.Show, Panel) end) -- after Blizzard's mail frame has shown
end)

ns:Listen("MAILBOX_CLOSED", function()
    Panel:Hide()
    if receiversFrame then
        receiversFrame:Hide()
    end
end)

for _, message in ipairs({ "MAILER_CHANGED", "ROSTER_CHANGED", "OPTION_CHANGED" }) do
    ns:Listen(message, function()
        Panel:Refresh()
    end)
end

local refreshQueued = false
ns:On("BAG_UPDATE_DELAYED", function()
    if not Panel:IsShown() or refreshQueued then
        return
    end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        ns.SafeCall(Panel.Refresh, Panel)
    end)
end)

ns:RegisterCommand("show", "at a mailbox: bring the panel back after its X", function()
    if not ns.Mailer.open then
        ns:Print("the panel shows at a mailbox. '/aam plan' tells what would go, from anywhere.")
        return
    end
    Panel:Show()
end)

ns:RegisterCommand("receivers", "who takes what (at a mailbox: the list; elsewhere: in the chat)", function()
    if Panel:IsShown() then
        Panel:ToggleReceivers()
        return
    end
    ns:Print("receivers:")
    for _, profession in ipairs(ns.Data.PROFESSIONS) do
        if ns.Data.GOODS[profession] then
            local entry, why = ns.Roster:ReceiverFor(profession)
            print("   " .. GOLD .. profession .. "|r: " .. (entry and (ns.Roster.Label(entry) .. DIM .. " (" .. why .. ")|r") or (DIM .. why .. "|r")))
        end
    end
    local banker, bankWhy = ns.Roster:Banker()
    print("   " .. GOLD .. "Banker|r: " .. (banker and ns.Roster.Label(banker) or (DIM .. bankWhy .. "|r")))
end)

ns:RegisterCommand("unkeep", "your keep list; '/aam unkeep <item id>' frees one, '/aam unkeep all' frees them all", function(rest)
    if rest == "all" then
        ns.db.keep = {}
        ns:Print("keep list cleared.")
        Panel:Refresh()
        return
    end
    local id = tonumber(rest)
    if id then
        ns.db.keep[id] = nil
        ns:Print("item " .. id .. " can be mailed again.")
        Panel:Refresh()
        return
    end
    local ids = {}
    for itemID in pairs(ns.db.keep) do
        ids[#ids + 1] = itemID
    end
    table.sort(ids)
    if #ids == 0 then
        ns:Print("your keep list is empty: right-click an item on the panel to keep it.")
        return
    end
    ns:Print("kept, never mailed:")
    for _, itemID in ipairs(ids) do
        local name = type(C_Item) == "table" and ns.Read(C_Item.GetItemNameByID, itemID)
        print("   " .. itemID .. (name and (" " .. name) or ""))
    end
end)
