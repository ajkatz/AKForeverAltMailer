-- AKForeverAltMailer core: namespace, safe calls, event dispatch, message bus, saved variables, the character's
-- profile, session log and slash commands.
--
-- The mission of this addon family, built for the WoW: Forever game mode: minimalistic UI additions that bring
-- out the utility Blizzard's UI does not give - minimal in nature, no Lua errors, always smooth. So: every entry
-- point goes through ns.SafeCall, and every error is kept for the report.
--
-- What this addon is for (the user, 2026-10-20): "determine profession/class needs and automatically take an
-- inventory of stuff and mail it to the right alts. For instance i want to always have a designated enchanter
-- where all BoE items go, a designated alchemist where all herbs go, a designated tailor where all cloth goes".
-- His four answers: receivers follow each alt's professions (the highest skill), with a panel to override;
-- at the mailbox a preview with one send button; profession materials, BoE gear to the enchanter, gear an alt
-- can wear, and class supplies, all four; and the receiving alt takes the mail of your own alts - "sending
-- primary goal / receiving secondary goal": this build sends.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMetadata and getMetadata(ADDON_NAME, "Version")) or "dev"
if string.find(ns.version, "@", 1, true) then
    ns.version = "dev" -- a working copy: the packager has not replaced the @project-version@ token
end
ns.version = (string.gsub(ns.version, "^v", ""))

local PRINT_PREFIX = "|cff8fd16bAltMailer|r: "

function ns:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    print(PRINT_PREFIX .. table.concat(parts, " "))
end

------------------------------------------------------------------------
-- Secret values. WoW: Forever runs the Midnight-era API, where some values handed to addons may be held but
-- not inspected. Nothing this addon reads is documented as secret (bags, items, mail, professions), but every
-- answer is checked all the same before it is looked at.
------------------------------------------------------------------------
local issecret = type(issecretvalue) == "function" and issecretvalue or nil

function ns.IsSecret(value)
    if issecret then
        return issecret(value) and true or false
    end
    return false
end

function ns.AnySecret(...)
    for i = 1, select("#", ...) do
        if ns.IsSecret((select(i, ...))) then
            return true
        end
    end
    return false
end

local function pack(...)
    return { n = select("#", ...), ... }
end

-- Call a client function: its results as a list (with `n`, positions kept even where a result is nil), or nil
-- when it errors, is missing, or answers with anything secret.
function ns.Readable(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local results = pack(pcall(fn, ...))
    if not results[1] then
        return nil
    end
    local out = { n = results.n - 1 }
    for i = 2, results.n do
        if ns.IsSecret(results[i]) then
            return nil
        end
        out[i - 1] = results[i]
    end
    return out
end

-- the first result alone, or nil
function ns.Read(fn, ...)
    local results = ns.Readable(fn, ...)
    return results and results[1]
end

------------------------------------------------------------------------
-- Safe calls: every distinct error is kept for the report.
------------------------------------------------------------------------
ns.errors = {}

local function onError(err)
    err = tostring(err)
    local seen = ns.errors[err]
    ns.errors[err] = (seen or 0) + 1
    if not seen then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        end
    end
    return err
end

function ns.SafeCall(fn, ...)
    return xpcall(fn, onError, ...)
end

------------------------------------------------------------------------
-- Session log (ring buffer)
------------------------------------------------------------------------
local LOG_MAX = 200
ns.sessionLog = {}

function ns:Log(kind, data)
    local log = ns.sessionLog
    log[#log + 1] = {
        t = math.floor(GetTime() * 1000) / 1000,
        k = kind,
        d = data,
    }
    if #log > LOG_MAX then
        table.remove(log, 1)
    end
end

------------------------------------------------------------------------
-- Internal message bus
------------------------------------------------------------------------
local listeners = {}

function ns:Listen(message, fn)
    listeners[message] = listeners[message] or {}
    table.insert(listeners[message], fn)
end

function ns:Fire(message, ...)
    local list = listeners[message]
    if not list then
        return
    end
    for i = 1, #list do
        ns.SafeCall(list[i], ...)
    end
end

------------------------------------------------------------------------
-- Game events: one frame, handlers per event, every handler in a SafeCall
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
ns.unknownEvents = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = eventHandlers[event]
    if not list then
        return
    end
    for i = 1, #list do
        ns.SafeCall(list[i], event, ...)
    end
end)

