export const chartAnnotationLayoutTokens = Object.freeze({
  fontSize: 14, lineHeight: 18, paddingX: 0, paddingY: 3,
  maxWidth: 220, gap: 8, anchorGap: 12,
});

const { lineHeight, paddingX, paddingY, maxWidth, gap, anchorGap } = chartAnnotationLayoutTokens;
const directions = ["top", "right", "bottom", "left"];
const preferredByKind = {
  benchmark: ["left", "top", "bottom", "right"],
  event: ["right", "left", "bottom", "top"],
  range: ["top", "bottom", "right", "left"],
  point: directions,
};
const finite = Number.isFinite;
const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(value, maximum));
const right = (box) => box.x + box.width;
const bottom = (box) => box.y + box.height;
const separated = (a, b) => right(a) + gap <= b.x + 1e-7 || right(b) + gap <= a.x + 1e-7
  || bottom(a) + gap <= b.y + 1e-7 || bottom(b) + gap <= a.y + 1e-7;
// boxAt clamps every candidate; sizes are checked before candidate generation.
const available = (box, obstacles) => obstacles.every((other) => separated(box, other));

function preference(item) {
  const requested = Array.isArray(item.preferred) ? item.preferred : [item.preferred];
  return [...new Set([...requested, ...(preferredByKind[item.kind] ?? directions), ...directions]
    .filter((direction) => directions.includes(direction)))];
}

function measuredText(measureText) {
  const widths = new Map();
  return (text) => {
    if (widths.has(text)) return widths.get(text);
    const measured = measureText?.(text);
    const width = typeof measured === "number" ? measured : measured?.width;
    const result = finite(width) && width >= 0 ? width : [...text].length * 6.5;
    widths.set(text, result);
    return result;
  };
}

// Keep the complete label. Long individual words may break between characters;
// text that cannot fit in three lines belongs in a full-text figure note.
function wrapLabel(label, width, measure) {
  const lines = [];
  while (label && lines.length < 3) {
    const characters = [...label];
    let length = characters.length;
    while (length && measure(characters.slice(0, length).join("")) > width) length--;
    if (!length) return null;
    let head = characters.slice(0, length).join("");
    if (length < characters.length && head.lastIndexOf(" ") > 0) head = head.slice(0, head.lastIndexOf(" "));
    lines.push(head);
    label = label.slice(head.length).trimStart();
  }
  return label ? null : lines;
}

function fullSizes(item, plot, measure) {
  const sizes = [];
  const seen = new Set();
  const limit = Math.min(maxWidth, plot.width);
  // Keep every distinct full-text shape for tight plots, then prefer a compact,
  // balanced two-line phrase. Never shorten the authored label to force a wrap.
  const widths = [limit, Math.min(limit, 180), Math.min(limit, 140)];
  for (let width = Math.floor(limit); width >= 32; width--) widths.push(width);
  for (const outerWidth of new Set(widths)) {
    const lines = wrapLabel(item.label, outerWidth - paddingX * 2, measure);
    if (!lines) continue;
    const width = Math.max(32, Math.ceil(Math.max(...lines.map(measure)) + paddingX * 2));
    const height = lines.length * lineHeight + paddingY * 2;
    const key = `${width}:${height}`;
    if (width <= plot.width && height <= plot.height && !seen.has(key)) {
      seen.add(key);
      sizes.push({ width, height, lines });
    }
  }
  const naturalTwoLines = (size) => size.lines.length === 2 && size.lines.join(" ") === item.label;
  const rank = (size) => naturalTwoLines(size) ? 0 : size.lines.length === 1 ? 1 : 2;
  const balance = (size) => naturalTwoLines(size) ? Math.abs(measure(size.lines[0]) - measure(size.lines[1])) : 0;
  return sizes.sort((a, b) => rank(a) - rank(b) || balance(a) - balance(b));
}

function boxAt(x, y, size, plot) {
  return { x: clamp(x, plot.x, right(plot) - size.width),
    y: clamp(y, plot.y, bottom(plot) - size.height), width: size.width, height: size.height };
}

