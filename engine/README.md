# engine/ — payloads kept in the repository on purpose

This repository is used from machines with slow or metered internet, so the
files that would otherwise be a large download live here instead. The same idea
as `xam-eth/Scary-Night`, which keeps its Godot engine zip and its
`web_nothreads_*.zip` export templates in-tree.

## `web_templates/`

The **web** export templates for the pinned engine (4.7.2-stable), extracted from
the official template archive by the `web-preview` CI job. A full `.tpz` template
archive is ~1.2 GB; only the web parts are needed to export the browser preview,
and they are ~10 MB each.

| File | Used for |
|---|---|
| `web_nothreads_release.zip` | release export, single-threaded — the one the preview uses |
| `web_nothreads_debug.zip` | debug export (`scripts/export_web_preview.sh --debug`) |
| `web_release.zip`, `web_debug.zip` | threaded variants; not used by the preview (they need COOP/COEP headers) |

Install them for the pinned engine so a local export never needs the big
download:

```bash
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable
cp engine/web_templates/*.zip ~/.local/share/godot/export_templates/4.7.2.stable/
./scripts/install_godot.sh --with-templates   # for the engine binary itself
./scripts/export_web_preview.sh
```

On macOS the templates directory is
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`, on Windows
`%APPDATA%\Godot\export_templates\4.7.2.stable\`.

## Why not the engine binary too?

The engine is ~78 MB and platform specific; `scripts/install_godot.sh` fetches
the right build for the running system. If you also want the editor in-tree (the
Scary-Night layout), say so and it can be staged here the same way.

## Refreshing

The `web-preview` CI job exports the game on every push and commits `web/` plus
`engine/web_templates/` when they change. A re-export can differ by a few bytes
in `index.pck` even without a source change, which means a push can produce one
extra generated commit; it carries the skip-CI marker, so it never starts another
run, and it keeps the payload in step with the sources that produced it.

## Conventions

The `web-preview` CI job refreshes `web/` and this directory with a generated
commit whose message carries the skip-CI marker, so refreshing the payload never
starts another pipeline run. Keep the marker out of hand-written commit messages:
GitHub scans the whole message (subject and body) and skips *all* workflow runs
for a commit that contains it — which is how one push here ended up with no CI at
all.
