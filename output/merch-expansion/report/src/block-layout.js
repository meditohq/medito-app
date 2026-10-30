export const maxBlockLayoutRegions = 50;
export const maxBlockLayoutItems = 500;
export const maxBlockLayoutColumns = 12;
export const maxBlockLayoutRevision = 1_000_000;
export const defaultBlockMinimumSpans = Object.freeze({ metric: 2, chart: 3, custom: 3, table: 3, block: 3 });

const unsafeObjectKeys = new Set(["__proto__", "prototype", "constructor"]);

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    && [Object.prototype, null].includes(Object.getPrototypeOf(value));
}

export function validBlockLayoutId(value) {
  return typeof value === "string" && value.trim() === value && value.length > 0
    && value.length <= 200 && !unsafeObjectKeys.has(value);
}

function normalizedLayoutEntry(value) {
  if (!plainObject(value) || !Array.isArray(value.order)
    || value.order.length > maxBlockLayoutItems
    || Object.keys(value).some((key) => !["order", "spans", "preferredSpans", "soloSpans", "rows", "authoredRevision"].includes(key))
    || value.authoredRevision !== undefined && (!Number.isSafeInteger(value.authoredRevision)
      || value.authoredRevision < 1 || value.authoredRevision > maxBlockLayoutRevision)) return null;
  const order = [];
  const seen = new Set();
  for (const id of value.order) {
    if (!validBlockLayoutId(id) || seen.has(id)) return null;
    seen.add(id);
    order.push(id);
  }
  const entry = { order };
  if (value.authoredRevision !== undefined) entry.authoredRevision = value.authoredRevision;
  for (const field of ["spans", "preferredSpans", "soloSpans"]) {
    if (value[field] === undefined) continue;
    if (!plainObject(value[field]) || Object.keys(value[field]).length > maxBlockLayoutItems) return null;
    const spans = {};
    for (const [id, span] of Object.entries(value[field])) {
      if (!validBlockLayoutId(id) || !seen.has(id) || !Number.isInteger(span)
        || span < 1 || span > maxBlockLayoutColumns) return null;
      spans[id] = span;
    }
    if (Object.keys(spans).length) entry[field] = spans;
  }
  if (value.rows !== undefined) {
    if (!Array.isArray(value.rows) || value.rows.length > maxBlockLayoutItems) return null;
    const rowIds = new Set();
    const assigned = new Set();
    const rows = [];
    for (const row of value.rows) {
      // Discard metadata from the retired section-drag preview without losing
      // the user's existing card order or explicitly resized widths.
      if (!plainObject(row) || Object.keys(row).some((key) => !["id", "items", "sectionId"].includes(key))
        || !validBlockLayoutId(row.id) || rowIds.has(row.id) || !Array.isArray(row.items)
        || row.sectionId !== undefined && !validBlockLayoutId(row.sectionId)
        || row.items.length > maxBlockLayoutItems) return null;
      rowIds.add(row.id);
      for (const id of row.items) {
        if (!seen.has(id) || assigned.has(id)) return null;
        assigned.add(id);
      }
      rows.push({ id: row.id, items: [...row.items] });
    }
    if (assigned.size !== seen.size) return null;
    entry.rows = rows;
  }
  return entry;
}

export function normalizeBlockLayouts(value) {
  if (!plainObject(value)) return {};
  const normalized = {};
  for (const [regionId, layout] of Object.entries(value).slice(0, maxBlockLayoutRegions)) {
    if (!validBlockLayoutId(regionId)) continue;
    const entry = normalizedLayoutEntry(layout);
    if (entry) normalized[regionId] = entry;
  }
  return normalized;
}

export function validateBlockLayouts(value) {
  if (!plainObject(value) || Object.keys(value).length > maxBlockLayoutRegions) {
    throw new Error("Block layouts must be a bounded object of sortable regions.");
  }
  for (const [regionId, layout] of Object.entries(value)) {
    if (!validBlockLayoutId(regionId)) {
      throw new Error("Block layout region IDs must be bounded, nonempty, and safe.");
    }
    if (!normalizedLayoutEntry(layout)) {
      throw new Error(`Block layout "${regionId}" must contain unique safe IDs and bounded column spans.`);
    }
  }
  return normalizeBlockLayouts(value);
}

