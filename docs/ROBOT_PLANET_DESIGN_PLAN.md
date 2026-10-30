# Aetherfall — Robot Planet Tech Heist

**Status:** Phase 1 exterior macro composition dan Phase 2 cover/traversal blockout telah diproduksi. Bukti yang tersedia untuk Phase 2 adalah kontrak aset, konfigurasi, parse skrip, dan pemeriksaan clearance statis; inspeksi grafis serta runtime Godot tetap terpisah dan belum diklaim.

## 1. Direction decision

Aetherfall is **not** a spaceship hangar or an indoor arena. It is an exposed,
industrial region on a robot-controlled planet: a weathered extraction basin
built around an ancient energy tower. The outdoor landscape is the dominant
experience; buildings are weather-beaten robot facilities embedded into cliffs,
service gantries and mining platforms.

The mission is a tech heist:

> Enter a robot-controlled planetary refinery, survive or evade its security
> perimeter, breach the Sentinel Archive, and extract a newly discovered core
> technology from a computer inside the archive.

The level must read as a place with an operational purpose, not a flat prop
showcase. Every asset must support navigation, cover, landmarking, objective
readability, danger, or story.

## Configuration selected by reviewer

| Decision | Selected direction | Consequence |
| --- | --- | --- |
| Mission tone | **Mixed infiltration** | Exterior supports bypass routes and cover-based combat routes; neither stealth nor combat is falsely implemented before its systems exist. |
| Planet condition | **Ice / blue-energy planet** | Glacial cliffs, dark basalt, snow-dust, buried cryogenic machinery and blue fissure/robot energy replace the oxidised mining default. |
| Final reward | **Archive Data Core** | The indoor Archive Computer commits the unique Data Core record; later research/progression may consume it, but that broader catalog does not yet exist. |
| Archive scale | **Compact room + vestibule** | One mobile-aware indoor objective room provides a clear tech-computer climax without prematurely building a generic dungeon. |

## 2. Current verified starting point

| Existing element | Design role after this plan | Treatment |
| --- | --- | --- |
| Aetherfall energy tower around `(0, 0, -26)` | Planetary extraction beacon / long-range landmark | Preserve and strengthen as skyline target. |
| West primary spawn around `(-30, 1.2, 14)` | Landing-ridge insertion point | Preserve marker; build a readable outdoor arrival edge around it. |
| Central deck route | Scrapper Basin traversal spine | Break its visual flatness with terracing, cover and overhead infrastructure. |
| East bridge / west catwalk / lower approach | High flank / exposed flank / low canyon route | Preserve working connectors; give each a unique tactical role. |
| Current outpost, refinery, hangar, gantry and raised deck assets | Early structural vocabulary | Reposition or extend only where the final zone plan calls for it; they must not make the planet read as an enclosed hangar. |
| Tech cache and relay prototype | Interaction proof-of-concept only | Replace their mission meaning: final technology is collected **inside** the archive from a computer. |

**Known missing dependencies:** this branch still has no player-combat framework,
robot AI, weapon/damage system, mission service, general inventory, NavMesh, or
save architecture beyond the small vertical-slice ledger. The plan below marks
where those systems are required; no fake robot combat or fake mission rewards
will be presented as implemented.

## 3. Narrative and visual pillars

### 3.1 Planetary exterior, not an interior bay

- Open sky, distant glacial rock strata, snow-dust haze, blue-energy fissures
  and silhouette towers are always visible from the major exterior zones.
- Facilities are **attached to terrain**: half-buried cryogenic refinery walls,
  ice-locked piping, cliff anchors, frozen receiver masts, transit bridges and
  service decks.
- A limited archive interior is intentional contrast: calm, sealed, colder,
  cleaner and clearly owned by the robot faction.

### 3.2 Robot ownership language

- Repeating but purposeful machine geometry: octagonal sensors, receiver vanes,
  service conduits, panel seams, warning glyph zones and cyan diagnostic light.
- Robots should read as an ecosystem of distinct roles: scanner/sentry, patrol
  walker, heavy guard and dormant maintenance unit. Those are **planned roles**,
  not existing AI.
