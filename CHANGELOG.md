# AKForeverAltMailer

## 0.1.1

- **Recipes go to their profession's alt.** A tailoring pattern goes to your tailor, an alchemy recipe to
  your alchemist, plans to your blacksmith - the same alt that gets the profession's materials (your pick in the
  Receivers list wins). A recipe for a profession nobody has, or a book, still goes to the banker.
  `/aam set recipes off` leaves recipes to the banker as before.
- **Vendor goods stay.** Thread, dye, vials, flux, spices - the trade goods a vendor sells for money in any
  number - are no longer mailed to the profession's alt or to the banker: every alt buys its own, for less than
  the postage. The old world's trade-vendor goods are known by heart; anything else is learned, for the whole
  account, from the vendors' windows you open (not what a vendor has in limited supply, sells for tokens, or
  will not sell you). `/aam set vendorGoods off` mails them as before. `/aam diag` lists what was learned.

## 0.1.0

- **First build.** At any mailbox, a panel beside the mail window shows what in your bags goes to which of your
  characters, and why: profession materials to the alt highest in that profession (herbs to the alchemist,
  cloth to the tailor, ore to the blacksmith, leather to the leatherworker, dust to the enchanter, meat to the
  cook, parts to the engineer), gear that binds when worn to the alt it is the biggest upgrade for or else to
  the enchanter (never kept back for the character at the mailbox), class supplies - the enchanters' oils
  among them - to you when you are of their class or else to your highest alt of it, and tradeable valuables
  no rule takes to the banker you pick. One button sends it all, in mails of twelve with the goods in the
  subject; whether the client lets the mails after the first go out on their own is measured on the first
  run, and a client that wants a click per mail gets a "Send next" button. Each character writes itself down
  when you log in on it. Receivers are automatic by skill, and yours to pick in the Receivers list; a
  right-click on an item keeps it for good. The panel docks beside the mail window and closes with it.
  `/aam plan`, `/aam banker`, `/aam set`, `/aam diag`.
