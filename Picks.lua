-- Picks: who gets an item, set from the bags - and the tooltip line that says an item will be mailed.
--
-- WHY. The user, 2026-11-11: "on tooltips i want it to be displayed when an item will be automatically mailed
-- by the alt mailer. i'd also like an EASY way for users to add/remove alt targets per item/item type from an
-- item/the bag". Chosen with the user:
--   * THE TOOLTIP LINE only on what will be mailed ("AltMailer: to Purr Gola - the highest Alchemy (225)"),
--     nothing on what stays, so the bags' tooltips stay clean;
--   * ALT+RIGHT-CLICK an item in the bags opens a small menu: who gets this item (every copy, account-wide -
--     or automatic), never mail it (the keep list), and who gets the item's whole group;
--   * "ITEM TYPE" IS THE ADDON'S OWN GROUP: a profession's goods (its materials and recipes, and for Enchanting
--     the gear to disenchant) - the very pick the Receivers list makes - or, for anything else, the banker.
--
-- HOW. Nothing of Blizzard's is hooked. The line comes from TooltipDataProcessor.AddTooltipPostCall, Blizzard's
-- hook for addons, and only on GameTooltip shown for a bag item button (its GetBagID()/GetID()). The click is
-- read on GLOBAL_MOUSE_UP with the bag item button under the mouse - as AKForeverBags' mark mode reads it
-- (proven in game 2026-11-08). Blizzard's bag button does nothing with an Alt+right-click: a modified click
-- goes to its OnModifiedClick, where shift links, splits and sockets and ctrl dresses up (ContainerFrame.lua,
-- forever branch) - so the item is neither used nor attached to a mail. The menu is Blizzard's MenuUtil.
local _, ns = ...

local Picks = {}
ns.Picks = Picks
Picks.stats = { menus = 0, lines = 0 }

local MAIL_BAGS = {}
for _, bag in ipairs(ns.Plan.BAGS) do
    MAIL_BAGS[bag] = true
end

-- bag, slot of a bag item button (one of the bags the mailer reads), or nil
local function slotOf(button)
    if type(button) ~= "table" or type(button.GetBagID) ~= "function" or type(button.GetID) ~= "function" then
        return nil
    end
    local bag, slot = ns.Read(button.GetBagID, button), ns.Read(button.GetID, button)
    if type(bag) ~= "number" or type(slot) ~= "number" or not MAIL_BAGS[bag] then
        return nil
    end
    return bag, slot
end

local function mouseFocus()
    if type(GetMouseFoci) == "function" then
        local foci = ns.Read(GetMouseFoci)
        return type(foci) == "table" and foci[1] or nil
    end
    if type(GetMouseFocus) == "function" then
        return ns.Read(GetMouseFocus)
    end
    return nil
end

-- the stack in a bag slot, as Plan.Stacks reads it, with its facts and verdict; nil for an empty slot
function Picks.Judge(bag, slot, options)
    local api = C_Container
    local info = type(api) == "table" and ns.Read(api.GetContainerItemInfo, bag, slot)
    if type(info) ~= "table" or type(info.itemID) ~= "number" then
        return nil
    end
    local stack = {
        bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1, link = info.hyperlink,
        quality = info.quality, isBound = info.isBound, isLocked = info.isLocked, name = info.itemName,
    }
    stack.facts = ns.Classify.Facts(stack.link, stack.itemID)
    stack.name = stack.name or stack.facts.name or ("item " .. stack.itemID)
    stack.verdict = ns.Classify.Verdict(stack, stack.facts, options)
    return stack
end

------------------------------------------------------------------------
-- The tooltip line
------------------------------------------------------------------------
-- the line for a bag slot, or nil when its stack is not mailed from here
function Picks.LineFor(bag, slot)
    if not ns.characterKey then
        return nil
    end
    local stack = Picks.Judge(bag, slot)
    local verdict = stack and stack.verdict
    if not verdict or verdict.action ~= "send" then
        return nil
    end
    local to = ns.Roster.Label(ns.Roster:Get(verdict.receiver))
    return "AltMailer: to " .. to .. (verdict.reason and (" - " .. verdict.reason) or "")