- Amber is hazard/industrial authorization; cyan is robot system state; the
  natural planet palette is blue-white ice, dark basalt, frost-dulled metal and
  a cold luminous sky.

### 3.3 Density through structure, not clutter

Each exterior vista must contain all three scale bands:

1. **Near:** a cover-capable machine, boulder, cable tray, cargo rig or pipe
   junction.
2. **Mid:** a building face, rock outcrop, raised deck, security gate or tower
   support.
3. **Far:** the energy tower, refinery stack, cliff silhouette or elevated
   transit structure.

Loose crates without a logistics source, isolated props in the middle of a
route, and an overhead ceiling that makes the outdoor world feel like a hangar
are rejected.

## 4. World layout proposal

The plan preserves Aetherfall's useful footprint and connector routes; it does
not replace the world with a different procedural map.

```text
                         NORTH / TOWER BASIN
                    [Energy Tower + extraction scars]
               [Refinery wall]              [Refinery wall]
                         \  Sentinel Archive /
                          \  sealed interior /
                 High flank \    |    / Low canyon flank
                                [Scrapper Basin]
                     raised deck / overhead service gantry

  West landing ridge  ---- central approach ---- east relay bridge
  primary insertion        cover lanes              exposed flank
```

### Zone A — Landing Ridge / Primary Insertion

- **Location:** west/south around the existing primary spawn.
- **Feeling:** exposed alien plateau with a grounded arrival shuttle pad,
  weathered cargo derrick and cliff-side landing relay — not a roofed hangar.
- **Gameplay role:** safe orientation point; first view of the tower and the
  archive. It gives the player an immediate choice between central basin and
  west catwalk.
- **Cover target:** two hard-cover pieces, one tall line-of-sight break, and a
  side escape behind terrain. No combat claim until player/weapon systems exist.

### Zone B — Scrapper Basin / Central Combat Bowl

- **Location:** current central deck, reshaped visually as a fractured mining
  basin rather than a single empty slab.
- **Feeling:** cut ore plates, robot salvage machinery, short rock berms,
  overhead pipe gantry and low dust drifting through a trench.
- **Gameplay role:** main confrontation space and route junction.
- **Verticality:** low trench at existing lower approach, ground plateau, raised
  operations deck, and visible overhead service route. The top route is a
  visual/tactical goal; actual traversal comes only after a player movement
  test.
- **Cover target:** alternating left/right hard cover every 6–10m, with two
  larger sightline breaks near the centre and no continuous "safe wall".

### Zone C — High Flank / Relay Spine

- **Location:** existing east bridge and raised connection.
- **Feeling:** exposed narrow industrial route above the basin, attached to
  cliff-side receivers and robot power conduits.
- **Gameplay role:** high-risk alternate approach, with sightline advantage and
  less cover than the basin.
- **Obstacle plan:** active scanner gate and a damaged/energised conduit. These
  remain geometry/visual only until damage and hazard authority exist.

### Zone D — Lower Canyon / Maintenance Flank

- **Location:** existing lower approach and canyon descent.
- **Feeling:** natural alien rock with buried robot maintenance roots, coolant
  discharge, derelict maintenance shells and limited sky visibility.
- **Gameplay role:** lower, safer-from-sight but longer route to the archive.
- **Cover target:** rock + machinery mixed cover, never a chain of identical
  waist-high barriers.

### Zone E — Sentinel Archive Exterior

- **Location:** tower-side north basin, oriented toward the energy tower.
- **Feeling:** compact sealed robot research facility built into a cliff /
  refinery foundation. It needs one strong exterior façade, a clear door,
  receiver mast and multiple approach angles.
- **Gameplay role:** visible mission target from the beginning; exterior breach
  area has security cover and guard positions.
- **Building rule:** exterior mass must be tall enough to terminate long deck
  views, but it must retain open sky around it so it is a planetary installation,
  not a hangar wall.

### Zone F — Archive Interior / Tech Room

- **Location:** one compact room behind the Sentinel Archive exterior door,
  inside the same Aetherfall world or a streamed child scene — no loading-screen
  claim is required.
- **Feeling:** sealed, quiet, clean robot interface chamber. Its visual contrast
  makes the stolen technology consequential.
