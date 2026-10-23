// Keeps extension-added system prompt sections in the order the session transcript
// already holds them, so pi-claude-bridge can match the prompt it is asked to serve.
//
// pi renders custom sections in `systemPromptOptions.sections` insertion order, which
// is the order their before_agent_start handlers run. The transcript stores sections
// as patches and replays them in first-seen order: a section added later in a session
// lands after the existing ones. When the two disagree, the bridge's exact-match
// lookup fails with "prompt-capture: no capture for this N-char system prompt"
// (upstream elidickinson/pi-claude-bridge#153, still open in 0.9.3). Seen here when
// /reload connected pi-telegram in a session whose transcript already had pi's
// `mcp_servers`: the builder put `telegram` first, the replay put it last.
//
// Built-in extensions such as pi's MCP load after every file-based one, so this
// handler cannot run last. It pre-inserts the transcript's names in replay order
// instead: a later handler that assigns a name keeps its position, and an empty
// placeholder left behind is skipped by pi's builder (`content && ...`) and by the
// bridge. Remove this file once the bridge orders custom sections itself; the last
// case in tests/section-order.test.ts fails in check.sh when an update does.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** pi's built-in sections. They never live in `systemPromptOptions.sections`. */
const BUILTIN = new Set(["preamble", "tools", "rules", "docs", "addendum", "project_context", "skills", "cwd"]);

type Message = { role: string; sections?: Record<string, string | null> };

/** Custom section names in the order replaying the transcript leaves them, as pi-ai's
 *  getCurrentSystemMessage does: a set keeps its position, a null removes it. */
export function replayedSectionOrder(messages: readonly Message[]): string[] {
	const names = new Set<string>();
	for (const message of messages) {
		if (message.role !== "system") continue;
		for (const [name, value] of Object.entries(message.sections ?? {})) {
			if (BUILTIN.has(name)) continue;
			if (value === null) names.delete(name);
			else names.add(name);
		}
	}
	return [...names];
}

/** Reorders `sections` in place: the replayed names first, in replay order (an empty
 *  placeholder for one not set yet), then every other name in its current order. */
export function alignSections(sections: Record<string, string>, order: readonly string[]): void {
	const entries = Object.entries(sections);
	for (const [name] of entries) delete sections[name];
	const current = new Map(entries);
	for (const name of order) sections[name] = current.get(name) ?? "";
	for (const [name, value] of entries) if (!(name in sections)) sections[name] = value;
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", (event, ctx) => {
		const options = event.systemPromptOptions;
		if (options.forceSystemPrompt !== undefined) return;
		const order = replayedSectionOrder(ctx.sessionManager.buildSessionProjection().messages as Message[]);
		if (order.length > 0) alignSections(options.sections, order);
	});
}