export function reconcileBlockOrder(authoredIds, savedOrder = [], retainedIds = []) {
  const authored = [...new Set(authoredIds.filter(validBlockLayoutId))];
  const allowed = new Set([...authored, ...retainedIds.filter(validBlockLayoutId)]);
  const seen = new Set();
  const result = [];
  for (const id of Array.isArray(savedOrder) ? savedOrder : []) {
    if (!allowed.has(id) || seen.has(id)) continue;
    result.push(id);
    seen.add(id);
  }
  for (const id of authored) {
    if (seen.has(id)) continue;
    result.push(id);
    seen.add(id);
  }
  return result.slice(0, maxBlockLayoutItems);
}

export function moveBlockBefore(order, activeId, beforeId) {
  if (!Array.isArray(order) || !order.includes(activeId)
    || beforeId !== null && (!order.includes(beforeId) || beforeId === activeId)) return order;
  const remaining = order.filter((id) => id !== activeId);
  const index = beforeId === null ? remaining.length : remaining.indexOf(beforeId);
  if (index < 0) return order;
  const next = [...remaining.slice(0, index), activeId, ...remaining.slice(index)];
  return next.every((id, position) => id === order[position]) ? order : next;
}

export function preserveHiddenBlockPositions(previousOrder, visibleOrder, hiddenIds = []) {
  const hidden = new Set(hiddenIds);
  const knownVisible = new Set(visibleOrder);
  const result = [];
  let nextVisible = 0;
  for (const id of previousOrder) {
    if (hidden.has(id)) result.push(id);
    else if (knownVisible.has(id) && nextVisible < visibleOrder.length) {
      result.push(visibleOrder[nextVisible]);
      nextVisible += 1;
    }
  }
  return [...result, ...visibleOrder.slice(nextVisible)].slice(0, maxBlockLayoutItems);
}

export function reconcileBlockRows(authoredRows, savedRows = [], authoredIds = [], retainedIds = []) {
  const allowed = new Set([...authoredIds, ...retainedIds].filter(validBlockLayoutId));
  const source = Array.isArray(savedRows) && savedRows.length ? savedRows : authoredRows;
  const used = new Set();
  const rows = [];
  for (const row of source) {
    if (!validBlockLayoutId(row?.id) || rows.some((entry) => entry.id === row.id)) continue;
    const items = (Array.isArray(row.items) ? row.items : [])
      .filter((id) => allowed.has(id) && !used.has(id));
    for (const id of items) used.add(id);
    rows.push({ id: row.id, items });
  }
  // Anchor new rows to the next authored row without reordering saved rows.
  // Walk backward so consecutive additions retain their authored order too.
  for (let index = authoredRows.length - 1; index >= 0; index -= 1) {
    const authored = authoredRows[index];
    if (rows.some((row) => row.id === authored.id)) continue;
    const nextIndex = rows.findIndex((row) => row.id === authoredRows[index + 1]?.id);
    rows.splice(nextIndex < 0 ? rows.length : nextIndex, 0, { id: authored.id, items: [] });
  }
  for (const id of allowed) {
    if (used.has(id)) continue;
    const authored = authoredRows.find((row) => row.items.includes(id));
    const existing = authored && rows.find((row) => row.id === authored.id);
    if (existing) existing.items.push(id);
    else rows.push({ id: authored?.id ?? `row:${id}`, items: [id] });
    used.add(id);
  }
  return rows.slice(0, maxBlockLayoutItems);
}

function positiveSpan(value, fallback = 1) {
  return Number.isInteger(value) && value >= 1 && value <= maxBlockLayoutColumns ? value : fallback;
}

