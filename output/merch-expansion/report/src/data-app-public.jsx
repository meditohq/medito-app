export { Chart, Chart as ChartRenderer } from "./components/Chart.jsx";
export { ChartEditor } from "./components/ChartEditor.jsx";
export { ContainedDialog, NativeSelect } from "./components/contained-ui.jsx";
export { barChartSpec } from "./charting/bar-family.js";
export { chartDataShape, chartSpecKeys, groupAdditiveCategories, projectChartSpec } from "./charting/chart-data-shape.js";
export { normalizeChartAnnotations, resolveChartAnnotations } from "./charting/chart-annotations.js";
export {
  compact,
  displayValue,
  label,
  percentage,
  periodComparison,
  semanticColorResolver,
  shortDate,
} from "./charting/chart-theme.js";
export { DataTable, DataTable as Table, DateRangePicker, Dropdown, Filters, InlineFilters } from "./components/Controls.jsx";
export { ChartTooltip } from "./charting/ChartTooltip.jsx";
export { ChartMark } from "./charting/ChartMark.jsx";
export { DataComponent, ReportSection } from "./components/DataComponent.jsx";
export { EvidenceChart } from "./components/EvidenceChart.jsx";
export { MetricCard, MetricCardTabs, MetricSparkline } from "./components/MetricCard.jsx";
export { RangeSlider, Slider } from "./components/Slider.jsx";
export { SegmentedControl } from "./components/SegmentedControl.jsx";
export { Switch } from "./components/Switch.jsx";
export { ExecutiveSummary } from "./components/ExecutiveSummary.jsx";
export { EditableText } from "./components/EditableText.jsx";
export { Section, SectionHeader } from "./components/Section.jsx";
export { SectionNavigator } from "./components/SectionNavigator.jsx";
export { useSectionFilters } from "./use-section-filters.js";
export { RichNarrative } from "./components/RichMarkdown.jsx";
export { Icon } from "./components/Icon.jsx";
export { SourceInspector, SourceSidebar } from "./components/SourceInspector.jsx";
export { useDataAppShell as useDataApp, useDashboardTabs } from "./DataAppContext.jsx";
export { previousPeriodRows } from "./use-data-app.js";

export { SortableItem, SortableRegion } from "./components/SortableRegion.jsx";
export { Button, Dialog, InfoTooltip, Menu, MenuItem, MenuSub, MenuGroup, MenuSeparator, Tooltip, TruncatedText } from "./components/ui.jsx";
export { TabPanel, Tabs } from "./components/ui.jsx";

export { QueryDataBoundary } from "./components/QueryDataBoundary.jsx";
