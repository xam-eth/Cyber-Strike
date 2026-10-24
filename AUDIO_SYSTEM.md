# Audio system (procedural)

The game ships **no audio files**. Every sound is synthesised from maths at
startup by [`game/scripts/audio/procedural_sfx.gd`](game/scripts/audio/procedural_sfx.gd)
and played through a pooled set of players owned by the `Audio` autoload
([`game/scripts/audio/audio_director.gd`](game/scripts/audio/audio_director.gd)).

## Why generated instead of authored

- The asset pipeline in this repository is reviewed for provenance. A generated
  waveform needs no licence paperwork and no binary in Git.
- The web payload stays small: 14 sounds are about 0.5 MB of 16-bit PCM created
  in memory, instead of 14 files in the export.
- Tuning is a code review away: frequencies, envelopes and levels are readable
  numbers, not opaque WAV bytes.

The trade-off is honest: these are placeholder-grade effects, not design work.
Replacing them with authored audio means dropping files in `game/assets/audio/`
and pointing `build_all()` at them — nothing else in the game changes, because
gameplay code only ever calls the `Sfx` facade.

## Sounds

| Id | Trigger | Character |
| --- | --- | --- |
| `shot_pulse_rifle` | Pulse Rifle fire | falling saw + noise transient, ~0.11 s |
| `shot_nova_launcher` | Nova Launcher fire | saturated sub sweep, ~0.38 s |
| `shot_arc_shooter` | Arc Shooter fire | jittering square + noise spit |
| `impact` | Pulse projectile hit | short noise burst |
| `explosion` | Nova detonation | rumble + roar, ~0.5 s |
| `chain_zap` | Arc lightning hit | descending square zap |
| `enemy_down` | Runner / Shooter / drone destroyed | two descending tones |
| `player_hurt` | player takes damage | low thud + grit |
| `skill_pulse` | EMP skill fired | downward whoosh |
| `ui_click` | HUD buttons (pause, cycle, skill, retry) | short blip |
| `hit_confirm` | damage dealt to a target | bright tick |
| `wave_start` | wave begins | three rising notes |
| `session_clear` | wave session finished | four-note arpeggio |
| `defeat` | player defeated | descending minor tones |

Levels are per-sound (`ProceduralSfx.VOLUME_DB`) and applied to whichever pooled
player takes the voice; a small throttle table in the director stops several
projectiles landing in one frame from stacking identical transients.

## Calling it from gameplay

```gdscript
Sfx.play_shot(&"pulse_rifle", muzzle.global_position)  # positional
Sfx.play_ui(&"ui_click")                               # non-positional
Sfx.play_3d(&"enemy_down", enemy.global_position)
```

**Never call the `Audio` autoload by name.** An autoload's name is only a global
identifier in a real game session; headless `--script` runs (every smoke test in
this repository) do not register it, so `Audio.play_ui(...)` fails to compile and
takes the whole script — and the scene using it — down with it. `Sfx` looks the
node up at runtime and stays silent when audio is absent.

## Verification

- `tests/audio_smoke.gd` checks the sound set, that no sound is silence,
  the weapon→sound mapping, the mute path, the throttle, and that firing a
  weapon in the real `main.tscn` actually reaches the singleton.
- `Audio: first voice played (<id>) …` in any log proves the pipeline ran; the
  browser QA gate (`tools/web_qa.mjs --play`) asserts on that line, which is how
  the WebAssembly build is shown to reach audio after a user gesture.
- What is **not** verified: that a human hears it, on a real device, at a sane
  level. That needs a phone (see [`ANDROID_BASELINE.md`](ANDROID_BASELINE.md)).

## Known limits

- There is no settings screen and no volume slider; mute exists in the API
  (`Sfx.set_muted`) but is not yet exposed as a HUD button.
- Synthesis costs ~180–300 ms once, during load. It runs before the first frame,
  so it is hidden behind the loading screen, but it is real startup work on a
  low-end phone.
- Music does not exist.
