/**
 * OpenCode Plugin: Post-Code Hook
 *
 * Runs tests and security scans after file write/edit tools execute.
 * Uses the tool.execute.after hook to trigger the post_code_hook.sh script.
 *
 * Install using: ./install_hooks.sh
 */

// Debounce to avoid running on every single tool call in rapid succession
let lastRunTime = 0;
const DEBOUNCE_MS = 5000;

// Tools that modify files and should trigger the hook
const WRITE_TOOLS = new Set([
  "write",
  "edit",
  "notebook_edit",
  "create",
  "patch",
  "insert",
  "replace",
  "multi_edit",
]);

// install_hooks.sh replaces __OPENCODE_HOOK_SCRIPT__ with the absolute path
// to post_code_hook.sh at install time. Keep the placeholder here verbatim.
const HOOK_SCRIPT = "__OPENCODE_HOOK_SCRIPT__";

export const PostCodeHookPlugin = async ({ $, client, directory }) => {
  const log = (msg) => {
    if (client?.app?.log) client.app.log({ service: "post-code-hook", message: msg });
    else console.error(`[post-code-hook] ${msg}`);
  };

  if (HOOK_SCRIPT === "__" + "OPENCODE_HOOK_SCRIPT__") {
    log("hook script path not substituted — run install_hooks.sh");
    return {};
  }

  return {
    "tool.execute.after": async (input) => {
      const toolName = (input.tool || "").toLowerCase();
      if (!WRITE_TOOLS.has(toolName)) return;

      const now = Date.now();
      if (now - lastRunTime < DEBOUNCE_MS) return;
      lastRunTime = now;

      try {
        await $`bash ${HOOK_SCRIPT}`.cwd(directory);
      } catch (err) {
        log(`hook exited with issues: ${err.message}`);
      }
    },
  };
};
