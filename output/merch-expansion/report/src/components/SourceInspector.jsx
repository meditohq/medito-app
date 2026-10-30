import React, { useCallback, useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from "react";

// Standalone chart snippets only mount SourceSidebar. Keep receipt-only UI out
// of that release target; source builds, full apps, and receipts retain it.
const receiptsEnabled = typeof __DATA_SOURCE_RECEIPTS__ === "undefined" || __DATA_SOURCE_RECEIPTS__;

import { chartDataShape } from "../charting/chart-data-shape.js";
import { displayValue } from "../charting/chart-theme.js";
import { chartAnnotationFields } from "../charting/chart-annotations.js";
import { resolveChartSpec } from "../charting/chart-overrides.js";
import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { DataTable } from "./Controls.jsx";
import { Icon } from "./Icon.jsx";
import receiptTableIcon from "./icons/receipt-icon-table.svg?url";
import receiptChartIcon from "./icons/receipt-icon-chart.svg?url";
import receiptDocumentIcon from "./icons/receipt-icon-document.svg?url";
import receiptFileIcon from "./icons/receipt-icon-file.svg?url";
import receiptPresentationIcon from "./icons/receipt-icon-file-presentation.svg?url";
import receiptCodeIcon from "./icons/receipt-icon-file-code.svg?url";
import receiptImageIcon from "./icons/receipt-icon-file-image.svg?url";
import receiptVideoIcon from "./icons/receipt-icon-file-video.svg?url";
import receiptAudioIcon from "./icons/receipt-icon-file-audio.svg?url";
import receiptLinkIcon from "./icons/receipt-icon-link.svg?url";
import { Select, TabPanel, Tabs } from "./ui.jsx";
import { NativeSelect } from "./contained-ui.jsx";
import {
  consolidatedReceipt,
  receiptQueryLabel,
  formatReviewedSql,
  referencedDefinitionVariable,
  reviewedDateRange,
  reviewedDefinitionLineage,
  reviewedQueryLabel,
  reviewedSource,
  safeSourceHref,
  scopedMetricDefinitions,
  sourceTrustLabels,
} from "../source-provenance.js";

const RECEIPT_TAB_MOTION = { duration: 220, easing: "cubic-bezier(.2,.75,.2,1)" };
// Restricted chart snippets share the editor's native control, keeping source
// selection inside the host without shipping the full app's portaled menu.
const SourceSelect = receiptsEnabled ? Select : NativeSelect;

function formatSnapshot(value, withTimezone = false) {
  return new Intl.DateTimeFormat(undefined, {
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    month: "short",
    year: "numeric",
    ...(withTimezone ? { timeZoneName: "short" } : {}),
  }).format(new Date(value));
}

function SqlCode({ sql, receipt = false }) {
  receipt = receiptsEnabled && receipt;
  if (receipt) {
    const parts = [];
    const pattern = /(--[^\n]*|'(?:''|[^'])*'|\b(?:SELECT|FROM|WHERE|AND|AS|WITH|DISTINCT|COUNT|COUNT_IF|DATE|ROUND|CROSS|LEFT|RIGHT|FULL|OUTER|JOIN|IS|NOT|NULL|FALSE|TRUE|GROUP|ORDER|BY|LIMIT|ON|IN|CASE|WHEN|THEN|ELSE|END|LOWER|UPPER|CAST|BIGINT|DOUBLE|VARCHAR|CURRENT_DATE|UNNEST|SEQUENCE|DATE_ADD|DATE_TRUNC|COALESCE|NULLIF|DAY_OF_WEEK|OVER|PARTITION|AVG|SUM|MIN|MAX)\b|\b\d+(?:\.\d+)?\b)/gi;
    let cursor = 0;
    for (const match of sql.matchAll(pattern)) {
      parts.push(sql.slice(cursor, match.index));
      const token = match[0];
      const className = token.startsWith("--") ? "sql-comment" : token.startsWith("'") ? "sql-string"
        : /^\d/.test(token) ? "sql-number" : "sql-keyword";
      parts.push(<span key={match.index} className={className}>{token}</span>);
      cursor = match.index + token.length;
    }
    parts.push(sql.slice(cursor));
    return parts;
  }
  return (sql ?? "No reviewed SQL provided.")
    .split(/(\b(?:SELECT|FROM|WHERE|AS|ORDER BY|GROUP BY|JOIN|AND|OR|LIMIT|WITH)\b|'.*?')/gi)
    .map((part, index) => {
      const keyword = /^(SELECT|FROM|WHERE|AS|ORDER BY|GROUP BY|JOIN|AND|OR|LIMIT|WITH)$/i.test(part);
      return (
        <span className={keyword ? "sql-keyword" : /^'.*'$/.test(part) ? "sql-string" : undefined} key={index}>
          {part}
        </span>
      );
    });
}

function SourcePill({ children, href }) {
  const safeHref = safeSourceHref(href);
  const Element = safeHref ? "a" : "span";
  return (
    <Element
      className="source-pill"
      href={safeHref ?? undefined}
      target={safeHref ? "_blank" : undefined}
      rel={safeHref ? "noreferrer" : undefined}
    >
      <Icon name="database" size={14} />
      <span>{children}</span>
    </Element>
  );
}

