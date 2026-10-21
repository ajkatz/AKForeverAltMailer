-- Plan: everything in your bags, judged stack by stack, gathered per receiver and cut into mails of twelve.
-- Built fresh whenever it is asked for - when the mailbox opens, when your bags change, after every mail sent -
-- so it never works from a bag slot that has moved.
local _, ns = ...

local Plan = {}
ns.Plan = Plan

Plan.ATTACHMENTS = 12   -- per mail (Blizzard_MailFrame: ATTACHMENTS_MAX_SEND)
Plan.POSTAGE = 30       -- copper per attachment
Plan.BAGS = { 0, 1, 2, 3, 4, 5 } -- the backpack, four bags, the reagent bag (a bag that is not there has no slots)

local function container()
    return type(C_Container) == "table" and C_Container or nil
end

-- every stack in your bags: { bag, slot, itemID, count, link, quality, isBound, isLocked, name, icon }
function Plan.Stacks()
    local api = container()
    local stacks = {}
    if not api then
        return stacks
    end
    for _, bag in ipairs(Plan.BAGS) do
        local slots = ns.Read(api.GetContainerNumSlots, bag)
        for slot = 1, (type(slots) == "number" and slots or 0) do
            local info = ns.Read(api.GetContainerItemInfo, bag, slot)
            if type(info) == "table" and type(info.itemID) == "number" then
                stacks[#stacks + 1] = {
                    bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
                    link = info.hyperlink, quality = info.quality, isBound = info.isBound, isLocked = info.isLocked,
                    name = info.itemName, icon = info.iconFileID,
                }
            end
        end
    end
    return stacks
end

local function subjectFor(mail)
    local words, seen = {}, {}
    for _, stack in ipairs(mail.stacks) do
        local word
        if stack.verdict.category == "materials" then
            word = ns.Data.GOODS[stack.verdict.detail] or "materials"
        elseif stack.verdict.category == "gear" then
            word = stack.verdict.detail == "wear" and "gear for you" or "gear to disenchant"
        elseif stack.verdict.category == "valuables" then
            word = "valuables"
        else
            word = "class supplies"
        end
        if not seen[word] then
            seen[word] = true
            words[#words + 1] = word
        end
    end
    return "AltMailer: " .. table.concat(words, ", ")
end

-- the plan: { receivers = { {entry, stacks, mails = { {stacks, subject} }} ... }, kept = { [reason] = count }, keptStacks,
-- mails = total, attachments = total, postage = copper }
function Plan.Build()
    local plan = { receivers = {}, kept = {}, keptStacks = {}, mails = 0, attachments = 0, postage = 0, judged = 0 }
    local byKey = {}
    for _, stack in ipairs(Plan.Stacks()) do
        local facts = ns.Classify.Facts(stack.link, stack.itemID)
        stack.facts = facts
        stack.name = stack.name or facts.name
        stack.icon = stack.icon or facts.icon
        local verdict = ns.Classify.Verdict(stack, facts)
        stack.verdict = verdict
        plan.judged = plan.judged + 1
        if verdict.action == "send" then
            local group = byKey[verdict.receiver]
            if not group then
                group = { entry = ns.Roster:Get(verdict.receiver), stacks = {}, mails = {} }
                byKey[verdict.receiver] = group
                plan.receivers[#plan.receivers + 1] = group
            end
            group.stacks[#group.stacks + 1] = stack
        else
            if verdict.reason then
                plan.kept[verdict.reason] = (plan.kept[verdict.reason] or 0) + 1
            end
            plan.keptStacks[#plan.keptStacks + 1] = stack
        end
    end
    table.sort(plan.receivers, function(a, b) return ns.Roster.Label(a.entry) < ns.Roster.Label(b.entry) end)
    for _, group in ipairs(plan.receivers) do
        -- gear, then materials of one profession together, then supplies, then valuables; within that by name
        table.sort(group.stacks, function(a, b)
            local ca, cb = a.verdict.category .. (a.verdict.detail or ""), b.verdict.category .. (b.verdict.detail or "")
            if ca ~= cb then return ca < cb end
            return (a.name or "") < (b.name or "")
        end)
        local mail
        for _, stack in ipairs(group.stacks) do
            if not mail or #mail.stacks >= Plan.ATTACHMENTS then
                mail = { stacks = {}, receiver = group.entry }
                group.mails[#group.mails + 1] = mail
            end
            mail.stacks[#mail.stacks + 1] = stack
        end
        for _, m in ipairs(group.mails) do
            m.subject = subjectFor(m)
            plan.mails = plan.mails + 1
            plan.attachments = plan.attachments + #m.stacks
        end
    end
    plan.postage = plan.attachments * Plan.POSTAGE
    plan.builtAt = date and date("%H:%M:%S") or nil
    Plan.last = plan
    if plan.judged > 0 then
        Plan.lastFull = plan -- logging out, the bags read empty: the report takes this one then
    end
    return plan
end

-- the first mail of a plan, or nil
function Plan.FirstMail(plan)
    local group = plan and plan.receivers[1]
    return group and group.mails[1] or nil
end

ns:RegisterCommand("plan", "what would be mailed from here, and to whom (works away from a mailbox too)", function()
    local plan = Plan.Build()
    if #plan.receivers == 0 then
        ns:Print("nothing to mail from this character." .. (next(plan.kept) and "" or " (Log in on your alts once so the addon knows them.)"))
    else
        ns:Print(plan.mails .. " mail(s), " .. plan.attachments .. " item(s), postage " .. ns.FormatMoney(plan.postage) .. ":")
        for _, group in ipairs(plan.receivers) do
            local names = {}
            for _, stack in ipairs(group.stacks) do
                names[#names + 1] = (stack.name or ("item " .. stack.itemID)) .. (stack.count > 1 and (" x" .. stack.count) or "")
            end
            print("   |cffffd100" .. ns.Roster.Label(group.entry) .. "|r: " .. table.concat(names, ", "))
        end
    end
    local reasons = {}
    for reason, count in pairs(plan.kept) do
        reasons[#reasons + 1] = count .. " " .. reason
    end
    table.sort(reasons)
    if #reasons > 0 then
        print("   |cff999999kept: " .. table.concat(reasons, "; ") .. "|r")
    end
end)
