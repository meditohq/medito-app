// Shared by settings and both generated artifact surfaces. Plugin availability is
// supplied by a verified installed-plugin/tool inventory, never by this catalog.
export const builtInExportDestinations = Object.freeze(
  [
    { id: "spaces-page", label: "Spaces Page", icon: "document" },
    { id: "pdf", label: "PDF", icon: "pdf" },
    { id: "markdown", label: "Markdown", icon: "markdown" },
    { id: "site", label: "HTML / Site", icon: "site" },
    { id: "word", label: "Document", icon: "document" },
    { id: "powerpoint", label: "Presentation", icon: "presentation" },
    { id: "spreadsheet", label: "Spreadsheet", icon: "spreadsheet" },
    { id: "jupyter-notebook", label: "Jupyter Notebook", icon: "notebook" },
  ].map(Object.freeze),
);

const pluginPart = /^[a-zA-Z0-9][a-zA-Z0-9._-]*$/u;

export function exportDestinationId(name, marketplace) {
  return typeof name === "string" &&
    typeof marketplace === "string" &&
    pluginPart.test(name) &&
    pluginPart.test(marketplace)
    ? `plugin:${name.toLowerCase()}@${marketplace}`
    : null;
}

export function safeExportIcon(value) {
  if (typeof value !== "string" || /[\u0000-\u0020\u007f]/u.test(value)) return undefined;
  if (/^data:image\/(?:png|jpeg|webp);base64,[a-zA-Z0-9+/]+=*$/u.test(value)) return value;
  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) && !url.username && !url.password ? url.href : undefined;
  } catch {
    return undefined;
  }
}

export function createExportCatalog(dependencies = []) {
  const seen = new Set();
  return [
    ...builtInExportDestinations,
    ...dependencies.flatMap((dependency) => {
      if (!dependency?.categories?.includes("Export")) return [];
      const { name, marketplace } = dependency;
      const id = exportDestinationId(name, marketplace);
      if (!id || seen.has(id)) return [];
      seen.add(id);
      const label = name.replace(
        /(^|-)(\w)/gu,
        (_match, separator, letter) => `${separator ? " " : ""}${letter.toUpperCase()}`,
      );
      const iconSrc = safeExportIcon(dependency.iconSrc);
      return [{ id, label, icon: "plugin", plugin: { name, marketplace }, ...(iconSrc ? { iconSrc } : {}) }];
    }),
  ];
}

export function exportInstalledPluginId(destination) {
  const plugin = destination?.plugin;
  if (!exportDestinationId(plugin?.name, plugin?.marketplace)) return null;
  const value = destination.installedPluginId;
  if (value === undefined) return `${plugin.name.toLowerCase()}@${plugin.marketplace}`;
  if (typeof value !== "string") return null;
  const [name, marketplace, extra] = value.split("@");
  if (
    extra !== undefined ||
    !exportDestinationId(name, marketplace) ||
    name.toLowerCase() !== plugin.name.toLowerCase()
  )
    return null;
  const curatedAliases = ["openai-curated", "openai-curated-remote"];
  const compatible =
    marketplace === plugin.marketplace ||
    (curatedAliases.includes(marketplace) && curatedAliases.includes(plugin.marketplace));
  return compatible ? value : null;
}

function availablePluginDestinations(destinations) {
  if (!Array.isArray(destinations)) return [];
  const seen = new Set();
  return destinations.flatMap((destination) => {
    const plugin = destination?.plugin;
    const id = exportDestinationId(plugin?.name, plugin?.marketplace);
    const installedPluginId = exportInstalledPluginId(destination);
    if (!id || destination.id !== id || !installedPluginId || seen.has(id)) return [];
    seen.add(id);
    const label =
      typeof destination.label === "string" && destination.label.trim()
        ? destination.label.replace(/[\u0000-\u001f\u007f]/gu, " ").trim()
        : plugin.name;
    const iconSrc = safeExportIcon(destination.iconSrc);
    return [
      {
        id,
        label,
        icon: "plugin",
        plugin: { name: plugin.name, marketplace: plugin.marketplace },
        installedPluginId,
        ...(iconSrc ? { iconSrc } : {}),
      },
    ];
  });
}

// null/absent selects all available destinations; [] is an explicit opt-out.
// Keep stored IDs intact: removing a plugin hides it, reinstalling restores the
// same preference. A newly installed plugin joins default-all, not a subset.
export function dataAppExportOptions(snapshot = {}) {
  const preferences = snapshot?.exportPreferences;
  const catalog = [...builtInExportDestinations, ...availablePluginDestinations(preferences?.destinations)];
  const selected = preferences?.selected;
  const destinations =
    selected == null
      ? catalog
      : Array.isArray(selected)
        ? [...new Set(selected)].flatMap((id) => catalog.filter((destination) => destination.id === id))
        : [];
  return destinations.flatMap((destination) => {
    if (destination.plugin?.name.toLowerCase() === "google-drive") {
      return [
        {
          ...destination,
          action: `${destination.id}/google-docs`,
          format: "google-docs",
          label: "Google Docs",
          icon: "google-docs",
        },
        {
          ...destination,
          action: `${destination.id}/google-slides`,
          format: "google-slides",
          label: "Google Slides",
          icon: "google-slides",
        },
      ];
    }
    return [{ ...destination, action: destination.id }];
  });
}