function SourceTrust({ trust, kind }) {
  const assetType =
    kind === "table" ? "Table" : kind === "file" ? "File" : kind === "dashboard" ? "Dashboard" : "Source";
  const labels = [assetType, ...sourceTrustLabels(trust)];
  return <>
    <span className="source-trust">{labels.join(" · ")}</span>
    {trust?.usageNote && <span className="source-usage-note">{trust.usageNote}</span>}
  </>;
}

const receiptIcons = {
  table: receiptTableIcon, dashboard: receiptChartIcon, link: receiptLinkIcon,
  file: receiptFileIcon, document: receiptDocumentIcon, presentation: receiptPresentationIcon,
  code: receiptCodeIcon, image: receiptImageIcon, video: receiptVideoIcon, audio: receiptAudioIcon,
};
const fileExtensions = {
  document: new Set(["pdf", "doc", "docx", "txt", "md", "rtf"]),
  presentation: new Set(["ppt", "pptx", "key"]),
  code: new Set(["py", "r", "sql", "js", "jsx", "ts", "tsx", "ipynb", "sh"]),
  image: new Set(["jpg", "jpeg", "png", "gif", "webp", "svg", "tif", "tiff", "heic"]),
  video: new Set(["mp4", "mov", "webm", "mkv"]),
  audio: new Set(["mp3", "m4a", "wav", "flac", "aiff"]),
};

function receiptIconKind(kind, label) {
  if (kind !== "file") return Object.hasOwn(receiptIcons, kind) ? kind : "file";
  // File format is presentation-only and comes from the recorded filename.
  const extension = /\.([a-z\d]+)$/iu.exec(typeof label === "string" ? label.trim() : "")?.[1]?.toLowerCase();
  return Object.entries(fileExtensions).find(([, extensions]) => extensions.has(extension))?.[0] ?? "file";
}

export function ReceiptSourceIcon({ kind, label, className = "" }) {
  const iconKind = receiptIconKind(kind, label);
  return <span className={`dashboard-icon receipt-source-icon ${className}`.trim()} aria-hidden="true"
    data-source-kind={kind} data-source-icon={iconKind}
    style={{ width: 16, height: 16, "--dashboard-icon-mask": `url("${receiptIcons[iconKind]}")` }} />;
}

function SourceRow({ label, href, trust, role, kind = "link", receipt = false }) {
  receipt = receiptsEnabled && receipt;
  const safeHref = safeSourceHref(href);
  const Element = safeHref ? "a" : "span";
  const icon = kind === "table" || kind === "file" ? "database" : kind === "dashboard" ? "monitor" : "link";
  const displayLabel = receipt && kind === "table" && /^[a-z_][\w]*(?:\.[a-z_][\w]*)+$/iu.test(label)
    ? label.split(".").at(-1) : label;
  return (
    <Element
      className="source-row"
      data-source-kind={kind}
      data-source-title={receipt ? label : undefined}
      data-source-reason={receipt ? role : undefined}
      aria-label={receipt ? label : undefined}
      tabIndex={receipt && !safeHref ? 0 : undefined}
      href={safeHref ?? undefined}
      target={safeHref ? "_blank" : undefined}
      rel={safeHref ? "noreferrer" : undefined}
    >
      {receipt ? <ReceiptSourceIcon kind={kind} label={label} className="source-row-icon" />
        : <Icon name={icon} size={17} className="source-row-icon" />}
      <span className="source-row-copy">
        <span className="source-row-title">{displayLabel}</span>
        <SourceTrust trust={trust} kind={kind} />
      </span>
      {safeHref && <Icon name="arrowUpRight" size={15} className="source-row-external" />}
    </Element>
  );
}

function EvidenceStep({ index, step, collapsible = false, code }) {
  const record = typeof step === "string" ? { title: step } : step ?? {};
  const title = record.title ?? record.label ?? `Evidence step ${index + 1}`;
  const detail = record.detail ?? record.description ?? record.summary ?? record.text;
  const links = Array.isArray(record.links) ? record.links : [];
  const Content = collapsible ? "details" : "div";
  const Body = collapsible ? "div" : React.Fragment;

  return (
    <li className="source-trace-step">
      {!collapsible && <span className="source-trace-marker" aria-hidden="true">
        {index + 1}
      </span>}
      <Content className="source-trace-copy">
        {collapsible ? <summary><span className="source-trace-marker" aria-hidden="true">{index + 1}</span>
          <strong>{title}</strong><Icon name="chevronRight" size={15} /></summary> : <strong>{title}</strong>}
        <Body {...(collapsible ? { className: "receipt-trace-expanded" } : {})}>
        {detail && <p>{detail}</p>}
        {code !== undefined && <pre className="receipt-method"><code>{code}</code></pre>}
        {!!links.length && (
          <div className="source-pills">
            {links.map((entry, linkIndex) => {
              const link = typeof entry === "string" ? { label: entry, href: entry } : entry;
              return (
                <SourcePill key={`${link.label ?? link.href}:${linkIndex}`} href={link.href ?? link.url}>
                  {link.label ?? link.name ?? link.href ?? link.url}
                </SourcePill>
              );
            })}
          </div>
        )}
        </Body>
      </Content>
    </li>
  );
}

