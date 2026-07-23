// Calls the visitor counter API on page load and displays the result.
//
// The API endpoint is hardcoded here rather than injected from an
// environment/config file — a deliberate simplicity tradeoff for now.
// Phase 4's CI/CD pipeline could template this in automatically from
// the Terraform output instead, keeping the frontend fully decoupled
// from having to know infrastructure details by hand; worth revisiting
// if this project grows past a single environment.
const COUNTER_API_URL =
  "https://h0mw8aaoif.execute-api.us-east-1.amazonaws.com/count";

(function () {
  const countEl = document.getElementById("visit-count");

  fetch(COUNTER_API_URL)
    .then((response) => {
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }
      return response.json();
    })
    .then((data) => {
      if (countEl) {
        countEl.textContent = `Visitor count: ${data.count}`;
      }
    })
    .catch((error) => {
      // Fails quietly on the page itself — a broken counter shouldn't
      // block someone from reading the actual resume content. The
      // real error still goes to the console for debugging.
      console.error("Visitor counter request failed:", error);
      if (countEl) {
        countEl.textContent = "Visitor count: unavailable";
      }
    });
})();
