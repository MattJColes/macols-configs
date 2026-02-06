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

export const PostCodeHookPlugin = async ({ $, directory }) => {
  const hookScript = process.env.OPENCODE_HOOK_SCRIPT;

  if (!hookScript) {
    console.error(
      "[post-code-hook] OPENCODE_HOOK_SCRIPT not set. Run install_hooks.sh to configure."
    );
    return {};
  }

  return {
    "tool.execute.after": async (input) => {
      const toolName = (input.tool || "").toLowerCase();

      // Only trigger on file-modifying tools
      if (!WRITE_TOOLS.has(toolName)) {
        return;
      }

      // Debounce rapid consecutive writes
      const now = Date.now();
      if (now - lastRunTime < DEBOUNCE_MS) {
        return;
      }
      lastRunTime = now;

      try {
        await $`bash ${hookScript}`.cwd(directory);
      } catch (err) {
        // Log but don't block the session on hook failure
        console.error(`[post-code-hook] Hook exited with issues: ${err.message}`);
      }
    },
  };
};
