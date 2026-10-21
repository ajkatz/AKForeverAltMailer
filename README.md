# AKForeverAltMailer

Your alts get what they use. Open any mailbox and the addon lays out what in your bags belongs with which of
your characters - herbs to your alchemist, cloth to your tailor, BoE gear to the alt it is an upgrade for or
to your enchanter, class supplies to that class, tradeable valuables to your banker - and one button mails it.
For WoW: Forever.

## Who gets what

Each character writes itself down when you log in on it: class, level, faction, its professions with their
skill, the armor and weapons it has learned, the item level it wears in each slot. Log in on each alt once,
and again after it levels a profession, and the addon knows your account.

| What | Goes to |
|---|---|
| Herbs | your highest Alchemy |
| Cloth | your highest Tailoring |
| Ore, bars and stone | your highest Blacksmithing |
| Leather and hides | your highest Leatherworking |
| Dust, essences and shards | your highest Enchanting |
| Meat and fish | your highest Cooking |
| Engineering parts | your highest Engineering |
| Gear that binds when worn, green or better | the alt it is the biggest upgrade for; else your enchanter, to disenchant |
| Class supplies: candles, powders, runes, symbols, ankhs, soul shards, the enchanters' wizard and mana oils, arrows and bullets | you, when you are of their class; else your highest alt of those classes |
| Tradeable valuables no rule above takes | your banker |

- **Highest skill, this realm and faction.** Mail goes neither across realms nor across factions. You count
  too: when you are the alchemist, the herbs stay with you.
- **A material is known by the addon's own table** of the old world's herbs, cloth, ore, leather, enchanting
  materials and cooking ingredients, else by its trade-goods type - when a recipe uses it. Forever files the
  enchanters' oils as Enchanting trade goods; here they are class supplies, never the enchanter's material.
- **Gear goes to a wearer** among your other characters that can use the armor or weapon type (its own skill
  window, else its class), is at most three levels under the item's required level, suits the item's stats
  (intellect and spirit are not for a warrior, strength and agility not for a mage), and wears less in that
  slot. A one-hand weapon counts the off hand only for a character that can dual wield, and a two-hander holds
  the off hand. Nobody: the enchanter, with a note when its skill is short of disenchanting it. The character
  at the mailbox never keeps a piece "for itself": it holds the piece, and puts it on if it wants it.
- **The banker** is only ever the one you pick: `/aam banker <name>`, or in the Receivers list. It gets what is
  tradeable and worth something - green or better, a recipe, or a stack that sells for a gold at a vendor -
  when no other rule takes it, or a rule found nobody for it (engineering parts with no engineer). What a
  character uses up never goes to the banker: potions, food, scrolls, reagents, arrows and bullets stay.
- **What always stays:** the hearthstone, soulbound things, anything locked, quest items, keys, greys (for the
  vendor), and your keep list - a right-click on an item on the panel keeps it for good; `/aam unkeep` frees it.

The **Receivers** button lists who takes what. A click on a profession picks the next alt; a right-click goes
back to automatic. A click on the banker picks the next character; a right-click stops the banker.

## Sending

The panel docks beside the mail window when a mailbox opens and closes with it - on the client's events, or
when it sees the mail window gone; its X sends it away until the next mailbox. Each alt's goods come in mails of up to twelve items, thirty copper an item, each subject naming
the goods ("AltMailer: herbs, cloth"). The button says how many mails and what the postage is; after every
mail the plan is built afresh from your bags, so nothing is sent from a slot that moved.

**One click, or one per mail?** The first mail is your click. Whether the client lets the next ones go out on
their own is not documented, so the addon measures it on the first run: the second mail is tried on its own.
If the client blocks it, the addon says so, keeps the attachments where they are, and the button becomes
"Send next" - one click per mail from then on. If it goes through, one click sends everything. What it learned
is kept, and shown in `/aam diag`. On Forever one click sends everything (measured 2026-10-20).

A mail the mailbox refuses stops the run with the client's own words, and its items go back to your bags. Too
little money for the postage, or items already on the send window, stop it too.

## Commands

`/aam` (or `/altmail`) lists them.

- `/aam plan` - what would be mailed from here, and to whom (anywhere, no mailbox needed)
- `/aam send` - at a mailbox: the panel's button
- `/aam show` - the panel back after its X
- `/aam receivers` - who takes what
- `/aam banker <name>` - pick your banker; `/aam banker none` stops it
- `/aam alts` - your characters as the addon knows them; `/aam forget <name>` drops one
- `/aam unkeep` - your keep list; `/aam unkeep <item id>`, `/aam unkeep all`
- `/aam set` - the options: materials, gear and supplies on or off, the least quality of gear mailed, the
  level slack, the banker's quality and money lines, docking; `/aam set <name> <value>`, `/aam set <name> default`
- `/aam diag` - a report into the saved file

## Files

```
Core.lua         namespace, events, saved variables (one account table, a profile per character), commands, options
Data.lua         professions and their goods, the materials and class supplies tables, armor and weapon skills
Roster.lua       each character as it logs in; the receivers per profession; the banker
Classify.lua     where one stack goes, and why - or why it stays
Plan.lua         the bags judged, gathered per receiver, cut into mails of twelve
Mailer.lua       the sending, one mail at a time, and the measuring of one click or one per mail
Panel.lua        the preview beside the mail window, and the Receivers list
Diagnostics.lua  /aam diag
```

## What is proven, and what is not

Proven in game on 2026-10-20: the roster (professions from the professions book, the skill window's armor and
weapon lines, the gear worn); the panel at a mailbox; one click sent two mails, the second on its own; the
mailbox took the Forever names ("Purr Gola") as addresses. Logging out to the character list, the client reads
the bags as empty (a /reload reads them), so a report that finds them empty keeps the last plan that read them.
Still to measure, reported in `/aam diag`: which signal of the mailbox closing this client sends (MAIL_CLOSED,
the interaction manager's, or only the mail window hiding); whether the client's isCraftingReagent holds for
the old world's materials; the client's answer to CanDualWield.

Taking mail from your alts when you open a mailbox on the receiving alt is planned for a later version.

MIT, by Purrdee.
