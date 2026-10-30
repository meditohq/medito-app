import { dataAppExportOptions } from "../export-catalog.js";
import { useOptionalDataAppShell } from "../DataAppContext.jsx";
import { dataAppBuildState } from "../build-state.js";
import * as Dropdown from "@radix-ui/react-dropdown-menu";
import React, { useEffect, useLayoutEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";

import { readHandoffDestination, writeHandoffDestination } from "../handoff-preference.js";
import { dataAppChromeColors } from "../chrome-contrast.js";
import { dataAppPromptLinkProps, openDataAppHandoff } from "../data-app-handoff.js";
import { dataAppChromeLayout } from "../chrome-layout.js";
import { dataAppScheduleDays, normalizeDataAppRefreshSchedule } from "../data-app-schedule.js";
import { refreshCoachmarkDomain as workspaceCookieDomain, rememberRefreshCoachmark } from "../refresh-coachmark.js";
import { useVerificationReminder } from "../use-presentation.js";
import { reportDateMetadata } from "../report-date.js";
import { dataAppThemePalette, dataAppThemes, dataAppThemeToken } from "../theme-presets.js";
import convertGoogleDocsIcon from "./icons/convert-icon-google-docs.svg";
import convertGoogleSlidesIcon from "./icons/convert-icon-google-slides.svg";
import convertJupyterIcon from "./icons/convert-icon-jupyter.svg";
import convertPdfIcon from "./icons/convert-icon-pdf.svg";
import convertPowerpointIcon from "./icons/convert-icon-powerpoint.svg";
import convertSpreadsheetIcon from "./icons/convert-icon-spreadsheet.svg";
import convertWordIcon from "./icons/convert-icon-word.svg";
import { DashboardAskIcon, useDashboardAsk } from "./DashboardAsk.jsx";
import { DashboardTabs } from "./DashboardTabs.jsx";
import { RefreshSetupCoachmark } from "./RefreshSetupCoachmark.jsx";
import { PublishReviewDialog } from "./PublishReviewDialog.jsx";
import { Icon } from "./Icon.jsx";
import { Checkbox, Dialog, Menu, MenuGroup, MenuItem, MenuSeparator, MenuSub, Select, Tooltip } from "./ui.jsx";

const convertIcons = {
  pdf: convertPdfIcon,
  document: convertWordIcon,
  presentation: convertPowerpointIcon,
  spreadsheet: convertSpreadsheetIcon,
  notebook: convertJupyterIcon,
  "google-docs": convertGoogleDocsIcon,
  "google-slides": convertGoogleSlidesIcon,
};

const refreshFrequencyOptions = [
  { value: "hourly", label: "Every hour" },
  { value: "weekdays", label: "Every weekday" },
  { value: "daily", label: "Every day" },
  { value: "weekly", label: "Every week" },
  { value: "custom", label: "Custom days" },
];

const refreshTimeOptions = Array.from({ length: 96 }, (_, index) => {
  const hour = Math.floor(index / 4);
  const minute = String((index % 4) * 15).padStart(2, "0");
  return {
    value: `${String(hour).padStart(2, "0")}:${minute}`,
    label: `${hour % 12 || 12}:${minute} ${hour < 12 ? "AM" : "PM"}`,
  };
});

function formatReviewedAt(value, part = "date") {
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) return "";
  const options =
    part === "time"
      ? { hour: "numeric", minute: "2-digit" }
      : { month: "short", day: "numeric", ...(part === "compact" ? {} : { year: "numeric" }) };
  return new Intl.DateTimeFormat(undefined, options).format(date);
}

function ReviewedFreshness({ generatedAt }) {
  return (
    <>
      <span className="dashboard-freshness-full">
        Updated {formatReviewedAt(generatedAt)}
        <span className="dashboard-freshness-time">, {formatReviewedAt(generatedAt, "time")}</span>
      </span>
      <span className="dashboard-freshness-compact">{formatReviewedAt(generatedAt, "compact")}</span>
    </>
  );
}

function DataAppVerificationBadge({
  verification,
  pendingAction,
  showUnverified,
  canEdit,
  disabled,
  onVerificationChange,
  onReminderError,
}) {
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [dontShowAgain, setDontShowAgain] = useState(false);
  const { dismissed: reminderDismissed, check, remember } = useVerificationReminder();
  const verified = pendingAction ? pendingAction === "verify" : Boolean(verification);
  if (!verified && !showUnverified) return null;

  const tooltipId = "dashboard-verification-tooltip";
  const verifiedAt = verification
    ? new Intl.DateTimeFormat(undefined, {
        month: "short",
        day: "numeric",
        year: "numeric",
        hour: "numeric",
        minute: "2-digit",
      }).format(new Date(verification.verifiedAt))
    : "";
  const triggerProps = {
    className: "dashboard-verification-trigger",
    "aria-describedby": tooltipId,
  };

  return (
    <>
      <span className={`dashboard-verification${verified ? " is-verified" : ""}`}>
        {canEdit ? (
          <button
            {...triggerProps}
            type="button"
            disabled={disabled}
            aria-label={verified ? "Remove dashboard verification" : "Mark dashboard as verified"}
            aria-haspopup={verified || reminderDismissed ? undefined : "dialog"}
            onClick={() => {
              if (verified) onVerificationChange?.(false);
              else if (check()) onVerificationChange?.(true);
              else {
                setDontShowAgain(false);
                setConfirmOpen(true);
              }
            }}
          >
            <Icon name="shieldCheck" size={18} />
          </button>
        ) : (
          <span
            {...triggerProps}
            role="img"
            tabIndex={0}
            aria-label={verified ? "Verified dashboard" : "Unverified dashboard"}
          >
            <Icon name="shieldCheck" size={18} />
          </span>
        )}
        <Tooltip id={tooltipId} className="dashboard-verification-tooltip">
          {pendingAction ? (
            pendingAction === "verify" ? (
              "Verification will be applied when you save"
            ) : (
              "Verification will be removed when you save"
            )
          ) : verification ? (
            <>
              <strong>Verified at:</strong>
              <span>{verifiedAt}</span>
              <strong>Verified by:</strong>
              <span>{verification.verifiedBy}</span>
            </>
          ) : canEdit ? (
            "Mark as verified"
          ) : (
            "Unverified dashboard"
          )}
        </Tooltip>
      </span>
      <Dialog
        open={confirmOpen && canEdit && !disabled && !verified}
        onClose={() => setConfirmOpen(false)}
        title="What verification means"
        className="dashboard-verification-dialog"
        initialFocusSelector=".dialog-header"
      >
        <div className="dialog-prose">
          <p>
            Marking this page as verified tells others you’ve checked its sources, calculations, and conclusions, and
            that any important limitations are clearly stated.
          </p>
          <p>People who can view this page will see your email and when you verified it.</p>
        </div>
        <footer className="dashboard-verification-actions">
          <Checkbox checked={dontShowAgain} onChange={(event) => setDontShowAgain(event.target.checked)}>
            Don't show again
          </Checkbox>
          <button
            type="button"
            className="button primary"
            disabled={disabled}
            onClick={() => {
              if (dontShowAgain && !remember())
                onReminderError?.("Couldn't save your preference in this browser. The reminder will appear next time.");
              setConfirmOpen(false);
              onVerificationChange?.(true);
            }}
          >
            Got it
          </button>
        </footer>
      </Dialog>
    </>
  );
}

