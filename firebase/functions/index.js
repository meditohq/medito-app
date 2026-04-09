const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const {
  onNewFatalIssuePublished,
  onNewNonfatalIssuePublished,
  onNewAnrIssuePublished,
  onRegressionAlertPublished,
  onStabilityDigestPublished,
  onVelocityAlertPublished,
} = require("firebase-functions/v2/alerts/crashlytics");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const crypto = require("crypto");

// Store your secrets in Firebase:
//   firebase functions:secrets:set GITHUB_TOKEN
//   firebase functions:secrets:set WEBHOOK_SECRET
const githubToken = defineSecret("GITHUB_TOKEN");
const webhookSecret = defineSecret("WEBHOOK_SECRET");

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = "meditohq";
const GITHUB_REPO = "medito-app";

// ─── Helper: Verify HMAC signature ──────────────────────────────────────────
function verifySignature(secret, body, signatureHeader) {
  if (!signatureHeader) return false;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(typeof body === "string" ? body : JSON.stringify(body))
    .digest("hex");
  const signature = signatureHeader.replace(/^sha256=/, "");
  return crypto.timingSafeEqual(
    Buffer.from(expected, "hex"),
    Buffer.from(signature, "hex")
  );
}

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

// ─── Crashlytics Alert Triggers ──────────────────────────────────────────────
//
// These fire automatically when Firebase Crashlytics detects issues.
// No manual setup needed beyond deploying — Firebase routes alerts natively.

// New fatal crash
exports.onCrashlyticsFatalIssue = onNewFatalIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const issue = event.data.payload.issue;
    await triggerGitHubPR({
      title: `Fatal crash: ${issue.title}`,
      description: `${issue.subtitle}\n\nAffected version(s): ${event.data.payload.issue.appVersion || "unknown"}`,
      severity: "critical",
      source: "crashlytics",
      eventType: "new_fatal_issue",
      data: event.data.payload,
    });
  }
);

// New non-fatal issue
exports.onCrashlyticsNonfatalIssue = onNewNonfatalIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const issue = event.data.payload.issue;
    await triggerGitHubPR({
      title: `Non-fatal issue: ${issue.title}`,
      description: `${issue.subtitle}\n\nAffected version(s): ${issue.appVersion || "unknown"}`,
      severity: "medium",
      source: "crashlytics",
      eventType: "new_nonfatal_issue",
      data: event.data.payload,
    });
  }
);

// New ANR (Application Not Responding)
exports.onCrashlyticsAnrIssue = onNewAnrIssuePublished(
  { secrets: [githubToken] },
  async (event) => {
    const issue = event.data.payload.issue;
    await triggerGitHubPR({
      title: `ANR: ${issue.title}`,
      description: `${issue.subtitle}\n\nAffected version(s): ${issue.appVersion || "unknown"}`,
      severity: "high",
      source: "crashlytics",
      eventType: "new_anr_issue",
      data: event.data.payload,
    });
  }
);

// Regressed issue (was closed, came back)
exports.onCrashlyticsRegression = onRegressionAlertPublished(
  { secrets: [githubToken] },
  async (event) => {
    const issue = event.data.payload.issue;
    await triggerGitHubPR({
      title: `Regression: ${issue.title}`,
      description: `A previously closed issue has reappeared.\n\n${issue.subtitle}\n\nAffected version(s): ${issue.appVersion || "unknown"}`,
      severity: "critical",
      source: "crashlytics",
      eventType: "regression",
      data: event.data.payload,
    });
  }
);

// Stability digest (trending issues summary)
exports.onCrashlyticsStabilityDigest = onStabilityDigestPublished(
  { secrets: [githubToken] },
  async (event) => {
    const trendingIssues = event.data.payload.trendingIssues || [];
    const issueList = trendingIssues
      .map((i) => `- **${i.type}**: ${i.issue.title} (${i.eventCount} events, ${i.userCount} users)`)
      .join("\n");

    await triggerGitHubPR({
      title: `Stability digest: ${trendingIssues.length} trending issue(s)`,
      description: `Emerging issues causing a significant number of crashes:\n\n${issueList}`,
      severity: "high",
      source: "crashlytics",
      eventType: "stability_digest",
      data: event.data.payload,
    });
  }
);

// Velocity alert (sudden spike in crashes)
exports.onCrashlyticsVelocityAlert = onVelocityAlertPublished(
  { secrets: [githubToken] },
  async (event) => {
    const issue = event.data.payload.issue;
    const crashCount = event.data.payload.crashCount || "unknown";
    await triggerGitHubPR({
      title: `Crash spike: ${issue.title}`,
      description: `A sudden increase in crashes has been detected.\n\n${issue.subtitle}\n\nCrash count: ${crashCount}`,
      severity: "critical",
      source: "crashlytics",
      eventType: "velocity_alert",
      data: event.data.payload,
    });
  }
);

// ─── Firestore trigger: auto-create PR when a document is added ──────────────
//
// Any document created in "firebase_issues/{docId}" triggers a PR.
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

// ─── HTTP endpoint: generic webhook receiver ─────────────────────────────────
//
// Call this from any external service.
//
// POST https://<region>-<project>.cloudfunctions.net/webhookToGitHubPR
// Headers: X-Webhook-Signature: sha256=<HMAC hex digest>
// Body: { "title": "...", "description": "...", "severity": "critical", ... }
//
// Set the shared secret:
//   firebase functions:secrets:set WEBHOOK_SECRET
//
exports.webhookToGitHubPR = onRequest(
  {
    secrets: [githubToken, webhookSecret],
    cors: false,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Verify HMAC signature
    const secret = webhookSecret.value();
    if (!secret) {
      logger.error("WEBHOOK_SECRET is not configured");
      res.status(500).json({ error: "Server misconfiguration" });
      return;
    }

    const signature = req.get("X-Webhook-Signature");
    if (!verifySignature(secret, req.rawBody || req.body, signature)) {
      res.status(401).json({ error: "Invalid or missing signature" });
      return;
    }

    // Guard against missing/malformed body
    const body = req.body ?? {};
    const { title, description, severity, source, event_type, data } = body;

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