function scopedProvidedEvidence(evidenceFlow, definitions, activeFilters) {
  const detail = definitions.map(({ label, definition }) => `${label}: ${definition}`).join(" · ");
  const result = [];
  let includedDefinitions = false;

  for (const step of evidenceFlow) {
    const title = typeof step === "string" ? step : step?.title ?? step?.label ?? "";
    const definitionStep =
      /(?:metric\s+definitions?|definitions?\s+of\s+metrics?)/iu.test(title) ||
      Boolean(
        step &&
          typeof step === "object" &&
          (Object.hasOwn(step, "definitions") ||
            Object.hasOwn(step, "metricDefinitions") ||
            Object.hasOwn(step, "metric_definitions")),
      );

    if (!definitionStep) {
      result.push(step);
      continue;
    }
    if (!definitions.length || includedDefinitions) continue;

    const record = typeof step === "string" ? { title } : { ...step };
    delete record.definitions;
    delete record.metricDefinitions;
    delete record.metric_definitions;
    delete record.description;
    delete record.summary;
    delete record.text;
    result.push({ ...record, title: title || "Provided metric definitions", detail });
    includedDefinitions = true;
  }

  if (definitions.length && !includedDefinitions) {
    result.push({ title: "Provided metric definitions", detail });
  }
  if (activeFilters.length) {
    result.push({ title: "Current component filters", detail: activeFilters.join(" · ") });
  }
  return result;
}

function ReceiptSummaries({ summaries }) {
  return !!summaries.length && <div className="source-group">
    {summaries.map(({ value }, index) => <p key={index} className="receipt-description">
      {value}
    </p>)}
  </div>;
}

function DefinitionSentence({ record }) {
  const position = record.definition.toLowerCase().indexOf(record.label.toLowerCase());
  return position >= 0 ? <>{record.definition.slice(0, position)}<strong>{record.definition.slice(position, position + record.label.length)}</strong>{record.definition.slice(position + record.label.length)}</>
    : <><strong>{record.label}:</strong> {record.definition}</>;
}

function ReceiptOverview({ overview, assumptions, description }) {
  const { definitions, summaries, sources, caveats } = overview;
  // Authored sentences carry their subject and scope. Source ownership stays
  // in provenance, rather than becoming an automatic prefix in the prose.
  const qualifications = new Set([...(assumptions ?? []), ...caveats.map(({ value }) => value)]);
  return <>
    {description && <p className="receipt-description">{description}</p>}
    {!!definitions.length && <div className="receipt-definitions">
      <p className="source-label">Definitions</p>
      <ul className="receipt-definition-list">{definitions.map(({ value: record }, index) => {
        const calculation = record.calculationSummary;
        const redundant = calculation?.trim().toLowerCase().replace(/[.!?]+$/u, "")
          === record.definition.trim().toLowerCase().replace(/[.!?]+$/u, "");
        return <li className="receipt-definition-entry" key={index}>
          <p><DefinitionSentence record={record} /></p>
          {(calculation || record.formula) && <div className="receipt-definition-metadata">
            {calculation ? !redundant && <span className="receipt-definition-method">{calculation}</span>
              : record.formula && <span className="source-definition-formula">{record.formula}</span>}
          </div>}
        </li>;
      })}</ul>
    </div>}
    {!definitions.length && <ReceiptSummaries summaries={summaries} />}
    {qualifications.size > 0 && <div className="source-group receipt-qualifications">
      <p className="source-label">Assumptions and caveats</p>
      <ul className="receipt-qualification-list">{[...qualifications].map((text, index) =>
        <li key={index}>{text}</li>)}</ul>
    </div>}
    <div className="source-group">
      <p className="source-label">Sources</p>
      <div className="source-list">{sources.map(({ value }, index) => <SourceRow key={index} receipt {...value} />)}</div>
    </div>
  </>;
}

function visibleReceiptEvidence(overview) {
  return overview.evidence.filter(({ value }) => value.step?.showInReceipt !== false);
}

function supplementalReceiptCalculations(overview) {
  // The definition's calculation summary (or fallback formula) is already in
  // Overview. Only a formula hidden by that summary adds detail here.
  return overview.definitions.filter(({ value }) => value.calculationSummary && value.formula);
}

function hasReceiptEvidence(overview) {
  return visibleReceiptEvidence(overview).length || overview.filters.length || overview.periods.length
    || overview.sources.some(({ value }) => value.role)
    || overview.definitions.some((entry) => entry.lineage.length)
    || supplementalReceiptCalculations(overview).length
    || (overview.definitions.length && overview.summaries.length);
}

function ReceiptTraceSection({ label, children }) {
  return <div className="receipt-trace-section">
    {label && <p className="receipt-trace-section-label">{label}</p>}{children}
  </div>;
}

function receiptFilterEntries({ filters, periods }) {
  const unique = new Map();
  const entries = [
    ...periods.map((entry) => ({ ...entry, value: { label: "Reporting period", value: entry.value } })),
    ...filters,
  ];
  for (const { value, sourceLabels, scopeLabels } of entries) {
    const key = JSON.stringify(value);
    if (!unique.has(key)) unique.set(key, { value, sourceLabels: new Set(), shared: false });
    unique.get(key).shared ||= scopeLabels.length === 0;
    sourceLabels.forEach((label) => unique.get(key).sourceLabels.add(label));
  }
  return [...unique.values()].map(({ value, sourceLabels, shared }) => ({ value,
    sourceLabels: [...sourceLabels], scopeLabels: shared ? [] : [...sourceLabels],
  }));
}

