---
name: release
description: Cuts a new release of the Medito Flutter app — bumps the version in pubspec.yaml, runs prepare_release.sh to reorganise release_notes.txt, commits the changes, tags the commit, and pushes everything to origin. Use this whenever the user says "release", "cut a release", "release 3.x.x", "ship a new version", "tag a release", or otherwise indicates they want to publish a new version, even if they don't explicitly mention every step.
argument-hint: "[version]"
---

Cut a new release of the Medito app. Follow the steps below in order — each step assumes the previous one succeeded.

## 1. Decide the new version

Version names are **date-based**: `YY.M.D` (two-digit year, unpadded month, unpadded day — e.g. today's release would be `26.4.22`). If a release already exists for today, the script appends `.N` starting at `.1` (e.g. `26.4.22.1`, then `.2`, etc.).

You no longer compute the version yourself or pass `$ARGUMENTS` through — `prepare_release.sh` derives it from `date` and existing git tags in step 4. If the user passed an explicit version in `$ARGUMENTS`, tell them the script now auto-derives and ask whether they actually want to override; only proceed with `--force` if they confirm.

Before continuing, fetch tags so the script sees what's already shipped:

```bash
git fetch --tags
```

If the latest existing tag is ahead of today's date (e.g. last tag is `26.5.6` but today is `26.5.2`), the script will refuse to run without `--force`. That's the drift detector — surface the message to the user verbatim and only re-run with `--force` after explicit approval. With `--force` the script keeps the latest tag's date as the base and bumps the `.N` suffix.

Tell the user that the version will be derived in step 4 before doing anything destructive.

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
./prepare_release.sh
```

This script:
- Computes the new version from today's date and existing git tags (echoes `Computed version: <new-version>`)
- Refuses to run if the latest tag is ahead of today's date — pass `--force` only after the user has acknowledged the drift
- Rewrites the `version:` line in `pubspec.yaml` to `<new-version>+<existing-build>`
- Copies the version to the clipboard
- Moves the `Unreleased` entries in `release_notes.txt` under a new section headed with the version, leaving a fresh empty `Unreleased` at the top

After it runs, read the new version back from `pubspec.yaml` (`grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1`) so later steps can reference it.

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

## 9. Choose deploy tracks and dispatch the workflow

The `Build & Deploy` workflow (`.github/workflows/release.yml`) is **`workflow_dispatch`-only** — pushing the tag does not auto-deploy. After the tag is pushed, ask the user which tracks to ship to using `AskUserQuestion`:

- **Android**: `internal`, `production`, `both`, or `none`
- **iOS**: `testflight`, `appstore`, `both`, or `none`

Then trigger the workflow against the new tag with the chosen inputs:

```bash
gh workflow run release.yml \
  --ref <new-version> \
  -f android_internal=<true|false> \
  -f android_production=<true|false> \
  -f ios_testflight=<true|false> \
  -f ios_appstore=<true|false> \
  -f paywall_env=live \
  -f match_readonly=true
```

If the user chooses `none` for both platforms, skip the dispatch entirely and just report the tag was pushed without a build.

After dispatching, surface the run URL with `gh run list --workflow=release.yml --limit 1 --json url,databaseId` so the user can click through.

## 10. Report back

Tell the user concisely:
- The version that was released
- The commit SHA that was tagged
- That the tag has been pushed
- Which tracks were dispatched (or that no build was kicked off)
- The Actions run URL if a build was dispatched

Mention any deviations (e.g. "no unreleased notes, proceeded anyway because you said so"). Keep it short — the user can see the commit and tag themselves.

## Failure handling

If any step fails partway through, stop and tell the user exactly what state the repo is in rather than trying to auto-recover. Reversing a release mid-flight usually requires judgement calls (e.g. `git reset`, `git tag -d`, force-push) that shouldn't be automated.