export function rebalanceBlockRow(items, blocks, {
  columns = maxBlockLayoutColumns,
  autoResize = true,
  maxItems = 6,
  minimumSpans = defaultBlockMinimumSpans,
  currentSpans = {},
  preferredSpans = {},
  fill = true,
} = {}) {
  if (!Array.isArray(items) || !items.length || items.length > maxItems
    || columns < 1 || columns > maxBlockLayoutColumns) return null;
  const descriptors = items.map((id) => {
    const block = blocks instanceof Map ? blocks.get(id) : blocks?.[id];
    if (!block) return null;
    const minimum = Math.max(positiveSpan(block.minSpan, 1), positiveSpan(block.measuredMinSpan, 1),
      positiveSpan(minimumSpans[block.kind], 1));
    const preferred = Math.max(minimum,
      positiveSpan(preferredSpans[id] ?? currentSpans[id] ?? block.span, minimum));
    const current = Math.max(minimum, positiveSpan(currentSpans[id] ?? preferred, preferred));
    return { id, minimum, preferred, current, locked: Boolean(block.locked) };
  });
  if (descriptors.some((item) => !item)
    || descriptors.reduce((sum, item) => sum + item.minimum, 0) > columns) return null;
  const spans = Object.fromEntries(descriptors.map(({ id, current }) => [id, current]));
  let total = descriptors.reduce((sum, item) => sum + spans[item.id], 0);
  if (total > columns && !autoResize) return null;
  while (total > columns) {
    const candidates = descriptors.filter((item) => !item.locked && spans[item.id] > item.minimum)
      .sort((left, right) => spans[right.id] - right.minimum - (spans[left.id] - left.minimum));
    if (!candidates.length) return null;
    spans[candidates[0].id] -= 1;
    total -= 1;
  }
  while (fill && total < columns) {
    const candidates = descriptors.filter((item) => !item.locked)
      .sort((left, right) => spans[left.id] / left.preferred - spans[right.id] / right.preferred);
    if (!candidates.length) break;
    spans[candidates[0].id] += 1;
    total += 1;
  }
  return spans;
}

function uniqueRowId(rows, activeId) {
  const base = `row:${activeId}`;
  let next = base;
  let suffix = 2;
  while (rows.some((row) => row.id === next)) next = `${base}:${suffix++}`;
  return next;
}

