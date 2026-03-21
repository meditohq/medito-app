const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");

// Store your GitHub PAT in Firebase secrets:
//   firebase functions:secrets:set GITHUB_TOKEN
const githubToken = defineSecret("GITHUB_TOKEN");

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = "meditohq";
const GITHUB_REPO = "medito-app";

// ─── Helper: Trigger GitHub repository_dispatch ──────────────────────────────
async function triggerGitHubPR({ title, description, severity, source, eventType, data }) {
  const token = githubToken.value();
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches`;

  const payload = {
    event_type: "firebase-alert",
    client_payload: {
      title: title || "Untitled Firebase Alert",
      description: description || "",
      severity: severity || "medium",
      source: source || "firebase",
      event_type: eventType || "unknown",
      timestamp: new Date().toISOString(),
      data: data || {},
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GitHub API error ${response.status}: ${body}`);
  }

  logger.info("GitHub repository_dispatch triggered", { title, severity });
}

// ─── 1. Firestore trigger: auto-create PR when a document is added ───────────
//
// Example: any document created in "firebase_issues/{docId}" triggers a PR.
// Adjust the collection path to match your Firestore structure.
//
exports.onFirestoreIssueCreated = onDocumentCreated(
  {
    document: "firebase_issues/{docId}",
    secrets: [githubToken],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("No data in Firestore event");
      return;
    }

    const doc = snap.data();

    await triggerGitHubPR({
      title: doc.title || `Firestore issue: ${event.params.docId}`,
      description: doc.description || "",
      severity: doc.severity || "medium",
      source: "firestore",
      eventType: "document_created",
      data: doc,
    });
  }
);

// ─── 2. HTTP endpoint: generic webhook receiver ──────────────────────────────
//
// Call this from Firebase Alerts, Crashlytics hooks, or any external service.
//
// POST https://<region>-<project>.cloudfunctions.net/webhookToGitHubPR
// Body: { "title": "...", "description": "...", "severity": "critical", ... }
//
exports.webhookToGitHubPR = onRequest(
  {
    secrets: [githubToken],
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const { title, description, severity, source, event_type, data } = req.body;

    if (!title) {
      res.status(400).json({ error: "Missing required field: title" });
      return;
    }

    try {
      await triggerGitHubPR({
        title,
        description,
        severity,
        source,
        eventType: event_type,
        data,
      });
      res.status(200).json({ success: true, message: "GitHub PR workflow triggered" });
    } catch (err) {
      logger.error("Failed to trigger GitHub PR", err);
      res.status(500).json({ error: err.message });
    }
  }
);
