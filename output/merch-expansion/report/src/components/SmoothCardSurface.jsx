import React, { useLayoutEffect, useMemo, useRef, useState } from "react";
import { getSvgPath } from "figma-squircle";

// Paint only the card surface: clipping the component itself would also clip
// tooltips, menus, focus rings, and the existing CSS shadow.
export function SmoothCardSurface() {
  const ref = useRef(null);
  const [geometry, setGeometry] = useState(null);
  useLayoutEffect(() => {
    const card = ref.current.parentElement;
    function measure() {
      const style = getComputedStyle(card);
      const width = parseFloat(style.width);
      const height = parseFloat(style.height);
      const radius = parseFloat(style.borderTopLeftRadius);
      const border = parseFloat(style.borderTopWidth);
      // Nonuniform borders/radii and container-free report blocks keep their CSS.
      const uniform = [style.borderTopRightRadius, style.borderBottomRightRadius, style.borderBottomLeftRadius]
        .every((value) => value === style.borderTopLeftRadius)
        && [style.borderRightWidth, style.borderBottomWidth, style.borderLeftWidth]
          .every((value) => value === style.borderTopWidth)
        && [style.borderTopStyle, style.borderRightStyle, style.borderBottomStyle, style.borderLeftStyle]
          .every((value) => value === (border ? "solid" : "none"));
      const valid = uniform && /^\d+(?:\.\d+)?px$/u.test(style.borderTopLeftRadius)
        && style.boxSizing === "border-box" && radius > 0
        && width > border && height > border;
      const next = valid ? { width, height, radius, border } : null;
      setGeometry((previous) => previous?.width === next?.width && previous?.height === next?.height
        && previous?.radius === next?.radius && previous?.border === next?.border ? previous : next);
    }
    measure();
    const resizeObserver = new ResizeObserver(measure);
    resizeObserver.observe(card, { box: "border-box" });
    const themeObserver = new MutationObserver(measure);
    themeObserver.observe(document.documentElement, {
      attributes: true, attributeFilter: ["style", "data-app-theme"],
    });
    themeObserver.observe(card, {
      attributes: true, attributeFilter: ["style", "class", "data-permalink-target"],
    });
    return () => { resizeObserver.disconnect(); themeObserver.disconnect(); };
  }, []);
  const inset = (geometry?.border ?? 0) / 2;
  const path = useMemo(() => geometry && getSvgPath({
    width: geometry.width - geometry.border,
    height: geometry.height - geometry.border,
    cornerRadius: Math.max(0, geometry.radius - inset),
    cornerSmoothing: 0.6,
  }), [geometry, inset]);
  return <svg ref={ref} className="smooth-card-surface" aria-hidden="true" focusable="false"
    data-ready={geometry ? "true" : undefined}
    data-corner-smoothing="0.6"
    style={geometry ? { left: -geometry.border, top: -geometry.border,
      width: geometry.width, height: geometry.height } : undefined}
    viewBox={geometry ? `0 0 ${geometry.width} ${geometry.height}` : undefined}>
    {path && <path d={path} transform={`translate(${inset} ${inset})`} strokeWidth={geometry.border} />}
  </svg>;
}
