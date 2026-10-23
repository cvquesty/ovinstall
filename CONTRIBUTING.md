# Contributing to ovinstall

## Workflow

1. Branch from `master` (`fix/…`, `feat/…`, `docs/…`, `chore/…`).
2. Keep changes focused; update README / docs when behavior changes.
3. Open a pull request against `master`. CI must pass before merge.

## Checks (same as CI)

Run from the repo root:

```bash
# Syntax
for f in bin/* lib/*.sh; do bash -n "$f"; done

# Lint (follows sourced libs)
shellcheck -S warning -x bin/ovinstall bin/ovinstall-maintenance

# Help renders without root
./bin/ovinstall --help
```

To repeat the container syntax job locally (needs Docker):

```bash
for img in rockylinux:9 debian:12 ubuntu:24.04; do
  docker run --rm -v "$PWD":/src -w /src "$img" \
    bash -c 'for f in bin/* lib/*.sh; do bash -n "$f"; done' && echo "$img ok"
done
```

CI does not run real installs. If you test an install on a VM, say which OS and mode in the PR.

## License

By contributing you agree your work is licensed under the [Apache License 2.0](LICENSE).
