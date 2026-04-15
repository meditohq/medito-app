---
name: release
description: Cuts a new release of the Medito Flutter app — bumps the version in pubspec.yaml, runs prepare_release.sh to reorganise release_notes.txt, commits the changes, tags the commit, and pushes everything to origin. Use this whenever the user says "release", "cut a release", "release 3.x.x", "ship a new version", "tag a release", or otherwise indicates they want to publish a new version, even if they don't explicitly mention every step.
argument-hint: "[version]"
---

Cut a new release of the Medito app. Follow the steps below in order — each step assumes the previous one succeeded.

## 1. Decide the new version

Read the current version from `pubspec.yaml` (the `version:` line, format `MAJOR.MINOR.PATCH+BUILD`).

- If `$ARGUMENTS` contains an explicit version (e.g. `3.6.16`, `3.7.0`, `4.0.0`), use that.
- Otherwise, bump the **patch** number by one. E.g. current `3.6.15+302390` → new `3.6.16`.

Only the semver part (`MAJOR.MINOR.PATCH`) is your concern — `prepare_release.sh` preserves the build number. Validate the version matches `^\d+\.\d+\.\d+$` before continuing; if the user passed something that isn't a valid semver, stop and ask them to clarify.

Tell the user which version you're cutting before doing anything destructive.

## 2. Pre-flight checks

Before making changes, confirm the repo is in a sane state:

```bash
git status --porcelain
```

If there are uncommitted changes, stop and ask the user how to proceed — the release commit should only contain version + release notes updates, nothing else.

Also verify the tag doesn't already exist:

```bash
git tag -l <new-version>
```

If it does, stop and tell the user — this usually means the release was already cut.

## 3. Run prepare_release.sh

From the project root:

```bash
./prepare_release.sh <new-version>
```

This script:
- Rewrites the `version:` line in `pubspec.yaml` to `<new-version>+<existing-build>`
- Copies the version to the clipboard
- Moves the `Unreleased` entries in `release_notes.txt` under a new section headed with the version, leaving a fresh empty `Unreleased` at the top

If the script prints `No unreleased notes found — nothing to do.`, stop and ask the user whether to proceed anyway — usually you want notes in a release.

## 4. Sanity-check the diff

Run:

```bash
git status --porcelain
git diff pubspec.yaml release_notes.txt
```

Only `pubspec.yaml` and `release_notes.txt` should have changed. If anything else is modified, stop and show the user before continuing.

## 5. Commit

Stage only the two expected files and commit:

```bash
git add pubspec.yaml release_notes.txt
git commit -m "chore: release <new-version>"
```

Do **not** use `git add -A` — if the pre-flight check missed something, we don't want to accidentally sweep it into the release commit.

## 6. Tag the commit

Tags in this repo use bare semver (no `v` prefix — check recent tags with `git tag --sort=-creatordate | head` if unsure). Tag the commit you just made:

```bash
git tag <new-version>
```

## 7. Push

Push the branch and the tag to origin:

```bash
git push
git push origin <new-version>
```

## 8. Report back

Tell the user concisely:
- The version that was released
- The commit SHA that was tagged
- That the tag has been pushed

Mention any deviations (e.g. "no unreleased notes, proceeded anyway because you said so"). Keep it short — the user can see the commit and tag themselves.

## Failure handling

If any step fails partway through, stop and tell the user exactly what state the repo is in rather than trying to auto-recover. Reversing a release mid-flight usually requires judgement calls (e.g. `git reset`, `git tag -d`, force-push) that shouldn't be automated.