function ReceiptFilters({ filters, periods }) {
  const values = receiptFilterEntries({ filters, periods });
  return <ReceiptTraceSection>
    <div className="receipt-trace-chips" role="group" aria-label="Filters and reporting period">
      {values.map(({ value, scopeLabels }, index) => {
        // Absence from another query is also a scope difference.
        return <code className="receipt-trace-chip" key={index}>
          {scopeLabels.length > 0 ? `${scopeLabels.join(" · ")}: ` : ""}{value.label ? `${value.label} = ` : ""}{value.value}
        </code>;
      })}
    </div>
  </ReceiptTraceSection>;
}

function ReceiptRecordedSteps({ entries, showTitle = true, checkpointTitle }) {
  return entries.map(({ value }, index) => {
    const record = typeof value.step === "string" ? { title: value.step } : value.step;
    const detail = record.detail ?? record.description ?? record.summary ?? record.text;
    const title = record.title ?? record.label;
    const generic = [checkpointTitle, "Calculation", "Method", "Python calculation"].some((label) =>
      label && title?.trim().toLowerCase() === label.toLowerCase());
    const label = value.language === "python" ? "Python" : showTitle && !generic ? title : undefined;
    return <ReceiptTraceSection key={index} label={label}>
      {detail && <p>{detail}</p>}
      {value.code !== undefined && (value.language === "python"
        ? <pre className="receipt-method"><code>{value.code}</code></pre>
        : <p className="receipt-calculation-text">{value.code}</p>)}
      {!!record.links?.length && <div className="source-pills">{record.links.map((entry, linkIndex) => {
        const link = typeof entry === "string" ? { label: entry, href: entry } : entry;
        return <SourcePill key={linkIndex} href={link.href ?? link.url}>{link.label ?? link.name ?? link.href ?? link.url}</SourcePill>;
      })}</div>}
    </ReceiptTraceSection>;
  });
}

// Group accepted facts into conditional checkpoints. Metadata is detail
// inside its checkpoint, never a loose block beside the flow. Do not infer a
// step's meaning from its title or invent a review status for captured data.
function ReceiptEvidence({ overview, hasData, hasSql, onNavigate }) {
  const { definitions, summaries, sources, filters, periods } = overview;
  const evidence = visibleReceiptEvidence(overview);
  const grouped = { question: [], definition: [], source: [], filter: [], calculation: [], result: [], untyped: [] };
  for (const entry of evidence) {
    const kind = entry.value.step?.kind;
    const checkpoint = ({ metric: "definition", method: "calculation", validation: "result" })[kind] ?? kind;
    (Object.hasOwn(grouped, checkpoint) ? grouped[checkpoint] : grouped.untyped).push(entry);
  }
  const steps = [];
  const recorded = (key, title) => <ReceiptRecordedSteps entries={grouped[key]} checkpointTitle={title} />;
  const add = (key, title, content) => steps.push({ key, title, content });
  if (grouped.question.length || (definitions.length && summaries.length)) add("question", "Question and scope", <>
    {definitions.length > 0 && <ReceiptSummaries summaries={summaries} />}{recorded("question", "Question and scope")}
  </>);
  const definitionLineage = definitions.filter(({ lineage }) => lineage.length);
  if (definitionLineage.length || grouped.definition.length) add("definition", "Definitions", <>
    {definitionLineage.map(({ value, lineage }, index) => <ReceiptTraceSection key={index} label={value.label}>
      <p className="source-definition-lineage">{lineage.join(" · ")}</p>
    </ReceiptTraceSection>)}{recorded("definition", "Definitions")}
  </>);
  const explainedSources = sources.filter(({ value }) => value.role);
  if (explainedSources.length || grouped.source.length) add("source", "Source selection", <>
    {!!explainedSources.length && <ReceiptTraceSection><div className="receipt-trace-table-scroll" role="region" tabIndex={0} aria-label="Recorded source selection">
      <table className="receipt-trace-source-table" aria-label="Recorded source selection">
        <thead><tr><th scope="col">Source</th><th scope="col">Why it was used</th></tr></thead>
        <tbody>{explainedSources.map(({ value }, index) => <tr key={index}>
          <td><SourceRow receipt {...value} /></td><td>{value.role}</td>
        </tr>)}</tbody>
      </table>
    </div></ReceiptTraceSection>}
    {recorded("source", "Source selection")}
  </>);
  if (filters.length || periods.length || grouped.filter.length) add("filter", "Filters and reporting period", <>
    {recorded("filter", "Filters and reporting period")}
    <ReceiptFilters filters={filters} periods={periods} />
  </>);
  const calculations = supplementalReceiptCalculations(overview);
  if (calculations.length || grouped.calculation.length) add("calculation", "Calculation", <>
    {calculations.map(({ value }, index) => <ReceiptTraceSection key={index} label={value.label}>
      <p className="receipt-calculation-text">{value.formula}</p>
    </ReceiptTraceSection>)}
    {recorded("calculation", "Calculation")}
    {hasSql && <button className="receipt-trace-action" type="button" onClick={() => onNavigate("sql")}>View exact SQL</button>}
  </>);
  // Legacy untyped records remain truthful; new authors supply a checkpoint kind.
  grouped.untyped.forEach((entry, index) => add(`recorded-${index}`, entry.value.step?.title ?? entry.value.step?.label ?? entry.value.step,
    <ReceiptRecordedSteps entries={[entry]} showTitle={false} />));
  if (grouped.result.length) add("result", "Verification", <>
    {recorded("result", "Verification")}
    {hasData && <button className="receipt-trace-action" type="button" onClick={() => onNavigate("data")}>View returned data</button>}
  </>);
  return <ol className="source-trace" data-evidence-origin="recorded">
    {steps.map(({ key, title, content }, index) => <li className="source-trace-step" key={key} data-checkpoint={key}>
      <details className="source-trace-copy"><summary>
        <span className="source-trace-marker" aria-hidden="true">{String(index + 1).padStart(2, "0")}</span>
        <strong>{title}</strong><Icon name="chevronRight" size={15} />
      </summary><div className="receipt-trace-expanded">{content}</div></details>
    </li>)}
  </ol>;
}

