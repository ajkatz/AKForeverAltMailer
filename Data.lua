-- Data: what the addon knows by heart - the professions and the materials each one uses, the class supplies,
-- the armor and weapons each class can learn, and which equipment slot an item goes in.
--
-- MATERIALS are recognised three ways, the item's own word first:
--   1. the item's trade-goods type, when the client gives one (Item class 7 with the subclass numbers of the
--      modern client: 5 cloth, 6 leather, 7 metal and stone, 8 cooking, 9 herb, 12 enchanting, 1-3 engineering);
--   2. the table below - the old world's herbs, cloth, ore, bars, stone, leather, hides, enchanting materials
--      and cooking ingredients by item id, for a client whose classic items carry no such subtype (this client
--      documents no trade-goods subclass list, so which of the two it does is measured: /aam diag records the
--      class and subclass of everything in your bags);
--   3. a material you mark yourself (later).
-- Elemental materials and gems are used by many professions and are left where they are.
--
-- CLASS SUPPLIES are reagents and ammunition a class uses: they go to an alt of that class.
--
-- PROFICIENCIES come from each alt's own skill window when it was read (C_SkillInfo: Armor Proficiencies and
-- Weapon Skills by name); the class table here is only the fallback for an alt whose window gave none, with
-- the classic rules (mail and plate from level 40).
local _, ns = ...

local Data = {}
ns.Data = Data

-- canonical English names; GetProfessionInfo and the skill window name them the same way in an English client
Data.PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Inscription", "Jewelcrafting",
    "Leatherworking", "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing",
}
local PROFESSION_BY_LOWER = {}
for _, name in ipairs(Data.PROFESSIONS) do
    PROFESSION_BY_LOWER[string.lower(name)] = name
end

-- the canonical name of a profession the client named, or nil when it is none
function Data.ProfessionName(name)
    if type(name) ~= "string" then
        return nil
    end
    return PROFESSION_BY_LOWER[string.lower(name)]
end

-- the word for each profession's goods, in a mail's subject and on the panel
Data.GOODS = {
    Alchemy = "herbs", Tailoring = "cloth", Blacksmithing = "ore, bars and stone", Leatherworking = "leather",
    Enchanting = "enchanting materials", Cooking = "cooking ingredients", Engineering = "engineering parts",
}

-- item class 7 (trade goods), by subclass: the profession that uses them
Data.TRADEGOODS_SUBCLASS = {
    [1] = "Engineering", [2] = "Engineering", [3] = "Engineering",
    [5] = "Tailoring", [6] = "Leatherworking", [7] = "Blacksmithing", [8] = "Cooking", [9] = "Alchemy",
    [12] = "Enchanting",
}

local function list(profession, ids, into)
    for _, id in ipairs(ids) do
        into[id] = profession
    end
end