export function resolveCanvasMove({
  rows,
  spans = {},
  preferredSpans = {},
  soloSpans = {},
  blocks,
  activeId,
  targetId,
  placement,
  columns = maxBlockLayoutColumns,
  autoResize = true,
  maxItems = 6,
  minimumSpans = defaultBlockMinimumSpans,
  retainedRowIds = [],
}) {
  if (!validBlockLayoutId(activeId) || !validBlockLayoutId(targetId) || activeId === targetId
    || !["before", "after", "above", "below"].includes(placement)) return null;
  const sourceIndex = rows.findIndex((row) => row.items.includes(activeId));
  const targetIndex = rows.findIndex((row) => row.items.includes(targetId));
  if (sourceIndex < 0 || targetIndex < 0) return null;
  if (["above", "below"].includes(placement) && rows[sourceIndex].items.length === 1
    && sourceIndex === targetIndex + (placement === "below" ? 1 : -1)) return null;
  const active = blocks instanceof Map ? blocks.get(activeId) : blocks?.[activeId];
  if (!active || active.locked) return null;
  const nextRows = rows.map((row) => ({ id: row.id, items: row.items.filter((id) => id !== activeId) }));
  let destination;
  if (["above", "below"].includes(placement)) {
    destination = { id: uniqueRowId(nextRows, activeId), items: [activeId] };
    const index = nextRows.findIndex((row) => row.id === rows[targetIndex].id)
      + (placement === "below" ? 1 : 0);
    nextRows.splice(index, 0, destination);
  } else {
    destination = nextRows.find((row) => row.id === rows[targetIndex].id);
    const position = destination.items.indexOf(targetId) + (placement === "after" ? 1 : 0);
    destination.items.splice(position, 0, activeId);
  }
  const sameRowReorder = sourceIndex === targetIndex && ["before", "after"].includes(placement);
  const grewExistingRow = sourceIndex !== targetIndex && ["before", "after"].includes(placement);
  const currentSpans = grewExistingRow
    ? Object.fromEntries(destination.items.map((id) => [id, Math.floor(columns / destination.items.length)]))
    : spans;
  const destinationSpans = sameRowReorder ? null : rebalanceBlockRow(destination.items, blocks,
    { columns, autoResize, maxItems, minimumSpans, preferredSpans,
      currentSpans: destination.items.length === 1 ? { ...currentSpans, ...soloSpans } : currentSpans,
      fill: destination.items.length !== 1 || !soloSpans[destination.items[0]] });
  if (!sameRowReorder && !destinationSpans) return null;
  const nextSpans = { ...spans, ...destinationSpans };
  const source = nextRows.find((row) => row.id === rows[sourceIndex].id);
  if (source && source !== destination && source.items.length) {
    const sourceSpans = rebalanceBlockRow(source.items, blocks,
      { columns, autoResize: true, maxItems, minimumSpans, preferredSpans,
        currentSpans: source.items.length === 1 ? { ...spans, ...soloSpans } : spans,
        fill: source.items.length !== 1 || !soloSpans[source.items[0]] });
    if (!sourceSpans) return null;
    Object.assign(nextSpans, sourceSpans);
  }
  const retained = new Set(retainedRowIds.filter(validBlockLayoutId));
  const retainedRows = nextRows.filter((row) => row.items.length || !row.id.startsWith("row:") || retained.has(row.id));
  const order = retainedRows.flatMap((row) => row.items);
  const previousOrder = rows.flatMap((row) => row.items);
  if (previousOrder.some((id, index) => {
    const descriptor = blocks instanceof Map ? blocks.get(id) : blocks?.[id];
    return descriptor?.locked && order.indexOf(id) !== index;
  })) return null;
  const unchangedRows = JSON.stringify(retainedRows) === JSON.stringify(rows);
  if (unchangedRows && order.every((id, index) => id === previousOrder[index])) return null;
  return { rows: retainedRows, spans: nextSpans, preferredSpans, soloSpans, order, targetId, placement,
    rowId: destination.id, ...(retained.size ? { retainedRowIds: [...retained] } : {}) };
}