function rangeStartBox(item, size, plot, obstacles) {
  const range = item.kind === "range" ? item.range : null;
  if (!range || !["x", "y"].includes(range.axis) || ![range.start, range.end].every(finite)) return null;
  const extent = range.axis === "x" ? "width" : "height";
  const start = Math.max(plot[range.axis], Math.min(range.start, range.end));
  const end = Math.min(plot[range.axis] + plot[extent], Math.max(range.start, range.end));
  if (end <= start) return null;
  const box = { x: plot.x + anchorGap, y: plot.y + anchorGap, width: size.width, height: size.height };
  // Read from the physical upper leading edge, even on a reversed scale. A
  // narrow band may be narrower than its text, but the text starts inside it.
  box[range.axis] = start + Math.min(anchorGap, (end - start) / 2);
  // Do not clamp this preference back outside the band to make a wide label fit.
  if (!obstacles) return right(box) <= right(plot) && bottom(box) <= bottom(plot) ? box : null;
  if (box[range.axis] + size[extent] > plot[range.axis] + plot[extent]) return null;
  // Pin the leading edge, but let the text move along it. Reuse the interval
  // sweep rather than checking every curve sample against every candidate.
  const strip = { ...plot, [range.axis]: box[range.axis], [extent]: size[extent] };
  return clearPocket({ anchor: { x: box.x + size.width / 2, y: box.y + size.height + anchorGap } },
    size, strip, obstacles);
}

function nearbyBoxes(item, size, plot, distance = anchorGap) {
  if (size.width > plot.width || size.height > plot.height) return [];
  const { x, y } = item.anchor;
  const { width, height } = size;
  const positions = {
    top: [x - width / 2, y - height - distance],
    right: [x + distance, y - height / 2],
    bottom: [x - width / 2, y + distance],
    left: [x - width - distance, y - height / 2],
  };
  const candidates = [];
  for (const direction of preference(item)) {
    const [left, top] = positions[direction];
    candidates.push([left, top]);
    if (direction === "top" || direction === "bottom") {
      candidates.push([x + anchorGap, top], [x - width - anchorGap, top]);
    } else candidates.push([left, y + anchorGap], [left, y - height - anchorGap]);
  }
  return candidates.map(([left, top]) => boxAt(left, top, size, plot));
}

// Search nearby obstacle edges and a bounded grid before moving text to the figure note.
function globalBoxes(item, size, plot, obstacles) {
  const { width, height } = size;
  const boxes = [];
  const add = (x, y) => boxes.push(boxAt(x, y, size, plot));
  for (const mark of obstacles.slice(0, 16)) {
    add(item.anchor.x - width / 2, mark.y - height - gap);
    add(item.anchor.x - width / 2, bottom(mark) + gap);
    add(mark.x - width - gap, item.anchor.y - height / 2);
    add(right(mark) + gap, item.anchor.y - height / 2);
  }
  const dx = Math.max(24, (plot.width - width) / 24);
  const dy = Math.max(24, (plot.height - height) / 24);
  for (let x = plot.x; x < right(plot); x += dx)
    for (let y = plot.y; y < bottom(plot); y += dy) add(x, y);
  const distance = (box) => (box.x + width / 2 - item.anchor.x) ** 2
    + (box.y + height / 2 - item.anchor.y) ** 2;
  return boxes.sort((a, b) => distance(a) - distance(b));
}

