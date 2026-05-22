#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBSPEC="$SCRIPT_DIR/pubspec.yaml"

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=1
            ;;
        -*)
            echo "✗ Unknown flag: $arg" >&2
            exit 1
            ;;
        *)
            echo "✗ Unexpected positional argument: $arg" >&2
            echo "  prepare_release.sh now derives the version itself from today's date." >&2
            echo "  Drop the argument and rerun. Use --force to override drift detection." >&2
            exit 1
            ;;
    esac
done

# Compare two YYMM.D tuples. Echoes -1 / 0 / 1 for a<b / a==b / a>b.
cmp_date() {
    local a="$1" b="$2"
    local IFS=.
    local -a aa=($a) bb=($b)
    for i in 0 1; do
        if [ "${aa[$i]}" -lt "${bb[$i]}" ]; then echo -1; return; fi
        if [ "${aa[$i]}" -gt "${bb[$i]}" ]; then echo 1; return; fi
    done
    echo 0
}

TODAY="$(date +%y%m.%-d)"

# Find the latest date-shaped tag by numeric tuple. Tags use the YYMM.D[.N]
# shape; older YY.M.D tags from before the format change are ignored.
LATEST_TAG=""
LATEST_KEY=""
while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    [[ "$tag" =~ ^[0-9]{4}\.[0-9]+(\.[0-9]+)?$ ]] || continue
    # Build a zero-padded sort key: YYYY DDD NNN
    IFS=. read -r tym td tn <<<"$tag"
    [ -z "$tn" ] && tn=0
    key=$(printf "%04d%03d%03d" "$tym" "$td" "$tn")
    if [ -z "$LATEST_KEY" ] || [ "$key" \> "$LATEST_KEY" ]; then
        LATEST_KEY="$key"
        LATEST_TAG="$tag"
    fi
done < <(git tag --list '[0-9][0-9][0-9][0-9].[0-9]*')

if [ -n "$LATEST_TAG" ]; then
    LATEST_DATE="$(echo "$LATEST_TAG" | cut -d. -f1-2)"
else
    LATEST_DATE=""
fi

# Decide BASE date for the new version.
if [ -z "$LATEST_DATE" ]; then
    BASE="$TODAY"
else
    case "$(cmp_date "$LATEST_DATE" "$TODAY")" in
        1)
            if [ "$FORCE" -ne 1 ]; then
                echo "✗ Latest tag $LATEST_TAG is ahead of today ($TODAY)." >&2
                echo "  This usually means a previous release used the wrong date." >&2
                echo "  Rerun with --force to add a same-day suffix on top of $LATEST_DATE." >&2
                exit 1
            fi
            BASE="$LATEST_DATE"
            ;;
        0)
            BASE="$LATEST_DATE"
            ;;
        -1)
            BASE="$TODAY"
            ;;
    esac
fi

# Find the next .N suffix for BASE. First release of the day is .0; reissues bump to .1, .2, ...
# Flutter's pubspec parser rejects 2-component versions, so the bare "$BASE" form is never emitted.
MAX_SUFFIX=-1
while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    n="${tag#${BASE}.}"
    case "$n" in
        ''|*[!0-9]*) continue ;;
    esac
    if [ "$n" -gt "$MAX_SUFFIX" ]; then
        MAX_SUFFIX="$n"
    fi
done < <(git tag --list "${BASE}.*")

NEW_VERSION="${BASE}.$((MAX_SUFFIX + 1))"

if ! [[ "$NEW_VERSION" =~ ^[0-9]{4}\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✗ Computed version $NEW_VERSION does not match expected shape" >&2
    exit 1
fi

if [ -n "$(git tag -l "$NEW_VERSION")" ]; then
    echo "✗ Tag $NEW_VERSION already exists — refusing to overwrite" >&2
    exit 1
fi

echo "✓ Computed version: $NEW_VERSION"

BUILD_NUMBER=$(grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f2)
sed -i '' "s/^version: .*/version: $NEW_VERSION+$BUILD_NUMBER/" "$PUBSPEC"
echo "✓ pubspec.yaml updated to $NEW_VERSION+$BUILD_NUMBER"

VERSION="$NEW_VERSION"

# Copy to clipboard
echo -n "$VERSION" | pbcopy
echo "✓ Version $VERSION copied to clipboard"

# Reorganise release_notes.txt
NOTES_FILE="$SCRIPT_DIR/release_notes.txt"

python3 - "$NOTES_FILE" "$VERSION" <<'EOF'
import sys

path = sys.argv[1]
version = sys.argv[2]

with open(path) as f:
    content = f.read()

lines = content.splitlines()

unreleased_lines = []
rest_lines = []
in_unreleased = False
found_end = False

for line in lines:
    if not found_end:
        if line.strip() == "Unreleased":
            in_unreleased = True
            continue
        if in_unreleased:
            if line and not line.startswith("-") and not line.startswith(" "):
                found_end = True
                rest_lines.append(line)
            else:
                if line.startswith("-"):
                    unreleased_lines.append(line)
            continue
    else:
        rest_lines.append(line)

unreleased_lines = [l for l in unreleased_lines if l.strip() != "-"]

if not unreleased_lines:
    print("No unreleased notes found — nothing to do.")
    sys.exit(0)

new_content = (
    "Unreleased\n-\n\n"
    + version + "\n"
    + "\n".join(unreleased_lines) + "\n\n"
    + "\n".join(rest_lines)
).rstrip() + "\n"

with open(path, "w") as f:
    f.write(new_content)

print(f"✓ release_notes.txt updated — unreleased notes moved to {version}")
EOF