export function resizeBlockRow({
  rows,
  spans = {},
  preferredSpans = {},
  blocks,
  activeId,
  neighborId,
  span,
  columns = maxBlockLayoutColumns,
  maxItems = 6,
  minimumSpans = defaultBlockMinimumSpans,
}) {
  if (!validBlockLayoutId(activeId) || !Number.isInteger(span) || span < 1 || span > columns) return null;
  const row = rows.find((entry) => entry.items.includes(activeId));
  const active = blocks instanceof Map ? blocks.get(activeId) : blocks?.[activeId];
  if (!row || !active || active.locked) return null;
  const neighbor = neighborId && (blocks instanceof Map ? blocks.get(neighborId) : blocks?.[neighborId]);
  if (neighborId && (!validBlockLayoutId(neighborId) || !neighbor || neighbor.locked
    || Math.abs(row.items.indexOf(activeId) - row.items.indexOf(neighborId)) !== 1)) return null;
  if (span === columns && row.items.length > 1) {
    if (neighborId) return null;
    const targetId = row.items.find((id) => id !== activeId);
    const moved = resolveCanvasMove({ rows, spans, preferredSpans, blocks, activeId, targetId,
      placement: "below", columns, maxItems, minimumSpans });
    return moved ? { ...moved, preferredSpans: { ...preferredSpans, [activeId]: span } } : null;
  }
  if (neighborId) {
    const minimum = (block) => Math.max(positiveSpan(block.minSpan, 1),
      positiveSpan(block.measuredMinSpan, 1), positiveSpan(minimumSpans[block.kind], 1));
    if (row.items.length > maxItems || span < minimum(active)) return null;
    const current = positiveSpan(spans[activeId] ?? active.span, minimum(active));
    const nextSpans = { ...spans, [activeId]: span };
    const nextPreferred = { ...preferredSpans, [activeId]: span };
    let difference = span - current;
    if (difference < 0) {
      nextSpans[neighborId] = positiveSpan(spans[neighborId] ?? neighbor.span, minimum(neighbor)) - difference;
      nextPreferred[neighborId] = nextSpans[neighborId];
    } else if (difference > 0) {
      const activeIndex = row.items.indexOf(activeId);
      const direction = row.items.indexOf(neighborId) > activeIndex ? 1 : -1;
      for (let index = activeIndex + direction;
        difference > 0 && index >= 0 && index < row.items.length; index += direction) {
        const donorId = row.items[index];
        const donor = blocks instanceof Map ? blocks.get(donorId) : blocks?.[donorId];
        if (!donor || donor.locked) continue;
        const existing = positiveSpan(spans[donorId] ?? donor.span, minimum(donor));
        const transferred = Math.min(difference, Math.max(0, existing - minimum(donor)));
        if (!transferred) continue;
        nextSpans[donorId] = existing - transferred;
        nextPreferred[donorId] = nextSpans[donorId];
        difference -= transferred;
      }
      if (difference) return null;
    }
    return { rows, spans: nextSpans, preferredSpans: nextPreferred,
      order: rows.flatMap((entry) => entry.items), rowId: row.id };
  }
  const locked = blocks instanceof Map ? new Map(blocks)
    : new Map(Object.entries(blocks ?? {}));
  locked.set(activeId, { ...active, locked: true });
  const nextPreferred = { ...preferredSpans, [activeId]: span };
  const next = rebalanceBlockRow(row.items, locked, {
    columns, maxItems, minimumSpans,
    currentSpans: { ...spans, [activeId]: span },
    preferredSpans: nextPreferred,
  });
  if (!next || next[activeId] !== span) return null;
  return { rows, spans: { ...spans, ...next }, preferredSpans: nextPreferred,
    order: rows.flatMap((entry) => entry.items), rowId: row.id };
}