function ns:On(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            ns.unknownEvents[event] = true
        end
    end
    table.insert(eventHandlers[event], fn)
end

------------------------------------------------------------------------
-- Blocked actions: the client's word on an action it refused an addon - with the function's name, since
-- "Interface action failed because of an AddOn" names nothing on screen. Kept for the report, and handed to
-- the mailer (a send the client refuses without a click is how it learns to ask for one click per mail).
------------------------------------------------------------------------
ns.blocked = {}
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    ns:On(event, function(_, addon, func) -- handlers get the event first
        addon = (not ns.IsSecret(addon) and type(addon) == "string") and addon or "?"
        func = (not ns.IsSecret(func) and type(func) == "string") and func or "?"
        local record = { event = event, addon = addon, func = func, at = math.floor(GetTime()) }
        ns.blocked[#ns.blocked + 1] = record
        if #ns.blocked > 40 then
            table.remove(ns.blocked, 1)
        end
        ns:Log("blocked", record)
        if addon == ADDON_NAME then
            ns:Fire("BLOCKED", record)
        end
    end)
end

------------------------------------------------------------------------
-- Saved variables: one account-wide table - the roster of your characters, the receivers you picked, the keep
-- list, what was learned about sending - and a profile per character, keyed "First Last - Realm" as the
-- client names you since build 70170 (the surname sits in the realm slot of UnitName; the name on the wire is
-- GetUnitName(unit, true)).
------------------------------------------------------------------------
local OPTION_DEFAULTS = {
    materials = true,  -- profession materials go to the alt highest in that profession
    gear = true,       -- unbound gear: to an alt who would wear it as an upgrade, else to the enchanter
    supplies = true,   -- class supplies (reagents, ammo) go to an alt of that class
    gearQuality = 2,   -- the least quality of gear that is mailed: 2 = uncommon (green)
    levelSlack = 3,    -- gear for an alt up to this many levels above it: it will wear it soon
    bankerQuality = 2, -- the banker takes tradeable items of this quality or better (2 = uncommon, green) ...
    bankerValue = 10000, -- ... or that sell to a vendor for at least this much in copper (1 gold), and recipes
    dock = true,       -- the panel sits beside the mail window and closes with it
}

local function initDB()
    if type(AKForeverAltMailerDB) ~= "table" then
        AKForeverAltMailerDB = {}
        ns.savedStateSource = "none (first run, or the client did not load it)"
    else
        ns.savedStateSource = "client"
    end
    local db = AKForeverAltMailerDB
    db.schema = db.schema or 1
    db.loads = (db.loads or 0) + 1
    db.options = db.options or {}
    db.chars = db.chars or {}           -- [key] = this character's own settings (cdb)
    db.characters = db.characters or {} -- [key] = the roster entry (Roster.lua)
    db.receivers = db.receivers or {}   -- [profession] = key: the receiver you picked; nil = automatic. Banker: picked only
    db.keep = db.keep or {}             -- [itemID] = true: never mailed
    db.sending = db.sending or {}       -- what was learned about sending on this client (Mailer.lua)
    ns.db = db
    ns.cdb = ns.cdb or {} -- a stand-in until the profile is bound at PLAYER_LOGIN
end

-- the name the client puts on the wire, plus the realm
function ns.PlayerKey()
    local name = ns.Read(GetUnitName, "player", true)
    if type(name) ~= "string" or name == "" or name == "Unknown" then
        name = ns.Read(UnitName, "player")
    end
    local realm = ns.Read(GetRealmName)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name .. " - " .. (type(realm) == "string" and realm or "?"), name, realm
end

local function bindProfile()
    local key, name, realm = ns.PlayerKey()
    ns.characterKey, ns.playerName, ns.realm = key, name, realm
    if not key then
        ns.cdb = ns.cdb or {}
        return
    end
    ns.db.chars[key] = ns.db.chars[key] or {}
    local carried = ns.cdb
    ns.cdb = ns.db.chars[key]
    for k, v in pairs(carried or {}) do -- anything written before the name was known
        if ns.cdb[k] == nil then
            ns.cdb[k] = v
        end
    end
end

function ns:GetOption(key)
    local options = ns.db and ns.db.options
    local value = options and options[key]
    if value == nil then
        return OPTION_DEFAULTS[key]
    end
    return value
end

function ns:SetOption(key, value)
    ns.db.options[key] = value
    ns:Fire("OPTION_CHANGED", key, value)
end

------------------------------------------------------------------------
-- Slash commands: modules register their own sub-commands
------------------------------------------------------------------------
local commands, commandOrder = {}, {}

function ns:RegisterCommand(name, help, fn)
    commands[name] = { help = help, fn = fn }
    commandOrder[#commandOrder + 1] = name
end

SLASH_AKFOREVERALTMAILER1 = "/akforeveraltmailer"
SLASH_AKFOREVERALTMAILER2 = "/aam"
SLASH_AKFOREVERALTMAILER3 = "/altmail"
SlashCmdList["AKFOREVERALTMAILER"] = function(message)
    local name, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    local command = commands[string.lower(name or "")]
    if command then
        ns.SafeCall(command.fn, rest or "")
        return
    end
    ns:Print("v" .. ns.version .. " - your alts get what they use, mailed from any mailbox. Commands:")
    for _, commandName in ipairs(commandOrder) do
        print("   |cffffd100/aam " .. commandName .. "|r - " .. commands[commandName].help)
    end
end

------------------------------------------------------------------------
-- Options: '/aam set' lists them, '/aam set <name> <value>' changes one, '... default' puts one back
------------------------------------------------------------------------
local OPTION_HELP = {
    { "materials", "flag", "profession materials go to the alt highest in that profession" },
    { "gear", "flag", "BoE gear goes to the alt it is an upgrade for, else to the enchanter" },
    { "supplies", "flag", "class supplies go to an alt of that class" },
    { "gearQuality", "quality", "the least quality of BoE gear that is mailed" },
    { "levelSlack", "number", "gear goes to an alt up to this many levels under the item's" },
    { "bankerQuality", "quality", "the banker takes tradeable items of this quality or better ..." },
    { "bankerValue", "money", "... or a stack worth this much at a vendor (2g, 50s)" },
    { "dock", "flag", "the panel sits beside the mail window" },
}
local QUALITY_NAMES = { [0] = "grey", [1] = "white", [2] = "green", [3] = "blue", [4] = "purple", [5] = "orange" }
local QUALITY_WORDS = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
for quality, name in pairs(QUALITY_NAMES) do
    QUALITY_WORDS[name] = quality
end
local FLAG_WORDS = { on = true, yes = true, ["true"] = true, ["1"] = true, off = false, no = false, ["false"] = false, ["0"] = false }

local function showOption(kind, value)
    if kind == "flag" then
        return value and "on" or "off"
    elseif kind == "quality" then
        return (QUALITY_NAMES[value] or tostring(value)) .. " (" .. tostring(value) .. ")"
    elseif kind == "money" then
        return ns.FormatMoney(value)
    end
    return tostring(value)
end

-- a value as typed, or nil and what was wrong with it
local function parseOption(kind, text)
    text = string.lower(text or "")
    if kind == "flag" then
        local flag = FLAG_WORDS[text]
        if flag == nil then
            return nil, "on or off"
        end
        return flag
    elseif kind == "quality" then
        local quality = tonumber(text) or QUALITY_WORDS[text]
        if not quality or not QUALITY_NAMES[quality] then
            return nil, "a quality: grey, white, green, blue, purple, orange (or 0-5)"
        end
        return quality
    elseif kind == "money" then
        local copper, found = 0, false
        for amount, unit in string.gmatch(text, "(%d+)%s*([gsc])") do
            copper = copper + tonumber(amount) * ((unit == "g" and 10000) or (unit == "s" and 100) or 1)
            found = true
        end
        if not found then
            local gold = tonumber(text)
            if not gold then
                return nil, "an amount: 2g, 50s, 1g 50s"
            end
            copper = math.floor(gold * 10000 + 0.5) -- a bare number is gold
        end
        return copper
    end
    local number = tonumber(text)
    if not number or number < 0 then
        return nil, "a number"
    end
    return math.floor(number)
end

ns:RegisterCommand("set", "the options: '/aam set' lists them, '/aam set <name> <value>' changes one", function(rest)
    local name, value = string.match(rest or "", "^(%S*)%s*(.-)$")
    if not name or name == "" then
        ns:Print("options ('/aam set <name> <value>', '/aam set <name> default'):")
        for _, option in ipairs(OPTION_HELP) do
            print("   |cffffd100" .. option[1] .. "|r " .. showOption(option[2], ns:GetOption(option[1])) .. " |cff999999- " .. option[3] .. "|r")
        end
        return
    end
    local found
    for _, option in ipairs(OPTION_HELP) do
        if string.lower(option[1]) == string.lower(name) then
            found = option
        end
    end
    if not found then
        ns:Print("no option called " .. name .. ": '/aam set' lists them.")
        return
    end
    local key, kind = found[1], found[2]
    local before = ns:GetOption(key)
    if string.lower(value) == "default" then
        ns:SetOption(key, nil)
    else
        local parsed, wanted = parseOption(kind, value)
        if parsed == nil then
            ns:Print(key .. " takes " .. wanted .. ".")
            return
        end
        ns:SetOption(key, parsed)
    end
    ns:Print(key .. ": " .. showOption(kind, ns:GetOption(key)) .. " (was " .. showOption(kind, before) .. ").")
end)

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------
ns.inCombat = false

ns:On("ADDON_LOADED", function(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    initDB()
end)

ns:On("PLAYER_LOGIN", function()
    if not ns.db then
        initDB()
    end
    bindProfile()
    local class = ns.Readable(UnitClass, "player")
    ns.playerClass = class and class[2] or nil
    ns.inCombat = InCombatLockdown() and true or false
    ns:Log("login", { version = ns.version, loads = ns.db.loads, savedState = ns.savedStateSource, character = ns.characterKey })
    ns:Fire("LOGIN")
end)

ns:On("PLAYER_REGEN_DISABLED", function()
    ns.inCombat = true
end)

ns:On("PLAYER_REGEN_ENABLED", function()
    ns.inCombat = false
end)

-- money as the client writes it: 1g 2s 3c
function ns.FormatMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold, silver, rest = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
    return table.concat(parts, " ")
end
