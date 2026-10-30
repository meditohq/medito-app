export const dataAppScheduleDays = [
  { value: "MO", label: "Monday", short: "M" },
  { value: "TU", label: "Tuesday", short: "T" },
  { value: "WE", label: "Wednesday", short: "W" },
  { value: "TH", label: "Thursday", short: "T" },
  { value: "FR", label: "Friday", short: "F" },
  { value: "SA", label: "Saturday", short: "S" },
  { value: "SU", label: "Sunday", short: "S" },
];

const frequencies = new Set(["hourly", "weekdays", "daily", "weekly", "custom"]);
const dayValues = new Set(dataAppScheduleDays.map(({ value }) => value));

export function normalizeDataAppRefreshSchedule(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || !frequencies.has(value.frequency)) {
    return null;
  }

  if (value.frequency === "hourly") return { frequency: "hourly" };
  if (typeof value.time !== "string" || !/^(?:[01]\d|2[0-3]):[0-5]\d$/u.test(value.time)) {
    return null;
  }

  const requestedDays = new Set(Array.isArray(value.days)
    ? value.days.filter((day) => typeof day === "string" && dayValues.has(day))
    : []);
  const days = dataAppScheduleDays
    .filter(({ value: day }) => requestedDays.has(day))
    .map(({ value: day }) => day);

  if (value.frequency === "custom" && days.length === 0) return null;
  if (value.frequency === "weekly" && days.length !== 1) return null;
  return {
    frequency: value.frequency,
    time: value.time,
    ...(["weekly", "custom"].includes(value.frequency) ? { days } : {}),
  };
}

export function dataAppScheduleCadence(value) {
  const schedule = normalizeDataAppRefreshSchedule(value);
  if (!schedule) throw new Error("Choose a valid Data app refresh schedule.");

  if (schedule.frequency === "hourly") return "every hour on the hour";
  if (schedule.frequency === "weekdays") return `every weekday at ${schedule.time}`;
  if (schedule.frequency === "daily") return `every day at ${schedule.time}`;

  const days = (schedule.days ?? []).map((day) =>
    dataAppScheduleDays.find(({ value }) => value === day)?.label).filter(Boolean);
  if (schedule.frequency === "weekly") return `every week on ${days[0]} at ${schedule.time}`;
  return `every ${days.join(", ")} at ${schedule.time}`;
}
