export function pivot(rows, x, group, value) {
  const grouped = new Map();
  rows.forEach((row) => {
    if (!grouped.has(row[x])) grouped.set(row[x], { [x]: row[x] });
    grouped.get(row[x])[row[group]] = row[value];
  });
  return [...grouped.values()];
}

/** Points with no adjacent finite observation form a one-point line segment. */
export function isolatedPointIndexes(rows, field) {
  const present = (index) => Number.isFinite(rows[index]?.[field]);
  const indexes = [];
  for (let index = 0; index < rows.length; index += 1) {
    if (present(index) && !present(index - 1) && !present(index + 1)) indexes.push(index);
  }
  return indexes;
}

export function stackedMarkBounds(payload, fields, field, { x, y, width, height, horizontal = false }) {
  const current = Number(payload?.[field]);
  if (!Number.isFinite(current) || current === 0 || !width || !height) return null;

  const values = fields.map((name) => {
    const value = Number(payload?.[name]);
    return Number.isFinite(value) && Math.sign(value) === Math.sign(current) ? Math.abs(value) : 0;
  });
  const index = fields.indexOf(field);
  if (index < 0) return null;
  const scale = Math.abs(horizontal ? width : height) / Math.abs(current);
  const total = values.reduce((sum, value) => sum + value, 0);
  const before = values.slice(0, index).reduce((sum, value) => sum + value, 0);
  const after = values.slice(index + 1).reduce((sum, value) => sum + value, 0);
  return {
    x: horizontal ? (current < 0 ? x + width - after * scale : x - before * scale) : x,
    y: horizontal ? y : current < 0 ? y + height - before * scale : y - after * scale,
    width: horizontal ? total * scale : Math.abs(width),
    height: horizontal ? Math.abs(height) : total * scale,
  };
}

export function histogram(rows, field) {
  const values = rows.map((row) => Number(row[field])).filter(Number.isFinite);
  if (!values.length) return [];
  const minimum = Math.min(...values);
  const maximum = Math.max(...values);
  const targetCount = Math.max(1, Math.min(16, Math.ceil(Math.sqrt(values.length))));
  const range = maximum - minimum || Math.max(Math.abs(maximum), 1);
  const rawWidth = range / targetCount;
  const magnitude = 10 ** Math.floor(Math.log10(rawWidth));
  const normalizedWidth = rawWidth / magnitude;
  const niceWidth = normalizedWidth <= 1 ? 1 : normalizedWidth <= 2 ? 2 : normalizedWidth <= 5 ? 5 : 10;
  const width = niceWidth * magnitude;
  const first = Math.floor(minimum / width) * width;
  const bucketCount = Math.max(1, Math.ceil((maximum - first) / width));
  const buckets = Array.from({ length: bucketCount }, (_, index) => ({
    start: first + index * width,
    count: 0,
    end: first + (index + 1) * width,
  }));
  values.forEach((value) => {
    const index = Math.min(bucketCount - 1, Math.max(0, Math.floor((value - first) / width)));
    buckets[index].count += 1;
  });
  return buckets;
}

const waterfallRoleFields = ["totalType", "waterfallRole", "role", "type"];
const waterfallTotalFields = ["isTotal", "total"];
const waterfallCategoryFields = ["label", "stage", "name", "driver"];
const firstDefinedField = (row, fields) => fields.find((field) => row[field] != null);
const firstDefinedValue = (row, fields) => {
  const field = firstDefinedField(row, fields);
  return field === undefined ? undefined : row[field];
};

/** Raw metadata that can affect this waterfall's running balances. */
export function waterfallRowFields(rows, categoryField) {
  const fields = new Set();
  for (const row of rows) {
    const roleField = firstDefinedField(row, waterfallRoleFields);
    if (roleField) fields.add(roleField);
    for (const field of waterfallTotalFields) if (row[field] === true) fields.add(field);
    if (!categoryField) {
      const category = firstDefinedField(row, waterfallCategoryFields);
      if (category) fields.add(category);
    }
  }
  return [...fields];
}

