import React, { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useState } from "react";
import { Sankey, Tooltip, useChartWidth } from "recharts";

import { useChartText } from "./ChartAnnotations.jsx";
import { ChartTooltip } from "./ChartTooltip.jsx";
import { sankeyGraph } from "./chart-transforms.js";
import { categoryLabel, compact, compactAxisCategory, percentage } from "./chart-theme.js";

const sankeyMargin = { top: 12, right: 0, bottom: 12, left: 0 };
const expandedSankeyMargin = { top: 18, right: 6, bottom: 18, left: 6 };
const emptySankeyCriteria = Object.freeze([]);
const emptySankeyColorMap = Object.freeze({});
const SankeyInteractionContext = /* @__PURE__ */ createContext(null);

function sankeyNodeKey(node) {
  return JSON.stringify([Number(node?.stage), String(node?.name ?? "")]);
}

function sankeyLinkKey(source, target) {
  return JSON.stringify([
    Number(source?.stage),
    String(source?.name ?? ""),
    Number(target?.stage),
    String(target?.name ?? ""),
  ]);
}

function sankeySelection(node) {
  return {
    field: node.field,
    stage: Number(node.stage),
    name: String(node.name ?? ""),
    key: sankeyNodeKey(node),
  };
}

function sankeyLinkSelection(link) {
  const source = sankeySelection(link.source);
  const target = sankeySelection(link.target);
  const key = sankeyLinkKey(link.source, link.target);
  return {
    type: "link",
    key,
    linkKey: key,
    sourceKey: source.key,
    targetKey: target.key,
    criteria: [source, target],
  };
}
function SankeyNode({ x, y, width, height, payload, colorFor, showValues, lastStage, labelMaxLength = 10,
  labelFontSize = 11, valueFontSize = 10, penultimateLabelAlignment = "right",
  terminalLabelAlignment = "auto" }) {
  const interaction = useContext(SankeyInteractionContext);
  const chartWidth = useChartWidth();
  const { measureFont, measureText } = useChartText(400, labelFontSize);
  const nodeKey = sankeyNodeKey(payload);
  const reportNodePosition = interaction?.reportNodePosition;
  useLayoutEffect(() => {
    if (Number.isFinite(y)) reportNodePosition?.(nodeKey, y);
  }, [nodeKey, reportNodePosition, y]);
  const selected = interaction?.selectedNodeKeys.has(nodeKey) ?? false;
  const hovered = interaction?.hoveredNodeKey === nodeKey;
  const active = !interaction?.engaged || interaction.activeNodeKeys.has(nodeKey) || selected || hovered;
  const color = payload.color
    ?? colorFor({ field: payload.field, dimension: payload.field, value: payload.name, index: payload.stage });
  const beforeTerminal = lastStage > 0 && payload.stage === lastStage - 1;
  const centerY = y + height / 2;
  const name = categoryLabel(payload.field, payload.name);
  let visibleName = compactAxisCategory(name, Math.max(4, Math.min(40, Number(labelMaxLength) || 10)));
  const value = compact(payload.value);
  const columnStep = payload.depth > 0 ? payload.x / payload.depth : 0;
  const terminal = payload.targetNodes?.length === 0 && payload.sourceNodes?.length > 0;
  const labelWidth = Math.min(140, Math.max(72, visibleName.length * labelFontSize * 0.58));
  const labelGap = 10;
  const clearance = 6;
  const requiredStep = width / 2 + labelWidth / 2 + clearance + labelWidth + labelGap;
  const placeTerminalLeft = terminal && columnStep >= requiredStep;
  const terminalAbove = terminal && !placeTerminalLeft;
  const placeTerminalRight = terminal && terminalLabelAlignment === "right";
  const reviewedTerminalLeft = placeTerminalLeft && !placeTerminalRight;
  const reviewedTerminalAbove = terminalAbove && !placeTerminalRight;
  const rightAlignPenultimate = beforeTerminal && penultimateLabelAlignment === "right";
  const placeAboveNode = beforeTerminal || terminalAbove;
  const reviewedPlaceAboveNode = placeTerminalRight ? false : placeAboveNode;
  const valueVisible = !beforeTerminal && !placeAboveNode &&
    (showValues === true ? height >= 20 : showValues !== false && height >= 32);
  const textX = placeTerminalRight ? x + width + labelGap
    : rightAlignPenultimate ? x + width
    : reviewedTerminalLeft ? x - labelGap
    : reviewedTerminalAbove ? x + width
      : reviewedPlaceAboveNode ? x + width / 2 : x + width + labelGap;
  const textAnchor = placeTerminalRight ? "start"
    : rightAlignPenultimate || reviewedTerminalLeft || reviewedTerminalAbove
    ? "end" : reviewedPlaceAboveNode ? "middle" : "start";
  const availableLabelWidth = Math.max(0, textAnchor === "start" ? chartWidth - textX - 4
    : textAnchor === "end" ? textX - 4 : 2 * Math.min(textX - 4, chartWidth - textX - 4));
  while (visibleName.length > 1 && measureText(visibleName) > availableLabelWidth) {
    visibleName = `${visibleName.replace(/…$/u, "").slice(0, -1).trimEnd()}…`;
  }
  const nameY = reviewedPlaceAboveNode ? Math.max(11, y - 5) : centerY + (valueVisible ? -3 : 4);
  return (
    <g className="chart-sankey-node" data-active={active || undefined} data-selected={selected || undefined}
      data-hovered={hovered || undefined} opacity={active ? 1 : 0.16} role="button" tabIndex={0}
      aria-pressed={selected} aria-label={`${name}, ${value}`}
      onKeyDown={(event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        event.stopPropagation();
        interaction?.toggleNode(payload);
      }}>
      <rect x={x} y={y} width={width} height={height} rx={Math.min(4, height / 3)} fill={color}
        stroke={selected || hovered ? "var(--text)" : "none"} strokeWidth={selected ? 2.5 : hovered ? 1.5 : 0} />
      <text
        ref={measureFont}
        x={textX}
        y={nameY}
        textAnchor={textAnchor}
        fill="var(--text)"
        stroke="var(--surface)"
        strokeWidth={3}
        strokeLinejoin="round"
        paintOrder="stroke"
        fontSize={labelFontSize}
      >
        <title>{name}</title>
        {visibleName}
      </text>
      {valueVisible && (
        <text
          x={textX}
          y={centerY + 12}
          textAnchor={textAnchor}
          fill="var(--secondary)"
          stroke="var(--surface)"
          strokeWidth={3}
          strokeLinejoin="round"
          paintOrder="stroke"
          fontSize={valueFontSize}
        >
          {value}
        </text>
      )}
    </g>
  );
}

