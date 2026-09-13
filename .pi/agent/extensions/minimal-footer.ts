import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          // --- Left: cwd + branch + cost ---
          const home = process.env.HOME ?? "";
          let cwd: string = ctx.cwd;
          if (home && cwd.startsWith(home)) cwd = "~" + cwd.slice(home.length);

          // shorten deep paths: keep first + last 2 segments
          const parts = cwd.split("/");
          const shortCwd = parts.length > 4 ? `${parts[0]}/…/${parts.slice(-2).join("/")}` : cwd;

          const branch = footerData.getGitBranch();

          let cost = 0;
          for (const e of ctx.sessionManager.getBranch()) {
            if (e.type === "message" && e.message.role === "assistant") {
              cost += (e.message as AssistantMessage).usage.cost.total;
            }
          }

          // --- Right: model + thinking effort ---
          const model = ctx.model?.id ?? "no-model";
          const thinking = ctx.thinkingLevel ?? "";

          const leftRaw = branch
            ? `${shortCwd} (${branch})  $${cost.toFixed(3)}`
            : `${shortCwd}  $${cost.toFixed(3)}`;
          const rightRaw = thinking ? `${model} (${thinking})` : model;

          const left = theme.fg("dim", leftRaw);
          const right = theme.fg("dim", rightRaw);
          const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
          return [truncateToWidth(left + pad + right, width)];
        },
      };
    });
  });
}
