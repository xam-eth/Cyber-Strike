# Human Playtest Runbook (Phase E — TECH HUNT hypothesis)

> **Purpose:** run the pre-registered human playtest that decides whether the
> TECH HUNT hypothesis continues, is revised, or stops
> ([`../DEVELOPMENT.md`](../DEVELOPMENT.md) Phase E). This runbook owns the
> **protocol, thresholds, and decision record**. Device preparation stays in
> [`ANDROID.md`](ANDROID.md); visual review stays in
> [`VISUAL_REVIEW.md`](VISUAL_REVIEW.md); executed results and the final
> decision belong in [`../VALIDATION.md`](../VALIDATION.md).

> **Evidence rules (non-negotiable, from [`../VALIDATION.md`](../VALIDATION.md)):**
> a screenshot or recording is a capture, not an approval. Observations are
> reported per participant with setup and sample size — never generalized into
> retention or device-performance claims. Browser runs say nothing about
> Android rendering or touch comfort; those need the physical device sections.

---

## 1. Pre-registration (fill in and commit BEFORE the first session)

The protocol is only valid if participants, devices, and thresholds are fixed
before any data exists. Record the filled-in table in the session's evidence
folder and reference it from the VALIDATION checkpoint.

| Field | Value (fill before testing) |
| --- | --- |
| Date window | |
| Facilitator(s) | |
| Participants (N, experience split) | target **5–8**: ≥2 with shooter experience, ≥2 without |
| Session length | 30–40 min per participant |
| Build(s) under test | web build `<git sha>` / Android APK `<workflow run url>` |
| Devices | baseline low/mid Android (see ANDROID.md §0.5) + 1 comparator; desktop browser for web sessions |
| Consent | verbal consent recorded in the notes; participants may stop at any time |

## 2. Builds and setup

- **Web session:** serve the committed `web/` payload (see
  [`WEB_PREVIEW.md`](WEB_PREVIEW.md)) on the facilitator's machine. The web
  path proves the shell and gameplay boot; it is not Android evidence.
- **Android session:** download the `android-debug-apk` artifact from the
  `Android debug APK` workflow run matching the tested commit (Actions →
  Android debug APK → Artifacts). `adb install -r`, then run
  `./scripts/android_usb.sh` per [`ANDROID.md`](ANDROID.md). The APK is
  debug-signed and **packaging only** — install and measure before any claim.
- Screen-record every session (OS recorder or `scripts/android_visual.sh`).
  Recording overhead is acknowledged and kept identical across participants.

## 3. Session script

| Step | Time | What happens |
| --- | --- | --- |
| 1. Welcome | 2 min | Consent, framing ("we are testing the game, not you"), think-aloud instruction. No mechanics explanation. |
| 2. Unassisted run | 15–20 min | Participant plays from boot to SH-01 Recovery completion, defeat, or 20 min cap. Facilitator stays silent except for "what are you trying to do now?" probes. |
| 3. Scenario probes | 8–10 min | Facilitator drives the fixed probes in §5 (death/retry/reload, ADS, pause/resume) if the unassisted run did not reach them. |
| 4. Comprehension questions | 4 min | The fixed question set in §6, answered without the game on screen. |
| 5. Debrief | 3 min | Free-form: what felt good, what felt unfair, what did not make sense. |

## 4. What we are testing (hypotheses, not features)

Per Phase E, each observation maps to exactly one hypothesis area. Do not
collect general "is it fun" verdicts.

1. **Objective comprehension** — does the player know what to do after each
   guidance line (READY → engage → secure → extract/continue)?
2. **Route choice** — does the player follow guidance to the caches, and do
   they understand the optional-vs-mandatory distinction?
3. **Dodge/punish understanding** — after being hit or downed once, does the
   player identify the enemy telegraph and change behavior?
4. **Secure/death comprehension** — does the player understand what is kept
   (blueprints, permanent BP) versus reset (run loadout) after defeat?
5. **Redeploy reasoning** — after RETRY, does the player adjust route or
   approach instead of repeating the same failure?

## 5. Fixed scenario probes (run when not reached organically)

| # | Probe | Expected observable |
| --- | --- | --- |
| P1 | Death before first secure → RETRY | Session restarts cleanly; no duplicate rewards; player states what carried over |
| P2 | Death after ≥1 secure → RETRY | Secured caches stay secured; BP not double-banked |
| P3 | Save/reload mid-mission (close app, relaunch) | Mission state restored as designed; no reward duplication |
| P4 | ADS (right mouse / hold AIM) + `[+]` reticle | Player can articulate the ADS benefit; reticle stays on target while moving |
| P5 | Pause → resume; app background → resume | No soft-lock, no state loss |
| P6 | Extract vs Continue after main objective | Player understands the trade-off offered |
| P7 | EMP + SWAP + Armory path | Run-scoped upgrades visibly separate from permanent progression |

## 6. Comprehension question set (asked verbatim, after play)

1. "What was your objective in that mission?" (expect: secure caches / recover tech)
2. "If you had died right after securing two caches, what would you have kept?"
3. "What did the EMP button do for you?" 
4. "What is the difference between the Armory upgrades and the blueprint you unlocked?"
5. "Why did you choose the route you took?"

Score each answer 0 (wrong), 1 (partial), 2 (clearly correct) against the
intended design ([`../GAMEPLAY_DESIGN.md`](../GAMEPLAY_DESIGN.md)).

## 7. Thresholds (fixed before testing; rerun affected gates after fixes)

| Gate | Threshold | Failure severity if missed |
| --- | --- | --- |
| Completion | ≥ 4 of 5 (or ≥ 70% of N) finish SH-01 Recovery unassisted within 15 min | S2 |
| Stability | 0 crashes, 0 soft-locks across all sessions | **S1** |
| Reward integrity | 0 duplicated rewards across all P1–P3 probes | **S1** |
| Objective comprehension | Q1 ≥ 60% of participants score 2 | S2 |
| Secure/death comprehension | Q2 ≥ 60% score ≥ 1 | S2 |
| Controls (touch sessions) | 0 systematic mis-taps on FIRE/EMP/SWAP; no control clipped or covered in any recorded frame | S2 (S1 if a control is unreachable) |
| Dodge/punish | ≥ 60% adjust behavior after first death (observable in recording) | S3 |
| Subjective | No more than 25% of participants call the mission "unfair" unprompted | S3 |

Severity scale: **S1** = progression loss, duplication, crash, or unreachable
control (blocks release regardless of averages); **S2** = a hypothesis area
fails its threshold (revise that area and rerun the affected gates); **S3** =
friction to watch (fix opportunistically, do not block the decision).

## 8. Failure classification

Tag every observed problem with exactly one class, matching Phase E:
`guidance` · `combat readability` · `controls` · `balance` · `reward value` ·
`motivation` · `stability`. Add severity and the smallest correction the
evidence indicates. Do not redesign beyond the indicated correction before
the decision record exists.

## 9. Evidence and decision record

- Per participant: the screen recording, the filled §3–§6 notes, and the
  questionnaire scores go to `qa-evidence/playtest/<date>/<id>/`.
- The aggregate: participant table, threshold results, classified failures,
  and the **decision record** (continue / revise / stop the TECH HUNT
  hypothesis, with rationale) are written to
  [`../VALIDATION.md`](../VALIDATION.md) as a dated checkpoint.
- The decision record is the exit criterion of Phase E. Everything else in
  this runbook exists to make that record honest.
