# What the competitors do, and what we changed because of it

Round 12b asked for UI/UX decisions backed by data from shipped games and from
published interaction research, not by preference. This file is the ledger: each
finding names where it came from, then what it changed here — or why it changed
nothing.

Frames referenced below live in `qa-evidence/ui/round-12/i18n/engine/` (the
in-engine HUD, pause, settings and dashboard in both languages) and in
`qa-evidence/ui/round-12/i18n/` (the HTML shell in both languages).

## The sources

| Source | What it is | Used for |
| --- | --- | --- |
| [Call of Duty: Mobile — Boot Camp Part 1](https://blog.activision.com/call-of-duty/2019-09/Call-of-Duty-Mobile-Boot-Camp-Part-1-Getting-Started-in-the-Game) and [Part 2](https://blog.activision.com/call-of-duty/2019-10/Call-of-Duty-Mobile-Boot-Camp-Part-2) | Activision's own description of the shipped lobby | Where a mobile shooter puts its primary navigation, and what its loadout page contains |
| [CoD Mobile controls guide](https://blog.activision.com/call-of-duty/2019-10/Getting-a-Grip-on-the-Call-of-Duty-Mobile-Controls) | Activision, in-game control map | What the pause/settings entry point must offer mid-run |
| [GameSpot — how the Gunsmith works](https://www.gamespot.com/articles/call-of-duty-mobile-how-to-use-the-gunsmith/1100-6497253/) | Walkthrough of the shipped weapon flow | Weapon choice as a picture-led modal, not a label |
| [PUBG Mobile Help Center — settings location](https://pubgmobile.helpshift.com/hc/en/3-pubg-mobile/faq/280-i-want-to-change-the-location-of-the-control-key/?l=en) | Official support page | Secondary destinations live behind one overflow, not in the dock |
| [r/CODWarzone UI complaint thread](https://www.reddit.com/r/CODWarzone/comments/101l5j8/list_of_uxui_issues_and_missing_features/) | Players listing shipped UI defects | The two failures players name: too few items visible, and no numbers to compare |
| [Material 3 — navigation bar guidelines](https://m3.material.io/components/navigation-bar/guidelines) | Current Google spec | 3–5 destinations; never drop labels; don't use a bar for a single task; translated text needs room |
| [Material 3 — navigation bar accessibility](https://m3.material.io/components/navigation-bar/accessibility) | Same spec, a11y page | Labels stay legible to 2× text scaling; the bar grows rather than truncates |
| [Apple HIG — tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars) | Apple's spec | Tab bars navigate, not act; never disable or hide a tab; keep labels; avoid overflow |
| [NN/g — touch targets](https://www.nngroup.com/articles/touch-target-size/) | Measured study (Parhi, Karlson & Bederson) | 1 cm × 1 cm floor; thumb impact area is ~2.5 cm |
| [NN/g — mobile navigation patterns](https://www.nngroup.com/articles/mobile-navigation-patterns/) | Primer on nav patterns | Above five options a bar stops holding its touch-target size |
| [CSA Research — Can't Read, Won't Buy, B2C](https://csa-research.com/l/media/Consumers-Prefer-their-Own-Language) | 8,709 consumers, 29 countries, 2020 | Why the language row exists at all |
| [Newzoo 2024 Global Games Market Report](https://best-of-gaming.be/wp-content/uploads/2024/09/2024_Newzoo_Global_Games_Market_Report.pdf) | Market data | 2.848 bn mobile players vs 908 m PC: this is a phone product |

## The findings

1. **A mobile shooter's dock is three to five destinations, and the rest of the
   lobby is not in it.** CoD Mobile's shipped lobby is a bottom row of
   destinations with a single settings glyph; PUBG Mobile keeps its whole
   secondary menu behind one arrow in a corner. Material says 3–5 and so does
   Apple; NN/g adds the mechanical reason — past five, a bar can no longer hold a
   48 dp target.
   → Our dock is **HOME / OPERATIVE / THEATRE plus one gear**: three
   destinations, and settings is a glyph rather than a fourth tab
   (`lobby_chrome.gd`, `TABS`). At 667×375 the three destinations still carry
   words; the label-dropping threshold is 560 physical px, below anything we
   ship (`qa-evidence/ui/round-12/i18n/id-hub-667x375.png`).

2. **Labels are not optional, even when the dock is tight.** Material: "Don't
   remove the labels from navigation items", full label visible up to 2× text
   size, and the bar grows or wraps rather than truncating. Apple: "Include tab
   labels", and "don't disable or hide tab bar buttons".
   → The dock keeps words down to 560 px and only falls back to glyphs below
   that, where a 40 px word tab would break the touch floor. Glyphs are distinct
   (house, shield, target) rather than generic. The three tabs are never disabled:
   an unavailable page says why in its own content, and `common.in_development`
   is the sentence.

3. **The weapon is chosen by picture, in a modal, with numbers beside it.**
   GameSpot's walkthrough of the shipped Gunsmith: weapons are picked from a
   category list where each entry has art, then stats sit on the right, and
   attachments are compared by their numeric effect. The complaint thread is the
   other half of the evidence — players name "only 5 weapons fit on screen" and
   "no detailed descriptions and numerical values" as defects.
   → The rack (`index.html` `#hero-rack`, `armory_ui.gd`) lists each weapon with
   its art, its three numbers (damage, rate, capacity) and its price, and the
   locked entries read `NEED %d MORE BP` rather than showing a dead button. Three
   weapons, because three fit; the count is the content, not the viewport.

4. **One screen, one job; the actions live on the page, not in the bar.** Apple:
   "Use a tab bar to support navigation, not to provide actions"; Material: a nav
   bar "shouldn't be used for accessing single tasks".
   → DEPLOY is a page action on HOME, not a fourth tab; ARMORY is a page action
   on HOME and a chip inside the run. Nothing that *does* something sits in the
   dock; everything in the dock *goes* somewhere.

5. **Mid-run, the pause entry point must carry the loadout too.** Activision's
   control map: the in-game settings glyph offers Settings, Loadout, Exit and
   Resume. A player who wants a different weapon mid-run presses the same button
   as a player who wants the volume.
   → Our pause sheet is RESUME / RESTART / SETTINGS / HOME, and the armory chip
   inside the arena opens the same rack over live play. Every one of those menus
   also has HOME — that is DECISIONS 44, and Apple's "never hide a destination"
   is the same rule from the other direction.

6. **Touch targets are physical, and ours are generous.** NN/g: 1 cm × 1 cm
   minimum for reliable selection, 2.5 cm is the average thumb's impact area.
   → `AegisTokens.MIN_TOUCH_PX = 64` at 844×390 is 64 device-independent px;
   the tabs, the pause plates and the shell's dock tiles are all ≥ 48 dp. The
   1 cm floor is the reason the dock drops a word instead of shrinking a tab.

7. **Japanese/Korean/Chinese/Indonesian readers prefer local-language content
   more than the global average.** CSA Research's 8,709-person survey: 76 % pick
   the product whose information is in their language, 40 % will never buy from a
   site in another language, and Indonesia is one of the strongest
   local-language markets in the survey.
   → This is the case for the language row existing in both halves and for the
   Indonesian column being written rather than translated (DECISIONS 46).
   Material's warning that a nav bar must leave room for "translated text" is
   also why the Indonesian dock was measured, not assumed: the longest
   Indonesian tab is `TEATER`, shorter than `THEATRE`.

## What the research changed in this round

* **The Deploy caption stopped repeating the theatre.** Both languages were
  truncated to `…READY TO…` / `…SIAP…` at 844 px — the exact class of failure
  Material predicts when copy grows and the container does not. The caption now
  states the condition (`READY TO DEPLOY` / `SIAP TURUN`) and the theatre is
  named once, in row 02.
* **Weapon names and units come from the catalogue**, so the shell and the game
  cannot disagree about what a weapon is called (`wpn.*.name`,
  `wpn.unit_damage`, `wpn.unit_bp`).
* **The HUD editor's group picker selects by id, not by its own label**, so the
  rows can be renamed in Indonesian without changing what a drag is saved
  against.

## What we are not doing yet, and why

* **Custom HUD drag (PUBG Mobile, Free Fire).** Both shipped shooters let players
  move every button. Ours moves *groups* only (`hud_editor.gd`, six groups). The
  data says per-button drag is a competitive expectation; it also says it is the
  most expensive feature in either game's settings. Group drag is the honest
  subset until there is a reason a specific button must move.
* **A per-weapon stat comparison table.** The Warzone thread asks for it; with
  three weapons the rack already shows all three stat lines at once, so a
  comparison mode would be a second screen answering a question the first screen
  answers.
* **Removing hover tooltips.** They are mouse-only in a touch product, which
  makes them decoration plus a capture artifact (the tooltip at the top-left of
  `engine/*-05-home.png` is the synthetic pointer sitting at 0,0). They stay
  because the web preview is played with a mouse, but no information lives only
  in one.