function SankeyTooltip({ active, payload = [], total = 0 }) {
  if (!active || !payload.length) return null;
  const item = payload[0]?.payload?.payload ?? payload[0]?.payload;
  if (!item) return null;
  const value = Number(item.value) || 0;
  const isLink = item.source && item.target;
  const sourceName = isLink ? categoryLabel(item.source.field, item.source.name) : null;
  const targetName = isLink ? categoryLabel(item.target.field, item.target.name) : null;
  const name = isLink ? `${sourceName} → ${targetName}` : categoryLabel(item.field, item.name);
  const denominator = isLink ? Number(item.source.value) || 0 : total;
  return <ChartTooltip active label={name} details={[
    { label: "Count", value: compact(value) },
    {
      label: isLink ? "Share of source" : "Share of all",
      value: denominator > 0 ? percentage(value / denominator).replace("+", "") : "—",
    },
  ]} />;
}

function SankeyLinkPath({ sourceX, targetX, sourceY, targetY, sourceControlX, targetControlX,
  linkWidth, payload, colorMode = "source" }) {
  const interaction = useContext(SankeyInteractionContext);
  const linkKey = sankeyLinkKey(payload.source, payload.target);
  const selected = interaction?.selectedLinkKeys.has(linkKey) ?? false;
  const hovered = interaction?.hoveredLinkKey === linkKey;
  const effectiveHover = hovered && !interaction?.pinned;
  const active = !interaction?.engaged || interaction.activeLinkKeys.has(linkKey) || selected || effectiveHover;
  const path = `M${sourceX},${sourceY}C${sourceControlX},${sourceY} ${targetControlX},${targetY} ${targetX},${targetY}`;
  const stroke = payload.source.color ?? "var(--chart-1)";
  const reviewedStroke = colorMode === "target" ? payload.target.color ?? stroke : stroke;
  const strength = Number(payload.source.colorStrength) || 60;
  const restingOpacity = 0.07 + strength / 100 * 0.21;
  const activeOpacity = 0.3 + strength / 100 * 0.32;
  const opacity = selected ? 0.78 : effectiveHover ? 0.7
    : active ? interaction?.engaged ? activeOpacity : restingOpacity : 0.035;
  const sourceName = categoryLabel(payload.source.field, payload.source.name);
  const targetName = categoryLabel(payload.target.field, payload.target.name);
  const hitInset = Math.min(16, Math.max(0, (targetX - sourceX) / 4));
  const hitPath = `M${sourceX + hitInset},${sourceY}C${sourceControlX},${sourceY} `
    + `${targetControlX},${targetY} ${targetX - hitInset},${targetY}`;
  return <g className="chart-sankey-link" data-active={active || undefined}
    data-selected={selected || undefined} data-hovered={hovered || undefined}
    role="button" tabIndex={0} aria-pressed={selected}
    aria-label={`${sourceName} to ${targetName}, ${compact(payload.value)}`}
    onKeyDown={(event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      event.stopPropagation();
      interaction?.toggleLink(payload);
    }}>
    <path className="chart-sankey-link-visible" d={path} fill="none" stroke={reviewedStroke}
      strokeWidth={Math.max(1, linkWidth)} strokeOpacity={opacity} pointerEvents="none" />
    <path className="chart-sankey-link-hit-area" d={hitPath} fill="none" stroke="transparent"
      strokeWidth={Math.max(12, linkWidth)}
      pointerEvents="stroke" />
  </g>;
}

