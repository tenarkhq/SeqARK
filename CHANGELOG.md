# Changelog

## 0.7.0

- Built-in sequences for six more specializations, each order measured in SimC:
  - Death Knight: Unholy ST (1-3 targets) and AE (4+ targets, with Epidemic); Frost one order for single target and AoE
  - Demon Hunter: Havoc one order for single target and AoE; Devourer ST and AE (Collapsing Star goes out first whenever it is up)
  - Shaman: Enhancement ST and AE; Elemental ST and AE
- Havoc and Frost have one order only: the same order was the best on one target and on many, so there is no separate AE for them
- The orders use trinket 14 only where the measured profile's trinket has a use effect; Surging Totem is placed at your feet, Earthquake at the mouse cursor

## 0.6.1

- The window shows your sequences in two groups: IMPORTED and BUILT IN. A built-in sequence that an imported one of the same name replaces stays in the list, dimmed, marked "Not used"; its key is on the imported one. Delete the imported one and the built-in gets the key back
- Wider window and columns: long titles wrap to a second line instead of being cut off, and the source text no longer runs into the key field
- STHP, AEHP, STHPNOCD and AEHPNOCD from 0.6.0 are removed. The game tries only the first matching cast line of a press, so with too little Holy Power the spender line failed and the builder behind it never went out. A key bound to them does nothing until you bind it again

## 0.6.0

- Four new built-in Retribution sequences beside the old ones: STHP, AEHP, STHPNOCD and AEHPNOCD. Every press tries the spender first (Final Verdict in single target, Divine Storm in AoE): with 3 or more Holy Power it goes out, with less the step's builder or cooldown goes out instead. So Holy Power is spent before a builder would waste it at 5. The steps hold builders, cooldowns and trinkets only
- The old ST, AE, STNOCD and AENOCD stay as they were

## 0.5.2

- On a mount, in a vehicle and with an override bar (skyriding, quest vehicles) SeqARK lets go of its keys, so the mount's and vehicle's buttons work; the keys come back when you get off, also in combat

## 0.5.1

- A sequence key does nothing while you are on a mount: no target change, no cast that takes you off the mount, and the step stays

## 0.5.0

- The window is sorted by class and specialization: class and spec on the left, the chosen spec's sequences on the right
- Every specialization can have its own sequence of the same name (one ST for Retribution, one for Fury); earlier saves are moved over at login
- Keys can be set for the other specs of your class too
- Minimap button (through LibDBIcon, when another addon has loaded it) and an entry in the game's addon menu
- Addon icon

## 0.4.1

- An empty Bindings.xml: the game looks for it in every addon folder and warned without it

## 0.4.0

- Icon button: makes a macro that only shows the sequence's spell (#showtooltip), to put on the action bar slot of the same key
- Optional `icon {spellid}` line in the sequence text

## 0.3.0

- `/seqark` opens a window: the sequences of your specialization, where each comes from (built in or imported) and its key
- Click a key field and press a key to bind it, right-click to clear it
- Import window with the reason when a text cannot be imported; Export and Delete per sequence

## 0.2.0

- Each key press runs the next step: the key presses a small button on key down, which clicks the sequence button; keys are override bindings set by SeqARK at every login
- Every sequence starts from step 1 again after combat

## 0.1.0

- First test build: built-in Retribution sequences (ST, AE, STNOCD, AENOCD), the SeqARK text format for import and export, `/seqark` commands
