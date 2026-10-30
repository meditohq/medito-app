import React from "react";
import { Cell, Label, LabelList, Pie, PieChart, Sector, useIsTooltipActive } from "recharts";
import { compact, percentage } from "./chart-theme.js";

function ActivePieSlice(props) {
  const active = useIsTooltipActive();
  return <Sector {...props} data-pie-active={active || undefined} />;
}

export function PieRenderer({ spec, rows: slices, colorFor, onSelect, children }) {
  const { x, y } = spec;
  const total = slices.reduce((sum, row) => sum + Math.max(0, Number(row[y]) || 0), 0);
  const positiveSlices = slices.filter((row) => row[y] > 0);
  const minimumSliceAngle = total ? Math.min(...positiveSlices.map((row) => row[y] / total * 360)) : 0;
  const sliceGap = positiveSlices.length > 1 ? Math.min(1.5, minimumSliceAngle / 4) : 0;
  const centerValue =
    spec.centerValue ??
    (spec.centerLabel && slices[0] && total ? percentage(Number(slices[0][y]) / total).replace("+", "") : undefined);
  return (
    <PieChart accessibilityLayer>
      {children}
      <Pie
        className="chart-pie"
        activeShape={<ActivePieSlice />}
        data={slices}
        dataKey={y}
        nameKey={x}
        cx="50%"
        cy="50%"
        innerRadius="54%"
        outerRadius="82%"
        paddingAngle={sliceGap}
        stroke="none"
        isAnimationActive={false}
        onClick={(entry, index, event) => onSelect?.(entry?.payload ?? slices[index], event)}
      >
        {slices.map((row) => (
          <Cell
            key={String(row[x])}
            fill={colorFor(row)}
          />
        ))}
        {spec.showValues && (
          <LabelList dataKey={y} position="outside" formatter={compact} fill="var(--secondary)" fontSize={12} />
        )}
        {centerValue != null && (
          <Label
            position="center"
            content={({ viewBox }) => {
              const centerX = Number(viewBox?.cx ?? Number(viewBox?.x) + Number(viewBox?.width) / 2);
              const centerY = Number(viewBox?.cy ?? Number(viewBox?.y) + Number(viewBox?.height) / 2);
              if (!Number.isFinite(centerX) || !Number.isFinite(centerY)) return null;
              return (
                <g className="chart-donut-center">
                  <text
                    x={centerX}
                    y={centerY - (spec.centerLabel ? 5 : 0)}
                    textAnchor="middle"
                    dominantBaseline="middle"
                    fill="var(--text)"
                    fontSize={26}
                    fontWeight={500}
                  >
                    {centerValue}
                  </text>
                  {spec.centerLabel && (
                    <text
                      x={centerX}
                      y={centerY + 19}
                      textAnchor="middle"
                      dominantBaseline="middle"
                      fill="var(--secondary)"
                      fontSize={12}
                    >
                      {spec.centerLabel}
                    </text>
                  )}
                </g>
              );
            }}
          />
        )}
      </Pie>
    </PieChart>
  );
}