// Search the remaining pockets without sorting all marks again at every x.
// Expanded obstacle boundaries contain every possible change in availability;
// a range-add tree maintains their y coverage as marks enter and leave the sweep.
function clearPocket(item, size, plot, obstacles) {
  const maxX = right(plot) - size.width, maxY = bottom(plot) - size.height;
  const idealX = item.anchor.x - size.width / 2, idealY = item.anchor.y - size.height - anchorGap;
  const coordinates = (axis, extent, minimum, maximum, ideal) => [...new Set([
    minimum, maximum, clamp(ideal, minimum, maximum),
    ...obstacles.flatMap((box) => {
      const start = box[axis] - size[extent] - gap, end = box[axis] + box[extent] + gap;
      // Tangency is legal, including the same tolerance used by separated().
      return [start, start + 1e-7, end - 1e-7, end];
    }),
  ])].filter((value) => value >= minimum && value <= maximum).sort((a, b) => a - b);
  const xs = coordinates("x", "width", plot.x, maxX, idealX);
  const ys = coordinates("y", "height", plot.y, maxY, idealY);
  const first = (values, predicate) => {
    let low = 0, high = values.length;
    while (low < high) {
      const middle = (low + high) >>> 1;
      if (predicate(values[middle])) high = middle;
      else low = middle + 1;
    }
    return low;
  };
  const events = [];
  for (const mark of obstacles) {
    // Use the actual separation comparisons, not inverse arithmetic, so tree
    // coverage agrees at floating-point boundaries as well as exact tangencies.
    const x0 = first(xs, (x) => x + size.width + gap > mark.x + 1e-7);
    const x1 = first(xs, (x) => right(mark) + gap <= x + 1e-7);
    const y0 = first(ys, (y) => y + size.height + gap > mark.y + 1e-7);
    const y1 = first(ys, (y) => bottom(mark) + gap <= y + 1e-7);
    if (x0 >= x1 || y0 >= y1) continue;
    events.push([x0, y0, y1 - 1, 1], [x1, y0, y1 - 1, -1]);
  }
  events.sort((a, b) => a[0] - b[0]);
  const minimum = new Int32Array(ys.length * 4), lazy = new Int32Array(ys.length * 4);
  const update = (from, to, delta, node = 1, low = 0, high = ys.length - 1) => {
    if (from <= low && high <= to) { minimum[node] += delta; lazy[node] += delta; return; }
    const middle = (low + high) >>> 1;
    if (from <= middle) update(from, to, delta, node * 2, low, middle);
    if (to > middle) update(from, to, delta, node * 2 + 1, middle + 1, high);
    minimum[node] = lazy[node] + Math.min(minimum[node * 2], minimum[node * 2 + 1]);
  };
  const free = (from, to, reverse, node = 1, low = 0, high = ys.length - 1, inherited = 0) => {
    if (high < from || low > to || minimum[node] + inherited > 0) return -1;
    if (low === high) return low;
    const middle = (low + high) >>> 1, carry = inherited + lazy[node];
    const left = () => free(from, to, reverse, node * 2, low, middle, carry);
    const right = () => free(from, to, reverse, node * 2 + 1, middle + 1, high, carry);
    const found = reverse ? right() : left();
    return found >= 0 ? found : reverse ? left() : right();
  };
  const idealIndex = first(ys, (y) => y >= clamp(idealY, plot.y, maxY));
  let event = 0, best = null, distance = Infinity;
  for (let index = 0; index < xs.length;) {
    while (event < events.length && events[event][0] === index) {
      const [, from, to, delta] = events[event++];
      update(from, to, delta);
    }
    const next = events[event]?.[0] ?? xs.length;
    if (minimum[1] === 0) {
      // Coverage is constant until the next event; only its nearest x matters.
      const x = clamp(idealX, xs[index], xs[next - 1]);
      for (const yIndex of [free(0, idealIndex, true), free(idealIndex, ys.length - 1, false)]) {
        if (yIndex < 0) continue;
        const y = ys[yIndex], candidateDistance = (x - idealX) ** 2 + (y - idealY) ** 2;
        if (candidateDistance < distance) { best = { x, y, ...size }; distance = candidateDistance; }
      }
    }
    index = next;
  }
  return best;
}

function segmentCrossesBox(start, end, box) {
  let low = 0, high = 1;
  for (const [axis, size] of [["x", "width"], ["y", "height"]]) {
    const delta = end[axis] - start[axis];
    const minimum = box[axis] - 2, maximum = box[axis] + box[size] + 2;
    if (!delta) { if (start[axis] < minimum || start[axis] > maximum) return false; continue; }
    const a = (minimum - start[axis]) / delta, b = (maximum - start[axis]) / delta;
    low = Math.max(low, Math.min(a, b)); high = Math.min(high, Math.max(a, b));
    if (low > high) return false;
  }
  return true;
}

