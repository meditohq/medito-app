import { refreshCoachmarkDomain as workspaceCookieDomain } from "./refresh-coachmark.js";

// A browser convenience, not identity or verification authority. Workspace Sites
// share a cookie; other origins retain their own local preference.
export const VERIFICATION_REMINDER_COOKIE = "data_app_verification_reminder_v1";
const maxAge = 400 * 24 * 60 * 60;

export function readVerificationReminderDismissed({ document = globalThis.document, location = globalThis.location, storage } = {}) {
  try {
    if (!workspaceCookieDomain(location)) return (storage ?? globalThis.localStorage)?.getItem(VERIFICATION_REMINDER_COOKIE) === "1";
    if (!document) return false;
    const values = document.cookie.split(";").map(value => value.trim())
      .filter(value => value.startsWith(`${VERIFICATION_REMINDER_COOKIE}=`));
    return values.length === 1 && values[0] === `${VERIFICATION_REMINDER_COOKIE}=1`;
  } catch { return false; }
}

export function rememberVerificationReminderDismissed({ document = globalThis.document, location = globalThis.location, storage } = {}) {
  try {
    const domain = workspaceCookieDomain(location);
    if (!domain) {
      const local = storage ?? globalThis.localStorage;
      local?.setItem(VERIFICATION_REMINDER_COOKIE, "1");
      return local?.getItem(VERIFICATION_REMINDER_COOKIE) === "1";
    }
    if (!document) return false;
    document.cookie = `${VERIFICATION_REMINDER_COOKIE}=1; Domain=${domain}; Path=/; Max-Age=${maxAge}; Secure; SameSite=Lax`;
    return readVerificationReminderDismissed({ document, location });
  } catch { return false; }
}