export function resolveCanvasInsertion({
  rows,
  spans,
  preferredSpans,
  blocks,
  activeId,
  items,
  pointer,
  dragRect,
  dragDirection,
  rowZone = 40,
  rowAttraction = 8,
  allowNewRow = false,
  stickyGap,
  confirmedGap,
  hysteresis = 0,
  ...policy
}) {
  const candidates = items.filter(({ id }) => id !== activeId);
  if (!candidates.length) return null;
  const byId = new Map(items.map((item) => [item.id, item]));
  const measuredRows = rows.map((row) => {
    const rowItems = row.items.map((id) => byId.get(id)).filter(Boolean);
    if (!rowItems.length) return null;
    return {
      id: row.id,
      items: rowItems,
      top: Math.min(...rowItems.map(({ rect }) => rect.top)),
      bottom: Math.max(...rowItems.map(({ rect }) => rect.bottom)),
      left: Math.min(...rowItems.map(({ rect }) => rect.left)),
      right: Math.max(...rowItems.map(({ rect }) => rect.right)),
    };
  }).filter(Boolean).sort((left, right) => left.top - right.top);
  const pointerRow = measuredRows.find((row) => pointer.y >= row.top - Math.max(1, rowAttraction + 2)
    && pointer.y <= row.bottom + 1
    && row.items.some(({ id }) => id !== activeId));

  if (!pointerRow && allowNewRow && confirmedGap && confirmedGap.key === stickyGap) {
    const confirmed = resolveCanvasMove({ rows, spans, preferredSpans, blocks, activeId,
      targetId: confirmedGap.targetId, placement: confirmedGap.placement, ...policy });
    if (confirmed) return confirmed;
  }

  let gap;
  const boundaries = [
    { before: null, after: measuredRows[0], center: measuredRows[0]?.top - rowZone / 2 },
    ...measuredRows.slice(0, -1).map((before, index) => {
      const after = measuredRows[index + 1];
      return { before, after, center: (before.bottom + after.top) / 2 };
    }),
    { before: measuredRows.at(-1), after: null,
      center: measuredRows.at(-1)?.bottom + rowZone / 2 },
  ];
  for (const boundary of boundaries) {
    if (pointerRow) break;
    const { before, after, center } = boundary;
    const anchor = after ?? before;
    if (!anchor || !Number.isFinite(center)) continue;
    const key = `${before?.id ?? "start"}:${after?.id ?? "end"}`;
    const naturalWidth = before && after ? Math.max(0, after.top - before.bottom) : rowZone;
    const attraction = stickyGap === key || naturalWidth >= rowZone
      ? 0 : Math.min(rowAttraction, Math.max(0, naturalWidth / 2 - 8));
    const half = Math.max(8, Math.min(rowZone / 2, naturalWidth / 2)
      - attraction);
    const tolerance = stickyGap === key ? Math.max(half, rowZone * .7) : half;
    const insideRow = measuredRows.some((entry) => pointer.y >= entry.top && pointer.y <= entry.bottom);
    if (Math.abs(pointer.y - center) > tolerance || insideRow
      || pointer.x < Math.min(before?.left ?? anchor.left, after?.left ?? anchor.left)
      || pointer.x > Math.max(before?.right ?? anchor.right, after?.right ?? anchor.right)) continue;
    const target = after?.items.find(({ id }) => id !== activeId)
      ?? [...(before?.items ?? [])].reverse().find(({ id }) => id !== activeId);
    if (!target) continue;
    const placement = after?.items.some(({ id }) => id === target.id) ? "above" : "below";
    gap = { key, targetId: target.id, placement, beforeRowId: before?.id, afterRowId: after?.id };
    break;
  }

  if (gap) {
    const resolved = resolveCanvasMove({ rows, spans, preferredSpans, blocks, activeId,
      targetId: gap.targetId, placement: gap.placement, ...policy });
    if (resolved) return allowNewRow ? resolved : { ...gap, pending: true };
    return null;
  }

  const collision = dragRect ? { x: dragRect.left + dragRect.width / 2,
    y: pointerRow ? Math.max(pointerRow.top, Math.min(pointerRow.bottom,
      dragRect.top + Math.min(dragRect.height, pointerRow.bottom - pointerRow.top) / 2))
      : dragRect.top + dragRect.height / 2 } : pointer;
  const occupied = measuredRows.filter((row) => collision.y >= row.top && collision.y <= row.bottom
    && row.items.some(({ id }) => id !== activeId));
  const nearest = pointerRow ?? [...(occupied.length ? occupied : measuredRows)].sort((left, right) => {
    const leftDistance = collision.y < left.top ? left.top - collision.y
      : collision.y > left.bottom ? collision.y - left.bottom : 0;
    const rightDistance = collision.y < right.top ? right.top - collision.y
      : collision.y > right.bottom ? collision.y - right.bottom : 0;
    return leftDistance - rightDistance;
  })[0];
  const rowCandidates = nearest?.items.filter(({ id }) => id !== activeId) ?? candidates;
  if (!rowCandidates.length) return null;
  const hovered = rowCandidates.filter(({ rect }) => dragRect
    ? dragRect.left < rect.right && dragRect.right > rect.left
      && dragRect.top < rect.bottom && dragRect.bottom > rect.top
    : pointer.x >= rect.left && pointer.x <= rect.right
      && pointer.y >= rect.top && pointer.y <= rect.bottom);
  const closest = [...(hovered.length ? hovered : rowCandidates)].sort((left, right) =>
    itemDistance(collision, left, "grid") - itemDistance(collision, right, "grid"))[0];
  const midpoint = closest.rect.left + closest.rect.width / 2;
  const position = dragRect && dragDirection?.x
    ? dragDirection.x > 0 ? dragRect.right : dragRect.left : collision.x;
  if (Math.abs(position - midpoint) < hysteresis) return null;
  const placement = position < midpoint ? "before" : "after";
  return resolveCanvasMove({ rows, spans, preferredSpans, blocks, activeId,
    targetId: closest.id, placement, ...policy });
}

