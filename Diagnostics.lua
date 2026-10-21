-- Diagnostics: '/aam diag' writes a report into the saved file - your characters as the addon knows them, what
-- the client answered for professions and the skill window, every stack in your bags with the class, subclass,
-- bind type and quality the client gives and the verdict on it (how materials are recognised on this client is
-- read from here), what was learned about sending, the mailbox's answers, every error and blocked action. Each
-- value is checked before it is copied, so that a secret cannot poison the file. The same report is written at
-- logout. Logging out to the character list, the client read the bags as empty (2026-10-20: 0 stacks judged on two
-- characters; a /reload read all 45), so a report that finds them empty takes the last plan that read them, and
-- says when that was.
local _, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics

local function sanitize(value, depth)
    depth = depth or 0
    if ns.IsSecret(value) then
        return "<secret>"
    end
    local kind = type(value)
    if kind == "table" then
        if depth > 6 then
            return "<deep>"
        end
        local out = {}
        for k, v in pairs(value) do
            if not ns.IsSecret(k) and type(v) ~= "function" and type(v) ~= "userdata" and k ~= "facts" and k ~= "entry" then
                out[k] = sanitize(v, depth + 1)
            end
        end
        return out
    elseif kind == "function" or kind == "userdata" or kind == "thread" then
        return "<" .. kind .. ">"
    end
    return value
end

function Diagnostics:Collect()
    local before = ns.Plan.lastFull
    local plan = ns.Plan.Build()
    local planFrom = "now"
    if plan.judged == 0 and before and before.judged > 0 then
        plan, planFrom = before, "the last time the bags read (" .. tostring(before.builtAt) .. ")"
    end
    local bags = {}
    for _, group in ipairs(plan.receivers) do
        for _, stack in ipairs(group.stacks) do
            bags[#bags + 1] = { stack = stack, to = ns.Roster.Label(group.entry) }
        end
    end
    for _, stack in ipairs(plan.keptStacks) do
        bags[#bags + 1] = { stack = stack }
    end
    local items = {}
    for _, item in ipairs(bags) do
        local s, f, v = item.stack, item.stack.facts or {}, item.stack.verdict or {}
        items[#items + 1] = {
            item = s.itemID, name = s.name, count = s.count, bag = s.bag, slot = s.slot,
            class = f.classID, subclass = f.subclassID, bind = f.bindType, quality = s.quality or f.quality,
            itemLevel = f.itemLevel, minLevel = f.minLevel, equipLoc = f.equipLoc, bound = s.isBound, reagent = f.isCraftingReagent,
            verdict = v.action, to = item.to, category = v.category, reason = v.reason,
        }
    end
    local errors = 0
    for _ in pairs(ns.errors) do
        errors = errors + 1
    end
    return {
        version = ns.version,
        when = date and date("%Y-%m-%d %H:%M:%S") or nil,
        character = ns.characterKey,
        savedState = ns.savedStateSource,
        readings = sanitize(ns.Roster.readings),
        characters = sanitize(ns.db.characters),
        receivers = (function()
            local out = {}
            for _, profession in ipairs(ns.Data.PROFESSIONS) do
                if ns.Data.GOODS[profession] then
                    local entry, why = ns.Roster:ReceiverFor(profession)
                    out[profession] = { to = entry and entry.key or nil, why = why }
                end
            end
            local banker, bankWhy = ns.Roster:Banker()
            out.Banker = { to = banker and banker.key or nil, why = bankWhy }
            return out
        end)(),
        picked = sanitize(ns.db.receivers),
        keep = sanitize(ns.db.keep),
        plan = { mails = plan.mails, attachments = plan.attachments, postage = plan.postage, judged = plan.judged, kept = sanitize(plan.kept), from = planFrom },
        items = sanitize(items),
        sending = sanitize(ns.Mailer:Describe()),
        options = sanitize(ns.db.options),
        errors = sanitize(ns.errors),
        errorCount = errors,
        blocked = sanitize(ns.blocked),
        unknownEvents = sanitize(ns.unknownEvents),
        log = sanitize(ns.sessionLog),
    }
end

function Diagnostics:Save()
    ns.db.diag = self:Collect()
    return ns.db.diag
end

ns:RegisterCommand("diag", "write a report into the saved file (it is written at logout too) - then /reload", function()
    local report = Diagnostics:Save()
    ns:Print("report written: " .. #report.items .. " stacks judged, " .. report.plan.mails .. " mail(s) planned, sending: "
        .. tostring(report.sending.mode) .. ", " .. report.errorCount .. " error(s). /reload to put it in the file.")
end)

ns:On("PLAYER_LOGOUT", function()
    if ns.db then
        ns.SafeCall(Diagnostics.Save, Diagnostics)
    end
end)