function DataAppFreshnessLabel({ generatedAt }) {
  return (
    <span className="freshness freshness-label">
      <ReviewedFreshness generatedAt={generatedAt} />
    </span>
  );
}

function ReportDateLabel({ asOf, generatedAt }) {
  const metadata = reportDateMetadata({ asOf, generatedAt });
  if (!metadata) return null;
  const formatted = new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: metadata.timeZone,
  }).format(metadata.date);
  return (
    <span className="freshness freshness-label">
      {metadata.label} <time dateTime={metadata.value}>{formatted}</time>
    </span>
  );
}

function dataAppActionLink(getActionHref, action, options) {
  return dataAppPromptLinkProps((destination) => getActionHref(action, options, destination));
}

function DataAppConvertItems({ getActionHref, options }) {
  return options.map(({ action, label, icon, iconSrc }) => (
    <MenuItem
      key={action}
      className="dashboard-convert-menu-item"
      leading={
        iconSrc || convertIcons[icon] ? (
          <img className="dashboard-convert-icon" src={iconSrc ?? convertIcons[icon]} alt="" aria-hidden="true" />
        ) : (
          <Icon name={icon === "markdown" ? "textDocument" : "globe"} />
        )
      }
      {...dataAppActionLink(getActionHref, action)}
    >
      {label}
    </MenuItem>
  ));
}

function DataAppPublishButton({
  published,
  getActionHref,
  surface,
  disabled,
  open,
  onOpenChange,
  editing = false,
  onSave,
}) {
  const [accessMode, setAccessMode] = useState("custom");
  const disabledTooltipId = React.useId();
  useEffect(() => {
    if (open) setAccessMode("custom");
  }, [open]);
  const href = open ? getActionHref("sites", published ? {} : { accessMode }) : null;
  function openReview() {
    setAccessMode("custom");
    onOpenChange(true);
  }
  return (
    <>
      <span className="history-tooltip-trigger" data-delayed-tooltip>
        <button
          aria-describedby={disabled && !editing ? disabledTooltipId : undefined}
          type="button"
          className="dashboard-publish-button"
          data-mode-action="primary"
          aria-label={editing ? "Save" : published ? "Publish changes" : "Publish"}
          onClick={editing ? onSave : openReview}
          disabled={disabled}
        >
          <span className="dashboard-header-action-label-full">
            {editing ? "Save" : published ? "Publish changes" : "Publish"}
          </span>
          <span className="dashboard-header-action-label-compact">{editing ? "Save" : "Publish"}</span>
        </button>
        {disabled && !editing && (
          <Tooltip id={disabledTooltipId} className="topbar-mode-tooltip">
            Available when this {surface === "report" ? "report" : "dashboard"} is ready.
          </Tooltip>
        )}
      </span>
      <PublishReviewDialog
        open={open}
        onClose={() => onOpenChange(false)}
        published={published}
        surface={surface}
        accessMode={accessMode}
        onAccessChange={setAccessMode}
        href={href}
        disabled={disabled}
      />
    </>
  );
}