- **Required contents:** airlock/door threshold, short vestibule, central
  **Archive Computer**, server pylons, diagnostic screens, cable floor channels,
  one emergency exit/light source and cover-sized console banks.
- **Final interaction:** the player obtains the actual new technology from the
  Archive Computer inside this room. The outdoor cache may become an access
  credential/power cell or be removed; it cannot remain the final tech reward.

### Zone G — Extraction Readback

- **Location:** return sightline to landing ridge, with the tower in view.
- **Purpose:** creates a coherent outbound direction after the archive objective
  without requiring a second world. Its actual extraction/mission conclusion is
  deferred until mission authority exists.

## 5. Mission and interaction state design

| Step | Player-facing intent | Physical proof | Required authority |
| --- | --- | --- | --- |
| 0. Insert | Identify the tower and sealed archive | landing ridge, skyline framing | camera/world only |
| 1. Reach archive | Choose central/high/low exterior route | route markers, cover, obstacles | player movement later |
| 2. Breach security | Open archive access after finding an access item or state | exterior door terminal | local interaction/progression state |
| 3. Enter archive | Cross a real exterior-to-interior threshold | door, vestibule, interior scene/space | collision + streaming decision |
| 4. Steal tech | Use Archive Computer in the tech room | computer animation, signal validation, durable reward transaction | progression state / persistence |
| 5. Exit | Return to extraction direction | recontextualised exterior world | mission state later |

**Reward policy:** `Archive Computer` commits a named final technology record
only after the interaction state and persistence write succeed. UI feedback,
unlocks or mission completion must derive from that record, never from a visual
animation alone.

## 6. Robot and obstacle plan — explicitly deferred implementation

### Planned robot roles

| Role | Space | Behaviour target | Current status |
| --- | --- | --- | --- |
| Scanner Sentry | high flank / archive gate | scan cone, alarm, route denial | NOT IMPLEMENTED |
| Patrol Walker | central basin | patrol between cover anchors | NOT IMPLEMENTED |
| Heavy Archive Guard | archive exterior | holds doorway / defensive reposition | NOT IMPLEMENTED |
| Dormant Maintenance Robot | canyon / structures | environmental storytelling first | MAY BE VISUAL ONLY initially |

### Planned obstacles

- scanner gate with a safe bypass route;
- exposed electrical conduit and cooldown timing;
- damaged moving bridge or raised-deck access;
- archive door authorization terminal;
- floor/cable hazard inside the archive.

No obstacle may apply damage, detect stealth, lock the player, or report mission
completion until the project has a real player, health/damage, AI/navigation and
mission-state integration path. Until then, it is documented environmental
storytelling only.

## 7. Build order and approval gates

### Phase 0 — Approve this plan

Approve: outdoor robot planet direction, seven-zone flow, indoor archive as
final-tech location, and camera-only QA. **No production geometry starts before
this gate.**

### Phase 1 — Exterior macro composition — IMPLEMENTED

1. Added original PBR ice maps and four authored Blender asset families:
   glacier shelf, frozen spire, cryo pylon and Sentinel Archive exterior.
2. Added nine deliberate placements: Sentinel Archive, four glacial perimeter
   masses, two skyline spires and two robot cryo pylons.
3. Tuned the world toward a cold open-sky palette with restrained blue haze;
   it is not framed as an indoor hangar.
4. Added camera preset 7 for the archive exterior and 8 for tower/glacial
   skyline, while retaining the existing inspection presets.

The archive door aligns with the central-route destination and uses segmented
collider volumes that leave the later doorway/vestibule work possible. The
phase does **not** claim a playable door or Archive Interior yet.

**Gate result:** static asset, placement, PBR and script-parse checks are
available; final graphical camera QA and altered-route collision runtime checks
remain pending a Godot runtime.

### Phase 2 — Cover and traversal blockout — IMPLEMENTED (static assembly)

1. Added four Blender-authored PBR setpiece families: irregular **glacier berm**,
   directional robot **salvage pod**, tall **cryo bulkhead**, and three-step
   **ice terrace**. They reuse the real ice/metal/hazard PBR maps rather than
   flat colour substitutions.
