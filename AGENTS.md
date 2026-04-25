# koel-docker — Agent Instructions

This repo builds the official Docker image for [koel](https://github.com/koel/koel). It is **separate** from the main koel application repo (which lives alongside this one). Releases are decoupled: a koel app release does not automatically produce a Docker image — that requires running the release script in this repo as a follow-up.

## Releasing
- To release a new version, run `./release vX.Y.Z` from the repo root. Always pass an explicit version with the `v` prefix (matching the app repo's tag).
- The script is the source of truth for the flow:
    1. Refuses to run unless on `master` with a clean working tree.
    2. Updates `Dockerfile`'s `ARG KOEL_VERSION_REF=...` (used as a git ref to clone the koel app at that version).
    3. Updates the version line in `goss.yaml` marked `# DO NOT REMOVE — used by the release script`.
    4. Commits as `bump Koel to vX.Y.Z`.
    5. Tags `vX.Y.Z` (lightweight) and force-moves the `latest` tag.
    6. Pushes `master`, the new tag, and the force-updated `latest` tag.
- The tag push triggers `.github/workflows/release.yml`: it runs goss tests, then (on success) builds a multi-arch image (`linux/amd64`, `linux/arm64`, `linux/arm/v7`) and pushes to Docker Hub as `phanan/koel:latest` and `phanan/koel:X.Y.Z` (note: `v` prefix stripped — see "Image tags" below).
- There is **no draft step** for Docker images. If the workflow succeeds, the image is live on Docker Hub immediately. If goss tests fail, the git tag is already public but no image is pushed — you'll need to investigate and re-tag.
- Wait for the workflow with `gh run watch <id>` (workflow name: `Release Docker image`). Verify after with `docker pull phanan/koel:X.Y.Z`.
- The Docker release for a given version should follow the koel app release for that same version. Run the app release first (`php artisan koel:release` in the koel repo), wait for it to publish on GitHub, then run `./release vX.Y.Z` here.

## Commit Conventions
- This repo does **NOT** use [Conventional Commits](https://www.conventionalcommits.org/) — that's the main koel app repo's convention, not this one.
- Use plain, descriptive prose: `bump Koel to v9.1.2`, `drop workbox body assertion from sw.js test`, `automate version bump in release script`. Look at recent `git log` for tone.
- Do not prefix with `fix:`, `feat:`, `chore:` etc. unless you find clear precedent in recent history (a few older commits use `chore:` but it's not the dominant style).

## Image Tags
- Git tags are `vX.Y.Z` (with `v` prefix).
- Docker Hub image tags are `X.Y.Z` (without `v` prefix) — `release.yml` strips the prefix at runtime via `${GITHUB_REF_NAME#v}`.
- So `docker pull phanan/koel:v9.1.2` will fail; the correct pull is `docker pull phanan/koel:9.1.2`. Make sure any user-facing docs that recommend a docker pull command use the unprefixed form.

## Testing
- Container smoke tests use [goss](https://github.com/goss-org/goss) — a lightweight assertion framework that checks files, ports, processes, and command outputs inside a built image.
- The goss test config lives in `goss.yaml`. The release script touches the version-string line; do not edit that line manually.
- The CI test job runs via `./.github/actions/test` against a freshly built image before any image push.

## Script Portability
- `release` is a bash script that uses BSD `sed` syntax (`sed -i ''` with an empty-string argument). It runs correctly on macOS but **will misbehave on GNU sed (Linux)** — `sed -i` on Linux requires no empty arg. Do not assume this script can be moved to CI runners without modification.

## Relationship to the koel App Repo
- This repo's `Dockerfile` clones the koel application at the ref recorded in `ARG KOEL_VERSION_REF`. Bumping the version in `Dockerfile` is what tells the image which app version to ship.
- The two repos have independent git histories, independent release scripts, and different commit-message conventions. Do not assume conventions cross over.