// Nearby text needs no decoration. Displaced text gets an actual arrow pointing
// toward its exact reviewed anchor, unless it would cross other text or evidence.
// Explicit path geometry avoids SVG marker IDs and survives standalone export.
function arrowShape(start, end, control) {
  const from = control ?? start;
  const dx = end.x - from.x, dy = end.y - from.y, length = Math.hypot(dx, dy);
  const ux = dx / length, uy = dy / length;
  const left = { x: end.x - ux * 7 - uy * 4, y: end.y - uy * 7 + ux * 4 };
  const rightHead = { x: end.x - ux * 7 + uy * 4, y: end.y - uy * 7 - ux * 4 };
  return { start, end, left, right: rightHead, ...(control ? { control } : {}),
    path: `M ${start.x} ${start.y} ${control ? `Q ${control.x} ${control.y}` : "L"} ${end.x} ${end.y} M ${left.x} ${left.y} L ${end.x} ${end.y} L ${rightHead.x} ${rightHead.y}` };
}

export function chartAnnotationArrow(box, otherLabels = [], obstacles = [], referenceAxis) {
  const start = { x: clamp(box.anchor.x, box.x, right(box)), y: clamp(box.anchor.y, box.y, bottom(box)) };
  const end = { ...box.anchor }, length = Math.hypot(end.x - start.x, end.y - start.y);
  if (!finite(length) || length <= 24) return null;
  const arrow = arrowShape(start, end);
  const segments = [[start, end], [arrow.left, end], [end, arrow.right]];
  // A point or reference must meet its exact anchor. Permit only the final
  // marker-sized contact with geometry at that anchor, never a crossing through
  // the rest of a curve/area merely because its bounds also contain the target.
  const beforeAnchor = { x: end.x - (end.x - start.x) * 8 / length,
    y: end.y - (end.y - start.y) * 8 / length };
  const blocked = otherLabels.some((other) => segments.some(([a, b]) => segmentCrossesBox(a, b, other)))
    || obstacles.some((other) => {
      const touchesAnchor = end.x >= other.x - 2 && end.x <= right(other) + 2
        && end.y >= other.y - 2 && end.y <= bottom(other) + 2;
      return touchesAnchor ? segmentCrossesBox(start, beforeAnchor, other)
        : segments.some(([a, b]) => segmentCrossesBox(a, b, other));
    });
  if (!blocked) return arrow;
  // A benchmark/event identifies a whole line. If the centered arrowhead
  // grazes a mark, try either quarter of the label's span on that SAME line.
  // This avoids a fit -> note -> resize -> fit loop without moving the label,
  // weakening clearance, or changing exact point-annotation targets.
  if (referenceAxis) for (const fraction of [0.25, 0.75]) {
    const anchor = { ...box.anchor, [referenceAxis]: box[referenceAxis]
      + box[referenceAxis === "x" ? "width" : "height"] * fraction };
    const alternative = chartAnnotationArrow({ ...box, anchor }, otherLabels, obstacles);
    if (alternative) return alternative;
  }
  return null;
}

// Bars already show the reviewed value. Resolve that exact endpoint to one
// painted mark, then stop the connector at its actual (possibly rounded) edge.
// `contains` tests the SVG fill in plot coordinates; no row/index matching or
// assumed corner radius is involved. Missing/ambiguous geometry gets no arrow.
function pointBar(anchor, bars, horizontal) {
  const category = horizontal ? "y" : "x", value = horizontal ? "x" : "y";
  const breadth = horizontal ? "height" : "width", length = horizontal ? "width" : "height";
  const matches = bars.filter((bar) => typeof bar.contains === "function"
    && [bar.x, bar.y, bar.width, bar.height].every(finite) && bar.width > 0 && bar.height > 0
    && Math.abs(anchor[category] - bar[category] - bar[breadth] / 2) <= 1
    && Math.min(Math.abs(anchor[value] - bar[value]), Math.abs(anchor[value] - bar[value] - bar[length])) <= 1);
  return matches.length === 1 ? matches[0] : null;
}