2. Added eight named placements: landing-ridge cover, two basin-side cover
   decisions, an east sightline break, archive-approach cover, two raised ice
   terraces, and one lower-canyon maintenance-shell cover. Each placement has a
   documented navigation/sightline reason in `phase2_cover.json`.
3. Added twelve deliberate proxy collision volumes: one per berm/pod/bulkhead
   and three physical levels per terrace. The main central spine and all three
   connector approaches are statically clearance-checked with at least 0.5 m
   beyond each conservative collision footprint and route half-width.
4. Added character-free camera presets 9 (Scrapper Basin near/mid/far cover to
   Archive) and 10 (lower canyon salvage / high-low read). Existing presets
   7–8 retain Archive and skyline review.

**VERIFIED (static):** GLB integrity, mesh/detail floor, embedded PBR
normal+ORM dependencies, eight configuration purposes, twelve collision boxes,
route-clearance calculation, Python compilation and GDScript parsing can be
checked from this repository.

**UNVERIFIED:** Godot runtime instantiation, capsule clearance after the new
colliders, graphical framing/material appearance, player traversal feel,
combat balance, AI, damage/hazards, Archive interior, Archive Computer and
Data Core interaction. None is claimed by this phase.

**Gate result:** cover purpose is documented per encounter space; no prop is
simply "decorative combat cover" without a sightline or route reason. Phase 3
remains blocked pending separate approval.

### Phase 3 — Archive interior and final tech computer

1. Build one compact Archive Interior scene/module with exterior door,
   vestibule and computer room.
2. Convert existing tech cache into access item or remove it from final reward
   flow.
3. Create reusable `ArchiveComputer` state machine: locked → authorised →
   downloading → collected, including persistence and duplicate prevention.

**Gate:** final technology cannot be collected outdoors; it is committed only by
interacting with the indoor computer and survives a reload.

### Phase 4 — Robot gameplay integration

Only after an actual controller/combat/AI decision is supplied or built:

1. player controller and camera collision validation;
2. NavMesh and robot patrol/guard state;
3. detection/damage/hazard authority;
4. encounter tuning and route balancing.

**Gate:** every robot has navigation, a valid target/health path, an encounter
purpose and a test. No visual-only "enemy" is counted as gameplay.

## 8. Asset plan after approval

| Asset family | Purpose | Reuse count target |
| --- | --- | --- |
| Alien cliff / extraction scar modules | planet silhouette, canyon walls, route bounds | 6–10 placements |
| Sentinel Archive exterior kit | final objective building and cover corners | one hero compound |
| Archive interior kit | airlock, server pylon, console banks, floor channels | one compact room |
| Archive Computer | final tech interaction, authored states | one reusable hero prop |
| Robot faction set | sentry, patrol, heavy, dormant visual unit | only after gameplay dependency gate |
| Terrain-integrated service props | pipes, derelict machinery, anchored cargo rigs | sparse clusters tied to zones |

## 9. Camera-only QA acceptance views

1. Landing ridge → archive/tower visible in distance.
2. Central basin → foreground cover, mid building, far tower in one frame.
3. East high flank → height/risk read and open sky.
4. Lower canyon → natural planet material and buried robot infrastructure.
5. Archive exterior → door legibility, future guard/cover anchors and destination read.
6. Archive interior → computer is unmistakably the final tech source (**deferred; not built in Phase 2**).
7. Return/extraction → route reads back toward landing ridge.
8. Phase 2 Scrapper Basin → berm or salvage foreground, cryo bulkhead/building mid-ground, Archive/tower far target.
9. Phase 2 lower flank → canyon salvage cover and a terrace/high-route relationship without a character in frame.

## 10. Approval checkpoint

The reviewer has selected the mixed mission tone, ice/blue-energy planet,
Archive Data Core reward, and compact archive interior. Phase 1 and the
purpose-defined Phase 2 exterior assembly are complete at the static-contract
level. The next remaining gate is separate approval for **Phase 3 — Archive
Interior and final-tech computer**.

Phase 3 must not fabricate robot AI, player combat, damage, mission completion,
mobile performance, or a Data Core unlock without its real persistence and
state-validation architecture.