function waterfallTotalKind(row, categoryField) {
  const role = String(firstDefinedValue(row, waterfallRoleFields) ?? "")
    .trim()
    .toLocaleLowerCase();
  const category = String(categoryField ? row[categoryField] : firstDefinedValue(row, waterfallCategoryFields) ?? "")
    .trim()
    .toLocaleLowerCase();
  if (/^(?:before|beginning|opening|starting|initial)(?:\s+(?:balance|total|value))?$/u.test(role || category)) {
    return "beginning";
  }
  if (/^(?:after|ending|closing|final)(?:\s+(?:balance|total|value))?$|^(?:end|net)\s+total$/u.test(role || category))
    return "ending";
  if (waterfallTotalFields.some((field) => row[field] === true) || role === "total") return "total";
  return "";
}

export function waterfall(rows, field, options = {}) {
  const { categoryField, beginning, ending, includeEnding = false } = options;
  const source = [...rows];
  const hasBeginningRow = source.some((row) => waterfallTotalKind(row, categoryField) === "beginning");
  if (Number.isFinite(beginning) && !hasBeginningRow) {
    source.unshift({
      ...(categoryField ? { [categoryField]: "Beginning" } : {}),
      [field]: beginning,
      totalType: "beginning",
      isTotal: true,
    });
  }
  if (source.length < 2) return [];

  const endpointValues = source.map((row) => Number(row[field]));
  const movementTotal = endpointValues.slice(1, -1).reduce((total, value) => total + value, 0);
  const inferredEndpoints =
    source.length >= 3 &&
    !source.some((row) => waterfallTotalKind(row, categoryField)) &&
    endpointValues.every(Number.isFinite) &&
    Math.abs(endpointValues[0] + movementTotal - endpointValues.at(-1)) <=
      Number.EPSILON * Math.max(1, ...endpointValues.map(Math.abs)) * 16;
  let balance = 0;
  const result = source.map((row, index) => {
    const numeric = Number(row[field]);
    const value = Number.isFinite(numeric) ? numeric : 0;
    const totalType =
      waterfallTotalKind(row, categoryField) ||
      (inferredEndpoints && index === 0
        ? "beginning"
        : inferredEndpoints && index === source.length - 1
          ? "ending"
          : "");
    const isTotal = Boolean(totalType);
    const previous = isTotal ? 0 : balance;
    if (isTotal) balance = value;
    else balance += value;
    const change = isTotal ? null : value;
    const waterfallRole =
      totalType === "beginning" ? "before" : totalType === "ending" ? "after" : totalType || "change";
    return {
      ...row,
      baseline: Math.min(previous, balance),
      magnitude: Math.abs(balance - previous),
      range: [previous, balance],
      change,
      balance,
      runningTotal: balance,
      isTotal,
      totalType: totalType || undefined,
      waterfallRole,
    };
  });

  const hasEndingRow = result.some((row) => row.totalType === "ending");
  const canDeriveEnding = includeEnding && result.some((row) => row.totalType === "beginning");
  if (!hasEndingRow && (Number.isFinite(ending) || canDeriveEnding)) {
    const value = Number.isFinite(ending) ? ending : balance;
    result.push({
      ...(categoryField ? { [categoryField]: "Ending" } : {}),
      [field]: value,
      baseline: Math.min(0, value),
      magnitude: Math.abs(value),
      range: [0, value],
      change: null,
      balance: value,
      runningTotal: value,
      isTotal: true,
      totalType: "ending",
      waterfallRole: "after",
    });
  }
  return result;
}

export function waterfallValueDomain(rows) {
  const values = rows.flatMap((row) => (row.isTotal ? [row.runningTotal] : row.range ?? [])).filter(Number.isFinite);
  if (!values.length) return undefined;

  const minimum = Math.min(...values);
  const maximum = Math.max(...values);
  const padding = Math.max((maximum - minimum) * 0.12, Math.max(Math.abs(minimum), Math.abs(maximum), 1) * 0.01);
  return [minimum - padding, maximum + padding];
}

export function funnelLayout(width, count) {
  if (!count || width == null || width >= count * 144) return "horizontal";
  return width >= count * 120 ? "compact" : "vertical";
}

