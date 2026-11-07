-- Vendors: trade goods a vendor sells stay where they are (the user, 2026-10-21: "stuff that is bought from a
-- trade vendor doesn't typically need to be mailed like thread"). Every alt buys its own at its own vendor - a
-- Coarse Thread costs 10 copper there, its mail 30.
--
-- Known two ways: the old world's trade-vendor goods by heart (Data.VENDOR_GOODS: threads, dyes, bleach, salt,
-- flux, vials, rods and wood, gun stocks, spices), and whatever a vendor's window shows you - each trade good it
-- sells for money, in any number, to you, is learned for the whole account when the window opens or changes.
-- What a vendor has in limited supply, sells for tokens or another currency, or will not sell you (a reputation
-- short) is not learned: not every alt can buy it. In a fight the window is left unread; the next one reads it.
--
-- Forever keeps some of a vendor's answers secret (measured 2026-10-04 in AKForeverBeastTraining: an item's name
-- is a secret value, its id is not), so each answer is checked before it is looked at, and a line that keeps a
-- needed one secret is skipped and counted for the report.
local _, ns = ...

local Vendors = {}
ns.Vendors = Vendors

local CLASS_TRADEGOODS = 7
-- what a line must answer to be learned; a secret price is no obstacle (the rest already say it costs money)
local NEEDED = { "numAvailable", "hasExtendedCost", "currencyID" }

Vendors.reads = 0
Vendors.secretFields = {} -- [field] = lines that kept it secret

-- is an item a vendor's good: known by heart, or seen sold for money in any number
function Vendors:Sells(itemID)
    local learned = ns.db and ns.db.vendorItems
    return (ns.Data.VENDOR_GOODS[itemID] or (learned and learned[itemID])) and true or false
end

-- the open vendor's line `index`: its item id when it is a trade good sold for money, in any number, to you;
-- else nil, and true when a secret answer was in the way
local function tradeGood(index)
    local itemID = ns.Read(GetMerchantItemID, index)
    local api = type(C_MerchantFrame) == "table" and C_MerchantFrame or nil
    local info = api and ns.Read(api.GetItemInfo, index)
    if type(itemID) ~= "number" or type(info) ~= "table" then
        return nil
    end
    local secret = false
    for _, field in ipairs(NEEDED) do
        if ns.IsSecret(info[field]) then
            Vendors.secretFields[field] = (Vendors.secretFields[field] or 0) + 1
            secret = true
        end
    end
    if secret then
        return nil, true
    end
    local price = info.price
    if ns.IsSecret(price) then
        price = nil
    end
    local purchasable = info.isPurchasable
    if ns.IsSecret(purchasable) then
        purchasable = nil
    end
    local forMoney = not info.hasExtendedCost and info.currencyID == nil and (price == nil or (type(price) == "number" and price > 0))
    local unlimited = type(info.numAvailable) == "number" and info.numAvailable < 0 -- the client's -1; a count is a limited supply
    if not forMoney or not unlimited or purchasable == false then
        return nil
    end
    local instant = type(C_Item) == "table" and ns.Readable(C_Item.GetItemInfoInstant, itemID)
    if not instant or instant[6] ~= CLASS_TRADEGOODS then
        return nil
    end
    return itemID
end

-- read the open vendor's window: the trade goods it sells without end are learned; how many were new
function Vendors:Read(source)
    if ns.inCombat or not ns.db then
        return 0
    end
    local lines = ns.Read(GetMerchantNumItems)
    if type(lines) ~= "number" then
        return 0
    end
    local learned, secret = {}, 0
    for index = 1, lines do
        local itemID, hidden = tradeGood(index)
        if hidden then
            secret = secret + 1
        elseif itemID and not self:Sells(itemID) then
            ns.db.vendorItems[itemID] = true
            learned[#learned + 1] = itemID
        end
    end
    self.reads = self.reads + 1
    self.lastRead = { source = source, lines = lines, learned = #learned, secret = secret, at = date and date("%H:%M:%S") or nil }
    if #learned > 0 then
        ns:Log("vendor_learned", { source = source, items = learned })
    end
    return #learned
end

-- for the report
function Vendors:Describe()
    local learned = {}
    for itemID in pairs(ns.db.vendorItems or {}) do
        learned[#learned + 1] = itemID
    end
    table.sort(learned)
    local byHeart = 0
    for _ in pairs(ns.Data.VENDOR_GOODS) do
        byHeart = byHeart + 1
    end
    return { byHeart = byHeart, learned = learned, reads = self.reads, lastRead = self.lastRead, secretFields = self.secretFields }
end

for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
    ns:On(event, function()
        Vendors:Read(event)
    end)
end
