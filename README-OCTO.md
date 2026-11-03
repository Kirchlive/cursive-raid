# Cursive Raid Threat (v5.1-octo)

One addon replacing three: **Cursive Raid** (debuff bars) + **TWThreat** (threat
meter) + **TankPlates** (aggro coloring). Base: Kirchlive cursive-raid 4.1.4.
Requires SuperWoW; uses Nampower/UnitXP_SP3 where present (LoS stripes).

## What each bar now shows
- Enemy name + health number (Cursive, unchanged)
- Your debuffs with timers (Cursive, unchanged)
- **Aggro holder's name + threat percent**, centered on the bar
- **Bar color = class of whoever holds aggro**: Warrior red, Paladin pink,
  Shaman blue, Priest white, Druid orange, Mage light blue, Warlock purple,
  Rogue yellow, Hunter green, unknown grey. Tanking everything as a paladin =
  a wall of pink; the one mob someone ripped turns their class color with
  their name on it.
- Your current target: toggle percent <-> your raw threat value.
- Pull warning: threat text turns red on your target when you pass 90% of the
  holder's threat.

## Data sources & limits (v5.0.2)
Two sources, best available wins per bar:
1. Server TWTv4 feed (party/raid + in combat + hostile target): exact threat
   values and percent for your CURRENT TARGET. OctoWoW's server does not
   implement the per-creature tank-mode extension, so percent is only known
   for the target.
2. Client-side aggro resolution (TankPlates method): every tracked mob's
   guid.."target" is read via SuperWoW, pets credit their owner. This colors
   EVERY bar with the aggro holder's class and name -- works solo too, no
   packets needed. No percent on non-target bars (the server doesn't offer
   one).

## Commands
    /cursive options      open the options window
    /cursive threat       toggle the threat module
    /cursive threatvalue  toggle percent <-> raw value on your target
All original Cursive commands (curse / multicurse / target) are untouched.

## Removed from the base addons ("fluff")
- FuBarPlugin, Tablet, Dewdrop libraries + minimap button (~6,900 lines)
- Test overlay & test framework (~1,000 lines)
- TWThreat's separate window, sounds, fonts, full-screen glow, version
  broadcasting, and its whole UI -- the data feed client is 280 lines here.
- Fixed upstream bugs: sound/texture paths pointed at "Cursive" instead of
  "Cursive-Raid" (resist/expiring sounds + target indicator never worked).

Settings live in the same CursiveDB as before -- your existing profile and
debuff configuration carry over untouched.