export function funnelStages(rows, category, field) {
  const numericValue = (value) => {
    if (!(typeof value === "number" || typeof value === "string" && value.trim())) return undefined;
    const number = Number(value);
    return Number.isFinite(number) && number >= 0 ? number : undefined;
  };
  const baseline = numericValue(rows[0]?.[field]);
  return rows.map((row, index) => {
    const value = numericValue(row[field]);
    const previous = index ? numericValue(rows[index - 1]?.[field]) : undefined;
    const conversion =
      index && Number.isFinite(value) && value >= 0 && Number.isFinite(previous) && previous > 0
        ? value / previous
        : undefined;
    return {
      ...row,
      __funnelStage: String(row[category] ?? ""),
      __funnelValue: Number.isFinite(value) ? value : undefined,
      __funnelConversion: conversion,
      __funnelChange: Number.isFinite(conversion) ? conversion - 1 : undefined,
      __funnelShare: Number.isFinite(value) && baseline > 0 ? value / baseline : undefined,
      __funnelDropoff: Number.isFinite(value) && Number.isFinite(previous) ? previous - value : undefined,
    };
  });
}

// Each stage is measured at its column center. Smooth joins stay between the
// endpoint values; missing stages break the ribbon instead of inventing zeroes.
export function funnelRibbonSegments(stages) {
  const maximum = Math.max(0, ...stages.map((stage) => stage.__funnelValue ?? 0));
  const segments = [];
  let points = [];
  const finish = () => {
    if (!points.length) return;
    const first = points[0];
    const last = points.at(-1);
    const edge = (point, side) => 100 + side * point.height / 2;
    let path = `M ${first.x - 50} ${edge(first, -1)} L ${first.x} ${edge(first, -1)}`;
    for (let index = 1; index < points.length; index += 1) {
      const previous = points[index - 1];
      const point = points[index];
      const middle = (previous.x + point.x) / 2;
      path += ` C ${middle} ${edge(previous, -1)} ${middle} ${edge(point, -1)} ${point.x} ${edge(point, -1)}`;
    }
    path += ` L ${last.x + 50} ${edge(last, -1)} L ${last.x + 50} ${edge(last, 1)} L ${last.x} ${edge(last, 1)}`;
    for (let index = points.length - 2; index >= 0; index -= 1) {
      const previous = points[index + 1];
      const point = points[index];
      const middle = (previous.x + point.x) / 2;
      path += ` C ${middle} ${edge(previous, 1)} ${middle} ${edge(point, 1)} ${point.x} ${edge(point, 1)}`;
    }
    path += ` L ${first.x - 50} ${edge(first, 1)} Z`;
    segments.push({ path, points });
    points = [];
  };
  stages.forEach((stage, index) => {
    if (!Number.isFinite(stage.__funnelValue)) { finish(); return; }
    points.push({ x: index * 100 + 50, height: maximum > 0 ? stage.__funnelValue / maximum * 180 : 0 });
  });
  finish();
  return segments;
}

export function normalizeZoomRange(rows, field, first, second) {
  if (first == null || second == null || String(first) === String(second)) return null;
  const [start, end] = [String(first), String(second)].sort();
  const matching = rows.filter((row) => String(row[field]) >= start && String(row[field]) <= end);
  return matching.length > 1 ? { start, end } : null;
}

export function orderTooltipEntries(entries, { stacked = false, vertical = false } = {}) {
  if (stacked) return [...entries].reverse();
  if (!vertical) return [...entries];
  return [...entries].sort((left, right) => Number(right.value) - Number(left.value));
}

function quantile(values, fraction) {
  const index = (values.length - 1) * fraction;
  const lower = Math.floor(index);
  return values[lower] + (values[Math.ceil(index)] - values[lower]) * (index - lower);
}

export const boxPlotSummaryFields = Object.freeze(["minimum", "lowerQuartile", "median", "upperQuartile", "maximum"]);

export function hasReviewedBoxPlotSummary(rows) {
  return rows.length > 0 && rows.every((row) => boxPlotSummaryFields.every((field) => Number.isFinite(row[field])));
}