function freeformGridPlacements(order, grid) {
  const occupied = new Set();
  const placements = new Map();
  let cursorRow = 0;
  let cursorColumn = 0;
  for (const id of order) {
    const footprint = grid.footprints[id];
    if (!footprint || footprint.columns < 1 || footprint.columns > grid.columns || footprint.rows < 1) return null;
    let row = cursorRow;
    let column = cursorColumn;
    while (row <= order.length * grid.columns) {
      if (column + footprint.columns > grid.columns) { row += 1; column = 0; continue; }
      let available = true;
      for (let offsetRow = 0; available && offsetRow < footprint.rows; offsetRow += 1) {
        for (let offsetColumn = 0; offsetColumn < footprint.columns; offsetColumn += 1) {
          if (occupied.has(`${row + offsetRow}:${column + offsetColumn}`)) { available = false; break; }
        }
      }
      if (!available) { column += 1; continue; }
      for (let offsetRow = 0; offsetRow < footprint.rows; offsetRow += 1) {
        for (let offsetColumn = 0; offsetColumn < footprint.columns; offsetColumn += 1) {
          occupied.add(`${row + offsetRow}:${column + offsetColumn}`);
        }
      }
      placements.set(id, { row, column, ...footprint });
      cursorRow = row;
      cursorColumn = column + footprint.columns;
      if (cursorColumn >= grid.columns) { cursorRow += 1; cursorColumn = 0; }
      break;
    }
    if (!placements.has(id)) return null;
  }
  return placements;
}

export function resolveFreeformGridInsertion({ order, activeId, dragRect, grid, lockedIds = [] }) {
  if (!Array.isArray(order) || !order.includes(activeId) || !dragRect || !grid?.footprints?.[activeId]
    || !Number.isInteger(grid.columns) || grid.columns < 2 || grid.columnWidth <= 0 || grid.rowHeight <= 0
    || lockedIds.includes(activeId)) return null;
  const original = freeformGridPlacements(order, grid);
  if (!original) return null;
  const footprint = grid.footprints[activeId];
  const desiredColumn = Math.max(0, Math.min(grid.columns - footprint.columns,
    Math.round((dragRect.left - grid.left) / (grid.columnWidth + (grid.columnGap ?? 0)))));
  const desiredRow = Math.max(0,
    Math.round((dragRect.top - grid.top) / (grid.rowHeight + (grid.rowGap ?? 0))));
  const remaining = order.filter((id) => id !== activeId);
  const originalIndex = order.indexOf(activeId);
  let best;
  for (let index = 0; index <= remaining.length; index += 1) {
    const nextOrder = [...remaining.slice(0, index), activeId, ...remaining.slice(index)];
    if (lockedIds.some((id) => order.indexOf(id) !== nextOrder.indexOf(id))) continue;
    const placements = freeformGridPlacements(nextOrder, grid);
    if (!placements) continue;
    const placement = placements.get(activeId);
    const distance = Math.abs(placement.row - desiredRow) * grid.columns
      + Math.abs(placement.column - desiredColumn);
    const displacement = remaining.reduce((sum, id) => {
      const previous = original.get(id);
      const next = placements.get(id);
      return sum + Math.abs(previous.row - next.row) + Math.abs(previous.column - next.column);
    }, 0);
    let gaps = 0;
    for (let row = 0; row < placement.row; row += 1) {
      for (let column = 0; column < grid.columns; column += 1) {
        const filled = [...placements.values()].some((item) => row >= item.row
          && row < item.row + item.rows && column >= item.column && column < item.column + item.columns);
        if (!filled) gaps += 1;
      }
    }
    const score = distance * 10000 + gaps * 1000 + displacement * 10 + Math.abs(index - originalIndex);
    if (!best || score < best.score) best = { score, index, order: nextOrder };
  }
  if (!best || best.order.every((id, index) => id === order[index])) return null;
  const beforeId = remaining[best.index] ?? null;
  const targetId = beforeId ?? remaining.at(-1);
  return { beforeId, targetId, placement: beforeId ? "before" : "after", order: best.order };
}

