-- Roster: every character of the account the addon has seen, with what decides who gets what - its professions
-- and their skill, the armor and weapons it has learned, its class, level and faction, and the item level it
-- wears in each slot. A character writes itself down when you log in on it and keeps that up to date while you
-- play it; the others are known from their last visit (the client reads the saved file back since build 70170).
--
-- RECEIVERS follow from it: for each profession the character with the highest skill in it on this realm and
-- faction (mail goes neither across realms nor across factions) - you included: when YOU are the alchemist,
-- the herbs stay with you. A receiver you picked yourself (/aam receivers) wins over the automatic one.
-- THE BANKER has no profession to be found by: it is only ever the one you pick (/aam banker <name>).
local _, ns = ...

local Roster = {}
ns.Roster = Roster

Roster.readings = {} -- what the client answered, for /aam diag

local function now()
    return time and time() or 0
end

------------------------------------------------------------------------
-- Reading the current character
------------------------------------------------------------------------
-- the skill window's lines, as far as they are expanded: { name, rank, maxRank, skillID, header }
function Roster:ReadSkillLines()
    local lines, collapsed = {}, {}
    local api = type(C_SkillInfo) == "table" and C_SkillInfo or nil
    local count = api and ns.Read(api.GetNumSkillLines)
    if type(count) ~= "number" then
        self.readings.skillLines = "no skill window API"
        return lines, collapsed
    end
    local header
    for index = 1, count do
        local info = ns.Read(api.GetSkillLineInfo, index)
        if type(info) == "table" and type(info.name) == "string" then
            if info.isHeader then
                header = info.name
                if info.isCollapsed then
                    collapsed[#collapsed + 1] = info.name
                end
            else
                lines[#lines + 1] = { name = info.name, rank = info.rank, maxRank = info.maxRank, skillID = info.skillID, header = header }
            end
        end
    end
    self.readings.skillLines = #lines .. " lines" .. (#collapsed > 0 and (", collapsed: " .. table.concat(collapsed, ", ")) or "")
    return lines, collapsed
end

-- professions: GetProfessions / GetProfessionInfo (the professions book's own calls on this flavour), then the
-- skill window by name for whatever those leave out (First Aid, say)
function Roster:ReadProfessions(skillLines)
    local found = {}
    local indices = ns.Readable(GetProfessions)
    local fromBook = 0
    if indices then
        for i = 1, math.max(indices.n or 0, 6) do
            local index = indices[i]
            if type(index) == "number" then
                local info = ns.Readable(GetProfessionInfo, index)
                local name = ns.Data.ProfessionName(info and info[1])
                local rank, maxRank, skillLine = info and info[3], info and info[4], info and info[7]
                if name and type(rank) == "number" then
                    found[name] = { skill = rank, max = maxRank, skillLine = skillLine, source = "professions book" }
                    fromBook = fromBook + 1
                end
            end
        end
    end
    local fromWindow = 0
    for _, line in ipairs(skillLines or {}) do
        local name = ns.Data.ProfessionName(line.name)
        if name and not found[name] and type(line.rank) == "number" and line.rank > 0 then
            found[name] = { skill = line.rank, max = line.maxRank, skillLine = line.skillID, source = "skill window" }
            fromWindow = fromWindow + 1
        end
    end
    self.readings.professions = { book = indices and fromBook or "no answer", window = fromWindow }
    return found
end

-- the armor and weapon skills the skill window names; empty sets when it named none
function Roster:ReadProficiencies(skillLines)
    local armor, weapons = {}, {}
    for _, line in ipairs(skillLines or {}) do
        local kind = ns.Data.KNOWN_SKILLS[line.name]
        if kind == "armor" then
            armor[line.name] = true
        elseif kind == "weapon" then
            weapons[line.name] = true
        end
    end
    return armor, weapons
end

-- an item's level from its link: the detailed level where the client gives one, else the item's own
function Roster.ItemLevel(link)
    if type(link) ~= "string" then
        return nil
    end
    local item = type(C_Item) == "table" and C_Item or nil
    local detailed = item and ns.Read(item.GetDetailedItemLevelInfo, link)
    if type(detailed) == "number" and detailed > 0 then
        return detailed
    end
    local info = item and ns.Readable(item.GetItemInfo, link)
    local level = info and info[4]
    if type(level) == "number" then
        return level
    end
    return nil
end

function Roster:ReadEquipment()
    local equipped = {}
    for _, slot in ipairs(ns.Data.EQUIPMENT_SLOTS) do
        local link = ns.Read(GetInventoryItemLink, "player", slot)
        local level = Roster.ItemLevel(link)
        if level then
            equipped[slot] = level
        end
    end
    return equipped
end

-- is the main hand's weapon a two-hander (it fills the off hand too)? false with the main hand empty; nil when
-- the client does not say
function Roster:MainHandTwoHanded()
    local link = ns.Read(GetInventoryItemLink, "player", 16)
    if not link then
        return false
    end
    local api = type(C_Item) == "table" and C_Item or nil
    local instant = api and ns.Readable(api.GetItemInfoInstant, link)
    local equipLoc = instant and instant[4]
    if type(equipLoc) ~= "string" then
        return nil
    end
    return equipLoc == "INVTYPE_2HWEAPON"
end

-- can this character fight with a weapon in each hand? The client's answer (CanDualWield); nil without one, and
-- then the class table speaks (Data.DUAL_WIELD)
function Roster:ReadDualWield()
    local can = ns.Readable(CanDualWield)
    self.readings.dualWield = can and tostring(can[1]) or "no answer"
    if not can or can[1] == nil then
        return nil
    end
    return can[1] and true or false
end

-- write the current character down (or bring its entry up to date)
function Roster:Record(reason)
    local key = ns.characterKey
    if not key or not ns.db then
        return nil
    end
    local class = ns.Readable(UnitClass, "player")
    local skillLines, collapsed = self:ReadSkillLines()
    local armor, weapons = self:ReadProficiencies(skillLines)
    local entry = ns.db.characters[key] or {}
    entry.key = key
    entry.address = ns.playerName -- the name a mail goes to: GetUnitName("player", true), as the client gives it
    entry.realm = ns.realm
    entry.faction = ns.Read(UnitFactionGroup, "player") or entry.faction
    entry.class = class and class[2] or entry.class
    entry.className = class and class[1] or entry.className
    entry.level = ns.Read(UnitLevel, "player") or entry.level
    entry.professions = self:ReadProfessions(skillLines)
    entry.proficiencies = { armor = armor, weapons = weapons, collapsed = (#collapsed > 0) and collapsed or nil }
    entry.equipped = self:ReadEquipment()
    entry.twoHanded = self:MainHandTwoHanded()
    entry.dualWield = self:ReadDualWield()
    entry.seen = now()
    ns.db.characters[key] = entry
    ns:Log("roster_recorded", { why = reason, professions = (function()
        local names = {}
        for name, p in pairs(entry.professions) do names[#names + 1] = name .. " " .. tostring(p.skill) end
        table.sort(names)
        return table.concat(names, ", ")
    end)() })
    ns:Fire("ROSTER_CHANGED")
    return entry
end

------------------------------------------------------------------------
-- The others
------------------------------------------------------------------------
-- the characters a mail from here can reach: this realm, this faction - you included
function Roster:Reachable()
    local me = ns.characterKey and ns.db.characters[ns.characterKey]
    local list = {}
    for key, entry in pairs(ns.db.characters) do
        if type(entry) == "table" and entry.address and (not me or (entry.realm == me.realm and (entry.faction == me.faction or not entry.faction or not me.faction))) then
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

function Roster:Get(key)
    return key and ns.db.characters[key] or nil
end

function Roster:IsMe(key)
    return key ~= nil and key == ns.characterKey
end

-- a short name for the panel: the address ("Purr Gola")
function Roster.Label(entry)
    return entry and (entry.address or entry.key) or "?"
end

-- the characters with a profession, best first: skill, then level, then name
function Roster:Candidates(profession)
    local list = {}
    for _, entry in ipairs(self:Reachable()) do
        local p = entry.professions and entry.professions[profession]
        if p and type(p.skill) == "number" and p.skill > 0 then
            list[#list + 1] = { key = entry.key, entry = entry, skill = p.skill }
        end
    end
    table.sort(list, function(a, b)
        if a.skill ~= b.skill then return a.skill > b.skill end
        if (a.entry.level or 0) ~= (b.entry.level or 0) then return (a.entry.level or 0) > (b.entry.level or 0) end
        return a.key < b.key
    end)
    return list
end

-- who takes a profession's goods: the one you picked, else the highest skill; nil when nobody has it
function Roster:ReceiverFor(profession)
    local picked = ns.db.receivers[profession]
    if picked and self:Get(picked) then
        for _, entry in ipairs(self:Reachable()) do
            if entry.key == picked then
                return entry, "your pick"
            end
        end
    end
    local best = self:Candidates(profession)[1]
    if best then
        return best.entry, "the highest " .. profession .. " (" .. best.skill .. ")"
    end
    return nil, "nobody has " .. profession .. " yet"
end

-- the character a class supply is for: YOU, when you are of one of its classes and near its level - you hold it
-- and use it, even with a higher alt of your class about; else the highest-level alt of any of its classes.
-- Returns entry, class (that character's class; the first of the list when nobody plays one).
function Roster:ReceiverForClasses(classes, minLevel)
    local wanted = {}
    for _, class in ipairs(classes or {}) do
        wanted[class] = true
    end
    local me = ns.characterKey and ns.db.characters[ns.characterKey]
    local slack = ns:GetOption("levelSlack") or 3
    if me and wanted[me.class or ""] and (type(minLevel) ~= "number" or (me.level or 0) + slack >= minLevel) then
        return me, me.class
    end
    local best
    for _, entry in ipairs(self:Reachable()) do
        if wanted[entry.class or ""] and (not best or (entry.level or 0) > (best.level or 0)) then
            best = entry
        end
    end
    if best then
        return best, best.class
    end
    return nil, classes and classes[1]
end

-- the banker you picked, if mail reaches it
function Roster:Banker()
    local picked = ns.db.receivers.Banker
    if not picked then
        return nil, "no banker picked"
    end
    for _, entry in ipairs(self:Reachable()) do
        if entry.key == picked then
            return entry, "your banker"
        end
    end
    return nil, "your banker is out of mail's reach"
end

-- the receiver you picked for a profession: the next candidate on every call, back to automatic after the last.
-- For the banker every character you have is a candidate.
function Roster:CycleReceiver(profession)
    local candidates = self:Candidates(profession)
    if profession == "Banker" then
        candidates = {}
        for _, entry in ipairs(self:Reachable()) do
            candidates[#candidates + 1] = { key = entry.key, entry = entry }
        end
    end
    local current = ns.db.receivers[profession]
    local nextKey
    if not current then
        nextKey = candidates[1] and candidates[1].key
    else
        for i, c in ipairs(candidates) do
            if c.key == current then
                nextKey = candidates[i + 1] and candidates[i + 1].key or nil
                break
            end
        end
    end
    ns.db.receivers[profession] = nextKey
    ns:Log("receiver_picked", { profession = profession, key = nextKey or "automatic" })
    ns:Fire("ROSTER_CHANGED")
    return nextKey
end

function Roster:Forget(key)
    if not ns.db.characters[key] then
        return false
    end
    ns.db.characters[key] = nil
    for profession, picked in pairs(ns.db.receivers) do
        if picked == key then
            ns.db.receivers[profession] = nil
        end
    end
    ns:Fire("ROSTER_CHANGED")
    return true
end

------------------------------------------------------------------------
-- Keeping it up to date
------------------------------------------------------------------------
local recordQueued = false
local function recordSoon(reason, delay)
    if recordQueued then
        return
    end
    recordQueued = true
    C_Timer.After(delay or 1, function()
        recordQueued = false
        ns.SafeCall(Roster.Record, Roster, reason)
    end)
end

ns:Listen("LOGIN", function()
    Roster:Record("login")
    recordSoon("login, items cached", 3) -- item levels of what you wear come once the client has the items
end)

for _, event in ipairs({ "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "TRADE_SKILL_SHOW" }) do
    ns:On(event, function()
        if ns.characterKey then
            recordSoon(event, 1)
        end
    end)
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
ns:RegisterCommand("alts", "your characters the addon knows, with their professions", function()
    local list = Roster:Reachable()
    if #list == 0 then
        ns:Print("no characters yet: log in on each of your alts once.")
        return
    end
    ns:Print(#list .. " characters on this realm and faction:")
    for _, entry in ipairs(list) do
        local professions = {}
        for name, p in pairs(entry.professions or {}) do
            professions[#professions + 1] = name .. " " .. tostring(p.skill)
        end
        table.sort(professions)
        print(string.format("   %s%s - level %s %s%s", Roster:IsMe(entry.key) and "> " or "  ", Roster.Label(entry), tostring(entry.level or "?"),
            entry.className or entry.class or "?", #professions > 0 and (": " .. table.concat(professions, ", ")) or ""))
    end
end)

ns:RegisterCommand("banker", "the alt that gets tradeable valuables nobody else takes: /aam banker <name> | none", function(rest)
    local wanted = string.lower(rest or "")
    if wanted == "" then
        local entry, why = Roster:Banker()
        ns:Print("banker: " .. (entry and Roster.Label(entry) or why) .. ". '/aam banker <name>' picks one, '/aam banker none' stops it.")
        return
    end
    if wanted == "none" then
        ns.db.receivers.Banker = nil
        ns:Print("no banker: valuables stay where they are.")
        ns:Fire("ROSTER_CHANGED")
        return
    end
    for _, entry in ipairs(Roster:Reachable()) do
        if string.lower(entry.address or "") == wanted or string.lower(entry.key) == wanted then
            ns.db.receivers.Banker = entry.key
            ns:Print(Roster.Label(entry) .. " is your banker: tradeable valuables no other alt takes go there.")
            ns:Fire("ROSTER_CHANGED")
            return
        end
    end
    ns:Print("no character called " .. rest .. " that mail reaches (log in on it once).")
end)

ns:RegisterCommand("forget", "forget a character: /aam forget <name>", function(rest)
    local wanted = string.lower(rest or "")
    if wanted == "" then
        ns:Print("whom? /aam forget <name>")
        return
    end
    for key, entry in pairs(ns.db.characters) do
        if string.lower(entry.address or "") == wanted or string.lower(key) == wanted then
            Roster:Forget(key)
            ns:Print("forgot " .. (entry.address or key) .. ".")
            return
        end
    end
    ns:Print("no character called " .. rest .. ".")
end)
