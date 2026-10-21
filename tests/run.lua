-- Scenario tests for AKForeverAltMailer: lua tests/run.lua  (from the addon's folder)
package.path = "tests/?.lua;" .. package.path
local Mock = require("wowmock")
local G = _G

local passed, failures = 0, {}

local function check(condition, message)
    if not condition then
        error(message or "check failed", 2)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message and (message .. ": ") or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function scenario(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok and #Mock.errors > 0 then
        ok, err = false, "the addon raised an error: " .. tostring(Mock.errors[1])
    end
    if ok then
        passed = passed + 1
        Mock.realPrint("  ok    " .. name)
    else
        failures[#failures + 1] = name
        Mock.realPrint("  FAIL  " .. name .. "\n          " .. tostring(err):gsub("\n", "\n          "))
    end
end

local function printed(text)
    for _, line in ipairs(Mock.printed) do
        if line:find(text, 1, true) then
            return true
        end
    end
    return false
end

------------------------------------------------------------------------
-- Items, as the client describes them. Classic materials often carry no trade-goods subtype (class 7,
-- subclass 0): those are known by the addon's table; others carry one.
------------------------------------------------------------------------
local TG, ARMOR, WEAPON = 7, 4, 2
Mock.item(2447, { name = "Peacebloom", classID = TG, subclassID = 0 })                 -- the table knows it
Mock.item(90001, { name = "Mock Herb", classID = TG, subclassID = 9 })                 -- its subtype says herb
Mock.item(2589, { name = "Linen Cloth", classID = TG, subclassID = 5 })
Mock.item(2770, { name = "Copper Ore", classID = TG, subclassID = 0 })
Mock.item(2318, { name = "Light Leather", classID = TG, subclassID = 6 })
Mock.item(10940, { name = "Strange Dust", classID = TG, subclassID = 12 })
Mock.item(769, { name = "Chunk of Boar Meat", classID = TG, subclassID = 0 })
Mock.item(90002, { name = "Mock Gizmo Part", classID = TG, subclassID = 1 })           -- engineering: nobody has it
Mock.item(50001, { name = "Mock Mail Chest", classID = ARMOR, subclassID = 3, equipLoc = "INVTYPE_CHEST", itemLevel = 30, minLevel = 25,
    bindType = 2, quality = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 7 } })
Mock.item(50002, { name = "Mock Robe of the Owl", classID = ARMOR, subclassID = 1, equipLoc = "INVTYPE_ROBE", itemLevel = 22, minLevel = 18,
    bindType = 2, quality = 2, stats = { ITEM_MOD_INTELLECT_SHORT = 6, ITEM_MOD_SPIRIT_SHORT = 6 } })
Mock.item(50003, { name = "Mock Plate Helm of Wisdom", classID = ARMOR, subclassID = 4, equipLoc = "INVTYPE_HEAD", itemLevel = 35, minLevel = 30,
    bindType = 2, quality = 2, stats = { ITEM_MOD_INTELLECT_SHORT = 9 } })
Mock.item(50004, { name = "Mock Sword of the Tiger", classID = WEAPON, subclassID = 7, equipLoc = "INVTYPE_WEAPON", itemLevel = 28, minLevel = 23,
    bindType = 2, quality = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_AGILITY_SHORT = 4 } })
Mock.item(50005, { name = "Mock White Boots", classID = ARMOR, subclassID = 2, equipLoc = "INVTYPE_FEET", itemLevel = 20, bindType = 2, quality = 1 })
Mock.item(50006, { name = "Mock Bound Bracers", classID = ARMOR, subclassID = 2, equipLoc = "INVTYPE_WRIST", itemLevel = 24, bindType = 1, quality = 2 })
Mock.item(17030, { name = "Ankh", classID = 5, subclassID = 0 })
Mock.item(17028, { name = "Holy Candle", classID = 5, subclassID = 0 })
Mock.item(6265, { name = "Soul Shard", classID = 15, subclassID = 0 })
Mock.item(2512, { name = "Rough Arrow", classID = 6, subclassID = 2 })
Mock.item(6948, { name = "Hearthstone", classID = 15, subclassID = 0 })
Mock.item(60001, { name = "Broken Fang", classID = 15, subclassID = 0, quality = 0 })
Mock.item(60002, { name = "Mock Quest Letter", classID = 12, subclassID = 0 })
Mock.item(60003, { name = "Mock Key", classID = 13, subclassID = 0 })
-- what the alts wear
Mock.item(70001, { name = "Worn Chest 15", classID = ARMOR, subclassID = 1, equipLoc = "INVTYPE_CHEST", itemLevel = 15 })
Mock.item(70002, { name = "Worn Chest 20", classID = ARMOR, subclassID = 3, equipLoc = "INVTYPE_CHEST", itemLevel = 20 })
Mock.item(70003, { name = "Worn Robe 25", classID = ARMOR, subclassID = 1, equipLoc = "INVTYPE_ROBE", itemLevel = 25 })
Mock.item(70004, { name = "Worn Weapon 18", classID = WEAPON, subclassID = 7, equipLoc = "INVTYPE_WEAPON", itemLevel = 18 })
Mock.item(70005, { name = "Worn Weapon 10", classID = WEAPON, subclassID = 15, equipLoc = "INVTYPE_WEAPON", itemLevel = 10 })
Mock.item(70006, { name = "Worn Offhand 8", classID = WEAPON, subclassID = 15, equipLoc = "INVTYPE_WEAPON", itemLevel = 8 })
Mock.item(70007, { name = "Worn Helm 30", classID = ARMOR, subclassID = 4, equipLoc = "INVTYPE_HEAD", itemLevel = 30 })
Mock.item(70008, { name = "Worn Greatsword 35", classID = WEAPON, subclassID = 8, equipLoc = "INVTYPE_2HWEAPON", itemLevel = 35 })
Mock.item(70009, { name = "Worn Mace 20", classID = WEAPON, subclassID = 4, equipLoc = "INVTYPE_WEAPON", itemLevel = 20 })

------------------------------------------------------------------------
-- The account: the alts, and the main at the mailbox
------------------------------------------------------------------------
local REALM = "ClassicBetaPvE"
local ALTS = {
    gola = { name = "Purr", surname = "Gola", class = "HUNTER", className = "Hunter", level = 25,
        professions = { { "Alchemy", 230 }, { "Herbalism", 200 } },
        skillLines = { { header = "Secondary Skills" }, { "Cooking", 100 } }, -- no weapon or armor lines: the class table speaks
        equipped = { [5] = 70002, [16] = 70004 } },
    die = { name = "Purr", surname = "Die", class = "WARLOCK", className = "Warlock", level = 28,
        professions = { { "Enchanting", 180 }, { "Tailoring", 150 } },
        skillLines = { { header = "Weapon Skills" }, { "Daggers" }, { "Staves" }, { "Wands" }, { header = "Armor Proficiencies" }, { "Cloth" } },
        equipped = { [5] = 70003, [16] = 70005 } },
    mage = { name = "Purr", surname = "Mage", class = "MAGE", className = "Mage", level = 24,
        professions = { { "Tailoring", 200 } },
        skillLines = { { header = "Weapon Skills" }, { "Staves" }, { "Wands" }, { header = "Armor Proficiencies" }, { "Cloth" } },
        equipped = { [5] = 70001 } },
    tank = { name = "Purr", surname = "Tank", class = "WARRIOR", className = "Warrior", level = 42,
        professions = { { "Blacksmithing", 220 }, { "Mining", 210 } },
        skillLines = { { header = "Weapon Skills" }, { "Two-Handed Swords" }, { "Axes" },
            { header = "Armor Proficiencies" }, { "Cloth" }, { "Leather" }, { "Mail" }, { "Plate Mail" }, { "Shield" } },
        equipped = { [5] = 70002, [1] = 70007, [16] = 70008 } },
    leather = { name = "Purr", surname = "Leather", class = "ROGUE", className = "Rogue", level = 20,
        professions = { { "Leatherworking", 100 }, { "Skinning", 90 } },
        skillLines = { { header = "Weapon Skills" }, { "Daggers" }, { "Swords" }, { header = "Armor Proficiencies" }, { "Cloth" }, { "Leather" } },
        equipped = { [16] = 70005, [17] = 70006 } },
    horde = { name = "Horde", surname = "Guy", faction = "Horde", class = "WARRIOR", className = "Warrior", level = 60,
        professions = { { "Alchemy", 300 } } },
    far = { name = "Far", surname = "Away", realm = "OtherRealm", class = "MAGE", className = "Mage", level = 60,
        professions = { { "Tailoring", 300 } } },
    bank = { name = "Purr", surname = "Bank", class = "WARRIOR", className = "Warrior", level = 1 }, -- a bank alt: no professions
}

local function mainBags()
    return {
        [0] = {
            [1] = { id = 2447, count = 20 }, [2] = { id = 90001, count = 5 }, [3] = { id = 2589, count = 30 }, [4] = { id = 2770, count = 10 },
            [5] = { id = 2318, count = 8 }, [6] = { id = 10940, count = 4 }, [7] = { id = 769, count = 6 }, [8] = { id = 90002, count = 2 },
            [9] = { id = 50001 }, [10] = { id = 50002 }, [11] = { id = 50003 }, [12] = { id = 50004 }, [13] = { id = 50005 },
            [14] = { id = 50006, bound = true }, [15] = { id = 17030, count = 2 }, [16] = { id = 17028, count = 5 },
        },
        [1] = {
            [1] = { id = 6265, count = 3 }, [2] = { id = 2512, count = 200 }, [3] = { id = 6948, bound = true }, [4] = { id = 60001, count = 3 },
            [5] = { id = 60002 }, [6] = { id = 60003 },
        },
    }
end

local function main(extra)
    local fixture = { name = "Purrdee", surname = "Bubson", class = "SHAMAN", className = "Shaman", level = 30,
        professions = { { "Mining", 150 }, { "Skinning", 140 } },
        skillLines = { { header = "Professions" }, { "Mining", 150 }, { "Skinning", 140 }, { header = "Secondary Skills" }, { "First Aid", 80 }, { "Cooking", 60 },
            { header = "Weapon Skills" }, { "Axes" }, { "Maces" }, { "Staves" }, { "Daggers" },
            { header = "Armor Proficiencies" }, { "Cloth" }, { "Leather" }, { "Shield" } },
        equipped = { [5] = 70001, [16] = 70009 }, bags = mainBags() }
    for k, v in pairs(extra or {}) do
        fixture[k] = v
    end
    return fixture
end

local function loginAs(fixture, db)
    local options = {}
    for k, v in pairs(fixture) do
        options[k] = v
    end
    options.db = db
    local ns, state = Mock.install(options)
    Mock.login()
    return ns, state, G.AKForeverAltMailerDB
end

-- every alt logs in once (and any more asked for); then the main
local function account(extra, more)
    local db
    local keys = { "gola", "die", "mage", "tank", "leather", "horde", "far" }
    for _, key in ipairs(more or {}) do
        keys[#keys + 1] = key
    end
    for _, key in ipairs(keys) do
        local _, _, d = loginAs(ALTS[key], db)
        db = d
    end
    return loginAs(main(extra), db)
end

local KEY = "Purrdee Bubson - " .. REALM
local function keyOf(name) return name .. " - " .. REALM end

-- the verdict on an item in the current plan
local function verdictOf(ns, itemID)
    local plan = ns.Plan.Build()
    for _, group in ipairs(plan.receivers) do
        for _, stack in ipairs(group.stacks) do
            if stack.itemID == itemID then
                return stack.verdict, group.entry
            end
        end
    end
    for _, stack in ipairs(plan.keptStacks) do
        if stack.itemID == itemID then
            return stack.verdict
        end
    end
end

local function sentTo(ns, itemID, who)
    local verdict, entry = verdictOf(ns, itemID)
    check(verdict, "no verdict for item " .. itemID)
    equal(verdict.action, "send", "item " .. itemID .. " (" .. tostring(verdict.reason) .. ")")
    equal(entry.address, who, "item " .. itemID .. " goes to")
    return verdict
end

local function keptWith(ns, itemID, reasonPart)
    local verdict = verdictOf(ns, itemID)
    check(verdict, "no verdict for item " .. itemID)
    equal(verdict.action, "keep", "item " .. itemID .. " stays")
    if reasonPart then
        check(verdict.reason and verdict.reason:find(reasonPart, 1, true), "item " .. itemID .. ": reason '" .. tostring(verdict.reason) .. "' lacks '" .. reasonPart .. "'")
    end
    return verdict
end

------------------------------------------------------------------------
-- Scenarios
------------------------------------------------------------------------
scenario("each character writes itself down when you log in on it: class, level, faction, its name for mail, professions from the professions book and the skill window, the armor and weapons it has learned, the item level it wears in each slot; the account's roster grows with each alt; '/aam alts' lists the ones mail reaches", function()
    local ns, _, db = account()
    local me = db.characters[KEY]
    check(me, "the main is on the roster")
    equal(me.class, "SHAMAN"); equal(me.level, 30); equal(me.faction, "Alliance"); equal(me.realm, REALM)
    equal(me.address, "Purrdee Bubson", "the name a mail goes to: first name and surname")
    equal(me.professions.Mining.skill, 150); equal(me.professions.Mining.source, "professions book")
    equal(me.professions["First Aid"].skill, 80); equal(me.professions["First Aid"].source, "skill window", "what the book leaves out, from the skill window")
    check(me.proficiencies.armor.Shield and me.proficiencies.weapons.Maces, "armor and weapon skills from the skill window")
    equal(me.equipped[5], 15); equal(me.equipped[16], 20, "item levels worn")
    local gola = db.characters[keyOf("Purr Gola")]
    equal(gola.professions.Alchemy.skill, 230); equal(gola.professions.Cooking.skill, 100)
    equal(next(gola.proficiencies.armor), nil, "its skill window named no armor: the class table will speak for it")
    equal(#ns.Roster:Reachable(), 6, "six on this realm and faction: the Horde alt and the one on another realm are out of mail's reach")
    Mock.slash("alts")
    check(printed("6 characters on this realm and faction"), "listed")
    check(printed("Purr Gola - level 25 Hunter: Alchemy 230, Cooking 100, Herbalism 200"), "with professions")
end)

scenario("receivers follow professions: the highest skill on this realm and faction - you included; a pick of yours wins (a click on the list cycles, a right-click goes back to automatic); nobody with a profession is said so", function()
    local ns = account()
    local R = ns.Roster
    equal(R.Label(R:ReceiverFor("Alchemy")), "Purr Gola", "230 here; the Horde alt's 300 is out of reach")
    equal(R.Label(R:ReceiverFor("Tailoring")), "Purr Mage", "200 beats 150; the other realm's 300 is out of reach")
    equal(R.Label(R:ReceiverFor("Blacksmithing")), "Purr Tank")
    equal(R.Label(R:ReceiverFor("Cooking")), "Purr Gola", "100 beats your 60")
    equal(R.Label(R:ReceiverFor("Enchanting")), "Purr Die")
    equal(R.Label(R:ReceiverFor("Leatherworking")), "Purr Leather")
    local nobody, why = R:ReceiverFor("Engineering")
    equal(nobody, nil); equal(why, "nobody has Engineering yet")
    local _, auto = R:ReceiverFor("Tailoring")
    equal(auto, "the highest Tailoring (200)")
    R:CycleReceiver("Tailoring")
    R:CycleReceiver("Tailoring")
    local picked, pickedWhy = R:ReceiverFor("Tailoring")
    equal(R.Label(picked), "Purr Die"); equal(pickedWhy, "your pick")
    R:CycleReceiver("Tailoring")
    equal(R.Label(R:ReceiverFor("Tailoring")), "Purr Mage", "past the last candidate: automatic again")
    equal(ns.db.receivers.Tailoring, nil)
end)

scenario("profession materials go to the alt highest in the profession that uses them - known by the item's trade-goods subtype where the client gives one, by the addon's table where it does not; with nobody for them, they stay and say so; your own profession's goods stay with you", function()
    local ns = account()
    sentTo(ns, 2447, "Purr Gola")      -- Peacebloom: no subtype, the table knows it
    sentTo(ns, 90001, "Purr Gola")     -- a herb by its subtype
    sentTo(ns, 2589, "Purr Mage")      -- cloth
    sentTo(ns, 2770, "Purr Tank")      -- ore, by the table
    sentTo(ns, 2318, "Purr Leather")
    sentTo(ns, 10940, "Purr Die")      -- enchanting dust
    sentTo(ns, 769, "Purr Gola")       -- cooking, by the table
    keptWith(ns, 90002, "nobody has Engineering yet")
    -- logged in on the alchemist itself: the herbs stay
    local _, _, db = loginAs(ALTS.gola, ns.db)
    local _, state = loginAs(ALTS.gola, db)
    state.bags[0] = { [1] = { id = 2447, count = 10 }, [2] = { id = 2589, count = 5 } }
    keptWith(Mock.ns, 2447, "yours: you are the alchemy alt")
    sentTo(Mock.ns, 2589, "Purr Mage")
end)

scenario("gear that binds when worn, green or better: to the alt who would wear it as the biggest upgrade - it can use the armor or weapon (its skill window, else its class), it is near the item's level, the stats suit its class, the item level beats what it wears there - never the character at the mailbox; failing all that, to the enchanter (with the skill a disenchant takes); white gear and bound gear stay", function()
    local ns = account()
    local chest = sentTo(ns, 50001, "Purr Tank")
    check(chest.reason:find("an upgrade for Purr Tank: item level 30 over the 20 it wears", 1, true), chest.reason)
    -- cloth, caster stats: the warlock wears better, the hunter is no caster; you (the shaman) gain as much as the
    -- mage and are higher - but you are at the mailbox: it goes to the mage
    local robe = sentTo(ns, 50002, "Purr Mage")
    check(robe.reason:find("an upgrade for Purr Mage: item level 22 over the 15 it wears", 1, true), robe.reason)
    local helm = sentTo(ns, 50003, "Purr Die") -- intellect plate: the warrior is no caster, there is no paladin
    check(helm.reason:find("to disenchant", 1, true), helm.reason)
    local sword = sentTo(ns, 50004, "Purr Gola") -- the hunter (class table: swords) gains 28 over nothing in its off hand ... the rogue only 20
    equal(sword.detail, "wear")
    keptWith(ns, 50006, "soulbound")
    local boots = verdictOf(ns, 50005)
    equal(boots.action, "keep"); equal(boots.reason, nil, "white gear: left alone, nothing to say")
    -- plate before level 40, by the class table; from 40 it is learned
    local C = ns.Classify
    local helmFacts = { classID = 4, subclassID = 4, equipLoc = "INVTYPE_HEAD" }
    equal(C.CanUse({ class = "WARRIOR", level = 35 }, helmFacts), false, "no plate before 40")
    equal(C.CanUse({ class = "WARRIOR", level = 40 }, helmFacts), true)
    equal(C.CanUse({ class = "MAGE", level = 60 }, { classID = 4, subclassID = 1, equipLoc = "INVTYPE_CLOAK" }), true, "everybody wears a cloak")
    -- an enchanter still short of the skill: said, and sent all the same
    ns.db.characters[keyOf("Purr Die")].professions.Enchanting.skill = 50
    local low = sentTo(ns, 50003, "Purr Die")
    check(low.reason:find("disenchanting it takes 75, it has 50", 1, true), low.reason)
end)

scenario("class supplies stay with you when you are of their class, else go to the highest alt of their classes, arrows and bullets to the hunter; a class nobody plays stays, saying so", function()
    local ns = account()
    keptWith(ns, 17030, "yours: you are the shaman") -- Ankh
    keptWith(ns, 17028, "no priest on this realm yet") -- Holy Candle
    sentTo(ns, 6265, "Purr Die")      -- Soul Shard
    sentTo(ns, 2512, "Purr Gola")     -- Rough Arrow
end)

scenario("what always stays: the hearthstone, soulbound things, greys, quest items, keys - and your keep list: a right-click on the panel adds an item, '/aam unkeep' lists and frees", function()
    local ns = account()
    keptWith(ns, 6948, "never mailed")
    keptWith(ns, 60001, "grey: for the vendor")
    keptWith(ns, 60002, "a quest item")
    keptWith(ns, 60003, "a key")
    Mock.openMailbox()
    local row
    for _, r in ipairs(ns.Panel.rows) do
        if r.stack and r.stack.itemID == 2447 and r:IsShown() then row = r end
    end
    check(row, "Peacebloom has a row on the panel")
    Mock.click(row, "RightButton")
    equal(ns.db.keep[2447], true)
    keptWith(ns, 2447, "on your keep list")
    Mock.slash("unkeep")
    check(printed("2447 Peacebloom"), "listed")
    Mock.slash("unkeep 2447")
    sentTo(ns, 2447, "Purr Gola")
end)

scenario("the banker, picked by you: gets what no other alt takes when it is tradeable and worth something - green or better, a recipe, a gold at a vendor - and what a rule found nobody for; herbs, gear and supplies still go where they did; on the banker itself it stays; '/aam banker none' stops it", function()
    Mock.item(80001, { name = "Mock Recipe: Fish Stew", classID = 9, subclassID = 5, quality = 1, sellPrice = 50 })
    Mock.item(80002, { name = "Mock Moss Agate", classID = 3, subclassID = 0, quality = 2, sellPrice = 2000 })
    Mock.item(80003, { name = "Mock Elemental Fire", classID = 7, subclassID = 10, quality = 1, sellPrice = 400 })
    Mock.item(80004, { name = "Mock Silver Idol", classID = 15, subclassID = 0, quality = 1, sellPrice = 20000 })
    Mock.item(80005, { name = "Mock Gold Gizmo", classID = 7, subclassID = 1, quality = 1, sellPrice = 15000 })
    Mock.item(80006, { name = "Mock Healing Potion", classID = 0, subclassID = 1, quality = 1, sellPrice = 600 })
    Mock.item(80007, { name = "Mock Green Scroll", classID = 0, subclassID = 4, quality = 2, sellPrice = 100 })
    Mock.item(80008, { name = "Mock Spare Bag", classID = 1, subclassID = 0, quality = 1, sellPrice = 12500 })
    local bags = mainBags()
    bags[3] = { [1] = { id = 80001 }, [2] = { id = 80002 }, [3] = { id = 80003, count = 2 }, [4] = { id = 80004 }, [5] = { id = 80005 },
        [6] = { id = 80006, count = 20 }, [7] = { id = 80007 }, [8] = { id = 80008 } }
    local ns = account({ bags = bags }, { "bank" })
    keptWith(ns, 80001) -- no banker yet: everything stays as before
    Mock.slash("banker Purr Bank")
    check(printed("Purr Bank is your banker"), "said")
    local recipe = sentTo(ns, 80001, "Purr Bank")
    check(recipe.reason:find("a recipe", 1, true), recipe.reason)
    sentTo(ns, 80002, "Purr Bank")                         -- a green gem
    keptWith(ns, 80003)                                    -- an elemental worth 8s: not the banker's
    local idol = sentTo(ns, 80004, "Purr Bank")            -- a white curio worth 2g at a vendor
    check(idol.reason:find("worth 2g at a vendor", 1, true), idol.reason)
    sentTo(ns, 80005, "Purr Bank")                         -- parts with no engineer, worth 1g 50s: falls through to the banker
    keptWith(ns, 80006)                                    -- 20 potions sell for 1g 20s, but they are your supply
    keptWith(ns, 80007)                                    -- a green scroll is used up too
    sentTo(ns, 80008, "Purr Bank")                         -- a spare bag worth 1g 25s
    keptWith(ns, 90002, "nobody has Engineering yet")      -- parts worth nothing still stay
    sentTo(ns, 2447, "Purr Gola"); sentTo(ns, 50001, "Purr Tank"); sentTo(ns, 6265, "Purr Die") -- the others' as before
    local plan = ns.Plan.Build()
    local bankMail
    for _, group in ipairs(plan.receivers) do
        if group.entry.address == "Purr Bank" then bankMail = group.mails[1] end
    end
    equal(bankMail.subject, "AltMailer: valuables")
    -- the receivers list has the banker's row
    Mock.openMailbox()
    Mock.click(G.AKForeverAltMailerReceiversButton)
    local row
    for _, r in ipairs(ns.Panel.receiverRows) do
        if r.profession == "Banker" and r:IsShown() then row = r end
    end
    check(row and row.text:GetText():find("Purr Bank", 1, true), row and row.text:GetText())
    Mock.click(row, "RightButton")
    check(row.text:GetText():find("none - click to pick one", 1, true), row.text:GetText())
    Mock.click(row)
    check(ns.Roster:Banker(), "a click picks one")
    Mock.closeMailbox()
    Mock.slash("banker none")
    keptWith(ns, 80004)
    -- on the banker itself, valuables stay
    Mock.slash("banker Purr Bank")
    local db = ns.db
    local _, state = loginAs(ALTS.bank, db)
    state.bags[0] = { [1] = { id = 80002 } }
    keptWith(Mock.ns, 80002, "yours: you are the banker")
end)

scenario("'/aam set' lists the options with their values; '/aam set <name> <value>' changes one (on/off, a quality by name or number, an amount of money), '... default' puts it back; a wrong name or value says what it takes", function()
    local ns = account()
    Mock.slash("set")
    check(printed("materials"), "listed")
    check(printed("bankerValue|r 1g"), "the banker's line, as money")
    check(printed("gearQuality|r green (2)"), "a quality, by name")
    Mock.slash("set materials off")
    keptWith(ns, 2447, "materials are switched off")
    check(printed("materials: off (was on)"), "said")
    Mock.slash("set Materials default")
    sentTo(ns, 2447, "Purr Gola")
    Mock.slash("set gearQuality blue")
    keptWith(ns, 50001)                                   -- a green chest is under the line now
    Mock.slash("set gearQuality 2")
    sentTo(ns, 50001, "Purr Tank")
    Mock.slash("set bankerValue 1g 50s")
    equal(ns:GetOption("bankerValue"), 15000)
    check(printed("bankerValue: 1g 50s (was 1g)"), "said")
    Mock.slash("set bankerValue 2")
    equal(ns:GetOption("bankerValue"), 20000, "a bare number is gold")
    Mock.slash("set levelSlack 5")
    equal(ns:GetOption("levelSlack"), 5)
    Mock.slash("set gearQuality 9")
    check(printed("gearQuality takes a quality"), "a wrong quality")
    Mock.slash("set dock maybe")
    check(printed("dock takes on or off"), "a wrong flag")
    Mock.slash("set nonsense 1")
    check(printed("no option called nonsense"), "a wrong name")
    equal(ns:GetOption("dock"), true, "unchanged")
end)

scenario("BoE gear and the hands: a piece only you could wear goes to the enchanter, not into your bags; a one-hand weapon counts the off hand only for a dual wielder (the client's CanDualWield, else the class); an empty off hand beside a two-hander is held by it; 'warbound until equipped' is gear like BoE", function()
    Mock.item(50007, { name = "Mock Totem of the Tides", classID = 4, subclassID = 9, equipLoc = "INVTYPE_RELIC", itemLevel = 25, minLevel = 20,
        bindType = 2, quality = 2 })
    Mock.item(50008, { name = "Mock Stamina Dagger", classID = 2, subclassID = 15, equipLoc = "INVTYPE_WEAPON", itemLevel = 18, minLevel = 15,
        bindType = 2, quality = 2, stats = { ITEM_MOD_STAMINA_SHORT = 5 } })
    Mock.item(50009, { name = "Mock Tower Shield", classID = 4, subclassID = 6, equipLoc = "INVTYPE_SHIELD", itemLevel = 30, minLevel = 25,
        bindType = 2, quality = 2, stats = { ITEM_MOD_STAMINA_SHORT = 6 } })
    Mock.item(50010, { name = "Mock Warbound Cloak", classID = 4, subclassID = 1, equipLoc = "INVTYPE_CLOAK", itemLevel = 25, minLevel = 20,
        bindType = 9, quality = 2 })
    local bags = mainBags()
    bags[3] = { [1] = { id = 50007 }, [2] = { id = 50008 }, [3] = { id = 50009 }, [4] = { id = 50010 } }
    local ns = account({ bags = bags, dualWield = false })
    local C = ns.Classify
    -- what each character wrote down of its hands
    equal(ns.db.characters[keyOf("Purr Tank")].twoHanded, true, "the greatsword")
    equal(ns.db.characters[keyOf("Purr Gola")].twoHanded, false, "a one-hander")
    equal(ns.db.characters[keyOf("Purr Mage")].twoHanded, false, "nothing in the main hand")
    equal(ns.db.characters[keyOf("Purrdee Bubson")].dualWield, false, "the client's answer")
    equal(ns.db.characters[keyOf("Purr Gola")].dualWield, nil, "no answer: the class speaks")
    equal(C.CanDualWield({ class = "WARLOCK", level = 60 }), false)
    equal(C.CanDualWield({ class = "ROGUE", level = 10 }), true)
    equal(C.CanDualWield({ class = "HUNTER", level = 19 }), false)
    equal(C.CanDualWield({ class = "SHAMAN", level = 30, dualWield = true }), true, "the client's answer wins")
    -- a totem only a shaman wears: you are the shaman, at the mailbox - so the enchanter gets it
    local totem = sentTo(ns, 50007, "Purr Die")
    check(totem.reason:find("to disenchant", 1, true), totem.reason)
    -- a shield: the warrior's greatsword holds the off hand at 35, the 30 shield is no upgrade; you would gain, but
    -- you are at the mailbox
    sentTo(ns, 50009, "Purr Die")
    -- a warbound cloak: gear like BoE; nobody wears a cloak, the highest level gains most
    sentTo(ns, 50010, "Purr Tank")
    -- a dagger: the hunter dual wields (class, 25) and has nothing beside its sword: 18 over nothing
    local dagger = sentTo(ns, 50008, "Purr Gola")
    check(dagger.reason:find("item level 18 over the 0 it wears", 1, true), dagger.reason)
    -- without the hunter and the rogue, the warlock: its off hand does not count, 18 over its 10 dagger
    ns.db.characters[keyOf("Purr Gola")] = nil
    ns.db.characters[keyOf("Purr Leather")] = nil
    dagger = sentTo(ns, 50008, "Purr Die")
    check(dagger.reason:find("item level 18 over the 10 it wears", 1, true), dagger.reason)
    equal(C.WornIn({ equipped = { [16] = 35 }, twoHanded = true }, 17), 35, "a two-hander holds the off hand")
    equal(C.WornIn({ equipped = { [16] = 35 } }, 17), 35, "not known: the cautious reading")
    equal(C.WornIn({ equipped = { [16] = 20 }, twoHanded = false }, 17), 0, "beside a one-hander the off hand is empty")
end)

scenario("the panel goes with the mail window: closed by MAIL_CLOSED, by the interaction manager's hide, or - with no event at all - when it sees the mail window gone; once a visit, whatever comes twice; it waits for the mail window to show first; the signals are counted for the report", function()
    local ns = account()
    local panel = G.AKForeverAltMailerPanel
    Mock.openMailbox("interaction")
    check(ns.Mailer.open and G.AKForeverAltMailerPanel and G.AKForeverAltMailerPanel:IsShown(), "opened by the interaction manager")
    panel = G.AKForeverAltMailerPanel
    Mock.click(G.AKForeverAltMailerReceiversButton)
    check(G.AKForeverAltMailerReceivers:IsShown(), "the receivers list")
    Mock.closeMailbox("interaction")
    check(not panel:IsShown() and not ns.Mailer.open, "closed by the interaction manager")
    check(not G.AKForeverAltMailerReceivers:IsShown(), "the receivers list too")
    -- no event at all: the panel sees the mail window gone
    Mock.openMailbox()
    check(panel:IsShown(), "open again")
    Mock.update(0.3)
    check(panel:IsShown(), "the mail window shows: the panel stays")
    Mock.closeMailbox("window")
    check(panel:IsShown(), "no event yet")
    Mock.update(0.3)
    check(not panel:IsShown() and not ns.Mailer.open, "gone with the mail window")
    -- both events: one closing
    Mock.openMailbox("both")
    check(panel:IsShown(), "open by both")
    Mock.closeMailbox("both")
    check(not panel:IsShown(), "closed")
    local closings = 0
    for _, entry in ipairs(ns.sessionLog) do
        if entry.k == "mailbox_closed" then closings = closings + 1 end
    end
    equal(closings, 3, "one closing per visit")
    -- the mail window a moment late: the panel waits for it
    G.MailFrame:Hide()
    Mock.fire("MAIL_SHOW")
    Mock.advance(0.1)
    check(panel:IsShown(), "shown on MAIL_SHOW")
    Mock.update(0.5)
    check(panel:IsShown(), "the mail window not seen yet: the panel waits")
    G.MailFrame:Show()
    Mock.update(0.3)
    G.MailFrame:Hide()
    Mock.update(0.3)
    check(not panel:IsShown(), "seen, then gone")
    local signals = ns.Mailer:Describe().signals
    equal(signals["interaction shown"], 2); equal(signals["interaction hidden"], 2)
    equal(signals["MAIL_SHOW"], 3); equal(signals["MAIL_CLOSED"], 1); equal(signals["mail window hidden"], 2)
end)

scenario("the enchanters' oils go to the alts that put them on a weapon, never to the enchanter as material: a wizard oil stays with a caster that holds it, from anyone else goes to the highest caster; a caster under the oil's level passes it on; a supply of your class stays with you, even with a higher alt of your class about; a trade good no recipe uses is no material unless the table names it", function()
    Mock.item(20746, { name = "Lesser Wizard Oil", classID = 7, subclassID = 12, minLevel = 30, reagent = false })
    Mock.item(20747, { name = "Lesser Mana Oil", classID = 7, subclassID = 12, minLevel = 40, reagent = false })
    Mock.item(80010, { name = "Mock Enchanted Trinket Part", classID = 7, subclassID = 12, reagent = false })
    Mock.item(80011, { name = "Mock Arcane Dust", classID = 7, subclassID = 12, reagent = true })
    Mock.item(80012, { name = "Mock Unknown Dust", classID = 7, subclassID = 12 }) -- the client says nothing: a material, as before
    Mock.item(10940, { name = "Strange Dust", classID = 7, subclassID = 12, reagent = false }) -- a wrong flag: the table wins
    local bags = mainBags()
    bags[3] = { [1] = { id = 20746 }, [2] = { id = 20747 }, [3] = { id = 80010 }, [4] = { id = 80011, count = 5 }, [5] = { id = 80012 } }
    local ns, _, db = account({ bags = bags })
    -- on the shaman (30): its own oil
    local oil = keptWith(ns, 20746, "yours: you are the shaman")
    equal(oil.category, "supplies")
    keptWith(ns, 20747, "yours: you are the shaman") -- under the mana oil's 40, but no healer is higher: it waits with you
    keptWith(ns, 80010)                               -- no recipe uses it: no enchanting material
    sentTo(ns, 80011, "Purr Die"); sentTo(ns, 80012, "Purr Die"); sentTo(ns, 10940, "Purr Die") -- the enchanter's
    -- on the hunter: the oil goes to the highest caster
    local hunter = { name = "Purr", surname = "Gola", class = "HUNTER", className = "Hunter", level = 25,
        professions = { { "Alchemy", 230 }, { "Herbalism", 200 } }, equipped = { [5] = 70002, [16] = 70004 },
        bags = { [0] = { [1] = { id = 20746 } } } }
    local nsHunter = loginAs(hunter, db)
    local sent = sentTo(nsHunter, 20746, "Purrdee Bubson")
    check(sent.reason:find("for your shaman", 1, true), sent.reason)
    -- on the mage (24): under the oil's 30 - it goes to the shaman
    local mage = { name = "Purr", surname = "Mage", class = "MAGE", className = "Mage", level = 24, professions = { { "Tailoring", 200 } },
        bags = { [0] = { [1] = { id = 20746 } } } }
    sentTo(loginAs(mage, db), 20746, "Purrdee Bubson")
    -- a second warlock, level 10, keeps its own soul shards though Purr Die (28) is a warlock too
    local imp = { name = "Purr", surname = "Imp", class = "WARLOCK", className = "Warlock", level = 10,
        bags = { [0] = { [1] = { id = 6265, count = 2 } } } }
    keptWith(loginAs(imp, db), 6265, "yours: you are the warlock")
    -- nobody plays the class: nil, and the first class of the list
    local entry, class = Mock.ns.Roster:ReceiverForClasses({ "DRUID", who = "druid" })
    equal(entry, nil); equal(class, "DRUID")
    Mock.item(10940, { name = "Strange Dust", classID = 7, subclassID = 12 }) -- as the other scenarios know it
end)

scenario("the plan: per receiver, mails of twelve; postage thirty copper an item; each subject names the goods; '/aam plan' tells it in the chat, anywhere", function()
    local bags = mainBags()
    for slot = 1, 13 do
        bags[2] = bags[2] or {}
        bags[2][slot] = { id = 2589, count = 20 }
    end
    local ns = account({ bags = bags })
    local plan = ns.Plan.Build()
    local mage
    for _, group in ipairs(plan.receivers) do
        if group.entry.address == "Purr Mage" then mage = group end
    end
    equal(#mage.stacks, 15, "fourteen stacks of cloth and the robe"); equal(#mage.mails, 2); equal(#mage.mails[1].stacks, 12); equal(#mage.mails[2].stacks, 3)
    equal(mage.mails[1].subject, "AltMailer: gear for you, cloth", "gear first, then the materials")
    equal(mage.mails[2].subject, "AltMailer: cloth")
    equal(plan.postage, plan.attachments * 30)
    local gola
    for _, group in ipairs(plan.receivers) do
        if group.entry.address == "Purr Gola" then gola = group end
    end
    local subject = gola.mails[1].subject
    check(subject:find("herbs", 1, true) and subject:find("cooking ingredients", 1, true) and subject:find("gear for you", 1, true) and subject:find("class supplies", 1, true), subject)
    Mock.slash("plan")
    check(printed(plan.mails .. " mail(s)"), "told in the chat")
    check(printed("Purr Mage"), "with the receivers")
end)

scenario("sending, measured: a click sends the first mail - each stack attached, then SendMail to the alt's name; the client lets the next go on its own: everything goes from that one click, 'one click sends everything' is learned; what was routed has left the bags, what stays is still there", function()
    local ns, state = account()
    local plan = ns.Plan.Build()
    local mails = plan.mails
    Mock.openMailbox()
    check(ns.Panel:IsShown(), "the panel opens with the mailbox")
    equal(ns.Panel.docked, true, "beside the mail window")
    local text = G.AKForeverAltMailerSend:GetText()
    check(text:find("Send " .. mails .. " mails", 1, true), text)
    Mock.click(G.AKForeverAltMailerSend)
    equal(#Mock.mails, 0, "on its way")
    check(G.AKForeverAltMailerSend:GetText():find("Sending 1 of", 1, true), G.AKForeverAltMailerSend:GetText())
    Mock.advance(30)
    equal(#Mock.mails, mails, "every mail delivered")
    equal(ns.db.sending.mode, "chain", "learned: no click needed after the first")
    local names = {}
    for _, m in ipairs(Mock.mails) do names[m.to] = true end
    check(names["Purr Gola"] and names["Purr Mage"] and names["Purr Tank"] and names["Purr Leather"] and names["Purr Die"], "to the alts by their names")
    check(ns.db.sending.addresses["Purr Gola"], "the names the client took are noted")
    local counts = Mock.bagCounts()
    equal(counts[2447], nil, "the herbs are gone"); equal(counts[50001], nil, "the chest is gone")
    equal(counts[17030], 2, "the Ankh stayed"); equal(counts[6948], 1, "the hearthstone stayed"); equal(counts[50002], nil, "the robe went to the mage")
    equal(G.AKForeverAltMailerSend:GetText(), "Nothing to mail")
    check(printed("all mailed: " .. mails .. " mail(s)"), "said so")
end)

scenario("a client that wants a click for every mail: the second mail is blocked (its items stay on the send window), the addon learns it and says so, the button becomes 'Send next'; each click sends one; the next run asks for clicks from the start", function()
    local ns, state = account({ sendNeedsClick = true })
    local mails = ns.Plan.Build().mails
    Mock.openMailbox()
    Mock.click(G.AKForeverAltMailerSend)
    Mock.advance(2)
    equal(#Mock.mails, 1, "the first mail went with the click")
    equal(Mock.blockedCalls, 1, "the second was tried without one, and blocked")
    equal(ns.db.sending.mode, "click")
    check(printed("this client wants a click for every mail"), "said once")
    check(next(state.attachments), "the blocked mail's items stay on the send window")
    check(G.AKForeverAltMailerSend:GetText():find("Send next (2 of " .. mails .. ")", 1, true), G.AKForeverAltMailerSend:GetText())
    for n = 2, mails do
        Mock.click(G.AKForeverAltMailerSend)
        Mock.advance(2)
        equal(#Mock.mails, n, "one more mail per click")
    end
    equal(Mock.blockedCalls, 1, "no more blocked tries once learned")
    equal(G.AKForeverAltMailerSend:GetText(), "Nothing to mail")
    -- another run: one mail per click from the start
    Mock.closeMailbox()
    state.bags[3] = { [1] = { id = 2589, count = 5 }, [2] = { id = 2447, count = 5 } }
    Mock.openMailbox()
    Mock.click(G.AKForeverAltMailerSend)
    Mock.advance(3)
    equal(#Mock.mails, mails + 1, "the first mail of the new run")
    equal(Mock.blockedCalls, 1, "nothing tried without a click")
    check(G.AKForeverAltMailerSend:GetText():find("Send next", 1, true), G.AKForeverAltMailerSend:GetText())
end)

scenario("when it goes wrong: a mail the mailbox refuses gives its items back and stops the run with the client's words; too little money for the postage attaches nothing; the mailbox closing ends a run", function()
    local ns, state = account({ unknownRecipients = { ["Purr Leather"] = true } })
    Mock.openMailbox()
    Mock.click(G.AKForeverAltMailerSend)
    Mock.advance(30)
    check(printed("the mail to Purr Leather failed: Cannot find player"), "the client's words")
    equal(ns.db.sending.lastError.reason, "Cannot find player")
    equal(next(state.attachments), nil, "its items went back")
    equal(Mock.bagCounts()[2318], 8, "the leather is still in the bags")
    local before = #Mock.mails
    check(before >= 1, "the mails before it went")
    -- money
    Mock.closeMailbox()
    local ns2, state2 = account({ money = 10 })
    Mock.openMailbox()
    Mock.click(G.AKForeverAltMailerSend)
    check(printed("not enough money for the postage"), "said")
    equal(next(state2.attachments), nil, "nothing attached")
    equal(#Mock.mails, 0)
    -- the mailbox closing
    state2.money = 100000
    Mock.click(G.AKForeverAltMailerSend)
    Mock.closeMailbox()
    Mock.advance(30)
    equal(ns2.Mailer.session, nil, "the run ended with the mailbox")
    check(#Mock.mails <= 1, "nothing more was sent after it closed")
end)

scenario("the panel: beside the mail window when a mailbox opens, gone when it closes; the X keeps it away until the next mailbox; each item says on hover where it goes and why; 'Receivers' lists who takes what, a click picks another alt, a right-click goes back to automatic", function()
    local ns = account()
    Mock.openMailbox()
    local point = { G.AKForeverAltMailerPanel:GetPoint(1) }
    equal(point[2], G.MailFrame); equal(point[3], "TOPRIGHT")
    local headerTexts = {}
    for _, h in ipairs(ns.Panel.headers) do
        if h:IsShown() then headerTexts[#headerTexts + 1] = h:GetText() end
    end
    check(table.concat(headerTexts, " | "):find("Purr Gola", 1, true), table.concat(headerTexts, " | "))
    local row
    for _, r in ipairs(ns.Panel.rows) do
        if r.stack and r.stack.itemID == 2447 and r:IsShown() then row = r end
    end
    row:GetScript("OnEnter")(row)
    local tip = table.concat(G.GameTooltip.__lines, " | ")
    check(tip:find("To Purr Gola: the highest Alchemy (230)", 1, true), tip)
    -- the X
    Mock.click(G.AKForeverAltMailerClose)
    check(not ns.Panel:IsShown(), "away")
    ns:Fire("MAILER_CHANGED")
    check(not ns.Panel:IsShown(), "and it stays away")
    Mock.closeMailbox()
    Mock.openMailbox()
    check(ns.Panel:IsShown(), "back at the next mailbox")
    -- receivers
    Mock.click(G.AKForeverAltMailerReceiversButton)
    check(G.AKForeverAltMailerReceivers:IsShown(), "the list")
    local tailoring
    for _, r in ipairs(ns.Panel.receiverRows) do
        if r.profession == "Tailoring" and r:IsShown() then tailoring = r end
    end
    check(tailoring.text:GetText():find("Purr Mage", 1, true) and tailoring.text:GetText():find("(automatic)", 1, true), tailoring.text:GetText())
    Mock.click(tailoring)
    Mock.click(tailoring)
    check(tailoring.text:GetText():find("Purr Die", 1, true) and tailoring.text:GetText():find("(your pick)", 1, true), tailoring.text:GetText())
    sentTo(ns, 2589, "Purr Die")
    Mock.click(tailoring, "RightButton")
    check(tailoring.text:GetText():find("Purr Mage", 1, true), "automatic again")
    Mock.closeMailbox()
    check(not ns.Panel:IsShown(), "gone with the mailbox")
end)

scenario("'/aam diag' writes the report: the characters, what the client answered for professions and the skill window, every stack with its class, subclass, bind type, quality and verdict, what was learned about sending; it is written at logout too", function()
    local ns = account()
    Mock.slash("diag")
    local report = ns.db.diag
    check(report, "written")
    equal(report.character, KEY)
    check(report.characters[keyOf("Purr Gola")], "the roster")
    check(report.readings.professions and report.readings.skillLines, "the client's answers")
    local herb
    for _, item in ipairs(report.items) do
        if item.item == 2447 then herb = item end
    end
    equal(herb.class, 7); equal(herb.subclass, 0); equal(herb.verdict, "send"); equal(herb.to, "Purr Gola")
    equal(report.sending.mode, "not measured")
    check(printed("report written"), "said")
    ns.db.diag = nil
    Mock.logout()
    check(ns.db.diag and ns.db.diag.items, "written at logout")
    -- at logout the client reads the bags as empty: the report keeps the last plan that read them
    Mock.state.bags = {}
    ns.db.diag = nil
    Mock.logout()
    check(#ns.db.diag.items > 0, "the items of the last full plan")
    check(ns.db.diag.plan.from:find("the last time the bags read", 1, true), ns.db.diag.plan.from)
    check(ns.db.diag.plan.judged > 0, "judged")
end)

Mock.realPrint(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then
    os.exit(1)
end
