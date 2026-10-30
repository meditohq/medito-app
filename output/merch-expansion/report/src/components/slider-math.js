const defaultMinimum = 0;
const defaultMaximum = 100;

function finiteNumber(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function clampToOrderedBounds(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value));
}

export function normalizeSliderBounds(minimum = defaultMinimum, maximum = defaultMaximum) {
  const first = finiteNumber(minimum, defaultMinimum);
  const second = finiteNumber(maximum, defaultMaximum);
  return first <= second
    ? { minimum: first, maximum: second }
    : { minimum: second, maximum: first };
}

export function normalizeSliderStep(step = 1) {
  const value = Number(step);
  return Number.isFinite(value) && value > 0 ? value : 1;
}

export function clampSliderValue(value, minimum = defaultMinimum, maximum = defaultMaximum) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  return clampToOrderedBounds(finiteNumber(value, bounds.minimum), bounds.minimum, bounds.maximum);
}

export function sliderPercent(value, minimum = defaultMinimum, maximum = defaultMaximum) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  const span = bounds.maximum - bounds.minimum;
  if (span === 0) return 0;
  return (clampSliderValue(value, bounds.minimum, bounds.maximum) - bounds.minimum) / span * 100;
}

export function sliderValueAtPosition(clientX, rect, minimum, maximum, step = 1, thumbWidth = 20) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  const size = Math.max(1, rect.width - thumbWidth);
  const fraction = Math.max(0, Math.min(1, (clientX - rect.left - thumbWidth / 2) / size));
  const increment = normalizeSliderStep(step);
  const count = Math.round(fraction * (bounds.maximum - bounds.minimum) / increment);
  return clampSliderValue(bounds.minimum + count * increment, bounds.minimum, bounds.maximum);
}

export function normalizeMinDistance(
  minDistance = 0,
  minimum = defaultMinimum,
  maximum = defaultMaximum,
) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  const distance = finiteNumber(minDistance, 0);
  return clampToOrderedBounds(Math.max(0, distance), 0, bounds.maximum - bounds.minimum);
}

export function normalizeRangeValue(
  value,
  minimum = defaultMinimum,
  maximum = defaultMaximum,
  minDistance = 0,
) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  const source = Array.isArray(value) ? value : [];
  const first = clampSliderValue(source[0], bounds.minimum, bounds.maximum);
  const second = clampSliderValue(source[1] ?? bounds.maximum, bounds.minimum, bounds.maximum);
  let lower = Math.min(first, second);
  let upper = Math.max(first, second);
  const distance = normalizeMinDistance(minDistance, bounds.minimum, bounds.maximum);

  if (upper - lower < distance) {
    if (lower + distance <= bounds.maximum) upper = lower + distance;
    else {
      upper = bounds.maximum;
      lower = bounds.maximum - distance;
    }
  }

  return [lower, upper];
}

export function updateRangeValue(
  value,
  thumb,
  nextValue,
  minimum = defaultMinimum,
  maximum = defaultMaximum,
  minDistance = 0,
) {
  const bounds = normalizeSliderBounds(minimum, maximum);
  const [lower, upper] = normalizeRangeValue(
    value,
    bounds.minimum,
    bounds.maximum,
    minDistance,
  );
  const distance = normalizeMinDistance(minDistance, bounds.minimum, bounds.maximum);
  const next = clampSliderValue(nextValue, bounds.minimum, bounds.maximum);

  if (thumb === "lower") {
    return [Math.min(next, upper - distance), upper];
  }
  if (thumb === "upper") {
    return [lower, Math.max(next, lower + distance)];
  }
  throw new TypeError('Range slider thumb must be "lower" or "upper".');
}

export function boxesOverlap(left, width, otherLeft, otherWidth, gap = 6) {
  return left < otherLeft + otherWidth + gap && otherLeft < left + width + gap;
}

function fitLabel(value, minimum, maximum) {
  return Math.min(Math.max(minimum, maximum), Math.max(minimum, value));
}

