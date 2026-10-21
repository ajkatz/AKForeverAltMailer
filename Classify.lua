-- Classify: where one stack in your bags goes, and why - or why it stays.
--
-- In this order, the first rule that speaks decides:
--   * stays: your keep list, soulbound, locked, a quest item or key, grey (for the vendor), the hearthstone;
--   * CLASS SUPPLIES (Data.SUPPLIES - candles, powders, shards, the enchanters' oils - and arrows and bullets):
--     they stay with you when you are of their class, else go to the highest-level alt of their classes;
--   * PROFESSION MATERIALS (Data.MATERIALS, else the item's trade-goods type): to the alt highest in the
--     profession that uses them. A trade good that no recipe uses (the client's isCraftingReagent says no) is a
--     product, not a material - unless the table names it;
--   * GEAR - unbound armor or weapons that bind when worn, green or better: to the alt who would wear it as the
--     biggest upgrade (it can use the armor or weapon type, it is near the item's level, the item's stats suit its
--     class, and the item's level beats what it wears in that slot); failing that to the enchanter. Never kept
--     for the character at the mailbox: it holds the piece and puts it on if it wants it (the user's pick: "a BoE
--     piece goes to the alt whose class can use it, instead of the enchanter"; kept "for you", the enchanter had
--     got next to nothing - 2026-10-20);
--   * THE BANKER, last (the user, 2026-10-20: "a general banker that just gets tradeable valuables"): what no rule
--     above took - or a rule took but found nobody for, like parts with no engineer - goes to the banker you
--     picked when it is tradeable and worth something: green or better, a recipe, or selling to a vendor for at
--     least a gold (both thresholds are options). What a character uses up - potions, food, scrolls, reagents,
--     arrows and bullets - is never the banker's: a stack of healing potions is your supply, not a valuable;
--   * everything else stays.
-- When the receiver a rule picks is YOU, the stack stays with you: you are the alchemist, the warlock, the
-- enchanter, the banker.
local _, ns = ...

local Classify = {}
ns.Classify = Classify

local CLASS_WEAPON, CLASS_ARMOR, CLASS_PROJECTILE, CLASS_TRADEGOODS, CLASS_QUEST, CLASS_KEY = 2, 4, 6, 7, 12, 13
local ItemBind = type(Enum) == "table" and type(Enum.ItemBind) == "table" and Enum.ItemBind or {}
-- gear that binds once worn: "binds when equipped", and "warbound until equipped" (Enum.ItemBind on Forever)
local UNTIL_EQUIPPED = { [ItemBind.OnEquip or 2] = true, [ItemBind.ToBnetAccountUntilEquipped or 9] = true }
local MAIN_HAND, OFF_HAND = 16, 17

local function item()
    return type(C_Item) == "table" and C_Item or nil
end

-- what the client says of an item: class, subclass, equip location, level, required level, bind type, stats
function Classify.Facts(link, itemID)
    local api = item()
    local facts = { itemID = itemID, link = link }
    local instant = api and ns.Readable(api.GetItemInfoInstant, itemID or link)
    if instant then
        facts.equipLoc, facts.icon, facts.classID, facts.subclassID = instant[4], instant[5], instant[6], instant[7]
    end
    local info = api and ns.Readable(api.GetItemInfo, link or itemID)
    if info then
        facts.name = info[1]
        facts.quality = info[3]
        facts.itemLevel = info[4]
        facts.minLevel = info[5]
        facts.equipLoc = facts.equipLoc or info[9]
        facts.classID = facts.classID or info[12]
        facts.subclassID = facts.subclassID or info[13]
        facts.sellPrice = info[11]
        facts.bindType = info[14]
        facts.isCraftingReagent = info[17] -- does any recipe use it? (Forever's GetItemInfo, 17th return)
    end
    facts.itemLevel = ns.Roster.ItemLevel(link) or facts.itemLevel
    return facts
end

local function statsOf(link)
    local api = item()
    local stats = api and ns.Read(api.GetItemStats, link)
    return type(stats) == "table" and stats or {}
end

-- does an item's stats suit a class? A caster's item (intellect or spirit, no strength or agility) is not for a
-- warrior; a fighter's item is not for a mage. Mixed or no stats: anyone.
function Classify.StatsSuit(class, stats)
    local caster = (stats.ITEM_MOD_INTELLECT_SHORT or stats.ITEM_MOD_SPIRIT_SHORT) and true or false
    local physical = (stats.ITEM_MOD_STRENGTH_SHORT or stats.ITEM_MOD_AGILITY_SHORT) and true or false
    if caster and not physical then
        return not ns.Data.PHYSICAL[class]
    end
    if physical and not caster then
        return not ns.Data.CASTER[class]
    end
    return true
end

-- can a character use an armor or weapon type? Its own skill window first, the class table when that named none.
function Classify.CanUse(entry, facts)
    local classID, subclass = facts.classID, facts.subclassID
    if facts.equipLoc == "INVTYPE_CLOAK" or facts.equipLoc == "INVTYPE_NECK" or facts.equipLoc == "INVTYPE_FINGER" or facts.equipLoc == "INVTYPE_TRINKET" then
        return true -- everybody wears a cloak, a necklace, rings and trinkets
    end
    local skill
    if classID == CLASS_ARMOR then
        local onlyFor = ns.Data.ARMOR_CLASS[subclass]
        if onlyFor then
            return entry.class == onlyFor
        end
        skill = ns.Data.ARMOR_SKILL[subclass]
        if not skill then
            return true -- generic armor: shirts, tabards, off-hand frills
        end
    elseif classID == CLASS_WEAPON then
        skill = ns.Data.WEAPON_SKILL[subclass]
        if not skill then
            return false -- fishing poles and the like are not gear to route
        end
    else
        return false
    end
    local learned = entry.proficiencies or {}
    local own = (classID == CLASS_ARMOR) and learned.armor or learned.weapons
    if own and next(own) then
        return own[skill] and true or false
    end
    local table_ = ns.Data.CLASS_SKILLS[entry.class or ""]
    if not table_ then
        return false
    end
    if classID == CLASS_ARMOR then
        local from = table_.armor[skill]
        return from ~= nil and (entry.level or 0) >= from
    end
    for _, name in ipairs(table_.weapons) do
        if name == skill then
            return true
        end
    end
    return false
end

-- can a character fight with a weapon in each hand? Its client's answer at its last login, else its class
function Classify.CanDualWield(entry)
    if entry.dualWield ~= nil then
        return entry.dualWield
    end
    local from = ns.Data.DUAL_WIELD[entry.class or ""]
    return from ~= nil and (entry.level or 0) >= from
end

-- the slots an item would take on a character: a one-hand weapon goes to the off hand only for a dual wielder
-- (a warlock's empty off hand had made every dagger an upgrade over nothing)
function Classify.SlotsFor(facts, entry)
    local slots = ns.Data.SLOTS[facts.equipLoc or ""]
    if slots and facts.equipLoc == "INVTYPE_WEAPON" and not Classify.CanDualWield(entry) then
        return { MAIN_HAND }
    end
    return slots
end

-- the item level a character wears in a slot. An empty off hand beside a two-hander is held by the two-hander -
-- also when it is not known whether the main hand holds one, the cautious reading; empty beside a one-hander, or
-- with no weapon at all, it holds nothing
function Classify.WornIn(entry, slot)
    local equipped = entry.equipped or {}
    local level = equipped[slot]
    if level == nil and slot == OFF_HAND and entry.twoHanded ~= false then
        level = equipped[MAIN_HAND]
    end
    return level or 0
end

-- the alt who would wear an item as the biggest upgrade: { entry, gain, wears } or nil. Never the character at
-- the mailbox: it holds the item, and puts it on if it wants it.
function Classify.BestWearer(facts)
    if type(facts.itemLevel) ~= "number" or not ns.Data.SLOTS[facts.equipLoc or ""] then
        return nil
    end
    local stats = statsOf(facts.link)
    local slack = ns:GetOption("levelSlack") or 3
    local best
    for _, entry in ipairs(ns.Roster:Reachable()) do
        local fits = not ns.Roster:IsMe(entry.key)
            and Classify.CanUse(entry, facts)
            and (type(facts.minLevel) ~= "number" or facts.minLevel <= (entry.level or 0) + slack)
            and Classify.StatsSuit(entry.class, stats)
        if fits then
            local wears
            for _, slot in ipairs(Classify.SlotsFor(facts, entry)) do
                local level = Classify.WornIn(entry, slot)
                if not wears or level < wears then
                    wears = level -- the weaker of the two rings, trinkets or hands
                end
            end
            local gain = facts.itemLevel - (wears or 0)
            if gain >= 1 then
                local better = not best or gain > best.gain or (gain == best.gain and (entry.level or 0) > (best.entry.level or 0))
                if better then
                    best = { entry = entry, gain = gain, wears = wears or 0 }
                end
            end
        end
    end
    return best
end

local function keep(reason, category)
    return { action = "keep", reason = reason, category = category }
end

local function send(entry, category, reason, detail)
    return { action = "send", receiver = entry.key, category = category, reason = reason, detail = detail }
end

local CLASS_RECIPE = 9
local USED_UP = { [0] = true, [5] = true, [6] = true } -- consumables, reagents, projectiles: your supplies

-- the banker's share: tradeable, unclaimed, and worth something; nil when it is not the banker's
function Classify.ForBanker(slotInfo, facts)
    if USED_UP[facts.classID] then
        return nil
    end
    local entry = ns.Roster:Banker()
    if not entry then
        return nil
    end
    local quality = slotInfo.quality or facts.quality or 0
    local value = (type(facts.sellPrice) == "number" and facts.sellPrice or 0) * (slotInfo.count or 1)
    local worth
    if facts.classID == CLASS_RECIPE then
        worth = "a recipe"
    elseif quality >= (ns:GetOption("bankerQuality") or 2) then
        worth = "green or better"
    elseif value >= (ns:GetOption("bankerValue") or 10000) then
        worth = "worth " .. ns.FormatMoney(value) .. " at a vendor"
    end
    if not worth then
        return nil
    end
    if ns.Roster:IsMe(entry.key) then
        return keep("yours: you are the banker", "valuables")
    end
    return send(entry, "valuables", "tradeable and " .. worth .. ": to your banker", "banker")
end

-- the verdict for one stack: { action = "send" | "keep", receiver, category, reason, detail }
function Classify.Verdict(slotInfo, facts)
    local itemID = facts.itemID
    if ns.db.keep[itemID] then
        return keep("on your keep list")
    end
    if ns.Data.NEVER[itemID] then
        return keep("never mailed")
    end
    if slotInfo.isBound then
        return keep("soulbound")
    end
    if slotInfo.isLocked then
        return keep("in use")
    end
    if facts.classID == CLASS_QUEST then
        return keep("a quest item")
    end
    if facts.classID == CLASS_KEY then
        return keep("a key")
    end
    local quality = slotInfo.quality or facts.quality
    if quality == 0 then
        return keep("grey: for the vendor")
    end
    local Roster = ns.Roster

    -- class supplies
    local classes = ns.Data.SUPPLIES[itemID] or (facts.classID == CLASS_PROJECTILE and ns.Data.PROJECTILE_CLASSES) or nil
    if classes then
        if not ns:GetOption("supplies") then
            return keep("class supplies are switched off", "supplies")
        end
        local entry, class = Roster:ReceiverForClasses(classes, facts.minLevel)
        if not entry then
            return Classify.ForBanker(slotInfo, facts) or keep("no " .. (classes.who or string.lower(class or "?")) .. " on this realm yet", "supplies")
        end
        if Roster:IsMe(entry.key) then
            return keep("yours: you are the " .. string.lower(class), "supplies")
        end
        return send(entry, "supplies", "for your " .. string.lower(class))
    end

    -- profession materials: the table first, then the trade-goods type - when a recipe uses the item
    local profession = ns.Data.MATERIALS[itemID]
    if not profession and facts.classID == CLASS_TRADEGOODS and facts.isCraftingReagent ~= false then
        profession = ns.Data.TRADEGOODS_SUBCLASS[facts.subclassID]
    end
    if profession then
        if not ns:GetOption("materials") then
            return keep("materials are switched off", "materials")
        end
        local entry, why = Roster:ReceiverFor(profession)
        if not entry then
            return Classify.ForBanker(slotInfo, facts) or keep(why, "materials")
        end
        if Roster:IsMe(entry.key) then
            return keep("yours: you are the " .. string.lower(profession) .. " alt (" .. why .. ")", "materials")
        end
        return send(entry, "materials", why, profession)
    end

    -- gear
    if facts.classID == CLASS_ARMOR or facts.classID == CLASS_WEAPON then
        if not UNTIL_EQUIPPED[facts.bindType] or (quality or 0) < (ns:GetOption("gearQuality") or 2) then
            return Classify.ForBanker(slotInfo, facts) or keep(nil, "gear") -- white gear, or no BoE: the banker's if worth it
        end
        if not ns:GetOption("gear") then
            return keep("gear is switched off", "gear")
        end
        local wearer = Classify.BestWearer(facts)
        if wearer then
            local gain = string.format("item level %d over the %d it wears", facts.itemLevel, wearer.wears)
            return send(wearer.entry, "gear", "an upgrade for " .. Roster.Label(wearer.entry) .. ": " .. gain, "wear")
        end
        local enchanter, why = Roster:ReceiverFor("Enchanting")
        if not enchanter then
            return Classify.ForBanker(slotInfo, facts) or keep("no alt would wear it, and " .. why, "gear")
        end
        local needs = ns.Data.DisenchantSkill(facts.itemLevel)
        local has = (enchanter.professions or {}).Enchanting and enchanter.professions.Enchanting.skill or 0
        local note = has < needs and (" - disenchanting it takes " .. needs .. ", it has " .. has) or ""
        if Roster:IsMe(enchanter.key) then
            return keep("yours to disenchant: you are the enchanter" .. note, "gear")
        end
        return send(enchanter, "gear", "to disenchant (" .. why .. ")" .. note, "disenchant")
    end

    return Classify.ForBanker(slotInfo, facts) or keep(nil)
end
