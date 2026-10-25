# Audio system — Frontier Signal

Frontier Signal is one original sci-fi palette shared by the opening, dashboard,
DEPLOY transition, and Godot gameplay: a restrained D-modal synth pad, a clean
telemetry motif, and synchronized electronic percussion. It is not a separate
music style for each screen. The same WAV files are loaded by the HTML shell and
the exported game.

## Ownership and flow

- The `Audio` autoload
  ([`game/scripts/audio/audio_director.gd`](game/scripts/audio/audio_director.gd))
  remains the only owner of gameplay music, pooled one-shots, throttling, and
  mute state. Gameplay calls the `Sfx` facade, never the autoload directly.
- [`ui/audio.js`](ui/audio.js) is a presentation-layer adapter for the HTML
  shell. It creates one Web Audio context only after a real pointer/keyboard
  gesture; it does not start hidden gameplay or a second gameplay director.
- DEPLOY plays `deploy_stinger.wav`, fades and disconnects the shell theme, and
  checks that no shell music voice remains **before** `engine.start()`. Godot
  then starts its own copy of the same theme. A failed launch can restore the
  launch bed; music beds are not allowed to overlap.
- `aegis.prefs.muted` is the shared Web preference. Godot also retains
  `user://audio.cfg` for native/fallback persistence and mirrors subsequent HUD
  mute changes back to the Web preference. Existing HUD and M-key controls stay
  on the same `Sfx` path.

## Music states

The 24-second theme and 6-second pulse start together and realign every four
pulse loops. State changes alter gain, not playback phase.

| State | Theme | Defense pulse |
| --- | --- | --- |
| Explore / front-end menus | −12 dB | silent |
| Preparing | −12 dB | −27 dB transition hint |
| Defense | −11 dB | −18 dB synchronized layer |
| Results | −14 dB | silent |

These are implementation starting levels, not a claim of final loudness or mix
acceptance. `Sfx.set_music_mode()` is called only by existing session transition
adapters in `main.gd`; it does not change combat, waves, rewards, or run state.

## Original generated assets

[`tools/generate_audio.py`](tools/generate_audio.py) uses only the Python
standard library. There are no external samples, borrowed tracks, runtime random
choices, or encoder dependencies. The fixed seed, 80 BPM tempo, pitch palette,
and synthesis code are reviewable source.

| File | Duration | Use |
| --- | ---: | --- |
| `frontier_signal.wav` | 24.0 s | seamless opening/dashboard/gameplay theme |
| `defense_pulse.wav` | 6.0 s | seamless gameplay-only percussion layer |
| `ui_navigate.wav` | 0.12 s | the same navigation tick in shell and Godot |
| `ui_confirm.wav` | 0.32 s | shell confirmation |
| `deploy_stinger.wav` | 1.50 s | shell DEPLOY and Godot `wave_start` |

All five are 22,050 Hz, stereo, 16-bit PCM WAV and total about 2.82 MB. The
adjacent `manifest.json` records provenance, dimensions, hash, peak/RMS, and
loop status. WAV is intentional: both Web Audio and Godot decode it without an
additional codec tool. The five small `.wav.import` files are deliberately
tracked source settings (`compress/mode=0`), not cache: Godot 4.7 otherwise uses
QOA, while the existing runtime/headless contract requires stereo PCM16.
Godot may add local UID metadata during import; as with the repo's other UID
cache, it is not required because every reference uses a `res://` path.
Regenerate and require byte-identical output with:

```bash
python3 tools/generate_audio.py
python3 tools/generate_audio.py --check
```

## Sound effects

The 14 existing sound IDs and the weapon mapping remain intact. Twelve effects
are deterministic runtime synthesis; `ui_click` and `wave_start` load shared
WAVs so shell and gameplay signals do not drift. Weapon/world effects retain
their identities, while UI, wave, reward, hit, and defeat pitches follow the
same D-modal palette.

| Id | Trigger | Character |
| --- | --- | --- |
| `shot_pulse_rifle` | Pulse Rifle fire | falling saw + noise transient |
| `shot_nova_launcher` | Nova Launcher fire | saturated sub sweep |
| `shot_arc_shooter` | Arc Shooter fire | jittering square + noise spit |
| `impact` | Pulse projectile hit | short noise burst |
| `explosion` | Nova detonation | rumble + roar |
| `chain_zap` | Arc lightning hit | descending square zap |
| `enemy_down` | Runner / Shooter / drone destroyed | two descending tones |
| `player_hurt` | player takes damage | low thud + grit |
| `skill_pulse` | EMP skill fired | downward whoosh |
| `ui_click` | HUD and shell navigation | shared `ui_navigate.wav` |
| `hit_confirm` | damage dealt to a target | bright A6 tick |
| `wave_start` | Defense begins | shared DEPLOY D-A-D signal |
| `session_clear` | session/reward confirmation | D-minor four-note arpeggio |
| `defeat` | player defeated | descending D-C-A tones |

Per-sound levels (`ProceduralSfx.VOLUME_DB`) and the director's throttle table
still prevent identical same-frame transients from stacking without limit.

## Calling it from gameplay

```gdscript
Sfx.play_shot(&"pulse_rifle", muzzle.global_position)
Sfx.play_ui(&"ui_click")
Sfx.play_3d(&"enemy_down", enemy.global_position)
Sfx.set_music_mode(&"defense")  # existing session adapter only
```

**Never call the `Audio` autoload by name from gameplay.** Headless `--script`
runs do not register autoload globals. `Sfx` looks the node up at runtime and
stays silent when audio is absent, keeping isolated smoke fixtures compilable.

## Verification and evidence limits

- `python3 -m unittest tools/tests/test_audio_assets.py -v` verifies hashes,
  deterministic regeneration, PCM format, non-silence, clipping/DC checks, clean
  one-shot edges, and loop-boundary continuity.
- `tests/audio_smoke.gd` additionally verifies the 14 IDs, stereo looping beds,
  4:1 loop alignment, facade/music-state wiring, mute restoration, throttle,
  weapon mapping, and a real shot through `main.tscn`.
- `node tools/web_qa.mjs --page / --journey --audio-shell` uses real browser
  gestures to check unlock, shell playback, mute persistence, DEPLOY retirement,
  and Godot music ownership. Adding `--play` also checks a real weapon voice and
  that HUD mute/unmute writes the shared shell preference in both directions.
## Validated payload — 2026-10-25

- **VERIFIED (CI/headless/runtime):** source `948ebb35`, CI `40174980634`;
  static checks and 28/28 Godot smoke tests passed, including `audio_smoke`.
- **VERIFIED (CI/browser):** four normal boot checks, opening/interrupted-
  download recovery, and strict Vanguard direct-DEPLOY with `--audio-shell`.
- **VERIFIED (local browser, final payload):** the same Vanguard journey with
  `--audio-shell --play 12` passed all checks, including `shot_pulse_rifle`,
  HUD mute/unmute, shared-pref mirroring, and zero shell music voices after
  handoff. No page error, failed request, or HTTP error was reported.
- **PAYLOAD:** commit `3719d705`; PCK 79,595,388 bytes / 884 files; SHA-256
  `bf65a6ccf564e10c705f1cf33ec703ee3a8e791fffb66fa49e0a782bb95d1a52`.
  This is below the 100,000,000-byte publication guard.
- **UNKNOWN / not signed off:** human listening, final mix/loudness acceptance,
  speaker/headphone quality, physical mobile behavior, and Android. Automated
  playback state and waveform checks are not substitutes for those reviews.
  No autoplay claim applies before a browser-valid user gesture.