export function chartAnnotationBarArrow(box, bars, horizontal = false, otherLabels = [], plot) {
  const painted = bars.filter((bar) => typeof bar.contains === "function");
  const bar = pointBar(box.anchor, painted, horizontal);
  if (!bar) return null;
  // Project toward the nearest face, not the center of a long, thin bar: a
  // shallow diagonal can put an arrowhead wing inside an otherwise clear fill.
  const insetX = Math.min(2, bar.width / 2), insetY = Math.min(2, bar.height / 2);
  const inside = { x: clamp(box.x + box.width / 2, bar.x + insetX, right(bar) - insetX),
    y: clamp(box.y + box.height / 2, bar.y + insetY, bottom(bar) - insetY) };
  const overlapX = [Math.max(box.x, bar.x), Math.min(right(box), right(bar))];
  const overlapY = [Math.max(box.y, bar.y), Math.min(bottom(box), bottom(bar))];
  if (overlapX[0] < overlapX[1] && (bottom(box) < bar.y || box.y > bottom(bar))) {
    inside.x = (overlapX[0] + overlapX[1]) / 2; inside.y = bar.y + bar.height / 2;
  } else if (overlapY[0] < overlapY[1] && (right(box) < bar.x || box.x > right(bar))) {
    inside.x = bar.x + bar.width / 2; inside.y = (overlapY[0] + overlapY[1]) / 2;
  }
  if (!bar.contains(inside)) { inside.x = bar.x + bar.width / 2; inside.y = bar.y + bar.height / 2; }
  if (!bar.contains(inside)) return null;
  const start = { x: clamp(inside.x, box.x, right(box)), y: clamp(inside.y, box.y, bottom(box)) };
  if (bar.contains(start)) return null;
  const dx = inside.x - start.x, dy = inside.y - start.y, distance = Math.hypot(dx, dy);
  if (!finite(distance) || !distance) return null;
  const at = (t) => ({ x: start.x + dx * t, y: start.y + dy * t });
  let outside = 0, within = 1;
  for (let iteration = 0; iteration < 24; iteration++) {
    const middle = (outside + within) / 2;
    if (bar.contains(at(middle))) within = middle;
    else outside = middle;
  }
  const endpoint = at(Math.max(0, outside - 6 / distance));
  const attached = chartAnnotationArrow({ ...box, anchor: endpoint });
  if (!attached) return null;
  // Keep the existing connector eligibility, then leave breathing room beside
  // the text as well as the painted bar. Rebuild the curve from the padded start.
  const length = Math.hypot(attached.end.x - attached.start.x, attached.end.y - attached.start.y);
  const arrow = arrowShape({ x: attached.start.x + (attached.end.x - attached.start.x) * 6 / length,
    y: attached.start.y + (attached.end.y - attached.start.y) * 6 / length }, attached.end);
  const span = Math.hypot(arrow.end.x - arrow.start.x, arrow.end.y - arrow.start.y);
  const bend = Math.min(8, span * 0.06);
  const control = { x: (arrow.start.x + arrow.end.x) / 2 - (arrow.end.y - arrow.start.y) / span * bend,
    y: (arrow.start.y + arrow.end.y) / 2 + (arrow.end.x - arrow.start.x) / span * bend };
  const curvePoint = (a, b, c, t) => ({ x: (1-t)**2*a.x+2*(1-t)*t*c.x+t*t*b.x,
    y: (1-t)**2*a.y+2*(1-t)*t*c.y+t*t*b.y });
  const inPlot = (p) => !plot || p.x >= plot.x && p.x <= right(plot) && p.y >= plot.y && p.y <= bottom(plot);
  // A small deterministic curve softens the connector. Keep the straight
  // version when that bend or its tangent-aligned head would cross evidence.
  for (const shape of [arrowShape(arrow.start, arrow.end, control), arrow]) {
    const limits = [shape.start, shape.end, shape.left, shape.right];
    if (shape.control) for (const axis of ["x", "y"]) {
      const t = (shape.start[axis] - shape.control[axis])
        / (shape.start[axis] - 2 * shape.control[axis] + shape.end[axis]);
      if (t > 0 && t < 1) limits.push(curvePoint(shape.start, shape.end, shape.control, t));
    }
    if (!limits.every(inPlot)) continue;
    let clear = true;
    for (const [a, b, c] of [[shape.start, shape.end, shape.control], [shape.left, shape.end], [shape.end, shape.right]]) {
      const p = c ?? a;
      const bounds = { x: Math.min(a.x, b.x, p.x), y: Math.min(a.y, b.y, p.y),
        width: Math.max(a.x, b.x, p.x) - Math.min(a.x, b.x, p.x), height: Math.max(a.y, b.y, p.y) - Math.min(a.y, b.y, p.y) };
      const nearby = painted.filter((mark) => !separated(bounds, mark));
      const steps = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) + bend));
      let previous = a;
      for (let index = 0; index <= steps && clear; index++) {
        const t = index / steps;
        const point = c ? curvePoint(a, b, c, t)
          : { x: a.x+(b.x-a.x)*t, y: a.y+(b.y-a.y)*t };
        clear = !nearby.some((mark) => mark.contains(point))
          && !otherLabels.some((label) => segmentCrossesBox(previous, point, label));
        previous = point;
      }
    }
    if (clear) return shape;
  }
  return null;
}

