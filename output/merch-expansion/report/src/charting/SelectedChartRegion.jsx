import React from "react";

export function SelectedChartRegion({ region }) {
  const props = { className: `dashboard-ask-selected-region is-${region.selectionType ?? "band"}`, "aria-hidden": true,
    style: { left: region.left, top: region.top, width: region.width, height: region.height } };
  if (region.selectionType !== "point") return <div {...props} />;
  return <svg {...props}>
    <line x1={0.5} x2={0.5} y1={0} y2={region.height} stroke={region.cursorStroke || "var(--border)"} strokeWidth={1} />
    {region.points.map((point, index) => <circle key={index} cx={point.x} cy={point.y} r={point.radius}
      fill={point.fill} fillOpacity={point.fillOpacity} opacity={point.opacity} stroke={point.stroke} strokeWidth={point.strokeWidth} />)}
  </svg>;
}
