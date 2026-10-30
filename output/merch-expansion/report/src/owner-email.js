// Sites owner configuration and authenticated visitors use the same normalized email.
export function normalizeOwnerEmail(value) {
  if (typeof value !== "string" || /\p{Cc}/u.test(value)) return null;
  const email = value.trim().toLowerCase();
  return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(email) ? email : null;
}
