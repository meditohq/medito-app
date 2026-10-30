import dataAppHtml from "../dist/index.html?raw";
import seedSnapshot from "./data.json";
import { createDataAppWorker } from "./data-app-worker.js";

export default createDataAppWorker({
  html: dataAppHtml,
  seedSnapshot,
});