function DataAppRefreshControl({ generatedAt, getActionHref, published, scheduleOpen, onScheduleOpenChange }) {
  const trigger = useRef(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const open = scheduleOpen;
  const setOpen = onScheduleOpenChange;
  const [frequency, setFrequency] = useState("weekdays");
  const [time, setTime] = useState("09:00");
  const [days, setDays] = useState(["MO", "WE", "FR"]);
  const schedule = normalizeDataAppRefreshSchedule({
    frequency,
    time,
    ...(frequency === "custom" ? { days } : frequency === "weekly" ? { days: [days[0]] } : {}),
  });
  let scheduleAction = null;
  let scheduleError = "";
  if (open && schedule) {
    try {
      scheduleAction = dataAppActionLink(getActionHref, "schedule-refresh", { schedule });
    } catch (error) {
      scheduleError = error.message;
    }
  }

  function openSchedule() {
    if (published === true) rememberRefreshCoachmark();
    setFrequency("weekdays");
    setTime("09:00");
    setDays(["MO", "WE", "FR"]);
    setOpen(true);
  }

  useEffect(() => {
    if (!open) return;
    setFrequency("weekdays");
    setTime("09:00");
    setDays(["MO", "WE", "FR"]);
  }, [open]);

  return (
    <>
      <Menu
        label="Refresh data"
        align="start"
        contentClassName="dashboard-refresh-menu"
        open={menuOpen}
        onOpenChange={setMenuOpen}
        trigger={
          <button
            ref={trigger}
            type="button"
            className="freshness freshness-button dashboard-refresh-trigger"
            aria-label="Refresh data"
            title="Refresh data or configure a recurring schedule"
          >
            <Icon name="refresh" size={16} />
            <span>
              <ReviewedFreshness generatedAt={generatedAt} />
            </span>
            <Icon name="chevronDown" size={18} className="dashboard-refresh-trigger-chevron" />
          </button>
        }
      >
        <MenuItem icon="refresh" {...dataAppActionLink(getActionHref, "refresh")}>
          Refresh now
        </MenuItem>
        <MenuItem icon="calendar" onSelect={openSchedule}>
          Schedule refresh
        </MenuItem>
      </Menu>
      <RefreshSetupCoachmark published={published} blocked={open || menuOpen} anchor={trigger} />
      {/* Focusing a native select opens its picker on iOS. Start on the
            heading so Repeat opens only after an intentional tap. */}
      <Dialog
        open={open}
        title="Schedule refresh"
        className="dashboard-schedule-dialog"
        titleInfo="Creates a cloud task for this dashboard's refresh schedule, or updates its existing cloud automation."
        initialFocusSelector=".dialog-header"
        onClose={() => setOpen(false)}
      >
        <form className="dashboard-schedule-form" onSubmit={(event) => event.preventDefault()}>
          <div className="dashboard-schedule-field">
            <span>Repeat</span>
            <Select
              label="Repeat schedule"
              value={frequency}
              choices={refreshFrequencyOptions.map(({ value }) => value)}
              onChange={(value) => {
                setFrequency(value);
                if (value === "weekly") setDays((current) => [current[0] ?? "MO"]);
              }}
              formatChoice={(value) => refreshFrequencyOptions.find((option) => option.value === value)?.label}
              triggerClassName="dashboard-schedule-select"
              contentClassName="dashboard-schedule-select-menu"
              align="end"
              modal={false}
            />
          </div>
          {(frequency === "custom" || frequency === "weekly") && (
            <div className="dashboard-schedule-days" role="group" aria-label="Repeat on">
              {dataAppScheduleDays.map(({ value, label, short }) => (
                <button
                  type="button"
                  key={value}
                  aria-label={label}
                  aria-pressed={days.includes(value)}
                  onClick={() =>
                    setDays((current) =>
                      frequency === "weekly"
                        ? [value]
                        : current.includes(value)
                          ? current.filter((day) => day !== value)
                          : [...current, value],
                    )
                  }
                >
                  {short}
                </button>
              ))}
            </div>
          )}
          {frequency !== "hourly" && (
            <div className="dashboard-schedule-field">
              <span>Time</span>
              <Select
                label="Refresh time"
                value={time}
                choices={refreshTimeOptions.map(({ value }) => value)}
                onChange={setTime}
                formatChoice={(value) => refreshTimeOptions.find((option) => option.value === value)?.label}
                triggerClassName="dashboard-schedule-select dashboard-schedule-time"
                contentClassName="dashboard-schedule-select-menu dashboard-schedule-time-menu"
                align="end"
                modal={false}
                scrollToSelected
              />
            </div>
          )}
          {scheduleError ? (
            <p role="alert">{scheduleError}</p>
          ) : (
            schedule &&
            !scheduleAction?.href && (
              <p>Open this app's HTML file directly or use its published URL to schedule refresh.</p>
            )
          )}
          <footer className="dashboard-schedule-actions">
            {scheduleAction?.href ? (
              <a className="dashboard-schedule-submit" role="button" {...scheduleAction}>
                Schedule refresh
              </a>
            ) : (
              <button type="button" className="dashboard-schedule-submit" disabled>
                Schedule refresh
              </button>
            )}
          </footer>
        </form>
      </Dialog>
    </>
  );
}

const HeaderActionButton = React.forwardRef(function HeaderActionButton(
  { label, compactLabel, icon, className = "", ...props },
  ref,
) {
  return (
    <button
      {...props}
      ref={ref}
      type="button"
      aria-label={label}
      className={["dashboard-header-action-button", className].filter(Boolean).join(" ")}
    >
      {icon && <DashboardAskIcon name={icon} size={18} />}
      <span className="dashboard-header-action-label dashboard-header-action-label-full">{label}</span>
      {compactLabel && (
        <span className="dashboard-header-action-label dashboard-header-action-label-compact">{compactLabel}</span>
      )}
    </button>
  );
});

const HeaderOverflowButton = React.forwardRef(function HeaderOverflowButton(props, ref) {
  const tooltipId = React.useId();
  return (
    <span className="history-tooltip-trigger" data-delayed-tooltip>
      <button
        {...props}
        ref={ref}
        type="button"
        aria-label="More"
        aria-describedby={tooltipId}
        className="dashboard-header-action-button dashboard-header-overflow-button"
      >
        <span className="dashboard-header-overflow-visual">
          <Icon name="more" size={18} />
        </span>
      </button>
      <Tooltip id={tooltipId} className="topbar-mode-tooltip">
        More
      </Tooltip>
    </span>
  );
});

export function DataAppHandoffMenu({ destination, onDestinationChange }) {
  return (
    <MenuSub icon="sliders" label="Open ChatGPT in…">
      <Dropdown.RadioGroup value={destination} onValueChange={onDestinationChange}>
        {[
          ["desktop", "Desktop app"],
          ["web", "Web browser"],
          ["ask", "Always ask"],
        ].map(([value, label]) => (
          <Dropdown.RadioItem key={value} className="menu-item" value={value}>
            <span className="menu-item-label">{label}</span>
            <Dropdown.ItemIndicator className="menu-check">
              <Icon name="check" />
            </Dropdown.ItemIndicator>
          </Dropdown.RadioItem>
        ))}
      </Dropdown.RadioGroup>
    </MenuSub>
  );
}

function DataAppOverflowMenu({
  canEdit,
  canSwitchTheme = canEdit,
  getActionHref,
  hiddenCount,
  mode,
  onAction,
  onOpenThemes,
  onOpenHandoffSettings,
  onRestoreHidden,
  onAsk,
  onEdit,
  onPublish,
  onScheduleRefresh,
  publishDisabled,
  hasRefresh,
  triggerRef,
  published,
  surface,
}) {
  const exportOptions = dataAppExportOptions(useOptionalDataAppShell()?.snapshot).filter(({ id }) => id !== "site");
  const [destination, setDestination] = useState(() => readHandoffDestination() ?? "ask");
  const canSetHandoffPreference = published && Boolean(workspaceCookieDomain());
  const hasActions = published || surface !== "report" || (canEdit && mode === "edit" && hiddenCount > 0);
  const hasPreferences = canSwitchTheme || canSetHandoffPreference;
  const nativeSelect = useRef(null);
  useLayoutEffect(() => {
    if (nativeSelect.current) nativeSelect.current.selectedIndex = -1;
  });
  const nativeAction = (event) => {
    const action = event.currentTarget.value;
    event.currentTarget.selectedIndex = -1; // A command is not a persistent selection.
    const openView = (callback) => requestAnimationFrame(() => callback?.());
    if (action === "ask") {
      const anchor = event.currentTarget;
      openView(() => onAsk?.(anchor));
    } else if (action === "edit") openView(onEdit);
    else if (action === "publish") openView(onPublish);
    else if (action === "schedule") openView(onScheduleRefresh);
    else if (action === "theme") openView(onOpenThemes);
    else if (action === "copy-link") onAction?.("copy-link");
    else if (action === "handoff-settings") openView(onOpenHandoffSettings);
    else if (action === "restore") onRestoreHidden?.();
    else if (action.startsWith("export:"))
      openDataAppHandoff((destination) => getActionHref(action.slice(7), undefined, destination), undefined, {
        requireTap: true,
      });
    else if (action === "refresh" || action === "duplicate")
      openDataAppHandoff((destination) => getActionHref(action, undefined, destination), undefined, {
        requireTap: true,
      });
  };
  return (
    <>
      <span className="dashboard-custom-overflow">
        <Menu
          label="More"
          onOpenChange={(open) => {
            if (open) setDestination(readHandoffDestination() ?? "ask");
          }}
          align="start"
          contentClassName="dashboard-header-action-menu"
          trigger={<HeaderOverflowButton ref={triggerRef} />}
        >
          <Dropdown.Group className="dashboard-mobile-menu-group">
            <Dropdown.Label className="menu-group-label">Actions</Dropdown.Label>
            <MenuItem
              icon="chatBubble"
              className="dashboard-action-menu-item"
              onSelect={() => {
                requestAnimationFrame(() => onAsk?.());
              }}
            >
              Ask ChatGPT
            </MenuItem>
            {canEdit && (
              <MenuItem icon="edit" className="dashboard-action-menu-item" onSelect={onEdit}>
                Edit text and layout
              </MenuItem>
            )}
            {!published && (
              <MenuItem
                icon="globe"
                className="dashboard-action-menu-item"
                disabled={publishDisabled}
                onSelect={onPublish}
              >
                Publish
              </MenuItem>
            )}
            <Dropdown.Separator className="menu-separator" />
          </Dropdown.Group>
          {hasRefresh && (
            <Dropdown.Group className="dashboard-mobile-menu-group">
              <Dropdown.Label className="menu-group-label">Refresh</Dropdown.Label>
              <MenuItem
                icon="refresh"
                className="dashboard-action-menu-item"
                {...dataAppActionLink(getActionHref, "refresh")}
              >
                Refresh now
              </MenuItem>
              <MenuItem icon="calendar" className="dashboard-action-menu-item" onSelect={onScheduleRefresh}>
                Schedule refresh
              </MenuItem>
              <Dropdown.Separator className="menu-separator" />
            </Dropdown.Group>
          )}
          {published && (
            <MenuItem icon="link" className="dashboard-action-menu-item" onSelect={() => onAction?.("copy-link")}>
              Copy link
            </MenuItem>
          )}
          {surface !== "report" && (
            <MenuItem
              icon="copy"
              className="dashboard-action-menu-item"
              {...dataAppActionLink(getActionHref, "duplicate")}
            >
              Create a copy
            </MenuItem>
          )}
          {canEdit && mode === "edit" && hiddenCount > 0 && (
            <MenuItem icon="eye" className="dashboard-action-menu-item" onSelect={onRestoreHidden}>
              Restore hidden ({hiddenCount})
            </MenuItem>
          )}
          {hasActions && hasPreferences && <MenuSeparator />}
          {canSwitchTheme && (
            <MenuItem icon="palette" className="dashboard-action-menu-item" onSelect={onOpenThemes}>
              Switch theme
            </MenuItem>
          )}
          {canSetHandoffPreference && (
            <DataAppHandoffMenu
              destination={destination}
              onDestinationChange={(value) => {
                if (writeHandoffDestination(value === "ask" ? null : value)) setDestination(value);
                else onAction?.("handoff-preference-error");
              }}
            />
          )}
          {exportOptions.length > 0 && (
            <>
              {(hasActions || hasPreferences) && <MenuSeparator />}
              <MenuGroup label="Export">
                <DataAppConvertItems getActionHref={getActionHref} options={exportOptions} />
              </MenuGroup>
            </>
          )}
        </Menu>
      </span>
      <span className="dashboard-native-overflow">
        <span className="dashboard-header-overflow-visual" aria-hidden="true">
          <Icon name="more" size={18} />
        </span>
        <select
          ref={nativeSelect}
          aria-label="More"
          onChange={nativeAction}
          onKeyDown={(event) => {
            if (event.key === "Escape") event.stopPropagation();
          }}
        >
          <optgroup label="Actions">
            <option value="ask" aria-label="Ask ChatGPT">
              Ask ChatGPT
            </option>
            {canEdit && <option value="edit">Edit text and layout</option>}
            {!published && (
              <option value="publish" aria-label="Publish" disabled={publishDisabled}>
                Publish
              </option>
            )}
            {canEdit && <option value="theme">Switch theme</option>}
            {published && <option value="copy-link">Copy link</option>}
            {published && onOpenHandoffSettings && <option value="handoff-settings">Open in ChatGPT settings</option>}
            {surface !== "report" && <option value="duplicate">Create a copy</option>}
            {canEdit && mode === "edit" && hiddenCount > 0 && (
              <option value="restore">Restore hidden ({hiddenCount})</option>
            )}
          </optgroup>
          {hasRefresh && (
            <optgroup label="Refresh">
              <option value="refresh">Refresh now</option>
              <option value="schedule">Schedule refresh</option>
            </optgroup>
          )}
          {exportOptions.length > 0 && (
            <optgroup label="Export">
              {exportOptions.map(({ action, label }) => (
                <option key={action} value={`export:${action}`}>
                  {label}
                </option>
              ))}
            </optgroup>
          )}
        </select>
      </span>
    </>
  );
}

const promptActionDetails = {
  "share-summary": {
    label: "Share key insights",
    subtext: "Choose where to share a summary",
    icon: "summaryBubble",
  },
  "alert-changes": {
    label: "Create a change alert",
    subtext: "Choose what triggers an alert",
    icon: "alertBell",
  },
  "create-report": {
    label: "Create a report",
    subtext: "Turn these findings into a report",
    icon: "textDocument",
  },
};

export function dataAppAskSuggestions({
  canEdit,
  hiddenCount,
  mode,
  onAction,
  getActionHref,
  onRestoreHidden,
  published,
  surface,
}) {
  const suggestions = Object.entries(promptActionDetails)
    .map(([action, details]) => {
      try {
        return {
          action,
          ...details,
          ...dataAppActionLink(getActionHref, action),
          getHandoffHref: (destination) => getActionHref(action, undefined, destination),
        };
      } catch {
        // An unavailable action must not break the composer or imply a valid target.
        return { action, ...details };
      }
    })
    .filter(({ href }) => href);
  if (canEdit) {
    const edit = dataAppActionLink(getActionHref, "edit-in-chatgpt");
    if (edit.href)
      suggestions.push({
        action: "edit-in-chatgpt",
        icon: "edit",
        label: surface === "report" ? "Change this report" : "Change this dashboard",
        subtext: "Tell ChatGPT what to change",
        ...edit,
        getHandoffHref: (destination) => getActionHref("edit-in-chatgpt", undefined, destination),
      });
  }
  return suggestions;
}

export function DataAppTopbar({
  title,
  buildStatus,
  generatedAt,
  reportAsOf,
  mode,
  onModeChange,
  onSave,
  onCancel,
  saving = false,
  editHistory,
  onTitleChange,
  onAction,
  getActionHref,
  onOpenThemes,
  surface = "dashboard",
  published = false,
  canEdit = true,
  verification,
  pendingVerification,
  onVerificationReminderError,
  onVerificationChange,
  saveStatus = "idle",
  className = "",
  tabs = [],
  activeTabId,
  onTabChange,
  onReorderTabs,
  hiddenCount = 0,
  onRestoreHidden,
}) {
  const build = dataAppBuildState({ buildStatus, surface });
  const editingBlocked = build.active;
  const editTooltipId = React.useId();
  const noun = surface === "report" ? "report" : "dashboard";
  const label = noun[0].toUpperCase() + noun.slice(1);
  const showTabs = surface !== "report" && tabs.length > 1;
  const [chromeColors, setChromeColors] = useState({});
  const [chromeLayout, setChromeLayout] = useState({});
  const topbar = useRef(null);
  const modeControls = useRef(null);
  const previousMode = useRef(mode);
  const actionBounds = useRef(new Map());
  useLayoutEffect(() => {
    const animations = [];
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    for (const button of modeControls.current?.querySelectorAll("[data-mode-action]") ?? []) {
      const bounds = button.getBoundingClientRect();
      const previous = actionBounds.current.get(button.dataset.modeAction);
      actionBounds.current.set(button.dataset.modeAction, bounds);
      if (!previous || reducedMotion || !bounds.width) continue;
      const scale = previous.width / bounds.width;
      const offset = previous.right - bounds.right;
      if (scale === 1 && offset === 0) continue;
      const options = { duration: 180, easing: "cubic-bezier(0.2, 0, 0, 1)" };
      // Animate composited transforms after the edit DOM has settled, not width
      // (which relayouts the header on every frame). Counter-scale the contents.
      animations.push(
        button.animate([{ transform: `translateX(${offset}px) scaleX(${scale})` }, { transform: "none" }], options),
      );
      for (const child of button.children) {
        animations.push(child.animate([{ transform: `scaleX(${1 / scale})` }, { transform: "none" }], options));
      }
    }
    animations.forEach((animation) => animation.pause());
    const frame = requestAnimationFrame(() => animations.forEach((animation) => animation.play()));
    return () => {
      cancelAnimationFrame(frame);
      animations.forEach((animation) => animation.cancel());
    };
  }, [mode]);
  useLayoutEffect(() => {
    // Removing mode-specific controls can move focus to the body.
    const activeElement = document.activeElement;
    const restoreFocus =
      previousMode.current !== mode &&
      (modeControls.current?.contains(activeElement) || activeElement === document.body);
    previousMode.current = mode;
    if (!restoreFocus) return undefined;
    const frame = requestAnimationFrame(() => {
      if (document.activeElement !== activeElement) return;
      modeControls.current
        ?.querySelector(mode === "edit" ? ".dashboard-publish-button" : ".dashboard-header-edit-button")
        ?.focus({ preventScroll: true });
    });
    return () => cancelAnimationFrame(frame);
  }, [mode]);
  const askTooltipId = React.useId();
  const askButtonRef = useRef(null);
  const moreButtonRef = useRef(null);
  const [publishOpen, setPublishOpen] = useState(false);
  const [refreshScheduleOpen, setRefreshScheduleOpen] = useState(false);
  const { openDashboardComposer } = useDashboardAsk();
  function openAskComposer(anchor = askButtonRef.current) {
    if (build.active) return;
    openDashboardComposer(
      anchor,
      dataAppAskSuggestions({
        canEdit,
        hiddenCount,
        mode,
        onAction,
        getActionHref,
        onRestoreHidden,
        published,
        surface,
      }),
    );
  }
  useEffect(() => {
    const header = topbar.current;
    if (!header) return undefined;
    header.setAttribute("data-tabs-motion-ready", "");
    return () => header.removeAttribute("data-tabs-motion-ready");
  }, []);
  useLayoutEffect(() => {
    if (!topbar.current || typeof getComputedStyle !== "function") return undefined;
    function updateChromeColors() {
      const header = topbar.current;
      if (!header) return;
      const rootStyles = getComputedStyle(document.documentElement);
      const headerStyles = getComputedStyle(header);
      const next = dataAppChromeColors({
        background: headerStyles.backgroundColor,
        underlay: getComputedStyle(document.body).backgroundColor,
        foreground: headerStyles.color,
        secondary: rootStyles.getPropertyValue("--secondary").trim(),
        positive: rootStyles.getPropertyValue("--positive").trim(),
      });
      setChromeColors((current) => (Object.keys(next).every((key) => current[key] === next[key]) ? current : next));
    }
    updateChromeColors();
    const observer = new MutationObserver(updateChromeColors);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["style", "data-app-theme", "data-color-scheme", "data-app-appearance"],
    });
    return () => observer.disconnect();
  }, []);
  useLayoutEffect(() => {
    const main = document.querySelector(`main[data-data-app-content="${surface}"]`);
    if (!main || typeof getComputedStyle !== "function" || typeof ResizeObserver !== "function") return undefined;
    let frame = 0;
    const sizes = new ResizeObserver(scheduleLayout);

    function scheduleLayout() {
      if (!frame) frame = requestAnimationFrame(updateChromeLayout);
    }

    function updateChromeLayout() {
      frame = 0;
      const styles = getComputedStyle(main);
      const next = dataAppChromeLayout({
        viewportWidth: window.innerWidth,
        paddingLeft: Number.parseFloat(styles.paddingLeft),
        paddingRight: Number.parseFloat(styles.paddingRight),
      });
      setChromeLayout((current) => (Object.keys(next).every((key) => current[key] === next[key]) ? current : next));
    }

    sizes.observe(main);
    window.addEventListener("resize", scheduleLayout);
    updateChromeLayout();
    return () => {
      cancelAnimationFrame(frame);
      sizes.disconnect();
      window.removeEventListener("resize", scheduleLayout);
    };
  }, [surface]);
  return (
    <>
      <header
        ref={topbar}
        style={{ ...chromeColors, ...chromeLayout }}
        className={["dashboard-topbar", className].filter(Boolean).join(" ")}
        data-data-app-chrome="topbar"
        data-mode={mode}
      >
        <div className="dashboard-chrome-inner dashboard-topbar-inner">
          <div className="dashboard-topbar-copy">
            {published && surface !== "report" && (verification || canEdit) && (
              <DataAppVerificationBadge
                onReminderError={onVerificationReminderError}
                verification={verification}
                pendingAction={pendingVerification}
                showUnverified={canEdit}
                canEdit={canEdit && mode === "edit" && Boolean(onVerificationChange)}
                disabled={saving || editingBlocked}
                onVerificationChange={onVerificationChange}
              />
            )}
            <strong
              className="dashboard-topbar-title"
              contentEditable={mode === "edit" && !saving && !editingBlocked}
              suppressContentEditableWarning
              aria-label={mode === "edit" ? `Edit ${noun} title` : undefined}
              onDoubleClick={
                canEdit && !editingBlocked && !saving && saveStatus !== "saving"
                  ? (event) => {
                      const target = event.currentTarget;
                      if (mode !== "edit") onModeChange?.("edit");
                      requestAnimationFrame(() =>
                        requestAnimationFrame(() => {
                          if (target.isConnected && target.isContentEditable) target.focus();
                        }),
                      );
                    }
                  : undefined
              }
              onBlur={
                mode === "edit"
                  ? (event) => {
                      const next = event.currentTarget.textContent.trim();
                      if (next) onTitleChange?.(next);
                      else event.currentTarget.textContent = title;
                    }
                  : undefined
              }
              onKeyDown={
                mode === "edit"
                  ? (event) => {
                      if (event.key === "Enter") {
                        event.preventDefault();
                        event.currentTarget.blur();
                      }
                    }
                  : undefined
              }
            >
              {title}
            </strong>
            {build.label && (
              <span
                className="freshness freshness-label dashboard-authoring-status"
                role="status"
                title={
                  build.active
                    ? `ChatGPT is working on this ${noun}. You can keep exploring; editing and publishing will be available when it finishes.`
                    : "Work is paused. Continue in ChatGPT to finish this update."
                }
              >
                {build.active && <Icon name="spinner" size={16} className="dashboard-authoring-spinner" />}
                {build.label}
              </span>
            )}
            {mode === "edit" ? (
              <span className="freshness freshness-label dashboard-edit-session-label">Editing</span>
            ) : null}
            {!build.label && mode !== "edit" && generatedAt && canEdit && surface !== "report" && (
              <DataAppRefreshControl
                generatedAt={generatedAt}
                getActionHref={getActionHref}
                published={published}
                scheduleOpen={refreshScheduleOpen}
                onScheduleOpenChange={setRefreshScheduleOpen}
              />
            )}
            {!build.label && mode !== "edit" && surface === "report" && (
              <ReportDateLabel asOf={reportAsOf} generatedAt={generatedAt} />
            )}
            {!build.label && generatedAt && !canEdit && surface !== "report" && (
              <span className="freshness freshness-label">
                <ReviewedFreshness generatedAt={generatedAt} />
              </span>
            )}
          </div>

          <div className="dashboard-topbar-mode-controls" ref={modeControls}>
            {canEdit && mode === "edit" && (
              <div className="dashboard-topbar-edit-controls">
                {(saving || saveStatus === "error") && (
                  <span
                    className={`dashboard-save-status${saveStatus === "error" ? " has-error" : ""}`}
                    data-status={saveStatus}
                    role="status"
                    aria-live="polite"
                  >
                    {saving ? "Saving…" : "Couldn’t save"}
                  </span>
                )}
                {editHistory && (
                  <div className="dashboard-edit-history" role="group" aria-label={`${label} edit history`}>
                    <span className="history-tooltip-trigger">
                      <button
                        type="button"
                        className="icon-button"
                        aria-label={`Undo ${noun} change`}
                        disabled={saving || editingBlocked || !editHistory.canUndo}
                        onClick={editHistory.undo}
                      >
                        <Icon name="undo" size={18} />
                      </button>
                      <Tooltip className="topbar-mode-tooltip">Undo</Tooltip>
                    </span>
                    <span className="history-tooltip-trigger">
                      <button
                        type="button"
                        className="icon-button"
                        aria-label={`Redo ${noun} change`}
                        disabled={saving || editingBlocked || !editHistory.canRedo}
                        onClick={editHistory.redo}
                      >
                        <Icon name="undo" size={18} className="chart-editor-redo-icon" />
                      </button>
                      <Tooltip className="topbar-mode-tooltip">Redo</Tooltip>
                    </span>
                  </div>
                )}
                {hiddenCount > 0 && (
                  <button
                    type="button"
                    className="dashboard-header-action-button"
                    disabled={saving || editingBlocked}
                    onClick={onRestoreHidden}
                  >
                    Restore hidden ({hiddenCount})
                  </button>
                )}
              </div>
            )}
            <div className="dashboard-topbar-actions">
              {mode !== "edit" && (
                <>
                  <DataAppOverflowMenu
                    canEdit={canEdit && !editingBlocked}
                    canSwitchTheme={canEdit}
                    getActionHref={getActionHref}
                    hiddenCount={hiddenCount}
                    mode={mode}
                    onAction={onAction}
                    onOpenThemes={onOpenThemes}
                    onOpenHandoffSettings={undefined}
                    onRestoreHidden={onRestoreHidden}
                    onAsk={(anchor) => openAskComposer(anchor ?? moreButtonRef.current)}
                    onEdit={() => onModeChange?.("edit")}
                    onPublish={() => setPublishOpen(true)}
                    onScheduleRefresh={() => {
                      if (published) rememberRefreshCoachmark();
                      setRefreshScheduleOpen(true);
                    }}
                    publishDisabled={build.publishBlocked}
                    hasRefresh={Boolean(generatedAt && canEdit && surface !== "report")}
                    triggerRef={moreButtonRef}
                    published={published}
                    surface={surface}
                  />
                  {canEdit && (
                    <span className="history-tooltip-trigger" data-delayed-tooltip>
                      <button
                        type="button"
                        className="dashboard-header-action-button dashboard-header-edit-button"
                        aria-describedby={editTooltipId}
                        aria-label="Edit text and layout"
                        disabled={editingBlocked || saveStatus === "saving"}
                        onClick={() => onModeChange?.("edit")}
                      >
                        <Icon name="edit" size={18} />
                      </button>
                      <Tooltip id={editTooltipId} className="topbar-mode-tooltip">
                        {editingBlocked ? `Available when this ${noun} is ready.` : "Edit text and layout"}
                      </Tooltip>
                    </span>
                  )}
                </>
              )}
              <span className="history-tooltip-trigger" data-delayed-tooltip>
                <HeaderActionButton
                  disabled={mode === "edit" ? saving : build.active}
                  data-mode-action="secondary"
                  aria-describedby={mode !== "edit" && build.active ? askTooltipId : undefined}
                  ref={askButtonRef}
                  label={mode === "edit" ? "Cancel" : "Ask ChatGPT"}
                  icon={mode === "edit" ? null : "chatBubble"}
                  compactLabel={mode === "edit" ? "Cancel" : "Ask"}
                  className="dashboard-ask-button"
                  onClick={mode === "edit" ? onCancel : () => openAskComposer()}
                />
                {build.active && (
                  <Tooltip id={askTooltipId} className="topbar-mode-tooltip">
                    Available when this {noun} is ready.
                  </Tooltip>
                )}
              </span>
              {(!published || mode === "edit") && (
                <DataAppPublishButton
                  published={published}
                  getActionHref={getActionHref}
                  surface={surface}
                  editing={mode === "edit"}
                  onSave={onSave}
                  disabled={mode === "edit" ? saving || editingBlocked : build.publishBlocked}
                  open={publishOpen}
                  onOpenChange={setPublishOpen}
                />
              )}
            </div>
          </div>
        </div>
        <div
          className={`dashboard-tabs-collapse${showTabs ? " is-open" : ""}`}
          aria-hidden={!showTabs}
          inert={!showTabs}
        >
          <div className="dashboard-tabs-collapse-inner">
            <DashboardTabs
              tabs={tabs}
              activeTabId={activeTabId}
              editMode={mode === "edit" && !saving && !editingBlocked}
              onChange={onTabChange}
              onReorder={onReorderTabs}
            />
          </div>
        </div>
      </header>
      {surface === "report" && mode !== "edit" && (reportAsOf || generatedAt) && (
        <div className="dashboard-mobile-report-date">
          <ReportDateLabel asOf={reportAsOf} generatedAt={generatedAt} />
        </div>
      )}
    </>
  );
}

