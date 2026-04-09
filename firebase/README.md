# Firebase Webhook → GitHub PR

Automatically create GitHub Pull Requests from Firebase Crashlytics alerts, Firestore events, or any custom webhook trigger.

## Architecture

```
Crashlytics alert (fatal, ANR, regression, velocity, digest)
  ↓
Cloud Function (native alert trigger)
  ↓
GitHub repository_dispatch API
  ↓
GitHub Action workflow
  ↓
New branch + PR created automatically
```

## Crashlytics Triggers

These fire **automatically** after deployment — no manual wiring needed:

| Function | Fires when | Severity |
|----------|-----------|----------|
| `onCrashlyticsFatalIssue` | New fatal crash detected | critical |
| `onCrashlyticsNonfatalIssue` | New non-fatal issue detected | medium |
| `onCrashlyticsAnrIssue` | New ANR (App Not Responding) | high |
| `onCrashlyticsRegression` | A closed issue reappears in a new version | critical |
| `onCrashlyticsStabilityDigest` | Trending/emerging issues summary | high |
| `onCrashlyticsVelocityAlert` | Sudden spike in crash rate | critical |

## Setup

### 1. Create a GitHub Personal Access Token (PAT)

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token with these permissions on `meditohq/medito-app`:
   - **Contents**: Read and Write
3. Copy the token

### 2. Store secrets in Firebase

```bash
# GitHub PAT (required for all triggers)
firebase functions:secrets:set GITHUB_TOKEN --project medito-9165c

# Shared secret for HTTP webhook (only needed for webhookToGitHubPR)
firebase functions:secrets:set WEBHOOK_SECRET --project medito-9165c
```

### 3. Deploy the Cloud Functions

```bash
cd firebase/functions
npm install
firebase deploy --only functions --project medito-9165c
```

After deploying, the Crashlytics triggers are active immediately. Any new crash, ANR, regression, or velocity alert from Crashlytics will automatically create a GitHub PR.

### 4. Test it

**Option A — Wait for a real Crashlytics alert** (the triggers fire automatically).

**Option B — Via the HTTP endpoint (requires HMAC signature):**

```bash
# Generate signature
SECRET="your-webhook-secret"
BODY='{"title":"Test alert","description":"Testing the pipeline","severity":"low","source":"manual-test","event_type":"test"}'
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

curl -X POST \
  https://<REGION>-medito-9165c.cloudfunctions.net/webhookToGitHubPR \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Signature: sha256=$SIGNATURE" \
  -d "$BODY"
```

**Option C — Via Firestore (auto-trigger):**

Add a document to the `firebase_issues` collection in Firestore:

```json
{
  "title": "Performance degradation in meditation player",
  "description": "Average load time increased by 200ms",
  "severity": "high"
}
```

**Option D — Test with GitHub API directly (bypasses Cloud Functions):**

```bash
curl -X POST \
  https://api.github.com/repos/meditohq/medito-app/dispatches \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer <YOUR_GITHUB_TOKEN>" \
  -d '{
    "event_type": "firebase-alert",
    "client_payload": {
      "title": "Test: Firebase webhook PR",
      "description": "Testing the webhook-to-PR pipeline",
      "severity": "low",
      "source": "manual-test",
      "event_type": "test"
    }
  }'
```

## Payload Schema (HTTP endpoint)

| Field         | Type   | Required | Description                              |
|---------------|--------|----------|------------------------------------------|
| `title`       | string | Yes      | Short title for the PR                   |
| `description` | string | No       | Detailed description of the issue        |
| `severity`    | string | No       | `critical`, `high`, `medium`, or `low`   |
| `source`      | string | No       | Origin (e.g., `crashlytics`, `firestore`)|
| `event_type`  | string | No       | Type of event (e.g., `crash_spike`)      |
| `data`        | object | No       | Any additional structured data           |

## Files

- `.github/workflows/firebase-webhook-pr.yml` — GitHub Action that creates the PR
- `firebase/functions/index.js` — Cloud Functions (Crashlytics triggers + Firestore trigger + HTTP endpoint)
- `firebase/functions/package.json` — Node.js dependencies
- `firebase.json` — Firebase project config pointing to functions source
