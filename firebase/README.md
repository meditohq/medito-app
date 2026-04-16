# Firebase → GitHub Issues

Automatically create GitHub Issues from Firebase Crashlytics alerts, Firestore events, or any custom webhook trigger.

## Architecture

```
Crashlytics alert (fatal, ANR, regression, velocity, digest)
  ↓
Cloud Function (native alert trigger)
  ↓
Creates GitHub Issue (with labels + details)
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
   - **Issues**: Read and Write
3. Copy the token

### 2. Store secrets in Firebase

```bash
# GitHub PAT (required — used to create issues)
firebase functions:secrets:set GITHUB_TOKEN --project medito-9165c

# Shared secret for HTTP webhook (only needed for webhookToGitHubPR)
firebase functions:secrets:set WEBHOOK_SECRET --project medito-9165c
```

### 3. Create GitHub labels (one-time)

The Cloud Function labels issues with `firebase-alert` and a severity tag. Create these labels in your repo:

- `firebase-alert`
- `critical`
- `high`
- `medium`
- `low`

### 4. Deploy the Cloud Functions

```bash
cd firebase/functions
npm install
firebase deploy --only functions --project medito-9165c
```

After deploying, the Crashlytics triggers are active immediately.

### 5. Test it

**Option A — Wait for a real Crashlytics alert** (the triggers fire automatically).

**Option B — Via the HTTP endpoint (requires HMAC signature):**

```bash
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

## What gets created

For each Firebase alert, you get a **GitHub Issue** with:
- Title matching the alert
- Labels: `firebase-alert` + severity (`critical`, `high`, etc.)
- Full alert details in the body
- Link to Firebase Console

## Files

- `firebase/functions/index.js` — Cloud Functions (Crashlytics triggers + Firestore trigger + HTTP endpoint)
- `firebase/functions/package.json` — Node.js dependencies
- `firebase.json` — Firebase project config pointing to functions source
