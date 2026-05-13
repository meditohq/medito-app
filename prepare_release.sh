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

# Compare two YY.M.D tuples. Echoes -1 / 0 / 1 for a<b / a==b / a>b.
cmp_date() {
    local a="$1" b="$2"
    local IFS=.
    local -a aa=($a) bb=($b)
    for i in 0 1 2; do
        if [ "${aa[$i]}" -lt "${bb[$i]}" ]; then echo -1; return; fi
        if [ "${aa[$i]}" -gt "${bb[$i]}" ]; then echo 1; return; fi
    done
    echo 0
}

TODAY="$(date +%y.%-m.%-d)"

# Find the most recent date-shaped tag. Only the YY.M.D portion drives the
# drift detector — any re-cut suffix (legacy .N or current -rN) is stripped.
LATEST_TAG=""
LATEST_DATE=""
LATEST_DATE_KEY=""
while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    [[ "$tag" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.[0-9]+|-r[0-9]+)?$ ]] || continue
    ty="${BASH_REMATCH[1]}"
    tm="${BASH_REMATCH[2]}"
    td="${BASH_REMATCH[3]}"
    key=$(printf "%03d%03d%03d" "$ty" "$tm" "$td")
    if [ -z "$LATEST_DATE_KEY" ] || [ "$key" \> "$LATEST_DATE_KEY" ]; then
        LATEST_DATE_KEY="$key"
        LATEST_DATE="${ty}.${tm}.${td}"
        LATEST_TAG="$tag"
    fi
done < <(git tag --list '[0-9]*.[0-9]*.[0-9]*')

# Decide BASE date for the new version.
if [ -z "$LATEST_DATE" ]; then
    BASE="$TODAY"
else
    case "$(cmp_date "$LATEST_DATE" "$TODAY")" in
        1)
            if [ "$FORCE" -ne 1 ]; then
                echo "✗ Latest tag $LATEST_TAG is ahead of today ($TODAY)." >&2
                echo "  This usually means a previous release used the wrong date." >&2
                echo "  Rerun with --force to add a re-cut suffix on top of $LATEST_DATE." >&2
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

# Count prior cuts for BASE so the new tag picks the next index:
#   BASE itself      → cut #1
#   BASE.N (legacy)  → cut #(N+1)   — e.g. 26.5.2.1 was the 2nd cut of 26.5.2
#   BASE-rN          → cut #N
# The pubspec version is always the 3-part BASE; the re-cut index lives on
# the git tag only, since Flutter rejects 4-part pubspec versions.
HIGHEST_CUT=0
base_re="${BASE//./\\.}"
while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    if [ "$tag" = "$BASE" ]; then
        idx=1
    elif [[ "$tag" =~ ^${base_re}\.([0-9]+)$ ]]; then
        idx=$(( ${BASH_REMATCH[1]} + 1 ))
    elif [[ "$tag" =~ ^${base_re}-r([0-9]+)$ ]]; then
        idx="${BASH_REMATCH[1]}"
    else
        continue
    fi
    if [ "$idx" -gt "$HIGHEST_CUT" ]; then
        HIGHEST_CUT="$idx"
    fi
done < <(git tag --list "${BASE}" "${BASE}.*" "${BASE}-r*")

NEXT_CUT=$(( HIGHEST_CUT + 1 ))
PUBSPEC_VERSION="$BASE"
if [ "$NEXT_CUT" -eq 1 ]; then
    TAG_NAME="$BASE"
else
    TAG_NAME="${BASE}-r${NEXT_CUT}"
fi

if ! [[ "$PUBSPEC_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "✗ Computed pubspec version $PUBSPEC_VERSION does not match expected shape" >&2
    exit 1
fi

if [ -n "$(git tag -l "$TAG_NAME")" ]; then
    echo "✗ Tag $TAG_NAME already exists — refusing to overwrite" >&2
    exit 1
fi

echo "✓ Pubspec version: $PUBSPEC_VERSION"
echo "✓ Git tag:         $TAG_NAME"

# Bump the build number — app stores require a monotonic build integer.
OLD_BUILD=$(grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f2)
NEW_BUILD=$((OLD_BUILD + 1))
sed -i '' "s/^version: .*/version: ${PUBSPEC_VERSION}+${NEW_BUILD}/" "$PUBSPEC"
echo "✓ pubspec.yaml updated to ${PUBSPEC_VERSION}+${NEW_BUILD} (build ${OLD_BUILD} → ${NEW_BUILD})"

VERSION="$TAG_NAME"

# Copy the tag name to clipboard for use in commit messages, etc.
echo -n "$VERSION" | pbcopy
echo "✓ Tag $VERSION copied to clipboard"

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