export function SankeyRenderer({ rows, stages, spec, colorFor, onSelection }) {
  const {
    y: valueField,
    colors: colorMap = emptySankeyColorMap,
    colorByColumn = true,
    showValues,
    labelMaxLength,
    sankeyNodeWidth: nodeWidth = 12,
    sankeyLabelFontSize: labelFontSize = 11,
    sankeyValueFontSize: valueFontSize = 10,
    penultimateLabelAlignment,
    sankeyTerminalLabelAlignment: terminalLabelAlignment = "auto",
    sankeyLinkColorMode: linkColorMode = "source",
    sankeySortNodes: sortNodes = true,
  } = spec;
  const [selectedByField, setSelectedByField] = useState({});
  const [selectedLink, setSelectedLink] = useState(null);
  const [hoveredItem, setHoveredItem] = useState(null);
  const graph = useMemo(() => sankeyGraph(rows, stages, valueField), [rows, stages, valueField]);
  const total = useMemo(() => rows.reduce((sum, row) => {
    const value = Number(row[valueField]);
    return sum + (Number.isFinite(value) && value > 0 ? value : 0);
  }, 0), [rows, valueField]);
  const graphSignature = useMemo(() => JSON.stringify({
    nodes: graph.nodes.map(sankeyNodeKey),
    links: graph.links.map(({ source, target, value }) => [
      sankeyNodeKey(graph.nodes[source]),
      sankeyNodeKey(graph.nodes[target]),
      Number(value) || 0,
    ]),
  }), [graph]);
  const [nodeLayout, setNodeLayout] = useState({ signature: "", positions: {} });
  const reportNodePosition = useCallback((key, position) => {
    const y = Math.round(Number(position) * 100) / 100;
    if (!Number.isFinite(y)) return;
    setNodeLayout((current) => {
      if (current.signature !== graphSignature) {
        return { signature: graphSignature, positions: { [key]: y } };
      }
      if (current.positions[key] === y) return current;
      return { ...current, positions: { ...current.positions, [key]: y } };
    });
  }, [graphSignature]);
  const nodePositions = nodeLayout.signature === graphSignature ? nodeLayout.positions : {};
  const coloredGraph = useMemo(() => {
    const rankings = new Map();
    for (let stage = 0; stage < stages.length; stage += 1) {
      const nodes = graph.nodes.filter((node) => node.stage === stage);
      const positioned = nodes.every((node) => Number.isFinite(nodePositions[sankeyNodeKey(node)]));
      if (!positioned) {
        nodes.forEach((node) => rankings.set(sankeyNodeKey(node), { index: 0, count: 1 }));
        continue;
      }
      const ordered = nodes.map((node, index) => ({ node, index }))
        .sort((left, right) => nodePositions[sankeyNodeKey(left.node)] - nodePositions[sankeyNodeKey(right.node)]
          || left.index - right.index)
        .map(({ node }) => node);
      ordered.forEach((node, index) => rankings.set(sankeyNodeKey(node), { index, count: nodes.length }));
    }
    return {
      ...graph,
      nodes: graph.nodes.map((node) => {
        const exactColor = !colorByColumn || node.stage === stages.length - 1 ? colorMap?.[node.name] : undefined;
        const baseColor = colorMap?.[node.field]
          ?? colorFor({ field: node.field, dimension: node.field,
            ...(colorByColumn ? {} : { value: node.name }), index: node.stage });
        const rank = rankings.get(sankeyNodeKey(node)) ?? { index: 0, count: 1 };
        const strength = rank.count <= 1 ? 72 : 100 - Math.round(rank.index / (rank.count - 1) * 76);
        return {
          ...node,
          colorStrength: strength,
          color: exactColor ?? (colorByColumn
            ? `color-mix(in oklch, ${baseColor} ${strength}%, var(--surface))`
            : baseColor),
        };
      }),
    };
  }, [colorByColumn, colorFor, colorMap, graph, nodePositions, stages.length]);
  const availableNodeKeys = useMemo(() => new Set(graph.nodes.map(sankeyNodeKey)), [graph]);
  const availableLinkKeys = useMemo(() => new Set(graph.links.map(({ source, target }) =>
    sankeyLinkKey(graph.nodes[source], graph.nodes[target]))), [graph]);

  useEffect(() => {
    setHoveredItem(null);
    setSelectedLink((current) => current && availableLinkKeys.has(current.key) ? current : null);
    setSelectedByField((current) => {
      const entries = Object.entries(current).filter(([, selected]) => availableNodeKeys.has(selected.key));
      return entries.length === Object.keys(current).length ? current : Object.fromEntries(entries);
    });
  }, [availableLinkKeys, availableNodeKeys]);

  const toggleNode = useCallback((node) => {
    const selected = sankeySelection(node);
    setSelectedLink(null);
    setSelectedByField((current) => {
      const next = { ...current };
      if (next[selected.field]?.key === selected.key) delete next[selected.field];
      else next[selected.field] = selected;
      return next;
    });
  }, []);
  const toggleLink = useCallback((link) => {
    const selected = sankeyLinkSelection(link);
    setSelectedByField({});
    setSelectedLink((current) => current?.key === selected.key ? null : selected);
  }, []);
  const handleMouseEnter = useCallback((item, type) => {
    if (type === "node") {
      const node = sankeySelection(item.payload);
      setHoveredItem({ type, nodeKey: node.key, criteria: [node] });
      return;
    }
    setHoveredItem(sankeyLinkSelection(item.payload));
  }, []);
  const handleMouseLeave = useCallback(() => setHoveredItem(null), []);
  const handleClick = useCallback((item, type, event) => {
    event?.stopPropagation();
    if (type === "node") toggleNode(item.payload);
    else if (type === "link") toggleLink(item.payload);
  }, [toggleLink, toggleNode]);
  const selectedNodes = useMemo(() => Object.values(selectedByField), [selectedByField]);
  useEffect(() => { onSelection?.(selectedLink?.criteria ?? selectedNodes); }, [onSelection, selectedLink, selectedNodes]);
  const focusedLink = selectedLink ?? (!selectedNodes.length && hoveredItem?.type === "link" ? hoveredItem : null);
  const criteria = selectedNodes.length ? selectedNodes
    : focusedLink ? emptySankeyCriteria : hoveredItem?.criteria ?? emptySankeyCriteria;
  const matchingRows = useMemo(() => {
    if (!criteria.length) return rows;
    return rows.filter((row) => criteria.every((selected) =>
      String(row[selected.field] ?? "") === selected.name));
  }, [criteria, rows]);
  const activeGraph = useMemo(() => {
    if (!criteria.length) return graph;
    return sankeyGraph(matchingRows, stages, valueField);
  }, [criteria.length, graph, matchingRows, stages, valueField]);
  const selectedNodeKeys = useMemo(() => new Set(selectedNodes.map(({ key }) => key)), [selectedNodes]);
  const selectedLinkKeys = useMemo(() => new Set(selectedLink ? [selectedLink.key] : []), [selectedLink]);
  const activeNodeKeys = useMemo(() => {
    if (focusedLink) return new Set([focusedLink.sourceKey, focusedLink.targetKey]);
    const keys = new Set(activeGraph.nodes.map(sankeyNodeKey));
    selectedNodes.forEach(({ key }) => keys.add(key));
    return keys;
  }, [activeGraph, focusedLink, selectedNodes]);
  const activeLinkKeys = useMemo(() => focusedLink ? new Set([focusedLink.key])
    : new Set(activeGraph.links.map(({ source, target }) =>
      sankeyLinkKey(activeGraph.nodes[source], activeGraph.nodes[target]))), [activeGraph, focusedLink]);
  const interaction = useMemo(() => ({
    engaged: Boolean(focusedLink) || criteria.length > 0,
    pinned: Boolean(selectedLink) || selectedNodes.length > 0,
    activeNodeKeys,
    activeLinkKeys,
    selectedNodeKeys,
    selectedLinkKeys,
    hoveredNodeKey: selectedLink || selectedNodes.length ? null
      : hoveredItem?.type === "node" ? hoveredItem.nodeKey : null,
    hoveredLinkKey: hoveredItem?.type === "link" ? hoveredItem.linkKey : null,
    toggleNode,
    toggleLink,
    reportNodePosition,
  }), [activeLinkKeys, activeNodeKeys, criteria.length, focusedLink, hoveredItem, selectedLink, selectedLinkKeys,
    selectedNodeKeys, selectedNodes.length, reportNodePosition, toggleLink, toggleNode]);
  const nodeRenderer = useMemo(() => <SankeyNode colorFor={colorFor} showValues={showValues}
    lastStage={Math.max(0, stages.length - 1)} labelMaxLength={labelMaxLength}
    labelFontSize={labelFontSize} valueFontSize={valueFontSize}
    penultimateLabelAlignment={penultimateLabelAlignment} terminalLabelAlignment={terminalLabelAlignment} />,
  [colorFor, labelFontSize, labelMaxLength, penultimateLabelAlignment, showValues, stages.length,
    terminalLabelAlignment, valueFontSize]);
  const linkRenderer = useMemo(() => <SankeyLinkPath colorMode={linkColorMode} />, [linkColorMode]);
  const expandedLayout = nodeWidth > 12 || labelFontSize > 11;
  const sankeyLayoutMargin = terminalLabelAlignment === "right"
    ? { ...expandedSankeyMargin, right: 320 }
    : expandedLayout ? expandedSankeyMargin : sankeyMargin;

  if (!graph.nodes.length || !graph.links.length) {
    return <svg role="img" aria-label="No matching flow paths" viewBox="0 0 100 100"
      preserveAspectRatio="xMidYMid meet">
      <text x="50" y="50" textAnchor="middle" dominantBaseline="middle"
        fill="var(--secondary)" fontSize="4">No matching flows</text>
    </svg>;
  }
  return <SankeyInteractionContext.Provider value={interaction}>
    <Sankey data={coloredGraph} node={nodeRenderer} link={linkRenderer} nodeWidth={nodeWidth}
      nodePadding={expandedLayout ? 18 : 16} iterations={48}
      margin={sankeyLayoutMargin} align="justify" sort={sortNodes}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave} onClick={handleClick}>
      <Tooltip content={<SankeyTooltip total={total} />} isAnimationActive={false} cursor={false} />
    </Sankey>
  </SankeyInteractionContext.Provider>;
}