function normalizedTokens(values) {
  if (typeof document === "undefined" || typeof getComputedStyle !== "function" || !document.body) {
    return values.map((value) => String(value));
  }
  const probe = document.createElement("i");
  probe.style.cssText = "position:absolute;visibility:hidden;pointer-events:none";
  document.body.append(probe);
  try {
    return values.map((value, index) => {
      if (index <= 20) {
        probe.style.color = value;
        return getComputedStyle(probe).color;
      }
      if (index <= 23) return String(Number.parseFloat(value));
      if (index <= 25) {
        probe.style.boxShadow = value;
        return getComputedStyle(probe).boxShadow;
      }
      probe.style.fontFamily = value;
      return getComputedStyle(probe).fontFamily;
    });
  } finally {
    probe.remove();
  }
}

function matchingPreset(originalTokens) {
  const original = normalizedTokens(originalTokens);
  const scheme = globalThis.document?.documentElement?.dataset.colorScheme ?? "light";
  return dataAppThemes.find((theme) => {
    const tokens = dataAppThemePalette(theme, scheme);
    return tokens && normalizedTokens(tokens).every((value, index) => value === original[index]);
  });
}

function fontLabel(font) {
  if (/mono|courier|menlo/iu.test(font)) return "Monospace";
  if (/rounded/iu.test(font)) return "Rounded sans";
  if (/georgia|times/iu.test(font)) return "Serif";
  return "Sans serif";
}