end

function Picks.AddToTooltip(tooltip)
    if tooltip ~= GameTooltip or type(tooltip.GetOwner) ~= "function" then
        return
    end
    local bag, slot = slotOf(ns.Read(tooltip.GetOwner, tooltip))
    if not bag then
        return
    end
    local text = Picks.LineFor(bag, slot)
    if text then
        tooltip:AddLine(text, 0.56, 0.82, 0.42, true)
        Picks.stats.lines = Picks.stats.lines + 1
    end
end

if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and type(Enum) == "table" and type(Enum.TooltipDataType) == "table" and Enum.TooltipDataType.Item ~= nil then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        ns.SafeCall(Picks.AddToTooltip, tooltip)
    end)
    Picks.tooltipHooked = true
end

------------------------------------------------------------------------
-- Setting picks
------------------------------------------------------------------------
local function changed(kind, data)
    ns:Log(kind, data)
    ns:Fire("ROSTER_CHANGED")
end

-- who gets every copy of an item: a character's key, or nil for automatic
function Picks:SetItem(itemID, key, name)
    if key then
        ns.db.itemReceivers[itemID] = { to = key, name = name }
    else
        ns.db.itemReceivers[itemID] = nil
    end
    changed("item_picked", { itemID = itemID, key = key or "automatic" })
end

function Picks:SetKeep(itemID, keep)
    ns.db.keep[itemID] = keep and true or nil
    changed(keep and "keep_added" or "keep_removed", itemID)
end

-- a group's receiver: a profession (the Receivers list's pick) or "Banker"; nil = automatic / no banker
function Picks:SetGroup(group, key)
    ns.db.receivers[group] = key
    changed("receiver_picked", { profession = group, key = key or "automatic" })
end

------------------------------------------------------------------------
-- The menu
------------------------------------------------------------------------
local function nameOf(entry)
    local label = ns.Roster.Label(entry)
    if ns.Roster:IsMe(entry.key) then
        label = label .. " (this character)"
    end
    return label
end

local function automaticWord(stack)
    local verdict = stack.verdict
    if verdict.action == "send" then
        return "Automatic: " .. ns.Roster.Label(ns.Roster:Get(verdict.receiver))
    end
    return "Automatic: stays" .. (verdict.reason and (" (" .. verdict.reason .. ")") or "")
end

