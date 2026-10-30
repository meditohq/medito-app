/** Reviewed heatmap cells can be selected; absent or unobserved cells cannot. */
export function canSelectHeatmapCell(row) {
  return row != null && !row.__unknown && !row.__missing;
}

export function exploreMarkKey(event, select) {
  if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) {
    event.preventDefault(); event.stopPropagation();
    const marks = [...event.currentTarget.closest(".chart-frame").querySelectorAll(".chart-explore-mark")];
    const direction = ["ArrowLeft", "ArrowUp"].includes(event.key) ? -1 : 1;
    marks[(marks.indexOf(event.currentTarget) + direction + marks.length) % marks.length]?.focus();
  } else if (["Enter", " "].includes(event.key)) { event.preventDefault(); event.stopPropagation(); select(event); }
}