function componentEvidence({ component, query, rows, filters, chartOverride, chartEdited = false }) {
  const chart = resolveChartSpec(component.chart, chartOverride);
  const displayedFields = chartEdited === true && chart
    ? [...new Set([chart.y, ...chartDataShape(chart, rows).rowFields, ...chartAnnotationFields(chart.annotations)].filter(Boolean))]
    : [
    ...new Set(
      [chart?.y, ...(Array.isArray(chart?.fields) ? chart.fields : []), ...chartAnnotationFields(chart?.annotations)].filter(
        (field) => typeof field === "string" && field.trim(),
      ),
    ),
  ];
  const source = reviewedSource(query?.source);
  const { sql, tables, files, definitions, links, caveats, evidenceFlow } = source;
  const visibleDefinitions = scopedMetricDefinitions(definitions, component.id, {
    displayedFields,
    chartEdited: chartEdited === true || Boolean(chartOverride),
  });
  const dateRange = reviewedDateRange(rows, { component, query, filters });
  const freshness = Number.isFinite(Date.parse(source.executedAt)) ? source.executedAt : null;
  const scopedFilters = filters.filter(
    ({ field, queryIds }) =>
      (!Array.isArray(queryIds) || queryIds.includes(component.queryId)) &&
      query?.rows?.some((row) => Object.hasOwn(row, field)),
  );
  const describeFilter = ({ label, value }) => `${label}: ${displayValue(value)}`;
  const activeFilters = [...new Set(scopedFilters.map(describeFilter))];
  const providedEvidence = evidenceFlow.filter(step => typeof step === "string" ? step.trim()
    : step && [step.title, step.label, step.detail, step.description, step.summary, step.text]
      .some(value => typeof value === "string" && value.trim()));
  const evidence = providedEvidence.length
    ? scopedProvidedEvidence(providedEvidence, visibleDefinitions, activeFilters) : [];
  const hasSql = typeof sql === "string" && Boolean(sql.trim());
  const hasData = Array.isArray(query?.rows) || Array.isArray(component.sourceRows) || rows.length > 0;
  const hasSourceLabel = typeof source.label === "string" && source.label.trim() && source.label !== "Reviewed query";
  const hasOverview = Boolean(hasSourceLabel || dateRange || freshness || visibleDefinitions.length || caveats.length
    || tables.length || files.length || links.length || source.filters.length || activeFilters.length);
  return { source, visibleDefinitions, dateRange, freshness, activeFilters, evidence, hasSql, hasData, hasSourceLabel, hasOverview };
}

