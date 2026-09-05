# CI and repository setup

## Workflows

- `build.yml` builds both image variants and publishes them to GHCR.
- `clean.yml` prunes old images/tags from the registry.
- `renovate.yml` runs scheduled dependency updates.
- The `validate-*.yml` workflows are left alone by convention (see
  `CLAUDE.md`) and are not covered here.

`build.yml` ignores `**.md` on both `push` and `pull_request` (its
`paths-ignore`), so a documentation-only change does not trigger an image
build.

## Forcing a cold build

`build.yml`'s `workflow_dispatch` takes a `no_cache` input. It sets
`REGISTRY_CACHE_READ=0`, which drops `--cache-from` in the `Justfile`'s build
recipe so no layer is pulled from GHCR. `--cache-to` is unaffected, so the run
still refreshes the cache for everyone after it. Every other trigger defaults
the variable to `1` and behaves as before.

This exists because a green build proves little on its own: the layers that
were slow before the native-overlayfs fix are exactly the ones that normally
hit cache, so a routine run never exercises them. The failure being guarded
against only appears when the upstream base digest moves and every layer below
it rebuilds. `no_cache` reproduces that on demand instead of waiting for it.

## Podman storage on the runner

`build.yml` writes `/etc/containers/storage.conf` before building - declaring
`driver = "overlay"` and `mountopt = "nodev,redirect_dir=off"`, with no
`mount_program` - then asserts that `podman info` reports
`Native Overlay Diff: true`.

It writes the file rather than patching it, and that is the result of a
regression. Runner image `ubuntu24/20260831.293` downgraded podman from 5.8.4
to 4.9.3, swapping the upstream build for Ubuntu's archive package, which does
not ship `storage.conf` at all. The previous `sed`-based approach then exited 2
on a missing file and took the whole step with it - builds failed from
2026-09-03 until the file was declared outright. Writing the whole file is also
idempotent and indifferent to what any future runner image ships.

Runner images have historically shipped that file pointing podman at
`/usr/local/bin/fuse-overlayfs`. Podman then reports its driver as `overlay`
while routing every layer operation through a userspace FUSE implementation.
The build runs as root with `d_type` support, so kernel overlayfs is
available and the mount program buys nothing. It cost roughly 27 minutes per
committed layer - a flat toll independent of what the layer changed, so
`RUN rm /opt && mkdir /opt` cost the same as a full package install. Six
committed layers put builds past the 120-minute step timeout in `build.yml`.

Leaving the mount program out is necessary but not sufficient. These runners also
report `redirect_dir = Y` in `/sys/module/overlay/parameters/`, and
containers/storage disables native diff whenever its probe mount shows the
kernel using redirect_dir. That probe appends `mountopt` to its test mount, so
setting `redirect_dir=off` there restores native diff with the change scoped to
podman. Turning the module parameter off host-wide works equally well and was
rejected as needlessly broad. The stock `mountopt` value's `fsync=0` is not
carried over - it is a fuse-overlayfs option the kernel driver rejects.

`projectbluefin/actions/bootc-build/setup-runner` has a `native-overlay` input
that covers most of this, and the hand-rolled step could be replaced by it. It
was kept because its `mountopt` is `"nodev"` alone, and the measurements below
say `redirect_dir=off` is required on these runners. Worth re-testing if this
step needs attention again.

Both parts are required, and so is discarding the runner's pre-baked ~29GB
container store. That store carries containers/storage's `.has-mount-program`
marker, which pins it to naive diff regardless of what the config says
afterwards. Measured on the runner: a reset without `redirect_dir=off` gives
native diff off, `redirect_dir=off` against the pre-baked store gives native
diff off, and the two together give native diff on. The build pulls its own
images, so nothing is lost by resetting.

The step fails the build if native overlay is not active afterwards. That is
deliberate: this regression went unnoticed for two months precisely because the
slow path was entered silently. `setup-runner` is passed
`storage-backend: btrfs`, but the underlying `container-storage-action` skips
its btrfs loopback with only a `::notice::` when `/mnt` is not a mountpoint -
which it no longer is on GitHub runners - and the step still reports success.
Until June 2026 that loopback did mount, which kept podman off the FUSE path
and builds at roughly 10 minutes.

## Permissions

`build.yml` declares `contents: read`, `packages: write`, `id-token: write`,
and `attestations: write` (`.github/workflows/build.yml:20-24`, repeated at
job level for the `build_push` job). These are the minimum GitHub Actions
needs to check out the repository, push images to GHCR, and produce signed
build provenance attestations.

## Secrets

- `SIGNING_SECRET` holds the cosign private key used to sign published
  images. See `signing.md` for setup, rotation, and what this control does
  and does not protect against.
- The Renovate token (`RENOVATE_TOKEN`) is validated by the
  `check-token-health` composite action in
  `.github/actions/check-token-health/` before Renovate runs. It fails fast
  if the token is expired, revoked, or missing required scopes, rather than
  letting Renovate fail confusingly deeper in the run. `renovate.yml` calls
  it with `required_scopes: repo,workflow`. If `RENOVATE_TOKEN` is not
  configured at all, the workflow skips Renovate rather than failing.
- `GITHUB_TOKEN`, as used by the `ghcurl` helper during the image build,
  needs no scopes — see `build-stages.md` for why and what it is used for.

## Image identity

The image's name, repository path, and vendor are set as constants in
`build/00-image-info.sh` (`IMAGE_NAME`, `IMAGE_REPO`, `IMAGE_VENDOR`).
`IMAGE_REPO` must stay lowercase, because OCI and GHCR repository names must
be lowercase.

That lowercase name (`sivablue`) is also the default `image_name` in the
Justfile and the `repositoryID` in `artifacthub-repo.yml`. Neither file
derives its value from `00-image-info.sh` automatically, so renaming the
image means updating all three together — `build/00-image-info.sh`,
`Justfile`, and `artifacthub-repo.yml` — by hand.

`build.yml` itself does not read these constants: it derives its own
`IMAGE_NAME` and `IMAGE_VENDOR` at run time from the GitHub repository name
and owner (`env.IMAGE_NAME`, `env.IMAGE_VENDOR` in `build.yml`), lower-cased
in the "Prepare environment" step. The two mechanisms are independent and
only agree because the repository's actual name and owner match the
constants above — they are not wired together.