/**
 * Place at most eight reviewed annotation labels in plot-pixel coordinates.
 * `preferred` is a side or ordered list of sides. `measureText` measures the
 * renderer's annotation font and may return a number or a TextMetrics-like object.
 * Omitted placements have no finite in-plot anchor or cannot fit their full text;
 * callers must display them as full-text figure notes, never hidden-only content.
 */
export function layoutChartAnnotations(items, plot, { measureText, obstacles = [] } = {}) {
  if (!Array.isArray(items) || !plot || ![plot.x, plot.y, plot.width, plot.height].every(finite)
    || ![right(plot), bottom(plot)].every(finite)
    || plot.width < 20 || plot.height < 20) return [];
  const seen = new Set();
  const candidates = items.slice(0, 8).flatMap((item) => {
    if (!item || typeof item.id !== "string" || !item.id || seen.has(item.id)
      || typeof item.label !== "string" || !item.label.trim()
      || !item.anchor || ![item.anchor.x, item.anchor.y].every(finite)
      || item.anchor.x < plot.x || item.anchor.x > right(plot)
      || item.anchor.y < plot.y || item.anchor.y > bottom(plot)) return [];
    seen.add(item.id);
    return [{ ...item, label: item.label.trim().replace(/\s+/gu, " "), anchor: { ...item.anchor } }];
  });
  const measure = measuredText(measureText);
  const marks = obstacles.filter((box) => box && [box.x, box.y, box.width, box.height].every(finite)
    && box.width >= 0 && box.height >= 0);
  const placed = [];
  const unplaceableSizes = [];
  for (const item of candidates) {
    // A bar-point connector needs room for a shaft and arrowhead outside the
    // fill. Other annotations retain their ordinary 8px data clearance.
    const targetBar = item.barPoint ? pointBar(item.anchor, marks, item.horizontal) : null;
    const fixed = [...marks.map((mark) => mark === targetBar
      ? { x: mark.x - 24, y: mark.y - 24, width: mark.width + 48, height: mark.height + 48 } : mark), ...placed];
    // An exact full-plot miss also rules out every larger rectangle, regardless
    // of its anchor or text. Later labels only add obstacles. A target bar's
    // extra clearance is item-specific, so never share failures from that buffer.
    const failedSizes = targetBar ? [] : unplaceableSizes;
    const cannotFit = (size) => unplaceableSizes.some(({ width, height }) => size.width >= width && size.height >= height)
      || targetBar && failedSizes.some(({ width, height }) => size.width >= width && size.height >= height);
    const sizes = fullSizes(item, plot, measure).filter((size) => !cannotFit(size));
    const natural = (size) => size.lines.join(" ") === item.label;
    // A horizontal threshold spans the plot: explain it at a matching text
    // edge, not a floating interior column. Prefer the right unless the left
    // keeps the explanation materially nearer its line. Vertical thresholds
    // retain their x-value association instead of inheriting this rule.
    if (item.kind === "benchmark" && !item.horizontal) {
      let best;
      for (const textAnchor of ["end", "start"]) for (const size of sizes.filter(natural)) {
        const strip = { ...plot, x: textAnchor === "end" ? right(plot) - size.width : plot.x, width: size.width };
        const box = clearPocket(item, size, strip, fixed);
        if (!box) continue;
        const distance = Math.max(box.y - item.anchor.y, item.anchor.y - bottom(box), 0);
        const score = distance + (textAnchor === "start" ? anchorGap : 0);
        if (!best || score < best.score) best = { box, size, textAnchor, score };
      }
      if (best) placed.push({ id: item.id, ...best.box, lines: best.size.lines, anchor: item.anchor, textAnchor: best.textAnchor });
      continue;
    }
    // Exhaust readable wraps on the reviewed category before trying whitespace
    // beside another bar. Clear the target's 24px buffer, the ordinary gap,
    // and one pixel of SVG rounding; the generic 12px preference cannot do so.
    if (targetBar) {
      const category = item.horizontal ? "y" : "x", extent = item.horizontal ? "height" : "width";
      let aligned;
      const size = sizes.find((size) => natural(size) && (aligned = nearbyBoxes(item, size, plot, 25 + gap)
        .find((box) => Math.abs(box[category] + box[extent] / 2 - item.anchor[category]) < 1e-7
          && available(box, fixed))));
      if (size) { placed.push({ id: item.id, ...aligned, lines: size.lines, anchor: item.anchor }); continue; }
      if (item.horizontal) continue; // A figure note is safer than another category's row.
    }
    let rangeSize = sizes.find((size) => {
      const box = natural(size) && rangeStartBox(item, size, plot);
      return box && available(box, fixed);
    });
    let rangeBox = rangeSize && rangeStartBox(item, rangeSize, plot);
    if (!rangeBox && item.kind === "range" && item.range) {
      const along = item.range.axis === "x" ? "y" : "x";
      let distance = Infinity;
      for (const size of sizes.filter(natural)) {
        const box = rangeStartBox(item, size, plot, fixed);
        if (!box) continue;
        const offset = Math.abs(box[along] - plot[along] - anchorGap);
        if (offset < distance) { rangeBox = box; rangeSize = size; distance = offset; }
      }
    }
    if (rangeSize) {
      placed.push({ id: item.id, ...rangeBox, lines: rangeSize.lines, anchor: item.anchor });
      continue;
    }
    // Try every readable wrap beside the anchor before moving farther away.
    // A wide shape in distant whitespace must not beat a compact nearby label.
    let found = false;
    // Give a complete two-line phrase an interior search before accepting a
    // three-line nearby block. Tight plots can still use the other full wraps.
    for (const readable of [sizes.filter((size) => natural(size) && size.lines.length === 2),
      sizes.filter((size) => natural(size) && size.lines.length !== 2), sizes.filter((size) => !natural(size))]) {
      for (const nearby of [true, false]) {
        for (const size of readable) {
          if (cannotFit(size)) continue;
          const box = nearby ? nearbyBoxes(item, size, plot).find((box) => available(box, fixed))
            : globalBoxes(item, size, plot, fixed).find((box) => available(box, fixed))
              ?? clearPocket(item, size, plot, fixed);
          if (!box) {
            if (!nearby) {
              failedSizes.push(size);
              // Certify a shared miss against the ordinary marks, without this
              // target's extra buffer. Dense bar charts can reuse that proof;
              // a buffer-only miss remains local to its own target.
              if (targetBar && !clearPocket(item, size, plot, [...marks, ...placed])) unplaceableSizes.push(size);
            }
            continue;
          }
          placed.push({ id: item.id, ...box, lines: size.lines, anchor: item.anchor });
          found = true;
          break;
        }
        if (found) break;
      }
      if (found) break;
    }
  }
  return placed;
}
