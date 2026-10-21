-- Mailer: sends the plan, one mail at a time, at an open mailbox.
--
-- A mail: the cursor emptied; each stack picked up from its bag slot (C_Container.PickupContainerItem) and put
-- on the next attachment (ClickSendMailItemButton, as Blizzard's own attachment buttons do), each one checked
-- (HasSendMailItem); then SendMail(the alt's name, a subject, no text). The client answers MAIL_SEND_SUCCESS or
-- MAIL_FAILED (the reason comes as UI_ERROR_MESSAGE just before); only one mail command is in flight at a time
-- (C_Mail.IsCommandPending). After each success the plan is built afresh from the bags, so nothing is sent from
-- a slot that moved.
--
-- ONE CLICK OR ONE PER MAIL? The send button is a click; whether the client lets the mails after the first one
-- go out on their own - from the success event, with no click - is not documented, so it is MEASURED: the first
-- time, the second mail is tried on its own. If the client blocks it (ADDON_ACTION_BLOCKED naming a mail
-- function), the attachments stay where they are, the button becomes "Send next", and every click sends one
-- mail from then on. If it goes through, every later run sends everything from one click. What was learned is
-- kept (AKForeverAltMailerDB.sending.mode) and shown in /aam diag.
--
-- THE ADDRESS is the alt's name as the client gave it on that alt (GetUnitName("player", true): "Purr Gola" on
-- Forever, first name and surname). Each name the client accepted is noted; a refused one stops the run with
-- the client's own words.
local _, ns = ...

local Mailer = {}
ns.Mailer = Mailer

local TIMEOUT = 10        -- seconds the mailbox has to answer a mail
local NEXT_DELAY = 0.7    -- between a success and the next mail

Mailer.open = false       -- a mailbox is open
Mailer.session = nil      -- the run: { total, sent, failed, started, waiting = "click" | nil, done }
Mailer.pending = nil      -- the mail on its way: { address, subject, count, at, how, blocked }
Mailer.lastError = nil
Mailer.stats = { mails = 0, items = 0, failures = 0, blocks = 0, timeouts = 0, attachFailures = 0 }

local function learned()
    ns.db.sending = ns.db.sending or {}
    return ns.db.sending
end

-- "chain": one click sends everything; "click": one click per mail; nil: not measured yet
function Mailer:Mode()
    return learned().mode
end

local function changed()
    ns:Fire("MAILER_CHANGED")
end

local function attached(index)
    local has = ns.Read(HasSendMailItem, index)
    return has and true or false
end

-- whatever sits on the send frame goes back to the bags
function Mailer:ClearAttachments()
    for index = 1, ns.Plan.ATTACHMENTS do
        if attached(index) then
            pcall(ClickSendMailItemButton, index, true)
        end
    end
    pcall(ClearCursor)
end

function Mailer:CountAttached()
    local n = 0
    for index = 1, ns.Plan.ATTACHMENTS do
        if attached(index) then
            n = n + 1
        end
    end
    return n
end

-- the run is over: everything that could go went
local function finish(session)
    session.done = true
    session.waiting = nil
    ns:Print("all mailed: " .. session.sent .. " mail(s)" .. (session.failed > 0 and (", " .. session.failed .. " failed") or "") .. ".")
    ns:Log("send_done", { sent = session.sent, failed = session.failed })
    ns:Fire("MAILER_CHANGED")
end

local function stop(message, keepSession)
    if message then
        ns:Print(message)
    end
    if Mailer.session and not keepSession then
        Mailer.session.done = true
        Mailer.session.waiting = nil
    end
    changed()
end

-- the button: start a run, or send the next mail of one that waits for a click
function Mailer:Click()
    if not self.open then
        ns:Print("open a mailbox first.")
        return false
    end
    if self.pending and not self.pending.blocked then
        return false -- a mail is on its way
    end
    if not self.session or self.session.done then
        local plan = ns.Plan.Build()
        if plan.mails == 0 then
            ns:Print("nothing to mail from this character.")
            return false
        end
        self.session = { total = plan.mails, sent = 0, failed = 0, started = GetTime() }
        ns:Log("send_start", { mails = plan.mails, attachments = plan.attachments, mode = self:Mode() or "not measured" })
    end
    self.session.waiting = nil
    return self:SendNext("click")
end

-- one mail: attach the first mail of a fresh plan and send it
function Mailer:SendNext(how)
    if not self.open or not self.session or self.session.done then
        return false
    end
    -- a mail the client blocked earlier: its attachments are still on the send frame - send it as it stands
    local blocked = self.pending and self.pending.blocked
    if blocked then
        if self:CountAttached() > 0 then
            return self:Post(self.pending.address, self.pending.subject, self.pending.count, how, self.pending.receiver)
        end
        self.pending = nil
    end
    local plan = ns.Plan.Build()
    local mail = ns.Plan.FirstMail(plan)
    if not mail then
        finish(self.session)
        return false
    end
    if self.session.sent + 1 > self.session.total then
        self.session.total = self.session.sent + plan.mails -- the bags gave more than counted at the start
    end
    local postage = #mail.stacks * ns.Plan.POSTAGE
    local money = ns.Read(GetMoney)
    if type(money) == "number" and money < postage then
        stop("not enough money for the postage (" .. ns.FormatMoney(postage) .. ").")
        return false
    end
    if self:CountAttached() > 0 then
        stop("the send window already holds items: send or clear them, then click again.")
        return false
    end
    pcall(ClearCursor)
    local api = C_Container
    for index, stack in ipairs(mail.stacks) do
        local okPick = pcall(api.PickupContainerItem, stack.bag, stack.slot)
        local okClick = okPick and pcall(ClickSendMailItemButton, index)
        if not okClick or not attached(index) then
            self.stats.attachFailures = self.stats.attachFailures + 1
            ns:Log("attach_failed", { item = stack.itemID, index = index, how = how })
            self:ClearAttachments()
            stop("could not attach " .. (stack.name or ("item " .. stack.itemID)) .. ": nothing was sent.")
            return false
        end
    end
    pcall(ClearCursor)
    return self:Post(mail.receiver.address, mail.subject, #mail.stacks, how, mail.receiver.key)
end

function Mailer:Post(address, subject, count, how, receiverKey)
    self.pending = { address = address, subject = subject, count = count, at = GetTime(), how = how, receiver = receiverKey }
    self.lastError = nil
    local token = {}
    self.pending.token = token
    local ok, err = pcall(SendMail, address, subject, "")
    if not ok then
        ns:Log("send_error", { error = tostring(err) })
    end
    if self.pending and self.pending.token == token and not self.pending.blocked then
        ns:Log("mail_sent_off", { to = address, items = count, how = how })
        C_Timer.After(TIMEOUT, function()
            ns.SafeCall(Mailer.CheckTimeout, Mailer, token)
        end)
    end
    changed()
    return true
end

function Mailer:CheckTimeout(token)
    local pending = self.pending
    if not pending or pending.token ~= token or pending.blocked then
        return
    end
    self.stats.timeouts = self.stats.timeouts + 1
    self.pending = nil
    ns:Log("send_timeout", { to = pending.address })
    stop("the mailbox did not answer for " .. TIMEOUT .. " seconds: stopped. Click to try again.")
end

------------------------------------------------------------------------
-- What the client says
------------------------------------------------------------------------
-- THE MAILBOX OPENING AND CLOSING. Forever's mail window comes and goes through Blizzard's interaction manager
-- (PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE with the type MailInfo); MAIL_SHOW and MAIL_CLOSED are
-- documented too, and the window's X or Escape calls CloseMail(). MAIL_CLOSED alone left the panel standing after
-- the mail window had closed (the user, 2026-10-20), so every one of them counts - once a visit - and the panel
-- also closes when it sees the mail window gone (Panel.lua). Each signal is counted for /aam diag.
local MAIL_INTERACTION = (type(Enum) == "table" and type(Enum.PlayerInteractionType) == "table" and Enum.PlayerInteractionType.MailInfo) or 17
Mailer.signals = {}

local function signal(name)
    Mailer.signals[name] = (Mailer.signals[name] or 0) + 1
end

function Mailer:Opened(source)
    signal(source)
    if self.open then
        return
    end
    self.open = true
    self.session = nil
    self.pending = nil
    ns:Log("mailbox_opened", source)
    ns:Fire("MAILBOX_OPENED")
    changed()
end

function Mailer:Closed(source)
    signal(source)
    if not self.open then
        return
    end
    self.open = false
    if self.session and not self.session.done then
        ns:Log("send_interrupted", { sent = self.session.sent, total = self.session.total })
    end
    self.session = nil
    self.pending = nil
    ns:Log("mailbox_closed", source)
    ns:Fire("MAILBOX_CLOSED")
    changed()
end

ns:On("MAIL_SHOW", function()
    Mailer:Opened("MAIL_SHOW")
end)

ns:On("MAIL_CLOSED", function()
    Mailer:Closed("MAIL_CLOSED")
end)

ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
    if kind == MAIL_INTERACTION then
        Mailer:Opened("interaction shown")
    end
end)

ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
    if kind == MAIL_INTERACTION then
        Mailer:Closed("interaction hidden")
    end
end)