function subscribeColorScheme(onChange) {
  const root = globalThis.document?.documentElement;
  if (!root || typeof MutationObserver === "undefined") return () => {};
  const observer = new MutationObserver(onChange);
  observer.observe(root, {
    attributes: true,
    attributeFilter: ["data-color-scheme"],
  });
  return () => observer.disconnect();
}

function currentColorScheme() {
  return globalThis.document?.documentElement?.dataset.colorScheme ?? "light";
}

function ThemePreview({ theme, originalTokens, colorScheme }) {
  const tokens = dataAppThemePalette(theme, colorScheme) ?? originalTokens;
  const background = dataAppThemeToken(tokens, "background", "var(--background)");
  const surface = dataAppThemeToken(tokens, "surface", "var(--surface)");
  const text = dataAppThemeToken(tokens, "text", "var(--text)");
  const accent = dataAppThemeToken(tokens, "accent", "var(--accent)");
  const secondary = dataAppThemeToken(tokens, "secondary", "var(--secondary)");
  const border = dataAppThemeToken(tokens, "border", "var(--border)");
  const control = dataAppThemeToken(tokens, "control", "var(--control)");
  const controlRadius = Number.parseFloat(dataAppThemeToken(tokens, "control-radius", "8px"));
  const radius = controlRadius >= 16 ? "999px" : controlRadius > 0 ? "5px" : "0px";
  const font = dataAppThemeToken(tokens, "font-sans", "ui-sans-serif, system-ui, sans-serif");
  const swatches = Array.from({ length: 5 }, (_, index) => dataAppThemeToken(tokens, `chart-${index + 1}`, accent));

  return (
    <span
      className="theme-preview"
      aria-hidden="true"
      style={{
        "--preview-background": background,
        "--preview-surface": surface,
        "--preview-text": text,
        "--preview-secondary": secondary,
        "--preview-accent": accent,
        "--preview-border": border,
        "--preview-control": control,
        "--preview-radius": radius,
        "--preview-font": font,
      }}
    >
      <span className="theme-preview-type">
        <strong>Aa</strong>
        <span>{fontLabel(font)}</span>
      </span>
      <span className="theme-preview-swatches">
        {swatches.map((swatch, index) => (
          <i key={`${swatch}:${index}`} style={{ background: swatch }} />
        ))}
      </span>
      <span className="theme-preview-geometry">
        <i />
      </span>
    </span>
  );
}

