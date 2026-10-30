import React from "react";
import { Icon } from "./Icon.jsx";
import googleDocs from "./icons/convert-icon-google-docs.svg?url";
import googleSlides from "./icons/convert-icon-google-slides.svg?url";
import googleSheets from "./icons/source-icon-google-sheets.svg?url";
import googleDrive from "./icons/source-icon-google-drive.svg?url";
import slack from "./icons/source-icon-slack.svg?url";
import github from "./icons/source-icon-github.svg?url";
import notion from "./icons/source-icon-notion.svg?url";

const assets = { "google-docs": googleDocs, "google-slides": googleSlides,
  "google-sheets": googleSheets, "google-drive": googleDrive, slack, github, notion };

export function SourceProviderIcon({ provider }) {
  const asset = assets[provider.id];
  const monochrome = provider.id === "github" || provider.id === "notion";
  return <span className="source-preview-provider-icon" data-source-provider={provider.id} aria-hidden="true">
    {asset ? monochrome
      ? <span className="source-preview-provider-mask" style={{ "--source-provider-mask": `url("${asset}")` }} />
      : <img src={asset} alt="" width="16" height="16" />
      : <Icon name={provider.id === "database" ? "database" : "globe"} size={16} />}
  </span>;
}
