/**
 * OpenCode Plugin: Post-Code Hook
 *
 * Runs tests and security scans after file write/edit tools execute.
 * Uses the tool.execute.after hook to trigger the post_code_hook.sh script.
 * Uses the session.idle hook to run comprehensive end-of-session validation.
 *
 * Install using: ./install_hooks.sh
 */

// Debounce to avoid running on every single tool call in rapid succession
let lastCodeRunTime = 0;
const CODE_DEBOUNCE_MS = 5000;

// Session idle debounce — only run task checks once per idle period
let lastIdleRunTime = 0;
const IDLE_DEBOUNCE_MS = 60000; // 1 minute between idle checks

// Hook script paths (replaced by install_hooks.sh via sed)
const HOOK_SCRIPT = "__HOOK_SCRIPT_PATH__";
const TASK_HOOK_SCRIPT = "__TASK_HOOK_SCRIPT_PATH__";

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

export const PostCodeHookPlugin = async ({ $, directory, worktree }) => {
  const cwd = worktree || directory;

  return {
    "tool.execute.after": async (input) => {
      const toolName = (input.tool || "").toLowerCase();

      // Only trigger on file-modifying tools
      if (!WRITE_TOOLS.has(toolName)) {
        return;
      }

      // Debounce rapid consecutive writes
      const now = Date.now();
      if (now - lastCodeRunTime < CODE_DEBOUNCE_MS) {
        return;
      }
      lastCodeRunTime = now;

      try {
        await $`bash ${HOOK_SCRIPT}`.cwd(cwd);
      } catch (err) {
        console.error(
          `[post-code-hook] Hook exited with issues: ${err.message}`
        );
      }
    },

    "session.idle": async () => {
      // Debounce: only run once per idle period
      const now = Date.now();
      if (now - lastIdleRunTime < IDLE_DEBOUNCE_MS) {
        return;
      }
      lastIdleRunTime = now;

      try {
        await $`bash ${TASK_HOOK_SCRIPT}`.cwd(cwd);
      } catch (err) {
        console.error(
          `[post-task-hook] Session validation found issues: ${err.message}`
        );
      }
    },
  };
};
