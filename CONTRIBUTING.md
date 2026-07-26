# Contributing

Thanks for your interest in Sivablue.

This repository builds the Sivablue bootc image. Start with
[`docs/README.md`](docs/README.md) for the documentation index, and
[`CLAUDE.md`](CLAUDE.md) (also `AGENTS.md`) for the rules that govern
this codebase.

Validate before submitting a change:

```bash
just lint    # shellcheck across all *.sh
just check   # just/Justfile syntax
just format  # shfmt
just build   # full image build
```

Only a full `just build` proves a build stage works.

Commits follow [Conventional Commits](.github/commit-convention.md).
AI agents disclose themselves with an `Assisted-by:` footer on every commit.