export function directionalBlockTilt(previous, current, elapsedMs, {
  smoothing = .18,
  maxDegrees = 1.5,
  deadZone = .04,
} = {}) {
  const velocity = elapsedMs > 0 ? (current - previous.position) / elapsedMs : 0;
  const smoothed = previous.velocity + (velocity - previous.velocity) * smoothing;
  const degrees = Math.abs(smoothed) < deadZone ? 0
    : Math.max(-maxDegrees, Math.min(maxDegrees, smoothed * maxDegrees * 2));
  return { position: current, velocity: smoothed, degrees };
}

function itemDistance(pointer, item, variant) {
  const centerY = item.rect.top + item.rect.height / 2;
  if (!["grid", "freeform"].includes(variant)) return Math.abs(pointer.y - centerY);
  const centerX = item.rect.left + item.rect.width / 2;
  const rowDistance = Math.abs(pointer.y - centerY);
  const columnDistance = Math.abs(pointer.x - centerX);
  return rowDistance * 2 + columnDistance;
}

export function resolveBlockInsertion({
  order,
  items,
  activeId,
  pointer,
  dragRect,
  dragDirection,
  variant = "stack",
  lockedIds = [],
  hysteresis = 0,
  previousBeforeId,
  spatialGrid,
}) {
  if (!Array.isArray(order) || !order.includes(activeId) || lockedIds.includes(activeId)) return null;
  if (variant === "freeform" && spatialGrid) {
    return resolveFreeformGridInsertion({ order, activeId, dragRect, grid: spatialGrid, lockedIds });
  }
  const remaining = order.filter((id) => id !== activeId);
  const candidates = items.filter(({ id }) => id !== activeId && remaining.includes(id));
  if (!candidates.length) return null;
  const collision = dragRect ? { x: dragRect.left + dragRect.width / 2,
    y: dragRect.top + dragRect.height / 2 } : pointer;
  const pointed = variant === "freeform" ? candidates.filter(({ rect }) =>
    pointer.x >= rect.left && pointer.x <= rect.right
      && pointer.y >= rect.top && pointer.y <= rect.bottom) : [];
  const intersecting = dragRect ? candidates.filter(({ rect }) =>
    dragRect.left < rect.right && dragRect.right > rect.left
    && dragRect.top < rect.bottom && dragRect.bottom > rect.top) : [];
  const matching = pointed.length ? pointed : intersecting.length ? intersecting : candidates;
  const closest = [...matching].sort((left, right) =>
    itemDistance(collision, left, variant) - itemDistance(collision, right, variant))[0];
  const horizontal = ["grid", "freeform"].includes(variant)
    && collision.y >= closest.rect.top && collision.y <= closest.rect.bottom;
  const midpoint = horizontal
    ? closest.rect.left + closest.rect.width / 2
    : closest.rect.top + closest.rect.height / 2;
  const direction = horizontal ? dragDirection?.x : dragDirection?.y;
  const position = dragRect && direction
    ? direction > 0 ? horizontal ? dragRect.right : dragRect.bottom
      : horizontal ? dragRect.left : dragRect.top
    : horizontal ? collision.x : collision.y;
  const placement = position < midpoint ? "before" : "after";
  if (Math.abs(position - midpoint) < hysteresis && previousBeforeId !== undefined) {
    return null;
  }
  if (placement === "before" && lockedIds.includes(closest.id)) return null;
  const candidateIndex = remaining.indexOf(closest.id);
  const beforeId = placement === "before" ? closest.id : remaining[candidateIndex + 1] ?? null;
  if (beforeId !== null && lockedIds.includes(beforeId)) return null;
  const nextOrder = moveBlockBefore(order, activeId, beforeId);
  if (nextOrder === order) return null;
  if (lockedIds.some((id) => order.indexOf(id) !== nextOrder.indexOf(id))) return null;
  return { beforeId, placement, targetId: closest.id, order: nextOrder };
}
