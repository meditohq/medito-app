#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBSPEC="$SCRIPT_DIR/pubspec.yaml"

# If a version argument is provided, update pubspec.yaml
if [ -n "$1" ]; then
    NEW_VERSION="$1"
    BUILD_NUMBER=$(grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f2)
    sed -i '' "s/^version: .*/version: $NEW_VERSION+$BUILD_NUMBER/" "$PUBSPEC"
    echo "✓ pubspec.yaml updated to $NEW_VERSION+$BUILD_NUMBER"
fi

# Get version from pubspec.yaml (strip build number)
VERSION=$(grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f1)

# Copy to clipboard
echo -n "$VERSION" | pbcopy
echo "✓ Version $VERSION copied to clipboard"

# Reorganise RELEASE_NOTES.txt
NOTES_FILE="$SCRIPT_DIR/RELEASE_NOTES.txt"

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

print(f"✓ RELEASE_NOTES.txt updated — unreleased notes moved to {version}")
EOF