export function DataAppThemeDrawer({
  activeTheme,
  open,
  onApply,
  onClose,
  onPreview,
  onPreviewEnd,
  originalTokens,
  appearance = "system",
  onAppearanceChange,
}) {
  const list = useRef(null);
  const colorScheme = useSyncExternalStore(subscribeColorScheme, currentColorScheme, currentColorScheme);
  const equivalentPreset = useMemo(() => matchingPreset(originalTokens), [originalTokens]);
  const themes = equivalentPreset ? dataAppThemes.filter(({ id }) => id !== "original") : dataAppThemes;
  const selected = activeTheme === "original" && equivalentPreset ? equivalentPreset.id : activeTheme;

  useEffect(() => {
    if (open && list.current) list.current.scrollLeft = 0;
  }, [open]);

  return (
    <section
      className={`theme-drawer${open ? " is-open" : ""}`}
      aria-hidden={!open}
      inert={!open}
      aria-label="Theme picker"
    >
      <div className="dashboard-chrome-inner theme-drawer-content">
        <header className="theme-drawer-header">
          <h2>Theme</h2>
          <div className="theme-drawer-actions">
            {onAppearanceChange && (
              <>
                <span className="theme-appearance-native">
                  <Select
                    label="Appearance"
                    value={appearance}
                    choices={["light", "dark", "system"]}
                    onChange={onAppearanceChange}
                    formatChoice={(value) => value[0].toUpperCase() + value.slice(1)}
                    triggerClassName="theme-appearance-trigger"
                  />
                </span>
                <span className="theme-appearance-menu">
                  <Menu
                    label="Dashboard appearance"
                    align="end"
                    trigger={
                      <button
                        type="button"
                        className="theme-appearance-trigger"
                        aria-label="Appearance"
                        tabIndex={open ? 0 : -1}
                      >
                        <Icon name={appearance === "light" ? "sun" : appearance === "dark" ? "moon" : "monitor"} />
                        <span>{appearance[0].toUpperCase() + appearance.slice(1)}</span>
                        <Icon name="chevronDown" />
                      </button>
                    }
                  >
                    <Dropdown.RadioGroup value={appearance} onValueChange={onAppearanceChange}>
                      {[
                        { value: "light", icon: "sun", label: "Light" },
                        { value: "dark", icon: "moon", label: "Dark" },
                        { value: "system", icon: "monitor", label: "System" },
                      ].map(({ value, icon, label }) => (
                        <Dropdown.RadioItem key={value} className="menu-item" value={value}>
                          <Icon name={icon} />
                          <span className="menu-item-label">{label}</span>
                          <Dropdown.ItemIndicator className="menu-check">
                            <Icon name="check" />
                          </Dropdown.ItemIndicator>
                        </Dropdown.RadioItem>
                      ))}
                    </Dropdown.RadioGroup>
                  </Menu>
                </span>
              </>
            )}
            <button
              type="button"
              className="icon-button theme-drawer-close"
              aria-label="Close theme picker"
              tabIndex={open ? 0 : -1}
              onClick={onClose}
            >
              <Icon name="cross" size={20} />
            </button>
          </div>
        </header>
      </div>
      <div ref={list} className="theme-card-list">
        {themes.map((theme) => (
          <button
            type="button"
            key={theme.id}
            className={`theme-card${selected === theme.id ? " is-active" : ""}`}
            aria-pressed={selected === theme.id}
            aria-label={`Apply ${theme.label}`}
            tabIndex={open ? 0 : -1}
            onClick={() => onApply(theme.id)}
            onPointerMove={() => {
              if (document.documentElement.dataset.appTheme !== theme.id) onPreview?.(theme.id);
            }}
            onPointerLeave={onPreviewEnd}
            onFocus={() => onPreview?.(theme.id)}
            onBlur={onPreviewEnd}
          >
            <ThemePreview theme={theme} originalTokens={originalTokens} colorScheme={colorScheme} />
            <span className="theme-card-label">{theme.label}</span>
          </button>
        ))}
      </div>
    </section>
  );
}