function SourceDetails({ component, query, rows = [], filters = [], allowCopy, receipt, section, chartEdited = false }) {
  receipt = receiptsEnabled && receipt;
  const [copied, setCopied] = useState(false);
  const chartOverride = useOptionalDataAppShell()?.chartOverrides?.[component.id];
  const { source, visibleDefinitions, dateRange: componentDateRange, freshness, activeFilters, evidence, hasSql, hasSourceLabel } =
    componentEvidence({ component, query, rows, filters, chartOverride, chartEdited });
  const { sql, queryLink, tables, tableLinks, tableTrust, files, links, caveats } = source;
  const dateRange = receipt ? receipt.reportingPeriod : componentDateRange;

  useEffect(() => {
    if (!copied) return undefined;
    const timeout = window.setTimeout(() => setCopied(false), 1400);
    return () => window.clearTimeout(timeout);
  }, [copied]);

  useEffect(() => setCopied(false), [component.queryId]);

  async function copySql() {
    if (!allowCopy || !sql) return;
    try {
      await navigator.clipboard?.writeText(sql);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  return (
    <>

      {section === "overview" && <>
        {!receipt && (dateRange || freshness) && <dl className="source-metadata">
          {!!dateRange && (
            <div>
              <dt>Reporting period</dt>
              <dd>{dateRange}</dd>
            </div>
          )}
          {!!freshness && (
            <div>
              <dt>{hasSql ? "Query executed" : "Source captured"}</dt>
              <dd>{formatSnapshot(freshness)}</dd>
            </div>
          )}
        </dl>}

        {!receipt && !!(source.filters.length || activeFilters.length) && <div className="source-group">
          <p className="source-label">Filters</p>
          <ul className="source-caveats">{[...new Set([...source.filters, ...activeFilters])].map(value => <li key={value}>{value}</li>)}</ul>
        </div>}
        {!receipt && !!visibleDefinitions.length && (
          <div className="source-group">
            <p className="source-label">Definitions</p>
            <table className="source-definitions">
              <tbody>
                {visibleDefinitions.map((record) => {
                  const { label, chartLabel, definition, formula } = record;
                  const variable = referencedDefinitionVariable(record, visibleDefinitions);
                  const lineage = reviewedDefinitionLineage(record, { tables, files });
                  return (
                    <tr key={label}>
                      <th scope="row">
                        {chartLabel ?? label}
                        {variable && (
                          <span className="source-definition-formula source-definition-variable">{variable}</span>
                        )}
                      </th>
                      <td>
                        {definition}
                        {formula && <span className="source-definition-formula">{formula}</span>}
                        {!!lineage.length && <span className="source-definition-lineage">{lineage.join(" · ")}</span>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        {!!caveats.length && (
          <div className="source-group">
            <p className="source-label">Assumptions and caveats</p>
            <ul className="source-caveats">
              {caveats.map((caveat) => (
                <li key={caveat}>{caveat}</li>
              ))}
            </ul>
          </div>
        )}
        {!!(receipt || hasSourceLabel || tables.length || files.length || links.length) && (
          <div className="source-group">
            <p className="source-label">Sources</p>
            <div className="source-list">
              {(receipt || hasSourceLabel) && !tables.length && !files.length && !links.length && <SourceRow receipt={Boolean(receipt)} label={source.label} />}
              {tables.map((table) => (
                <SourceRow
                  receipt={Boolean(receipt)}
                  key={`table:${table}`}
                  kind="table"
                  label={table}
                  href={tableLinks[table]}
                  trust={tableTrust[table]}
                />
              ))}
              {files.map(({ label, href }) => (
                <SourceRow receipt={Boolean(receipt)} key={`file:${label}`} kind="file" label={label} href={href} />
              ))}
              {links.map((entry, index) => {
                const href = safeSourceHref(typeof entry === "string" ? entry : entry.href);
                if (!href) return null;
                const label =
                  typeof entry !== "string" && entry.label
                    ? entry.label
                    : `Open reviewed source${index ? ` ${index + 1}` : ""}`;
                const trust = typeof entry === "string" ? null : entry.trust;
                const kind = typeof entry !== "string" && entry.kind === "dashboard" ? "dashboard" : "link";
                return <SourceRow receipt={Boolean(receipt)} key={`link:${href}`} kind={kind} label={label} href={href} trust={trust} />;
              })}
            </div>
          </div>
        )}
      </>}

      {section === "data" && <>
        {receipt?.preview && <p className="receipt-preview-note">
          <strong>{({ sample: "Sample", partial: "Partial preview", aggregate: "Aggregated preview" })[receipt.preview.kind]}</strong>
          {": "}{receipt.preview.note}
          {receipt.preview.totalRows !== undefined && <> ({rows.length} of {receipt.preview.totalRows} recorded rows)</>}
        </p>}
        <DataTable key={component.queryId} rows={rows} compactNumbers={false} searchable={!receipt}
          columns={receipt?.columns}
          pageSize={receipt ? 50 : 8} paginationStyle={receipt ? "receipt" : "default"} />
      </>}

      {section === "sql" && <>
        {(section === "sql" && (!receipt || sql)) && (
          <div className="sql-viewer">
            {(!receipt || queryLink) && <div className="sql-toolbar">
              <div className="sql-source-links">
                {queryLink && <a href={queryLink.href} target="_blank" rel="noopener noreferrer">
                  <Icon name="arrowUpRight" size={14} />
                  {queryLink.label}
                </a>}
                {!receipt && links.map((entry, index) => {
                  const href = safeSourceHref(typeof entry === "string" ? entry : entry.href);
                  if (!href || href === queryLink?.href) return null;
                  const label =
                    typeof entry !== "string" && entry.label
                      ? entry.label.replace(/^reviewed\s+/iu, "Open ")
                      : `Open reviewed query${index ? ` ${index + 1}` : ""}`;
                  return (
                    <a key={href} href={href} target="_blank" rel="noreferrer" title={label}>
                      <Icon name="link" size={14} />
                      {label}
                    </a>
                  );
                })}
              </div>
              {!receipt && <div className="sql-toolbar-actions">
                {allowCopy && sql && (
                  <button type="button" className="sql-copy-button" onClick={copySql}>
                    <Icon name={copied ? "check" : "copy"} size={15} />
                    {copied ? "Copied" : "Copy"}
                  </button>
                )}
              </div>}
            </div>}
            <pre className="sql">
              <code>
                {(receipt ? sql : formatReviewedSql(sql))
                  .split("\n")
                  .map((line, index) => (
                    <span className="sql-line" key={index}>
                      <span className="sql-line-number" aria-hidden="true">
                        {index + 1}
                      </span>
                      <span className="sql-line-content">
                        <SqlCode sql={line} receipt={Boolean(receipt)} />
                      </span>
                    </span>
                  ))}
              </code>
            </pre>
          </div>
        )}
      </>}

      {section === "evidence" && <>
        <ol className="source-trace" data-evidence-origin="provided">
          {evidence.map((step, index) => (
            <EvidenceStep
              key={`${typeof step === "string" ? step : step.title ?? step.label}:${index}`}
              index={index}
              step={step}
              collapsible={Boolean(receipt)}
            />
          ))}
        </ol>
      </>}
    </>
  );
}

// Keep evidence records together in the finding's card without joining unrelated
// row sets, SQL, periods or source-scoped qualifications.
function hasReceiptSection(query, section) {
  if (section === "data") return query.rows !== undefined;
  const source = reviewedSource(query.source);
  if (section === "sql") return Boolean(source.sql);
  return true;
}

export function SourceInspector({ component, query, rows = [], filters = [], allowCopy = true, chartEdited = false, receiptQueries, onReceiptCollapse, receiptContentId, externalReceiptToggle = false, receiptAssumptions }) {
  receiptQueries = receiptsEnabled ? receiptQueries : undefined;
  const tabsId = `source-tabs-${useId()}`;
  const inspectorRoot = useRef(null);
  const [tab, setTab] = useState("overview");
  const receipt = Boolean(receiptQueries);
  const queries = receiptQueries ?? [query];
  const consolidated = useMemo(() => receiptQueries ? consolidatedReceipt(receiptQueries, component.id) : null,
    [receiptQueries, component.id]);
  const chartOverride = useOptionalDataAppShell()?.chartOverrides?.[component.id];
  const available = receipt ? null : componentEvidence({ component, query, rows, filters, chartOverride, chartEdited });
  const hasData = receipt ? queries.some((entry) => hasReceiptSection(entry, "data")) : available.hasData;
  const hasSql = receipt ? queries.some((entry) => hasReceiptSection(entry, "sql")) : available.hasSql;
  const hasEvidence = receipt ? hasReceiptEvidence(consolidated) : available.evidence.length;
  const hasOverview = receipt || available.hasOverview;
  const tabs = [
    ...(hasOverview ? [{ id: "overview", label: "Overview" }] : []),
    ...(hasData ? [{ id: "data", label: "Data preview" }] : []),
    ...(hasSql ? [{ id: "sql", label: "SQL query" }] : []),
    ...(hasEvidence ? [{ id: "evidence", label: "Evidence flow" }] : []),
  ];
  const selectedTab = tabs.some(item => item.id === tab) ? tab : tabs[0]?.id;
  const [overviewHeight, setOverviewHeight] = useState(null);
  useLayoutEffect(() => {
    if (!receipt || tabs.length < 2) return;
    const inspector = inspectorRoot.current;
    const overview = inspector?.querySelector(".receipt-panels > .receipt-overview");
    if (!overview) return;
    const measure = () => {
      const panels = overview.parentElement;
      const width = panels?.getBoundingClientRect().width;
      if (!width) return;
      let nextHeight;
      if (overview.hidden) {
        // Measure at the current width without changing the active panel's layout.
        // The anchored-panel rule otherwise forces the hidden Overview to its old height.
        const previousStyle = overview.getAttribute("style");
        try {
          overview.style.cssText = `position: absolute; visibility: hidden; pointer-events: none; width: ${width}px; height: auto; overflow: visible;`;
          overview.hidden = false;
          nextHeight = Math.ceil(overview.getBoundingClientRect().height);
        } finally {
          overview.hidden = true;
          if (previousStyle === null) overview.removeAttribute("style");
          else overview.setAttribute("style", previousStyle);
        }
      } else {
        nextHeight = Math.ceil(overview.getBoundingClientRect().height);
      }
      if (nextHeight > 0) setOverviewHeight((previous) => previous === nextHeight ? previous : nextHeight);
    };
    measure();
    const observer = typeof ResizeObserver === "function" ? new ResizeObserver(measure) : null;
    observer?.observe(inspector);
    observer?.observe(overview);
    inspector.ownerDocument.defaultView?.addEventListener("resize", measure);
    return () => {
      observer?.disconnect();
      inspector.ownerDocument.defaultView?.removeEventListener("resize", measure);
    };
  }, [receipt, component.id, tabs.length, selectedTab]);
  const handleToolbarClick = (event) => {
    if (!event.target.closest("button, a, input, select, textarea, [role='button']")) onReceiptCollapse?.();
  };
  const collapseControl = onReceiptCollapse && (externalReceiptToggle
    ? <span className="receipt-card-collapse-placeholder" aria-hidden="true" />
    : <button type="button" className="receipt-card-collapse"
    aria-label={`Collapse ${component.title}`} aria-expanded="true" aria-controls={receiptContentId}
    onClick={onReceiptCollapse}><Icon name="chevronDown" size={16} /></button>);
  if (receipt && tabs.length === 1) return <div className="source-inspector receipt-overview-only">
    {collapseControl && <div className="receipt-card-toolbar" onClick={handleToolbarClick}>
      <p className="receipt-card-title">{component.title}</p>{collapseControl}
    </div>}
    <section className="source-section receipt-overview" aria-label="Source details">
      <ReceiptOverview overview={consolidated} assumptions={receiptAssumptions} description={component.description} />
    </section>
  </div>;
  const panels = tabs.map(({ id }) => {
    const entries = queries.filter((entry) => !receipt || hasReceiptSection(entry, id));
    return <TabPanel key={id} keepMounted={receipt} tabsId={tabsId} tabId={id}
      active={selectedTab === id} className={`source-section${receipt && id === "overview" ? " receipt-overview" : ""}`}>
      {receipt && id === "overview" ? <>
        <ReceiptOverview overview={consolidated} assumptions={receiptAssumptions} description={component.description} />
      </> : receipt && id === "evidence" ? <ReceiptEvidence overview={consolidated} hasData={hasData} hasSql={hasSql} onNavigate={(next) => {
        setTab(next);
        // The initiating action is hidden after navigation; restore focus to its tab.
        requestAnimationFrame(() => inspectorRoot.current?.querySelector('[role="tab"][aria-selected="true"]')?.focus());
      }} /> : entries.map((entry) => {
        const queryLabel = receipt ? receiptQueryLabel(entry, queries) : "";
        const details = <SourceDetails component={receipt ? { ...component, queryId: entry.id } : component}
          query={entry} rows={receipt ? entry.rows ?? [] : rows} filters={filters} allowCopy={allowCopy}
          receipt={receipt ? entry : undefined} section={id} chartEdited={chartEdited} />;
        return receipt && (entries.length > 1 || (id === "sql" && queries.length > 1)) ? <section key={entry.id} className="receipt-source-section" aria-label={queryLabel}>
          <h3 className="receipt-source-heading">{queryLabel}</h3>
          {details}
        </section> : <React.Fragment key={entry?.id ?? "source"}>{details}</React.Fragment>;
      })}
    </TabPanel>;
  });
  const tabBar = tabs.length > 0 && <Tabs
    id={tabsId} className="source-tabs" label="Data source sections"
    items={tabs} value={selectedTab} onChange={setTab}
    indicatorMotion={receipt ? RECEIPT_TAB_MOTION : undefined}
  />;
  return <div ref={inspectorRoot} className="source-inspector">
    {receipt ? <div className="receipt-card-toolbar" onClick={handleToolbarClick}>
      {tabBar}
      {collapseControl}
    </div> : tabBar}
    {!tabs.length && <p className="source-section">Source details weren’t recorded for this block.</p>}
    {receipt ? <div className="receipt-panels" data-anchored={selectedTab !== "overview" && overviewHeight ? "" : undefined}
      style={overviewHeight ? { "--receipt-overview-height": `${overviewHeight}px` } : undefined}>{panels}</div> : panels}
  </div>;

}

export function SourceSidebar({ component, getSource, queries, onClose, variant = "viewport", allowCopy = true, chartEdited = false }) {
  const [ready, setReady] = useState(false);
  const [requestedQueryId, setSelectedQueryId] = useState(component.queryId);
  const [closing, setClosing] = useState(false);
  const closeTimer = useRef(null);
  const layerRef = useRef(null);
  const headingRef = useRef(null);
  const queryIds = component.queryIds?.length > 1 ? component.queryIds : [component.queryId];
  const selectedQueryId = queryIds.includes(requestedQueryId) ? requestedQueryId : component.queryId;
  const source = useMemo(() => (ready ? getSource(selectedQueryId) : null), [ready, getSource, selectedQueryId]);
  const selectedComponent = selectedQueryId === component.queryId
    ? component : { ...component, queryId: selectedQueryId, sourceRows: source?.rows };
  const dismiss = useCallback(() => {
    if (closeTimer.current) return;
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) return onClose();
    setClosing(true);
    closeTimer.current = window.setTimeout(onClose, 140);
  }, [onClose]);
  useEffect(() => {
    const ownerDocument = headingRef.current?.ownerDocument ?? document;
    const focusRoot = variant === "contained" ? headingRef.current?.getRootNode() : ownerDocument;
    let previousFocus = focusRoot?.activeElement ?? ownerDocument.activeElement;
    if (variant === "contained") {
      while (previousFocus?.shadowRoot?.activeElement) previousFocus = previousFocus.shadowRoot.activeElement;
    }
    headingRef.current?.focus({ preventScroll: true });
    let secondFrame;
    const frame = window.requestAnimationFrame(() => {
      secondFrame = window.requestAnimationFrame(() => setReady(true));
    });
    return () => {
      window.cancelAnimationFrame(frame);
      window.cancelAnimationFrame(secondFrame);
      window.clearTimeout(closeTimer.current);
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
    };
  }, [variant]);
  useEffect(() => {
    const target = variant === "contained" ? layerRef.current : window;
    const close = (event) => {
      if (event.key !== "Escape" || event.defaultPrevented) return;
      if (variant === "contained") {
        event.preventDefault();
        event.stopPropagation();
      }
      dismiss();
    };
    target?.addEventListener("keydown", close);
    return () => target?.removeEventListener("keydown", close);
  }, [dismiss, variant]);

  return (
    <div
      ref={layerRef}
      className={`source-sidebar-layer${variant === "contained" ? " source-sidebar-layer--contained" : ""}${closing ? " is-closing" : ""}`}
    >
      <button type="button" className="source-sidebar-backdrop" aria-label="Close data source" onClick={dismiss} />
      <aside className="source-sidebar" aria-label={`Data source for ${component.title}`}>
        <header className="source-sidebar-header" ref={headingRef} tabIndex={-1}>
          <h2>{component.title}</h2>
          <button type="button" className="icon-button" aria-label="Close data source" onClick={dismiss}>
            <Icon name="cross" size={20} />
          </button>
        </header>
        <div className="source-sidebar-body" aria-busy={!source}>
          {source ? (
            <>
              {queryIds.length > 1 && <div className="source-section source-query-picker">
                <div className="source-group">
                  <p className="source-label">Data source</p>
                  <SourceSelect label="Choose reviewed data source" value={selectedQueryId}
                    choices={queryIds} onChange={setSelectedQueryId}
                    formatChoice={(queryId) => reviewedQueryLabel(queries?.[queryId], queryId)} />
                </div>
              </div>}
              <SourceInspector component={selectedComponent} {...source} allowCopy={allowCopy} chartEdited={chartEdited} />
            </>
          ) : (
            <div className="source-loading" aria-label="Loading data source">
              <i />
              <i />
              <i />
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}
