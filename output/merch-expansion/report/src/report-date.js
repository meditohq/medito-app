// Report dates describe an edition, not presentation edits. An explicit cutoff
// must be a calendar date; generatedAt is only a preparation-time fallback.
export function reportDateMetadata({ asOf, generatedAt } = {}) {
  if (typeof asOf === "string" && /^\d{4}-\d{2}-\d{2}$/u.test(asOf)) {
    const date = new Date(`${asOf}T00:00:00Z`);
    if (!Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === asOf)
      return { label: "As of", value: asOf, date, timeZone: "UTC" };
  }
  if (!generatedAt) return null;
  const date = new Date(generatedAt);
  return Number.isNaN(date.valueOf()) ? null : { label: "Prepared", value: generatedAt, date };
}