ns:On("UI_ERROR_MESSAGE", function(_, _, message)
    if Mailer.pending and not ns.IsSecret(message) and type(message) == "string" then
        Mailer.lastError = message
    end
end)

ns:On("MAIL_SEND_SUCCESS", function()
    local pending = Mailer.pending
    if not pending then
        return
    end
    Mailer.pending = nil
    Mailer.stats.mails = Mailer.stats.mails + 1
    Mailer.stats.items = Mailer.stats.items + (pending.count or 0)
    local store = learned()
    store.addresses = store.addresses or {}
    store.addresses[pending.address] = true -- a name the client accepted
    if pending.how == "chain" and store.mode ~= "chain" then
        store.mode, store.measuredAt = "chain", time and time() or 0 -- a mail went out with no click of its own
        ns:Log("mode_measured", "chain")
    end
    local session = Mailer.session
    if session then
        session.sent = session.sent + 1
    end
    ns:Log("mail_delivered", { to = pending.address, items = pending.count, how = pending.how })
    changed()
    if not session or session.done then
        return
    end
    if ns.Plan.Build().mails == 0 then
        finish(session) -- that was the last one: no "Send next" for nothing
        return
    end
    if Mailer:Mode() == "click" then
        session.waiting = "click"
        changed()
        return
    end
    C_Timer.After(NEXT_DELAY, function()
        ns.SafeCall(function()
            if type(C_Mail) == "table" and C_Mail.IsCommandPending and ns.Read(C_Mail.IsCommandPending) then
                C_Timer.After(NEXT_DELAY, function() ns.SafeCall(Mailer.SendNext, Mailer, "chain") end)
                return
            end
            Mailer:SendNext("chain")
        end)
    end)
end)

