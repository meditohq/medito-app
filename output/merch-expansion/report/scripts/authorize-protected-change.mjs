import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { digestProtectedFile } from "./protected-file-digest.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const argumentsList = process.argv.slice(2);
const scopes = [];
let reason = "";

for (let index = 0; index < argumentsList.length; index += 1) {
  if (argumentsList[index] === "--scope") {
    scopes.push(argumentsList[index + 1] ?? "");
    index += 1;
  } else if (argumentsList[index] === "--reason") {
    reason = argumentsList[index + 1] ?? "";
    index += 1;
  }
}

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

if (!argumentsList.includes("--confirmed") || process.env.DATA_APP_USER_CONFIRMED !== "1") {
  fail("A protected Data app change requires an explicit user request or approval; the request itself is sufficient authorization.");
} else if (!scopes.length || !reason.trim()) {
  fail("Confirmed protected changes require at least one --scope and an explicit --reason.");
} else {
  const manifest = JSON.parse(readFileSync(join(root, "protected-runtime.json"), "utf8"));
  const uniqueScopes = [...new Set(scopes)];
  const invalidScopes = uniqueScopes.filter((scope) => !Object.hasOwn(manifest.files, scope));
  if (invalidScopes.length) {
    fail(`Requested protected-change scope is not a protected runtime file: ${invalidScopes.join(", ")}`);
  } else {
    const changed = Object.entries(manifest.files).flatMap(([path, expected]) => {
      const absolute = join(root, path);
      if (!existsSync(absolute)) {
        fail(`Protected runtime files cannot be removed by scoped authorization: ${path}`);
        return [path];
      }
      try {
        const actual = digestProtectedFile(path, readFileSync(absolute));
        return actual === expected ? [] : [path];
      } catch (error) {
        fail(error instanceof Error ? error.message : String(error));
        return [path];
      }
    });
    const unapproved = changed.filter((path) => !uniqueScopes.includes(path));
    const unchanged = uniqueScopes.filter((path) => !changed.includes(path));
    if (unapproved.length) {
      fail(`Unrelated protected runtime changes are not authorized: ${unapproved.join(", ")}`);
    } else if (unchanged.length) {
      fail(`Confirmed protected-change scope contains unchanged files: ${unchanged.join(", ")}`);
    } else if (!process.exitCode) {
      const update = spawnSync(
        process.execPath,
        [join(root, "scripts/verify-protected-runtime.mjs"), "--update", "--maintainer"],
        {
          cwd: root,
          encoding: "utf8",
          env: { ...process.env, DATA_APP_MAINTAINER: "1" },
        },
      );
      if (update.status !== 0) {
        fail(update.stderr || update.stdout || "Unable to update the authorized protected runtime.");
      } else {
        process.stdout.write(update.stdout);
        console.log(`User-confirmed protected change authorized only for: ${uniqueScopes.join(", ")}.`);
      }
    }
  }
}
