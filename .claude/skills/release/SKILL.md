---
name: release
description: Cuts a new release of the Medito Flutter app — bumps the version in pubspec.yaml, runs prepare_release.sh to reorganise release_notes.txt, commits the changes, tags the commit, and pushes everything to origin. Use this whenever the user says "release", "cut a release", "release 3.x.x", "ship a new version", "tag a release", or otherwise indicates they want to publish a new version, even if they don't explicitly mention every step.
argument-hint: "[version]"
---

Cut a new release of the Medito app. Follow the steps below in order — each step assumes the previous one succeeded.

## 1. Decide the new version

Read the current version from `pubspec.yaml` (the `version:` line, format `YY.M.D[.N]+BUILD`).

Version names are **date-based**: `YY.M.D` (two-digit year, unpadded month, unpadded day — e.g. today's release would be `26.4.22`). If a release already exists for today, append `.N` starting at `.1` (e.g. `26.4.22.1`, then `.2`, etc.).

- If `$ARGUMENTS` contains an explicit version, use that. Validate it matches `^\d+\.\d+\.\d+(\.\d+)?$`.
- Otherwise, derive from today's date (`date +%y.%-m.%-d`). If `git tag -l <date>` already exists, try `<date>.1`, `<date>.2`, … until you find an unused one.

Only the version-name part is your concern — `prepare_release.sh` preserves the build number.

Tell the user which version you're cutting before doing anything destructive.

## 2. Pre-flight checks

Before making changes, confirm the repo is in a sane state:

```bash
git status --porcelain
```

If the worktree has any changes (modified, staged, or untracked), **show the user the full output and ask them to confirm before proceeding**. Don't block outright — untracked files like new skills or scratch notes can't end up in the release commit anyway (step 5 only stages `pubspec.yaml` and `release_notes.txt` explicitly). But the user should eyeball the list in case something important is lurking.

Also verify the tag doesn't already exist:

```bash
git tag -l <new-version>
```

If it does, stop and tell the user — this usually means the release was already cut.

## 3. Draft the release notes and have the user review them

The `Unreleased` section of `release_notes.txt` is what `prepare_release.sh` will move under the new version heading, so it needs to be accurate *before* step 4 runs. Don't skip this — shipping stale or empty release notes is the most common way this workflow goes wrong.

Invoke the `update-release-notes` skill (via the Skill tool) to populate `Unreleased` from recent commits. You can pass a commit count via arguments if the user mentioned one; otherwise let it use its default.

After that skill finishes, show the user the current `Unreleased` section (e.g. read `release_notes.txt` and quote the block) and ask them to confirm or edit before moving on. Wait for explicit approval — don't proceed to step 4 on silence.

If the user wants changes, either apply them yourself based on their feedback or let them edit the file directly and confirm when ready. Only continue once they've signed off on the notes.

## 4. Run prepare_release.sh and bump the build number

From the project root:

```bash
./prepare_release.sh <new-version>
```

This script:
- Rewrites the `version:` line in `pubspec.yaml` to `<new-version>+<existing-build>`
- Copies the version to the clipboard
- Moves the `Unreleased` entries in `release_notes.txt` under a new section headed with the version, leaving a fresh empty `Unreleased` at the top

If the script prints `No unreleased notes found — nothing to do.`, stop and ask the user whether to proceed anyway — usually you want notes in a release.

**Then bump the build number.** The build number (the integer after `+` in the `version:` line) must increment by exactly 1 on every release — `prepare_release.sh` preserves the existing build number, so you need to bump it yourself afterwards.

```bash
# Read current build, add 1, replace in pubspec.yaml
OLD_BUILD=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
NEW_BUILD=$((OLD_BUILD + 1))
sed -i '' "s/^version: .*/version: <new-version>+$NEW_BUILD/" pubspec.yaml
```

Confirm the result with `grep "^version:" pubspec.yaml` before continuing. E.g. `3.6.15+302390` → `3.6.16+302391`.

## 5. Sanity-check the diff

Run:

```bash
git status --porcelain
git diff pubspec.yaml release_notes.txt
```

Only `pubspec.yaml` and `release_notes.txt` should have changed. If anything else is modified, stop and show the user before continuing.

## 6. Commit

Stage only the two expected files and commit:

```bash
git add pubspec.yaml release_notes.txt
git commit -m "chore: release <new-version>"
```

Do **not** use `git add -A` — if the pre-flight check missed something, we don't want to accidentally sweep it into the release commit.

## 7. Tag the commit

Tags in this repo use bare semver (no `v` prefix — check recent tags with `git tag --sort=-creatordate | head` if unsure). Tag the commit you just made:

```bash
git tag <new-version>
```

## 8. Push

Push the branch and the tag to origin:

```bash
git push
git push origin <new-version>
```

## 9. Report back

Tell the user concisely:
- The version that was released
- The commit SHA that was tagged
- That the tag has been pushed

Mention any deviations (e.g. "no unreleased notes, proceeded anyway because you said so"). Keep it short — the user can see the commit and tag themselves.

## Failure handling

If any step fails partway through, stop and tell the user exactly what state the repo is in rather than trying to auto-recover. Reversing a release mid-flight usually requires judgement calls (e.g. `git reset`, `git tag -d`, force-push) that shouldn't be automated.