ns:On("MAIL_FAILED", function()
    local pending = Mailer.pending
    if not pending then
        return
    end
    Mailer.pending = nil
    Mailer.stats.failures = Mailer.stats.failures + 1
    if Mailer.session then
        Mailer.session.failed = Mailer.session.failed + 1
    end
    local reason = Mailer.lastError or "the mailbox refused it"
    learned().lastError = { to = pending.address, reason = reason, at = time and time() or 0 }
    ns:Log("mail_failed", { to = pending.address, reason = reason })
    Mailer:ClearAttachments()
    stop("the mail to " .. tostring(pending.address) .. " failed: " .. reason .. ". Stopped.")
end)

-- a mail function refused without a click: from now on, one click per mail
ns:Listen("BLOCKED", function(record)
    local func = record.func or ""
    if not (string.find(func, "SendMail", 1, true) or string.find(func, "ClickSendMailItemButton", 1, true) or string.find(func, "PickupContainerItem", 1, true)) then
        return
    end
    Mailer.stats.blocks = Mailer.stats.blocks + 1
    local store = learned()
    if store.mode ~= "click" then
        store.mode, store.measuredAt, store.blockedBy = "click", time and time() or 0, func
        ns:Log("mode_measured", { mode = "click", by = func })
        ns:Print("this client wants a click for every mail: the button now sends one mail per click.")
    end
    if Mailer.pending then
        Mailer.pending.blocked = true
    end
    if Mailer.session and not Mailer.session.done then
        Mailer.session.waiting = "click"
    end
    changed()
end)

function Mailer:Describe()
    return {
        open = self.open, mode = self:Mode() or "not measured", stats = self.stats, lastError = self.lastError, signals = self.signals,
        session = self.session and { total = self.session.total, sent = self.session.sent, failed = self.session.failed, waiting = self.session.waiting, done = self.session.done } or nil,
        learned = learned(),
    }
end

ns:RegisterCommand("send", "at a mailbox: send the next mail (the panel's button does the same)", function()
    Mailer:Click()
end)