export function layoutSingleSliderLabels({
  width,
  percent,
  valueWidth,
  inlineLabelWidth = 0,
  minimumBoundWidth = 0,
  maximumBoundWidth = 0,
  showBounds = true,
  padding = 8,
  gap = 12,
}) {
  const safeWidth = Math.max(0, finiteNumber(width, 0));
  const safeValueWidth = Math.max(0, finiteNumber(valueWidth, 0));
  const safeLabelWidth = Math.max(0, finiteNumber(inlineLabelWidth, 0));
  const point = safeWidth * clampToOrderedBounds(finiteNumber(percent, 0), 0, 100) / 100;
  const contentStart = padding + (safeLabelWidth ? safeLabelWidth + gap : 0);
  const inside = point - gap - safeValueWidth;
  const outside = point + gap;
  const placement = inside >= contentStart ? "inside" : "outside";
  const valueLeft = placement === "inside"
    ? inside
    : fitLabel(outside, contentStart, safeWidth - padding - safeValueWidth);
  const minimumLeft = padding;
  const maximumLeft = safeWidth - padding - maximumBoundWidth;
  const showMinimum = showBounds
    && !boxesOverlap(valueLeft, safeValueWidth, minimumLeft, minimumBoundWidth)
    && !(safeLabelWidth && boxesOverlap(padding, safeLabelWidth, minimumLeft, minimumBoundWidth));
  const showMaximum = showBounds
    && !boxesOverlap(valueLeft, safeValueWidth, maximumLeft, maximumBoundWidth);

  return { valueLeft, placement, showMinimum, showMaximum };
}

export function layoutRangeSliderLabels({
  width,
  startPercent,
  endPercent,
  lowerWidth,
  upperWidth,
  inlineLabelWidth = 0,
  minimumBoundWidth = 0,
  maximumBoundWidth = 0,
  showBounds = true,
  padding = 8,
  gap = 12,
}) {
  const safeWidth = Math.max(0, finiteNumber(width, 0));
  const safeLowerWidth = Math.max(0, finiteNumber(lowerWidth, 0));
  const safeUpperWidth = Math.max(0, finiteNumber(upperWidth, 0));
  const safeLabelWidth = Math.max(0, finiteNumber(inlineLabelWidth, 0));
  const contentStart = padding + (safeLabelWidth ? safeLabelWidth + gap : 0);
  const lowerPoint = safeWidth * clampToOrderedBounds(finiteNumber(startPercent, 0), 0, 100) / 100;
  const upperPoint = safeWidth * clampToOrderedBounds(finiteNumber(endPercent, 0), 0, 100) / 100;
  const insideLower = lowerPoint + gap;
  const insideUpper = upperPoint - gap - safeUpperWidth;
  const outsideLower = lowerPoint - gap - safeLowerWidth;
  const outsideUpper = upperPoint + gap;
  const insideFits = insideLower >= contentStart
    && insideUpper - (insideLower + safeLowerWidth) >= gap;
  const lowerFitsOutside = outsideLower >= contentStart;
  const upperFitsOutside = outsideUpper + safeUpperWidth <= safeWidth - padding;
  let lowerLeft;
  let upperLeft;
  let lowerPlacement;
  let upperPlacement;

  if (insideFits) {
    lowerLeft = insideLower;
    upperLeft = insideUpper;
    lowerPlacement = "inside";
    upperPlacement = "inside";
  } else if (lowerFitsOutside && upperFitsOutside) {
    lowerLeft = outsideLower;
    upperLeft = outsideUpper;
    lowerPlacement = "outside";
    upperPlacement = "outside";
  } else if (upperFitsOutside) {
    lowerLeft = fitLabel(insideLower, contentStart, safeWidth - padding - safeLowerWidth);
    upperLeft = outsideUpper;
    lowerPlacement = "inside";
    upperPlacement = "outside";
  } else if (lowerFitsOutside) {
    lowerLeft = outsideLower;
    upperLeft = fitLabel(insideUpper, contentStart, safeWidth - padding - safeUpperWidth);
    lowerPlacement = "outside";
    upperPlacement = "inside";
  } else {
    lowerLeft = contentStart;
    upperLeft = Math.max(
      contentStart + safeLowerWidth + gap,
      safeWidth - padding - safeUpperWidth,
    );
    lowerPlacement = "edge";
    upperPlacement = "edge";
  }

  const minimumLeft = padding;
  const maximumLeft = safeWidth - padding - maximumBoundWidth;
  const showMinimum = showBounds
    && !boxesOverlap(lowerLeft, safeLowerWidth, minimumLeft, minimumBoundWidth)
    && !boxesOverlap(upperLeft, safeUpperWidth, minimumLeft, minimumBoundWidth)
    && !(safeLabelWidth && boxesOverlap(padding, safeLabelWidth, minimumLeft, minimumBoundWidth));
  const showMaximum = showBounds
    && !boxesOverlap(lowerLeft, safeLowerWidth, maximumLeft, maximumBoundWidth)
    && !boxesOverlap(upperLeft, safeUpperWidth, maximumLeft, maximumBoundWidth);

  return {
    lowerLeft,
    upperLeft,
    lowerPlacement,
    upperPlacement,
    showMinimum,
    showMaximum,
  };
}
