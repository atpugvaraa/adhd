const params = new URLSearchParams(window.location.search);
const blockedURL = params.get("blocked") || "Direct Open";
const blockedTargetSpan = document.getElementById("blocked-target");
const noteArea = document.getElementById("note");
const sendButton = document.getElementById("send-btn");

if (blockedTargetSpan && blockedURL) {
  blockedTargetSpan.textContent = blockedURL;
}

function getObsidianUri(content) {
  const vaultName = "Obsidian.md";
  const folder = "adhd";

  const now = new Date();
  const dateStr = now.toISOString().slice(0, 10);
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const filePath = `${folder}/${dateStr}-${hours}-${minutes}`;

  return `obsidian://new?vault=${encodeURIComponent(vaultName)}&file=${encodeURIComponent(filePath)}&content=${encodeURIComponent(content)}`;
}

// Builds the full template with your thoughts appended under the bullet
function formatInterventionNote(userThoughts = "") {
  const header =
`Blocked site: ${blockedURL}
Trust me aarav, you don't have to do that.
What were you actually trying to avoid or feel right now?
- `;

  return userThoughts ? `${header}${userThoughts}` : header;
}

function sendToObsidian() {
  const userText = noteArea.value.trim();
  // Merges the template with whatever you typed in the textarea
  const fullContent = formatInterventionNote(userText);
  window.location.href = getObsidianUri(fullContent);
}

sendButton.addEventListener("click", sendToObsidian);

noteArea.addEventListener("keydown", (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
    sendToObsidian();
  }
});

// Auto-open Obsidian immediately on load with just the blank prompt template
window.addEventListener("DOMContentLoaded", () => {
  window.location.href = getObsidianUri(formatInterventionNote());
});
