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
