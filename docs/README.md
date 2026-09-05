# Sivablue documentation

This documents how the image is built and why, for maintainers. End users
want the root [`README.md`](../README.md), the welcome message shown at
every login, and `ujust --choose`.

## Pages

| Page | Covers |
|---|---|
| [`build-stages.md`](./build-stages.md) | How `build/build.sh` calls each numbered stage by name, and the ordering rules that keep that safe. |
| [`filesystem-layout.md`](./filesystem-layout.md) | Where files end up in the built image — the `system/` mirror, `/usr` read-only at runtime, `/opt` — for decisions that span several stages. |
| [`settings.md`](./settings.md) | The two mechanisms for shipping a GNOME/dconf default, and which one a given schema requires. |
| [`extensions.md`](./extensions.md) | How GNOME extensions are vendored as git submodules and built during the image build. |
| [`flatpaks.md`](./flatpaks.md) | How preinstalled Flatpaks are declared, and why the preinstall list must exist in the image. |
| [`ujust.md`](./ujust.md) | How user-facing `ujust` commands are wired up, and the conventions for writing a new recipe. |
| [`user-setup.md`](./user-setup.md) | How per-user setup hooks run on login, and how to version one safely. |
| [`signing.md`](./signing.md) | Why images must carry a valid cosign signature, and how to rotate the signing key. |
| [`ci.md`](./ci.md) | What each GitHub Actions workflow does, and the conventions around secrets and the image name. |
| [`bluefin-comparison.md`](./bluefin-comparison.md) | How Sivablue differs from upstream Bluefin, what Bluefin has changed since, and which of it is worth adopting. An analysis snapshot, not a rule page. |

## Which page do I update?

| Change | Page |
|---|---|
| Added, removed or renumbered a build stage | [`build-stages.md`](./build-stages.md) |
| Added a Fedora package, COPR or third-party repo | [`build-stages.md`](./build-stages.md) |
| Added or changed software built from source | [`build-stages.md`](./build-stages.md) |
| Chose where a file lives in the image | [`filesystem-layout.md`](./filesystem-layout.md) |
| Changed a default setting | [`settings.md`](./settings.md) |
| Added or updated a GNOME extension | [`extensions.md`](./extensions.md) |
| Changed the preinstalled Flatpak list | [`flatpaks.md`](./flatpaks.md) |
| Added a `ujust` command | [`ujust.md`](./ujust.md) |
| Added a per-user setup hook | [`user-setup.md`](./user-setup.md) |
| Touched signing or key rotation | [`signing.md`](./signing.md) |
| Changed a workflow, secret or the image name | [`ci.md`](./ci.md) |

## Note

`docs/superpowers/` holds design specs and implementation plans generated
during development. It is process history, not reference documentation, and
is deliberately not indexed here.
