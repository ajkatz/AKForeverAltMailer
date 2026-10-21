-- A small stand-in for the WoW: Forever client, enough to run AKForeverAltMailer's scenarios: frames, events,
-- timers, a character with professions, a skill window and equipment, bags of items with the facts the client
-- gives (class, subclass, bind type, quality, levels, stats), and a mailbox that attaches, sends and delivers -
-- or refuses a send without a click, when a scenario asks it to. Nothing here is the real client: what the real
-- client does is measured in game and written in the addon's comments.
local Mock = {}

local realPrint = print
Mock.realPrint = realPrint

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
Mock.SECRET = SECRET

local G = _G
local ADDON = "AKForeverAltMailer"

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local widgetMethods = {}

function widgetMethods.SetPoint(self, point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        point, relativeTo, relativePoint, x, y = point, self.__parent, point, relativeTo, relativePoint
    elseif type(relativeTo) == "string" then
        relativeTo, relativePoint, x, y = self.__parent, relativeTo, relativePoint, x
    end
    self.__points[#self.__points + 1] = { point, relativeTo, relativePoint or point, x or 0, y or 0 }
end
function widgetMethods.ClearAllPoints(self) self.__points = {} end
function widgetMethods.GetPoint(self, index)
    local p = self.__points[index or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end
function widgetMethods.SetSize(self, w, h) self.__width, self.__height = w, h end
function widgetMethods.SetWidth(self, w) self.__width = w end
function widgetMethods.SetHeight(self, h) self.__height = h end
function widgetMethods.GetWidth(self) return self.__width or 0 end
function widgetMethods.GetHeight(self) return self.__height or 0 end
function widgetMethods.Show(self) self.__shown = true; local s = self.__scripts.OnShow; if s then s(self) end end
function widgetMethods.Hide(self) self.__shown = false; local s = self.__scripts.OnHide; if s then s(self) end end
function widgetMethods.SetShown(self, shown) if shown then self:Show() else self:Hide() end end
function widgetMethods.IsShown(self) return self.__shown end
function widgetMethods.SetScript(self, name, fn) self.__scripts[name] = fn end
function widgetMethods.GetScript(self, name) return self.__scripts[name] end
function widgetMethods.RegisterEvent(self, event) self.__events[event] = true end
function widgetMethods.UnregisterEvent(self, event) self.__events[event] = nil end
function widgetMethods.RegisterForClicks(self) end
function widgetMethods.RegisterForDrag(self) end
function widgetMethods.SetMovable(self) end
function widgetMethods.SetClampedToScreen(self) end
function widgetMethods.EnableMouse(self) end
function widgetMethods.SetFrameStrata(self, s) self.__strata = s end
function widgetMethods.SetBackdrop(self, b) self.__backdrop = b end
function widgetMethods.SetBackdropColor(self) end
function widgetMethods.GetParent(self) return self.__parent end
function widgetMethods.GetName(self) return self.__name end
function widgetMethods.SetText(self, text) self.__text = text end
function widgetMethods.GetText(self) return self.__text end
function widgetMethods.SetJustifyH(self) end
function widgetMethods.SetWordWrap(self) end
function widgetMethods.SetTexture(self, t) self.__texture = t end
function widgetMethods.Enable(self) self.__enabled = true end
function widgetMethods.Disable(self) self.__enabled = false end
function widgetMethods.SetEnabled(self, on) self.__enabled = on and true or false end
function widgetMethods.IsEnabled(self) return self.__enabled ~= false end
function widgetMethods.SetOwner(self, owner) self.__owner = owner; self.__lines = {} end
function widgetMethods.AddLine(self, text) self.__lines[#self.__lines + 1] = tostring(text) end
function widgetMethods.AddDoubleLine(self, a, b) self.__lines[#self.__lines + 1] = tostring(a) .. " " .. tostring(b) end
function widgetMethods.SetHyperlink(self, link) self.__lines = { tostring(link) } end
function widgetMethods.Click(self, button)
    local script = self.__scripts.OnClick
    if script and self.__enabled ~= false then
        script(self, button or "LeftButton")
    end
end

local function newWidget(kind, name, parent)
    local w = { __kind = kind, __name = name, __parent = parent, __points = {}, __scripts = {}, __events = {}, __shown = true, __children = {}, __lines = {} }
    for method, fn in pairs(widgetMethods) do
        w[method] = fn
    end
    function w.CreateFontString(self, fsName)
        return newWidget("FontString", fsName, self)
    end
    function w.CreateTexture(self, tName)
        return newWidget("Texture", tName, self)
    end
    if parent then
        parent.__children[#parent.__children + 1] = w
    end
    return w
end

------------------------------------------------------------------------
-- Items: what the client knows of them. link = "|Hitem:<id>|h[name]|h"
------------------------------------------------------------------------
local ITEMS = {}
Mock.ITEMS = ITEMS

-- facts: { name, quality, itemLevel, minLevel, classID, subclassID, equipLoc, bindType, stats, stack }
function Mock.item(id, facts)
    facts.id = id
    facts.icon = facts.icon or (100000 + id)
    facts.itemLevel = facts.itemLevel or 1
    facts.minLevel = facts.minLevel or 0
    facts.equipLoc = facts.equipLoc or ""
    facts.bindType = facts.bindType or 0
    facts.quality = facts.quality or 1
    ITEMS[id] = facts
    return id
end

local function linkOf(id)
    local item = ITEMS[id]
    return item and ("|Hitem:" .. id .. "|h[" .. item.name .. "]|h") or nil
end
Mock.linkOf = linkOf

local function idOf(idOrLink)
    if type(idOrLink) == "number" then
        return idOrLink
    end
    if type(idOrLink) == "string" then
        return tonumber(string.match(idOrLink, "item:(%d+)"))
    end
end

------------------------------------------------------------------------
-- Install: a fresh client with the addon loaded
------------------------------------------------------------------------
local state
Mock.state = nil

-- options: { name, surname, realm, faction, class, className, level, professions = { {name, rank, max} },
-- skillLines = { {header} or {name, rank, max} }, equipped = { [slot] = itemID }, bags = { [bag] = { [slot] = { id, count, bound } } },
-- money, db, sendNeedsClick, unknownRecipients }
function Mock.install(options)
    options = options or {}
    for _, name in ipairs(Mock.globalNames or {}) do
        G[name] = nil
    end
    Mock.globalNames = {}
    Mock.now = 1000
    Mock.clock = 1760000000
    Mock.timers = {}
    Mock.frames = {}
    Mock.printed = {}
    Mock.errors = {}
    Mock.hardware = false
    Mock.mails = {}        -- delivered: { to, subject, items = { {id, count} } }
    Mock.blockedCalls = 0
    state = {
        name = options.name or "Purrdee", surname = options.surname or "Bubson", realm = options.realm or "ClassicBetaPvE",
        faction = options.faction or "Alliance", class = options.class or "SHAMAN", className = options.className or "Shaman",
        level = options.level or 30, professions = options.professions or {}, skillLines = options.skillLines or {},
        equipped = options.equipped or {}, bags = options.bags or {}, money = options.money or 100000,
        cursor = nil, attachments = {}, mailboxOpen = false, mailPending = false,
        sendNeedsClick = options.sendNeedsClick, unknownRecipients = options.unknownRecipients or {}, inCombat = false,
    }
    Mock.state = state

    G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        Mock.printed[#Mock.printed + 1] = table.concat(parts, " ")
    end
    G.issecretvalue = function(value) return value == SECRET end
    G.geterrorhandler = function()
        return function(err) Mock.errors[#Mock.errors + 1] = tostring(err) end
    end
    G.GetTime = function() return Mock.now end
    G.time = function() return Mock.clock + math.floor(Mock.now - 1000) end
    G.date = function() return "2026-10-20 12:00:00" end
    G.InCombatLockdown = function() return state.inCombat end
    G.UIParent = newWidget("Frame", "UIParent")
    G.GameTooltip = newWidget("GameTooltip", "GameTooltip")
    G.RAID_CLASS_COLORS = {
        WARRIOR = { colorStr = "ffc79c6e" }, MAGE = { colorStr = "ff69ccf0" }, SHAMAN = { colorStr = "ff0070de" },
        HUNTER = { colorStr = "ffabd473" }, WARLOCK = { colorStr = "ff9482c9" }, ROGUE = { colorStr = "fffff569" },
    }
    G.BackdropTemplateMixin = {}
    G.Enum = { PlayerInteractionType = { MailInfo = 17 }, ItemBind = { OnEquip = 2, ToBnetAccountUntilEquipped = 9 } }
    if options.dualWield ~= nil then
        G.CanDualWield = function() return options.dualWield end
    else
        G.CanDualWield = nil -- an older client's word is not there: the class table speaks
    end
    G.C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
    G.CreateFrame = function(kind, name, parent)
        local w = newWidget(kind, name, parent or G.UIParent)
        if name then
            G[name] = w
            Mock.globalNames[#Mock.globalNames + 1] = name
        end
        Mock.frames[#Mock.frames + 1] = w
        return w
    end
    G.C_Timer = {
        After = function(delay, fn) Mock.timers[#Mock.timers + 1] = { at = Mock.now + delay, fn = fn } end,
        NewTicker = function(interval, fn)
            local ticker = { at = Mock.now + interval, fn = fn, interval = interval }
            ticker.Cancel = function() ticker.cancelled = true end
            Mock.timers[#Mock.timers + 1] = ticker
            return ticker
        end,
    }

    -- who you are
    G.UnitName = function(unit) if unit == "player" then return state.name, state.surname end end
    G.GetUnitName = function(unit, full) if unit == "player" then return full and (state.name .. " " .. state.surname) or state.name end end
    G.GetRealmName = function() return state.realm end
    G.UnitClass = function(unit) if unit == "player" then return state.className, state.class end end
    G.UnitLevel = function(unit) if unit == "player" then return state.level end end
    G.UnitFactionGroup = function(unit) if unit == "player" then return state.faction, state.faction end end
    G.GetMoney = function() return state.money end

    -- professions: the professions book's calls, and the skill window
    G.GetProfessions = function()
        local p = state.professions
        return p[1] and 1 or nil, p[2] and 2 or nil, nil, nil, nil
    end
    G.GetProfessionInfo = function(index)
        local p = state.professions[index]
        if p then
            return p[1], 100 + index, p[2], p[3] or 300, 1, 1, 100 + index, 0, nil, nil, p[1]
        end
    end
    G.C_SkillInfo = {
        GetNumSkillLines = function() return #state.skillLines end,
        GetSkillLineInfo = function(index)
            local s = state.skillLines[index]
            if not s then return nil end
            if s.header then
                return { skillID = 0, name = s.header, isHeader = true, isCollapsed = s.collapsed or false, rank = 0, maxRank = 0 }
            end
            return { skillID = 1000 + index, name = s[1], isHeader = false, isCollapsed = false, rank = s[2] or 1, maxRank = s[3] or 300 }
        end,
    }

    -- equipment
    G.GetInventoryItemLink = function(unit, slot)
        local id = unit == "player" and state.equipped[slot]
        return id and linkOf(id) or nil
    end

    -- items
    G.C_Item = {
        GetItemInfoInstant = function(idOrLink)
            local item = ITEMS[idOf(idOrLink)]
            if not item then return nil end
            return item.id, "Type", "Subtype", item.equipLoc, item.icon, item.classID, item.subclassID
        end,
        GetItemInfo = function(idOrLink)
            local item = ITEMS[idOf(idOrLink)]
            if not item then return nil end
            return item.name, linkOf(item.id), item.quality, item.itemLevel, item.minLevel, "Type", "Subtype", item.stack or 20,
                item.equipLoc, item.icon, item.sellPrice or 0, item.classID, item.subclassID, item.bindType, 0, nil, item.reagent
        end,
        GetDetailedItemLevelInfo = function(link)
            local item = ITEMS[idOf(link)]
            return item and item.itemLevel or nil
        end,
        GetItemStats = function(link)
            local item = ITEMS[idOf(link)]
            return item and item.stats or {}
        end,
        GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id].name or nil end,
    }

    -- bags
    local function slotOf(bag, slot)
        return state.bags[bag] and state.bags[bag][slot] or nil
    end
    G.C_Container = {
        GetContainerNumSlots = function(bag)
            if bag == 0 then return 16 end
            return state.bags[bag] and 16 or 0
        end,
        GetContainerItemInfo = function(bag, slot)
            local s = slotOf(bag, slot)
            if not s then return nil end
            local item = ITEMS[s.id]
            return { itemID = s.id, stackCount = s.count or 1, quality = item and item.quality, isBound = s.bound or false,
                isLocked = s.locked or false, hyperlink = linkOf(s.id), itemName = item and item.name, iconFileID = item and item.icon }
        end,
        PickupContainerItem = function(bag, slot)
            local s = slotOf(bag, slot)
            if s and not s.locked then
                state.cursor = { bag = bag, slot = slot }
            end
        end,
    }
    G.ClearCursor = function() state.cursor = nil end
    G.CursorHasItem = function() return state.cursor ~= nil end

    -- the mailbox
    G.ClickSendMailItemButton = function(index, clear)
        if not state.mailboxOpen then return end
        if clear then
            local a = state.attachments[index]
            if a then
                local s = slotOf(a.bag, a.slot)
                if s then s.locked = false end
                state.attachments[index] = nil
            end
            return
        end
        local cursor = state.cursor
        if cursor and not state.attachments[index] then
            local s = slotOf(cursor.bag, cursor.slot)
            s.locked = true
            state.attachments[index] = { bag = cursor.bag, slot = cursor.slot }
            state.cursor = nil
        end
    end
    G.HasSendMailItem = function(index) return state.attachments[index] ~= nil end
    G.GetSendMailItem = function(index)
        local a = state.attachments[index]
        local s = a and slotOf(a.bag, a.slot)
        local item = s and ITEMS[s.id]
        if item then return item.name, item.id, item.icon, s.count, item.quality end
    end
    G.SendMail = function(to, subject, body)
        if state.sendNeedsClick and not Mock.hardware then
            Mock.blockedCalls = Mock.blockedCalls + 1
            Mock.fire("ADDON_ACTION_BLOCKED", ADDON, "SendMail()")
            return
        end
        state.mailPending = true
        local items = {}
        for index = 1, 12 do
            local a = state.attachments[index]
            if a then
                local s = slotOf(a.bag, a.slot)
                items[#items + 1] = { id = s.id, count = s.count or 1, bag = a.bag, slot = a.slot }
            end
        end
        G.C_Timer.After(0.3, function()
            state.mailPending = false
            if state.unknownRecipients[to] then
                Mock.fire("UI_ERROR_MESSAGE", 1, "Cannot find player")
                Mock.fire("MAIL_FAILED")
                return
            end
            state.money = state.money - 30 * math.max(1, #items)
            for _, i in ipairs(items) do
                state.bags[i.bag][i.slot] = nil -- gone with the mail
            end
            state.attachments = {}
            Mock.mails[#Mock.mails + 1] = { to = to, subject = subject, items = items }
            Mock.fire("MAIL_SEND_SUCCESS")
        end)
    end
    G.C_Mail = { IsCommandPending = function() return state.mailPending end }

    G.SlashCmdList = {}

    local ns = {}
    for _, file in ipairs({ "Core.lua", "Data.lua", "Roster.lua", "Classify.lua", "Plan.lua", "Mailer.lua", "Panel.lua", "Diagnostics.lua" }) do
        local chunk, err = loadfile(file)
        if not chunk then
            error("cannot load " .. file .. ": " .. tostring(err))
        end
        chunk(ADDON, ns)
    end
    G.AKForeverAltMailerDB = options.db
    Mock.ns = ns
    return ns, state
end

------------------------------------------------------------------------
-- Events, time, clicks
------------------------------------------------------------------------
function Mock.fire(event, ...)
    local frames = {}
    for i, frame in ipairs(Mock.frames) do
        frames[i] = frame
    end
    for _, frame in ipairs(frames) do
        if frame.__events[event] and frame.__scripts.OnEvent then
            frame.__scripts.OnEvent(frame, event, ...)
        end
    end
end

function Mock.advance(seconds)
    local target = Mock.now + seconds
    while true do
        local soonest, index
        for i, timer in ipairs(Mock.timers) do
            if not timer.cancelled and timer.at <= target and (not soonest or timer.at < soonest.at) then
                soonest, index = timer, i
            end
        end
        if not soonest then
            break
        end
        Mock.now = soonest.at
        if soonest.interval then
            soonest.at = soonest.at + soonest.interval
        else
            table.remove(Mock.timers, index)
        end
        soonest.fn()
    end
    Mock.now = target
end

function Mock.login()
    Mock.fire("ADDON_LOADED", ADDON)
    Mock.fire("PLAYER_LOGIN")
    Mock.advance(4)
end

function Mock.logout()
    Mock.fire("PLAYER_LOGOUT")
end

function Mock.slash(text)
    Mock.hardware = true
    G.SlashCmdList.AKFOREVERALTMAILER(text)
    Mock.hardware = false
end

function Mock.click(button, which)
    Mock.hardware = true
    button:Click(which)
    Mock.hardware = false
end

-- how: nil = MAIL_SHOW; "interaction" = PLAYER_INTERACTION_MANAGER_FRAME_SHOW (MailInfo, 17); "both"
function Mock.openMailbox(how)
    if not G.MailFrame then
        G.MailFrame = newWidget("Frame", "MailFrame", G.UIParent)
        Mock.globalNames[#Mock.globalNames + 1] = "MailFrame"
    end
    state.mailboxOpen = true
    G.MailFrame:Show()
    if how == nil or how == "both" then
        Mock.fire("MAIL_SHOW")
    end
    if how == "interaction" or how == "both" then
        Mock.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 17)
    end
    Mock.advance(0.1)
end

-- how: nil = MAIL_CLOSED; "interaction" = PLAYER_INTERACTION_MANAGER_FRAME_HIDE (MailInfo); "window" = the mail
-- window hides and no event comes; "both" = both events
function Mock.closeMailbox(how)
    for index in pairs(state.attachments) do
        G.ClickSendMailItemButton(index, true)
    end
    state.mailboxOpen = false
    G.MailFrame:Hide()
    if how == nil or how == "both" then
        Mock.fire("MAIL_CLOSED")
    end
    if how == "interaction" or how == "both" then
        Mock.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17)
    end
end

-- frames drawn for a while: every shown frame (its parents shown too) runs its OnUpdate each step; timers fire
local function drawn(w)
    while w do
        if not w.__shown then
            return false
        end
        w = w.__parent
    end
    return true
end

function Mock.update(seconds, step)
    step = step or 0.05
    local elapsed = 0
    while elapsed < seconds - 1e-9 do
        Mock.advance(step)
        elapsed = elapsed + step
        local frames = {}
        for i, frame in ipairs(Mock.frames) do
            frames[i] = frame
        end
        for _, frame in ipairs(frames) do
            local script = frame.__scripts.OnUpdate
            if script and drawn(frame) then
                script(frame, step)
            end
        end
    end
end

-- what is in the bags now: [itemID] = total count
function Mock.bagCounts()
    local counts = {}
    for _, slots in pairs(state.bags) do
        for _, s in pairs(slots) do
            counts[s.id] = (counts[s.id] or 0) + (s.count or 1)
        end
    end
    return counts
end

return Mock
