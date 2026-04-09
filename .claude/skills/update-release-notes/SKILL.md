---
name: update-release-notes
description: Reads recent git commits and updates the Unreleased section of release_notes.txt with user-facing changes.
argument-hint: "[number-of-commits]"
---

Review recent git commits and update the `## Unreleased` section of `release_notes.txt` with any user-facing changes. $ARGUMENTS specifies how many recent commits to inspect (defaults to 20 if not provided).

**Permissions:** You may edit `release_notes.txt` only. Do not run `git commit` or `git push` — leave all changes uncommitted.

## Steps

### 1. Read current release notes

Read `release_notes.txt` to understand what is already in the `Unreleased` section so you do not add duplicate entries.

### 2. Get recent commits

Run:
```
git log --oneline -<N>
```
where `<N>` is the number provided in $ARGUMENTS, or 20 by default.

Then for each commit that looks potentially user-facing, inspect its diff:
```
git show <hash> --stat
```
and if needed:
```
git show <hash>
```

Focus on commits that touch `lib/`, `android/`, `ios/`, or `pubspec.yaml`. Skip commits that only touch tests, CI, build scripts, docs, or dependency lock files unless there is a clear user-facing reason.

### 3. Determine what is user-facing

Apply the rules from the project's release notes style:

**Add entries for:**
- New features or screens the user can interact with
- Visible UI changes (layout, colours, icons, animations)
- Performance improvements the user would feel (faster loads, smoother scrolling)
- Bug fixes that were noticeably breaking the user experience
- Accessibility improvements

**Do NOT add entries for:**
- Refactors, architecture changes, code cleanup
- Test changes or CI/CD changes
- Dependency bumps (unless a direct user-facing fix comes with them)
- Internal configuration changes
- Anything already listed in the `Unreleased` section

### 4. Write the entries

For each user-facing change found:
- Write one short line in plain English from the user's perspective
- Focus on what the user can now *do* or what feels *better* — not what changed in code
- No jargon, no technical terms
- No version numbers

Good examples:
- `Classic purple theme is now available on Android`
- `App icons refreshed on iOS`
- `Fixed a crash when opening the player`

Bad examples (do not write):
- `Bring classic purple to android` ← this is a commit message, not user copy
- `Refactored ThemeService to support multiple palettes`
- `Updated pubspec.yaml`

### 5. Update release_notes.txt

Replace the `Unreleased` section's content (the lines after `Unreleased` and before the first versioned section) with the new entries. If no user-facing changes are found, leave the file unchanged and say so.

The file format is:
```
Unreleased
- Entry one
- Entry two

3.x.x
- ...
```

Keep the existing entries that are already there — only add new ones, do not remove or rewrite existing entries.

## Output

After editing, summarise what you added (or explain why nothing was added). Keep it brief.