export function boxPlots(rows, category, value) {
  if (!rows.length) return [];
  if (hasReviewedBoxPlotSummary(rows)) {
    return rows.map((row) => ({ ...row, spread: row.upperQuartile - row.lowerQuartile }));
  }

  const groups = new Map();
  rows.forEach((row) => {
    const observation = typeof row[value] === "number" ? row[value] : Number(row[value]);
    if (row[value] == null || !Number.isFinite(observation)) return;
    if (!groups.has(row[category])) groups.set(row[category], []);
    groups.get(row[category]).push(observation);
  });
  return [...groups].map(([name, observations]) => {
    const ordered = observations.filter(Number.isFinite).sort((left, right) => left - right);
    const lowerQuartile = quantile(ordered, 0.25);
    const upperQuartile = quantile(ordered, 0.75);
    return {
      [category]: name,
      minimum: ordered[0],
      lowerQuartile,
      median: quantile(ordered, 0.5),
      upperQuartile,
      maximum: ordered.at(-1),
      spread: upperQuartile - lowerQuartile,
    };
  });
}

export function heatmap(rows, x, y, value, { domain, startAtZero, xOrder, yOrder, missingValues } = {}) {
  const orderedValues = (field, preferred) => {
    const observed = [...new Set(rows.map((row) => row[field]))];
    if (!Array.isArray(preferred)) return observed;
    const available = new Set(observed);
    const ordered = preferred.filter((item) => available.has(item));
    return [...ordered, ...observed.filter((item) => !ordered.includes(item))];
  };
  const xValues = orderedValues(x, xOrder);
  const yValues = orderedValues(y, yOrder);
  const values = rows.filter(row => missingValues !== "gap" || row[value] != null).map((row) => Number(row[value])).filter(Number.isFinite);
  const observedMinimum = Math.min(...values, 0);
  const observedMaximum = Math.max(...values, 0);
  const actualMinimum = values.length ? Math.min(...values) : 0;
  const compressedRange = actualMinimum > 0 && observedMaximum > actualMinimum && actualMinimum / observedMaximum > 0.7;
  const minimum = Number.isFinite(domain?.[0])
    ? domain[0]
    : startAtZero === false || (startAtZero !== true && compressedRange)
      ? actualMinimum
      : observedMinimum;
  const maximum = Number.isFinite(domain?.[1]) ? domain[1] : observedMaximum;
  const range = Math.max(Number.EPSILON, maximum - minimum);
  const observed = new Map(rows.map((row) => [JSON.stringify([row[x], row[y]]), row]));
  return {
    rows: xValues.flatMap((column, xIndex) =>
      yValues.map((group, yIndex) => {
        const source = observed.get(JSON.stringify([column, group]));
        const unknown = missingValues === "gap" && (!source || source[value] == null);
        const row = source ?? { [x]: column, [y]: group, [value]: unknown ? null : 0, __missing: true };
        return {
          ...row,
          ...(unknown ? { __unknown: true } : {}),
          xIndex,
          yIndex,
          intensity: source ? Math.max(0, Math.min(1, ((Number(row[value]) || 0) - minimum) / range)) : 0,
        };
      }),
    ),
    xValues,
    yValues,
    minimum,
    maximum,
  };
}

export function sankeyGraph(rows, stages, value) {
  const fields = stages.filter(Boolean);
  if (fields.length < 2) return { nodes: [], links: [] };
  const nodes = [];
  const identities = new Map();
  const links = new Map();
  for (const row of rows) {
    const amount = Number(row[value]);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    const path = fields.flatMap((field, stage) => {
      const name = row[field];
      return name == null || name === "" ? [] : [{ stage, name }];
    });
    for (let index = 0; index < path.length - 1; index += 1) {
      const sourceValue = path[index];
      const targetValue = path[index + 1];
      const node = (stage, name) => {
        const identity = JSON.stringify([stage, name]);
        if (!identities.has(identity)) {
          identities.set(identity, nodes.length);
          nodes.push({ name: String(name), stage, field: fields[stage] });
        }
        return identities.get(identity);
      };
      const source = node(sourceValue.stage, sourceValue.name);
      const target = node(targetValue.stage, targetValue.name);
      const identity = `${source}:${target}`;
      const current = links.get(identity);
      if (current) current.value += amount;
      else links.set(identity, { source, target, value: amount });
    }
  }
  return { nodes, links: [...links.values()] };
}