-- [itemID] = the profession that uses it
Data.MATERIALS = {}
list("Alchemy", { -- herbs
    765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3818, 3819, 3820, 3821, 4625, 8153,
    8831, 8836, 8838, 8839, 8845, 8846, 13463, 13464, 13465, 13466, 13467, 13468, 19726,
}, Data.MATERIALS)
list("Tailoring", { -- cloth, bolts, spider silk
    2589, 2592, 4306, 4338, 14047, 14256, 2996, 2997, 4305, 4339, 14048, 14342, 3182, 4337, 10285, 14227,
}, Data.MATERIALS)
list("Blacksmithing", { -- ore, bars, stone
    2770, 2771, 2772, 2775, 2776, 3858, 7911, 10620, 11370,
    2840, 3576, 2841, 3575, 3859, 2842, 3577, 3860, 6037, 12359, 11371,
    2835, 2836, 2838, 7912, 12365,
}, Data.MATERIALS)
list("Leatherworking", { -- leather, hides, scales
    2934, 2318, 2319, 4234, 4304, 8170, 15417, 15419, 17012,
    783, 4232, 4235, 8169, 8171, 4461, 4231, 4233, 4236, 8172, 15407,
    8154, 8167, 15408, 7286, 7392, 8165, 15412, 15414, 15415, 15416,
}, Data.MATERIALS)
list("Enchanting", { -- dusts, essences, shards
    10940, 11083, 11137, 11176, 16204,
    10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203,
    10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344, 20725,
}, Data.MATERIALS)
list("Cooking", { -- meat, fish, eggs (the common ones; the item's own cooking subtype covers the rest)
    769, 723, 729, 731, 1015, 1080, 1081, 1468, 2672, 2673, 2674, 2675, 2677, 2924, 3173, 3404, 3667, 3685,
    3712, 3730, 3731, 4655, 5465, 5467, 5469, 5470, 5471, 5503, 12037, 12184, 12202, 12203, 12204, 12205,
    12206, 12207, 12208, 20424,
    6289, 6291, 6303, 6308, 6317, 6361, 6362, 4603, 8365, 13754, 13756, 13758, 13759, 13760, 13888, 13889,
    13893, 21071, 21153,
}, Data.MATERIALS)

-- the enchanters' oils: made by the enchanter for the alts that put them on a weapon (the user, 2026-10-20: "an
-- item enchanters should distribute TO alts"). Forever files them as trade goods of the Enchanting kind
-- (measured: Lesser Wizard Oil = class 7, subclass 12), so they had gone TO the enchanter as material.
local WIZARD_OIL = { "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", who = "caster" } -- spell damage
local MANA_OIL = { "PRIEST", "DRUID", "SHAMAN", "PALADIN", who = "healer" }           -- mana in a fight

-- [itemID] = the classes that use it: it stays with you when you are one of them, else goes to the highest alt
-- of any of them (Roster:ReceiverForClasses); `who` names them when nobody plays one
Data.SUPPLIES = {
    [20744] = WIZARD_OIL, [20746] = WIZARD_OIL, [20750] = WIZARD_OIL, [20749] = WIZARD_OIL, -- Minor, Lesser, Wizard, Brilliant Wizard Oil
    [20745] = MANA_OIL, [20747] = MANA_OIL, [20748] = MANA_OIL,                              -- Minor, Lesser, Brilliant Mana Oil
    [17020] = { "MAGE" },                 -- Arcane Powder
    [17031] = { "MAGE" },                 -- Rune of Teleportation
    [17032] = { "MAGE" },                 -- Rune of Portals
    [17056] = { "MAGE", "PRIEST" },       -- Light Feather
    [17028] = { "PRIEST" },               -- Holy Candle
    [17029] = { "PRIEST" },               -- Sacred Candle
    [17033] = { "PALADIN" },              -- Symbol of Divinity
    [21177] = { "PALADIN" },              -- Symbol of Kings
    [17030] = { "SHAMAN" },               -- Ankh
    [17057] = { "SHAMAN" },               -- Shiny Fish Scales
    [17058] = { "SHAMAN" },               -- Fish Oil
    [17021] = { "DRUID" },                -- Wild Berries
    [17026] = { "DRUID" },                -- Wild Thornroot
    [17034] = { "DRUID" }, [17035] = { "DRUID" }, [17036] = { "DRUID" }, [17037] = { "DRUID" }, [17038] = { "DRUID" }, -- seeds
    [5140] = { "ROGUE" },                 -- Flash Powder
    [5530] = { "ROGUE" },                 -- Blinding Powder
    [2928] = { "ROGUE" }, [2930] = { "ROGUE" }, [5173] = { "ROGUE" }, [8923] = { "ROGUE" }, [8924] = { "ROGUE" }, -- poison reagents
    [6265] = { "WARLOCK" },               -- Soul Shard
    [5565] = { "WARLOCK" },               -- Infernal Stone
    [16583] = { "WARLOCK" },              -- Demonic Figurine
}
-- item class 6 (projectiles: arrows and bullets) goes to a hunter
Data.PROJECTILE_CLASSES = { "HUNTER" }

-- never mailed, whatever else they are
Data.NEVER = {
    [6948] = true, -- Hearthstone
}

------------------------------------------------------------------------
-- Proficiencies
------------------------------------------------------------------------
-- item armor subclass -> the skill window's name for it; nil: anyone
Data.ARMOR_SKILL = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate Mail", [6] = "Shield" }
-- armor only one class carries
Data.ARMOR_CLASS = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" } -- libram, idol, totem
-- item weapon subclass -> the skill window's name for it
Data.WEAPON_SKILL = {
    [0] = "Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "Maces", [5] = "Two-Handed Maces",
    [6] = "Polearms", [7] = "Swords", [8] = "Two-Handed Swords", [10] = "Staves", [13] = "Fist Weapons",
    [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows", [19] = "Wands",
}
local KNOWN_SKILLS = {}
for _, name in pairs(Data.ARMOR_SKILL) do KNOWN_SKILLS[name] = "armor" end
for _, name in pairs(Data.WEAPON_SKILL) do KNOWN_SKILLS[name] = "weapon" end
Data.KNOWN_SKILLS = KNOWN_SKILLS

-- the fallback: what each class can learn (classic rules); [skill] = the level it comes at
local ALL_CLOTH_LEATHER = { Cloth = 1, Leather = 1 }
Data.CLASS_SKILLS = {
    WARRIOR = { armor = { Cloth = 1, Leather = 1, Mail = 1, ["Plate Mail"] = 40, Shield = 1 },
        weapons = { "Axes", "Two-Handed Axes", "Bows", "Guns", "Maces", "Two-Handed Maces", "Polearms", "Swords", "Two-Handed Swords", "Staves", "Fist Weapons", "Daggers", "Thrown", "Crossbows" } },
    PALADIN = { armor = { Cloth = 1, Leather = 1, Mail = 1, ["Plate Mail"] = 40, Shield = 1 },
        weapons = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Polearms", "Swords", "Two-Handed Swords" } },
    HUNTER = { armor = { Cloth = 1, Leather = 1, Mail = 40 },
        weapons = { "Axes", "Two-Handed Axes", "Bows", "Guns", "Polearms", "Swords", "Two-Handed Swords", "Staves", "Fist Weapons", "Daggers", "Thrown", "Crossbows" } },
    SHAMAN = { armor = { Cloth = 1, Leather = 1, Mail = 40, Shield = 1 },
        weapons = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Staves", "Fist Weapons", "Daggers" } },
    ROGUE = { armor = ALL_CLOTH_LEATHER,
        weapons = { "Bows", "Guns", "Maces", "Swords", "Fist Weapons", "Daggers", "Thrown", "Crossbows" } },
    DRUID = { armor = ALL_CLOTH_LEATHER,
        weapons = { "Maces", "Two-Handed Maces", "Polearms", "Staves", "Fist Weapons", "Daggers" } },
    PRIEST = { armor = { Cloth = 1 }, weapons = { "Maces", "Staves", "Daggers", "Wands" } },
    MAGE = { armor = { Cloth = 1 }, weapons = { "Swords", "Staves", "Daggers", "Wands" } },
    WARLOCK = { armor = { Cloth = 1 }, weapons = { "Swords", "Staves", "Daggers", "Wands" } },
}

-- the stats a class lives on: an item with only the other kind is not for it
Data.CASTER = { MAGE = true, PRIEST = true, WARLOCK = true }
Data.PHYSICAL = { WARRIOR = true, ROGUE = true, HUNTER = true }

------------------------------------------------------------------------
-- Equipment slots
------------------------------------------------------------------------
-- an item's equip location -> the inventory slots it can go in (compared against the weaker one)
Data.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
Data.EQUIPMENT_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
-- the level a class learns to fight with a weapon in each hand (classic trainers); the client's own answer
-- (CanDualWield, read at each login) wins over it
Data.DUAL_WIELD = { WARRIOR = 20, ROGUE = 10, HUNTER = 20 }

-- the Enchanting skill a disenchant needs, by the item's level (classic): shown, never a reason to keep
function Data.DisenchantSkill(itemLevel)
    itemLevel = tonumber(itemLevel) or 0
    if itemLevel <= 20 then return 1 end
    if itemLevel <= 60 then return math.floor((itemLevel - 21) / 5 + 1) * 25 end
    return 225 + math.min(75, math.floor((itemLevel - 61) / 5) * 25)
end