-- the menu's contents, as plain data - what MenuUtil is handed, and what the tests read:
-- { title, sections = { { text, entries = { { text, selected, pick = function() } } } }, keep = { selected, toggle } }
function Picks.MenuFor(bag, slot)
    local stack = Picks.Judge(bag, slot, { ignorePick = true })
    if not stack then
        return nil
    end
    local itemID = stack.itemID
    local menu = { title = stack.name, sections = {}, itemID = itemID }
    if stack.isBound then
        menu.note = "Soulbound: it cannot be mailed."
        return menu
    end
    local reachable = ns.Roster:Reachable()

    -- this item
    local current = ns.db.itemReceivers[itemID] and ns.db.itemReceivers[itemID].to
    local item = { text = "This item goes to", entries = {} }
    item.entries[1] = { text = automaticWord(stack), selected = current == nil, pick = function() Picks:SetItem(itemID, nil) end }
    for _, entry in ipairs(reachable) do
        local key = entry.key
        item.entries[#item.entries + 1] = { text = nameOf(entry), selected = current == key,
            pick = function() Picks:SetItem(itemID, key, stack.name) end }
    end
    menu.sections[#menu.sections + 1] = item

    -- its group
    local group = ns.Classify.GroupOf(stack.facts)
    if group then
        local goods = (ns.Data.GOODS[group] or "goods") .. ", recipes" .. (group == "Enchanting" and ", gear to disenchant" or "")
        local picked = ns.db.receivers[group]
        local best = ns.Roster:Candidates(group)[1]
        local section = { text = "All " .. group .. " goods (" .. goods .. ") go to", entries = {} }
        section.entries[1] = { text = "Automatic: " .. (best and (ns.Roster.Label(best.entry) .. ", the highest (" .. best.skill .. ")") or "nobody has " .. group .. " yet"),
            selected = picked == nil, pick = function() Picks:SetGroup(group, nil) end }
        for _, entry in ipairs(reachable) do
            local key = entry.key
            local p = entry.professions and entry.professions[group]
            local skill = p and type(p.skill) == "number" and p.skill > 0 and (" - " .. group .. " " .. p.skill) or ""
            section.entries[#section.entries + 1] = { text = nameOf(entry) .. skill, selected = picked == key,
                pick = function() Picks:SetGroup(group, key) end }
        end
        menu.sections[#menu.sections + 1] = section
    else
        local picked = ns.db.receivers.Banker
        local section = { text = "Valuables nobody else takes go to (your banker)", entries = {} }
        section.entries[1] = { text = "No banker", selected = picked == nil, pick = function() Picks:SetGroup("Banker", nil) end }
        for _, entry in ipairs(reachable) do
            local key = entry.key
            section.entries[#section.entries + 1] = { text = nameOf(entry), selected = picked == key,
                pick = function() Picks:SetGroup("Banker", key) end }
        end
        menu.sections[#menu.sections + 1] = section
    end

    menu.keep = { text = "Never mail this item", selected = ns.db.keep[itemID] == true,
        toggle = function() Picks:SetKeep(itemID, not ns.db.keep[itemID]) end }
    return menu
end

local function build(menu)
    return function(_, root)
        root:CreateTitle(menu.title)
        if menu.note then
            root:CreateTitle(menu.note)
            return
        end
        for _, section in ipairs(menu.sections) do
            local sub = root:CreateButton(section.text)
            for _, entry in ipairs(section.entries) do
                sub:CreateRadio(entry.text, function() return entry.selected end, function()
                    ns.SafeCall(entry.pick)
                end)
            end
        end
        root:CreateCheckbox(menu.keep.text, function() return menu.keep.selected end, function()
            ns.SafeCall(menu.keep.toggle)
        end)
    end
end

function Picks.Open(bag, slot)
    local menu = Picks.MenuFor(bag, slot)
    if not menu or type(MenuUtil) ~= "table" or type(MenuUtil.CreateContextMenu) ~= "function" then
        return false
    end
    MenuUtil.CreateContextMenu(nil, build(menu))
    Picks.stats.menus = Picks.stats.menus + 1
    ns:Log("menu", { itemID = menu.itemID })
    return true
end

ns:On("GLOBAL_MOUSE_UP", function(_, button)
    if button ~= "RightButton" or type(IsAltKeyDown) ~= "function" or ns.Read(IsAltKeyDown) ~= true then
        return
    end
    if type(CursorHasItem) == "function" and ns.Read(CursorHasItem) == true then
        return
    end
    local bag, slot = slotOf(mouseFocus())
    if bag then
        Picks.Open(bag, slot)
    end
end)

------------------------------------------------------------------------
-- /aam picks
------------------------------------------------------------------------
ns:RegisterCommand("picks", "your picks per item (Alt+right-click an item in your bags to set one); '/aam picks clear' takes them all off", function(rest)
    if rest == "clear" then
        ns.db.itemReceivers = {}
        changed("item_picks_cleared")
        ns:Print("item picks cleared: every item goes where the rules say.")
        return
    end
    local lines = {}
    for itemID, pick in pairs(ns.db.itemReceivers) do
        if type(pick) == "table" then
            lines[#lines + 1] = (pick.name or ("item " .. itemID)) .. " -> " .. ns.Roster.Label(ns.Roster:Get(pick.to) or { key = pick.to })
        end
    end
    table.sort(lines)
    if #lines == 0 then
        ns:Print("no item picks. Alt+right-click an item in your bags to pick who gets it.")
        return
    end
    ns:Print("item picks (Alt+right-click an item in your bags to change one):")
    for _, text in ipairs(lines) do
        ns:Print("  " .. text)
    end
end)
