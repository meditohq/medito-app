// This is the bundled example's analysis, not a required report schema.
const finite = Number.isFinite;
const number = (value) => finite(value) ? value.toLocaleString("en-US") : "Unavailable";
const signed = (value) => `${value > 0 ? "+" : ""}${number(value)}`;
export const rate = (value) => finite(value) ? `${(value * 100).toFixed(1)}%` : "Unavailable";

export function adoptionBrief(latest, previous, driverRows = [], segmentRows = [], accountRows = []) {
  const current = latest?.activeUsers;
  const prior = previous?.activeUsers;
  const change = finite(current) && finite(prior) ? current - prior : null;
  const target = latest?.targetUsers;
  const gap = finite(current) && finite(target) ? current - target : null;
  const title = !finite(current) ? "Active accounts are unavailable"
    : gap === null ? "Latest active accounts"
      : `Active accounts are ${gap > 0 ? "above" : gap < 0 ? "below" : "on"} plan`;
  const text = !finite(current)
    ? "The latest reviewed period has no active-account total. No growth or target comparison can be made."
    : `The week of ${latest.week} closed at **${number(current)} active accounts**`
      + (change === null ? ". No comparable earlier total is available."
        : `, ${signed(change)} versus ${previous.week}${prior > 0 ? ` (${signed(Number((change / prior * 100).toFixed(1)))}%)` : ""}.`)
      + (gap === null ? " The current operating target is unavailable."
        : ` That is ${number(Math.abs(gap))} ${gap >= 0 ? "above" : "below"} the ${number(target)} current-week target.`);
  const expected = ["Before", "Activation", "Expansion", "Churn", "After"];
  const rows = driverRows.filter((row) => row.week === latest?.week && expected.includes(row.driver));
  const values = Object.fromEntries(rows.map((row) => [row.driver, row.change]));
  const bridgeValid = change !== null && rows.length === expected.length
    && expected.every((key) => finite(values[key]) && rows.filter((row) => row.driver === key).length === 1)
    && values.Activation >= 0 && values.Expansion >= 0 && values.Churn <= 0
    && values.Before === prior && values.After === current
    && values.Activation + values.Expansion + values.Churn === change;
  const gross = values.Activation + values.Expansion;
  const bridgeText = bridgeValid
    ? `New activation added **${number(values.Activation)}** accounts and expansion added **${number(values.Expansion)}**; churn removed **${number(Math.abs(values.Churn))}**. `
      + `These recorded movements reconcile to ${signed(change)} net accounts.`
      + (gross > 0 && values.Churn < 0 ? ` Churn absorbed ${rate(-values.Churn / gross)} of gross additions, so acquisition alone is not the whole growth story.` : "")
    : "The available growth-driver rows do not reconcile to this period's comparable account totals. Resolve that gap before attributing the movement.";
  const segments = segmentRows.filter((row) => row.week === latest?.week
    && row.segment && row.segment !== "all");
  const comparableSegments = finite(current) && segments.every((row) => finite(row.retention)
    && row.retention >= 0 && row.retention <= 1 && finite(row.activeUsers) && row.activeUsers >= 0
    && finite(row.atRiskUsers) && row.atRiskUsers >= 0 && row.atRiskUsers <= row.activeUsers)
    && new Set(segments.map((row) => row.segment)).size === segments.length
    && segments.reduce((sum, row) => sum + row.activeUsers, 0) === current;
  const weakest = [...segments].sort((a, b) => a.retention - b.retention)[0];
  const totalRisk = segments.every((row) => finite(row.atRiskUsers))
    ? segments.reduce((sum, row) => sum + row.atRiskUsers, 0) : null;
  const uniqueLowest = weakest && segments.filter((row) => row.retention === weakest.retention).length === 1;
  const prioritySegment = comparableSegments && segments.length >= 2 && uniqueLowest ? weakest.segment : null;
  const accounts = accountRows.filter((row) => row.week === latest?.week && row.segment === prioritySegment
    && ["High", "Elevated"].includes(row.riskTier) && row.account && row.nextAction);
  const attention = prioritySegment
    ? `**${weakest.segment} merits the first retention review.** Its ${rate(weakest.retention)} retention is the lowest of the ${segments.length} reviewed segments`
      + (finite(weakest.atRiskUsers) && totalRisk > 0
        ? `, and it holds ${number(weakest.atRiskUsers)} of ${number(totalRisk)} flagged accounts (${rate(weakest.atRiskUsers / totalRisk)})` : "")
      + (accounts.length ? `. The source includes ${accounts.length} flagged ${weakest.segment} accounts and their recorded follow-ups; review those before deciding on an intervention.`
        : ". Obtain account-level renewal and engagement evidence before deciding on an intervention.")
      + " The segment comparison identifies where to investigate, not what caused the losses."
    : comparableSegments && segments.length >= 2 && !uniqueLowest
      ? "Several segments share the lowest retention. Compare their account-level risk and renewal evidence before choosing a priority."
      : "Comparable segment retention is unavailable or does not cover the current account total. Resolve the coverage gap before choosing where to intervene.";
  const conversionChange = finite(latest?.conversion) && finite(previous?.conversion)
    ? (latest.conversion - previous.conversion) * 100 : null;
  return { title, text: text.trim(), change, bridgeValid, bridgeText, attention, accounts,
    accountComparison: change === null || prior <= 0 ? "" : `${signed(Number((change / prior * 100).toFixed(1)))}%`,
    conversionComparison: conversionChange === null ? "" : `${conversionChange > 0 ? "+" : ""}${conversionChange.toFixed(1)} pp`,
    conversionDescription: `Activated accounts divided by qualified sign-ups. Previous comparable rate: ${rate(previous?.conversion)}.`,
    number };
}
