#!/usr/bin/env python3
"""Run the shared watch projection fixtures against the production Swift/Kotlin.

Requires Swift, Kotlin/JDK, and an org.json JAR (pass --json-jar or use Gradle cache).
Outputs go to a temporary directory; no watch simulator or signing is needed.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--json-jar", type=Path)
args = parser.parse_args()
jars = sorted((Path.home() / ".gradle/caches/modules-2/files-2.1/org.json/json").glob("*/*/json-*.jar"))
jar = args.json_jar or (jars[-1] if jars else None)
if jar is None:
    parser.error("provide --json-jar with an org.json JAR")
fixtures = root / "test/watch_progress/fixtures.json"
with tempfile.TemporaryDirectory(prefix="medito-watch-tests-") as work:
    work = Path(work)
    # The enum is pure Foundation code in the same compilation unit as WatchStore.
    source = (root / "ios/MeditoWatch/WatchStore.swift").read_text()
    (work / "WatchProgress.swift").write_text("import Foundation\nimport zlib\n" + source[source.index("enum WatchProgress {"):])
    subprocess.run(["swiftc", "-module-cache-path", str(work / "modules"), str(work / "WatchProgress.swift"),
        str(root / "test/watch_progress/main.swift"), "-o", str(work / "swift-tests")], check=True)
    subprocess.run([str(work / "swift-tests"), str(fixtures)], check=True)
    subprocess.run(["kotlinc", str(root / "android/wear/src/main/kotlin/meditofoundation/medito/wear/WatchProgress.kt"),
        str(root / "test/watch_progress/WatchProgressTest.kt"), "-cp", str(jar), "-include-runtime", "-d", str(work / "kotlin-tests.jar")], check=True)
    subprocess.run(["java", "-cp", f"{work / 'kotlin-tests.jar'}:{jar}",
        "meditofoundation.medito.wear.WatchProgressTestKt", str(fixtures)], check=True)
