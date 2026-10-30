/** Authoring progress is separate from data freshness and viewer permissions. */
export function dataAppBuildState({ buildStatus, surface } = {}) {
  // Older snapshots used in-progress for revisions; retain that read compatibility.
  const active = ["creating", "updating", "in-progress"].includes(buildStatus);
  const paused = buildStatus === "paused";
  const creating = buildStatus === "creating";
  const noun = surface === "report" ? "report" : "dashboard";
  return {
    active,
    label: active ? creating ? `Creating ${noun}…` : `Updating ${noun}…` : paused ? `${noun === "report" ? "Report" : "Dashboard"} update paused` : null,
    publishBlocked: active || paused,
  };
}

export function buildBlocksAction(snapshot, action) {
  const state = dataAppBuildState(snapshot);
  return state.publishBlocked && ["publish", "sites"].includes(action)
    || state.active && ["refresh", "schedule-refresh", "edit-in-chatgpt", "report-investigate-update", "report-correct"].includes(action);
}
