/**
 * magpi-render.ts - reading pages whose content only exists after JavaScript runs
 *
 * `magpi_fetch` reads the server's HTML. When a site builds its content in the
 * browser, that HTML is a shell: one parts-catalogue page answers 27.6 KB of Next.js scaffold
 * containing **zero** product data, and MagPi caches the 315-byte footer it extracted
 * from it as a *successful* `article`. This registers the escalation for that case:
 * drive the installed Firefox over WebDriver BiDi, wait for the page to stop changing,
 * and extract what a reader would see.
 *
 * Measured on the two pages this was built for (see README for the full numbers):
 *
 *   parts catalogue   27.6 KB shell -> 14.3 K chars, 11 tables, price and spec tables
 *                     intact, Product + FAQPage ld+json. 13-15 s.
 *   shop product      reviews, Q&A and the description live in three iframes, so
 *                     no top-document extraction can see them. Frame traversal returns
 *                     61 KB across 4 frames. 6 s.
 *
 * Design notes for anyone changing this file:
 *
 *   - **Every tunable is in TUNING at the top, with the measurement that set it.** The
 *     values are not taste: a 700 ms stability window (instead of 1.6 s) mistook
 *     the catalogue page's mid-load pause for the end and lost all 11 tables, and waiting for the
 *     `load` event never returns on the shop page at all. Argue with the evidence.
 *   - **Readability is a candidate, not the extractor.** It is built for articles and
 *     drops tables, which on a catalogue page *are* the content: it scored 0.08
 *     coverage with 0 tables where the layout pass scored 0.97 with 11. It is injected
 *     only when the layout pass looks weak.
 *   - **Extraction runs in the page**, so visibility comes from `getComputedStyle` and
 *     box geometry rather than from guessing at tag names. No server-side parser
 *     (Readability included) has that information.
 *   - **An empty result throws.** MagPi caches whatever it is handed, for `ttlHours`,
 *     and a rendered shell reads to the model as "this page says nothing" - the exact
 *     failure this file exists to fix, one layer further in.
 *   - **No site-specific code.** Two candidate handlers (the catalogue page's internal JSON API,
 *     the shop page's iframe endpoints) were measured, worked, and were dropped: an
 *     undocumented internal API has no compatibility promise, skips the site's own
 *     analytics, and is the first thing a site blocks. Rendering consumes the page the
 *     way the site intends.
 *   - **The browser is a child process, so it is outside `pi-sandbox`.** That extension
 *     enforces its policy at the `bash` tool; `spawn` from here is not covered, which
 *     is why this works with `allowBrowserProcess: false`. Measured: the same launch
 *     from inside sandboxed `bash` fails with Mach `bootstrap_check_in` errors.
 *   - **The BiDi socket is hand-rolled over `node:net`.** Node's global `WebSocket`
 *     honours `HTTP(S)_PROXY`, which this machine sets, and routes even a loopback
 *     connection through the proxy where the upgrade fails. A raw socket has no
 *     ambient configuration to get wrong.
 *   - Names borrow MagPi's: `magpi_fetch_rendered` sorts directly under `magpi_fetch`,
 *     which is the tool whose thin answer sends you here. Nothing under
 *     `npm/node_modules` is patched; see README for the namespace note.
 */

import { type ChildProcess, spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { connect, type Socket } from "node:net";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ════════════════════════════════════════════════════════════════════════════════
//  TUNING
//
//  Every number came out of a measured run against a Next.js parts-catalogue page whose
//  payload is 11 tables, and an electronics shop product page whose reviews, Q&A and
//  description live in three iframes. The measurement that set each value is named, so a
//  change argues with evidence rather than with taste.
// ════════════════════════════════════════════════════════════════════════════════
export const TUNING = {
	/** Waiting for the page to stop changing. */
	settle: {
		/** How often every frame is measured. */
		pollMs: 400,
		/**
		 * Consecutive polls with identical all-frame text before the page counts as
		 * settled: 4 x 400 ms = 1.6 s.
		 * Measured: the catalogue page pauses mid-load for 1.4 s (at 584 chars) and 2.4 s (at
		 * 14,104). A 700 ms window took the first pause for the end and lost all 11
		 * tables while reporting success in 2.9 s.
		 */
		stableRounds: 4,
		/**
		 * Quiet time since the last content-bearing response.
		 * Measured: the catalogue page's data XHRs arrive in bursts up to ~1.2 s apart.
		 */
		networkIdleMs: 1_500,
		/**
		 * Never settle earlier than this.
		 * Measured: the catalogue page's first table appears at 4.6 s, all 11 by 5.3 s.
		 */
		minWaitMs: 3_000,
		/**
		 * After the rule says "settled", wait this long and measure once more. Cheap
		 * insurance against a pause the rules did not catch.
		 */
		confirmMs: 800,
		/**
		 * Hard ceiling. Hitting it while text is still growing is reported rather than
		 * quietly returned, because a truncated page that looks successful is the
		 * failure this file exists to prevent.
		 * Measured: the catalogue page completes at ~8 s, the shop page's iframes at ~6 s; settle lands
		 * at 13-15 s and 6 s respectively.
		 */
		maxWaitMs: 25_000,
		/** A response only resets the idle timer when it could carry content. */
		contentBearing: {
			statusMin: 200,
			statusMax: 299,
			mimePattern: "json|html|xml|text/plain",
			/**
			 * Restrict the idle signal to the page's own registrable domain, so
			 * third-party ad/analytics/chat traffic cannot hold the settle back.
			 *
			 * Off by default, deliberately. Plenty of services serve their data from a
			 * sibling domain rather than a subdomain - a separate `*-api.io`, a
			 * CDN-hosted API - and restricting the signal would settle before that data
			 * arrives. Losing content is invisible; waiting too long is not.
			 * Measured cost of leaving it off: the catalogue page settles in 14.8 s instead of
			 * 13.3 s, because datadog RUM, criteo and channel.io keep answering with
			 * non-empty bodies (245 responses for one page; 80 of them third-party).
			 * `magpi-render.json`'s `sameSiteOnlyHosts` turns it on per host.
			 */
			sameSiteOnly: false,
		},
	},

	/** Choosing between the layout pass and Readability. */
	extract: {
		/**
		 * Coverage = extracted plain text / `document.body.innerText`, the rendered-text
		 * yardstick. Readability only gets a turn when the layout pass scores below this.
		 * Measured: the catalogue page layout 0.97 with 11 tables vs Readability 0.08 with 0 tables,
		 * so the rule disqualifies it without a special case.
		 */
		weakCoverage: 0.6,
		/** A table in the output means catalogue-shaped, and Readability would drop it. */
		tablesBeatReadability: true,
		/** Recursion guard for the DOM walk. */
		maxDepth: 40,
		/** Wider than this is a layout artefact, not a colspan. */
		maxColspan: 24,
	},

	/**
	 * What counts as chrome rather than content.
	 *
	 * The values most likely to need tuning, which is why they are here and not inside
	 * the injected script. Visibility itself is decided by the engine (computed style
	 * plus box geometry); these lists only cover what is visible but still not content.
	 */
	boilerplate: {
		skipTags: [
			"SCRIPT", "STYLE", "NOSCRIPT", "SVG", "CANVAS", "TEMPLATE", "LINK", "META", "HEAD",
			"IFRAME", "FRAME", "OBJECT", "EMBED", "AUDIO", "VIDEO",
			"SELECT", "OPTION", "BUTTON", "FORM", "INPUT", "TEXTAREA", "LABEL",
		],
		skipSemantic: ["NAV", "HEADER", "FOOTER", "ASIDE"],
		skipRolePattern:
			"^(navigation|banner|contentinfo|complementary|search|menu|menubar|toolbar|dialog|alertdialog|tablist)$",
		/** Korean shops name their navigation bars gnb/lnb/snb, hence those three. */
		skipClassPattern:
			"(^|[-_ ])(nav|navbar|menu|breadcrumb|footer|header|sidebar|banner|advert|ads?|gnb|lnb|snb|cookie|consent|popup|modal|toast|tooltip|skip|hidden)([-_ ]|$)",
		/** Smaller than this in both axes is a tracking pixel or a collapsed node. */
		minBoxPx: 2,
		/** Preferred content root, in order, before falling back to body. */
		mainSelectors: ["main", "[role=main]", "article"],
	},

	/** schema.org types worth lifting out of ld+json. Measured: the catalogue page injects Product and FAQPage. */
	structuredTypes:
		"^(Product|Article|NewsArticle|BlogPosting|TechArticle|FAQPage|QAPage|Recipe|SoftwareApplication|Offer|AggregateOffer|Dataset|Book)$",

	/** Browser process. */
	browser: {
		/**
		 * Absolute paths tried in order, then bare names looked up on `PATH`.
		 * `magpi-render.json`'s `browserBinary` precedes all of it.
		 */
		candidates: [
			"/Applications/Firefox.app/Contents/MacOS/firefox",
			"/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox",
			"/Applications/Firefox Nightly.app/Contents/MacOS/firefox",
			"/opt/homebrew/bin/firefox",
			"/usr/local/bin/firefox",
			"/usr/bin/firefox",
			"/snap/bin/firefox",
		],
		/** Looked up through `PATH`, which covers Nix, Flatpak wrappers and package managers the list above misses. */
		pathNames: ["firefox", "firefox-esr", "firefox-developer-edition"],
		/** Port 0 lets the OS choose, so concurrent pi instances cannot collide. */
		args: ["--headless", "--no-remote", "--remote-debugging-port", "0"],
		/** A throwaway profile per render: the operator's own Firefox profile is never touched. */
		prefs: [
			'user_pref("permissions.default.image", 2);',
			'user_pref("media.autoplay.default", 5);',
			'user_pref("datareporting.healthreport.uploadEnabled", false);',
			'user_pref("browser.shell.checkDefaultBrowser", false);',
		],
		startupTimeoutMs: 20_000,
		commandTimeoutMs: 30_000,
		/**
		 * One browser per render, killed afterwards. A pooled instance would save the
		 * measured 1.3 s startup, which is small next to a 6-15 s render and not worth
		 * the lifetime bugs until it is.
		 */
		reuse: false,
	},

	/** Refusing to return a shell. */
	empty: {
		/** Below this many characters, a rendered page has told us nothing. */
		minChars: 200,
		/**
		 * A frame with less visible text than this is furniture, not content.
		 * Measured: the catalogue page's Channel.io chat widget renders 22 characters in its own
		 * frame; including it dumped 2 KB of the widget's markup into the document.
		 * the shop page's smallest content frame (Q&A) has 1,499, so the gap is wide.
		 */
		frameMinChars: 200,
		/** Signals in the rendered text that name *why* it is empty. */
		loginPattern: "(로그인|로그인이 필요|sign in|log in|login required|create an account)",
		botPattern: "(are you a robot|captcha|cloudflare|just a moment|access denied|unusual traffic)",
	},

	/**
	 * Noticing that `magpi_fetch` came back with a shell.
	 *
	 * Detection reads MagPi's own `details` (`contentBytes`, `handler`, `kind`) rather than
	 * its preview text, so formatting changes upstream cannot fool it.
	 */
	detect: {
		/**
		 * A `webpage` result smaller than this is a shell, not a page.
		 * Measured: a marketing landing page cached **0 bytes** under a healthy title, and a
		 * catalogue page 315 bytes of company footer. The shop page's 13,377 bytes are *not*
		 * caught, and cannot be by any byte threshold: its loss is three empty iframes inside
		 * an otherwise real page. This catches shells, not partial losses.
		 */
		minContentBytes: 600,
		/**
		 * Only MagPi's default webpage handler is second-guessed. A thin answer from
		 * `reddit`, `discourse`, `naver-blog`, `github` or a registry is a different failure
		 * - blocked, renamed, genuinely empty - that a browser does not fix, and `render` is
		 * this extension's own handler, which must never re-trigger itself.
		 */
		handlers: ["webpage"],
		/** Page-shaped kinds only: a PDF, a JSON document or a cloned repo is not a shell. */
		kinds: ["article", "text"],
	},
} as const;
// ════════════════════════════════════════════════════════════════════════════════

const CONFIG_FILENAME = "magpi-render.json";

export interface RenderConfig {
	enabled: boolean;
	/** Overrides `TUNING.browser.candidates`. */
	browserBinary?: string;
	/** Hosts for which only same-site responses reset the network-idle timer. */
	sameSiteOnlyHosts: string[];
	/** Overrides `TUNING.settle.maxWaitMs` for slow pages. */
	maxWaitMs?: number;
	/**
	 * Hosts always fetched through the browser, as exact names or `*.example.com`.
	 * Written by hand; the learned store is the automatic half of the same list.
	 */
	renderHosts: string[];
	/** Set false to stop detection from adding hosts on its own. */
	learnHosts: boolean;
}

const DEFAULT_CONFIG: RenderConfig = { enabled: true, sameSiteOnlyHosts: [], renderHosts: [], learnHosts: true };

/** MagPi resolves its own config under `~/.pi/agent`; this keeps the two side by side. */
export function configPaths(cwd: string): { global: string; project: string } {
	return {
		global: join(homedir(), ".pi", "agent", CONFIG_FILENAME),
		project: join(cwd, ".pi", CONFIG_FILENAME),
	};
}

export function loadConfig(cwd: string, projectTrusted: boolean): RenderConfig {
	const read = (path: string): Partial<RenderConfig> => {
		try {
			return JSON.parse(readFileSync(path, "utf8")) as Partial<RenderConfig>;
		} catch {
			return {};
		}
	};
	const paths = configPaths(cwd);
	return {
		...DEFAULT_CONFIG,
		...read(paths.global),
		...(projectTrusted ? read(paths.project) : {}),
	};
}

// ---------------------------------------------------------------- pure helpers

/**
 * Registrable domain, approximated as the last two labels plus a short list of
 * two-part public suffixes. A correct answer needs the Public Suffix List; this is a
 * heuristic for a heuristic and is only consulted when `sameSiteOnly` is on.
 * `api.kr.example.com` and `kr.example.com` both reduce to `example.com`, which
 * is the case that matters.
 */
const TWO_PART_SUFFIXES = new Set([
	"co.kr", "or.kr", "ne.kr", "go.kr", "re.kr", "pe.kr",
	"co.jp", "ne.jp", "or.jp", "ac.jp",
	"co.uk", "org.uk", "ac.uk", "com.au", "com.br", "com.cn", "com.tw", "com.hk", "co.nz",
]);

export function registrableDomain(host: string): string {
	const labels = String(host).toLowerCase().split(".").filter(Boolean);
	if (labels.length <= 2) return labels.join(".");
	const lastTwo = labels.slice(-2).join(".");
	return TWO_PART_SUFFIXES.has(lastTwo) ? labels.slice(-3).join(".") : lastTwo;
}

export interface ResponseFacts {
	status: number;
	mimeType?: string;
	bodySize?: number;
	url?: string;
}

/** Whether a response is the kind that could still add text, so the idle timer restarts. */
export function isContentBearing(
	response: ResponseFacts | undefined,
	options: { sameSiteOnly: boolean; pageDomain: string },
): boolean {
	if (!response) return false;
	const { statusMin, statusMax, mimePattern } = TUNING.settle.contentBearing;
	if (response.status < statusMin || response.status > statusMax) return false;
	const substantial =
		(response.bodySize ?? 0) > 0 || new RegExp(mimePattern, "i").test(response.mimeType ?? "");
	if (!substantial) return false;
	if (!options.sameSiteOnly || !options.pageDomain) return true;
	let host = "";
	try {
		host = new URL(response.url ?? "").host;
	} catch {
		return true; // unparseable: do not silently drop a signal
	}
	return !host || registrableDomain(host) === options.pageDomain;
}

export interface SettleFacts {
	elapsedMs: number;
	stableRounds: number;
	quietForMs: number;
	inflight: number;
	totalText: number;
}

/** The settle rule, kept separate from the loop so its truth table can be tested. */
export function shouldSettle(facts: SettleFacts, maxWaitMs = TUNING.settle.maxWaitMs): boolean {
	if (facts.elapsedMs >= maxWaitMs) return true; // caller reports the cap as suspicious
	return (
		facts.elapsedMs >= TUNING.settle.minWaitMs &&
		facts.stableRounds >= TUNING.settle.stableRounds &&
		facts.quietForMs >= TUNING.settle.networkIdleMs &&
		facts.inflight === 0 &&
		facts.totalText > 0
	);
}

export interface FrameResult {
	url: string;
	depth: number;
	markdown: string;
	plainLen: number;
	visibleLen: number;
	tables: number;
	readableMarkdown?: string;
	readablePlainLen?: number;
	structured: unknown[];
	og: Record<string, string>;
}

/**
 * One frame's numbers and payload, assembled explicitly.
 *
 * Explicitly, because spreading the structured-data result (`{ blocks, og }`) into this
 * shape silently left `structured` undefined: the ld+json the page declares about itself
 * - `Product` with its price and rating, `FAQPage` - was dropped, and the document ended
 * in `[null, null]` where that data should have been. Types did not catch it; the field
 * names differ and both spreads were valid.
 */
export function toFrameResult(
	frame: { url: string; depth: number },
	converted: { markdown: string; plainLen: number; visibleLen: number; tables: number },
	structured: { blocks: unknown[]; og: Record<string, string> },
): FrameResult {
	return {
		url: frame.url,
		depth: frame.depth,
		markdown: converted.markdown,
		plainLen: converted.plainLen,
		visibleLen: converted.visibleLen,
		tables: converted.tables,
		structured: structured.blocks ?? [],
		og: structured.og ?? {},
	};
}

/** Coverage against the rendered-text yardstick. Above 1 is impossible by construction. */
export function coverageOf(frame: Pick<FrameResult, "plainLen" | "visibleLen">): number {
	return frame.visibleLen > 0 ? frame.plainLen / frame.visibleLen : 0;
}

/** Which candidate wins for one frame, and why. */
export function chooseExtractor(frame: FrameResult): { chosen: "layout" | "readability"; coverage: number } {
	const coverage = coverageOf(frame);
	if (frame.tables > 0 && TUNING.extract.tablesBeatReadability) return { chosen: "layout", coverage };
	if (frame.readableMarkdown === undefined) return { chosen: "layout", coverage };
	const readCoverage = frame.visibleLen > 0 ? (frame.readablePlainLen ?? 0) / frame.visibleLen : 0;
	return { chosen: readCoverage > coverage ? "readability" : "layout", coverage };
}

/**
 * One document out of every frame that held something, in tree order.
 *
 * Both candidates contribute markdown: Readability's HTML is walked by the same converter
 * first, so a chosen article keeps its headings and lists and no HTML tag can reach the
 * document.
 */
export function assembleMarkdown(url: string, frames: FrameResult[]): string {
	const sections: string[] = [`# ${url}`];
	for (const frame of frames) {
		const { chosen, coverage } = chooseExtractor(frame);
		const body = chosen === "layout" ? frame.markdown : (frame.readableMarkdown ?? frame.markdown);
		if (!body.trim()) continue;
		const label = frame.depth === 0 ? "main document" : `frame ${frame.url}`;
		sections.push(
			`<!-- rendered: ${label} | ${chosen} | coverage ${coverage.toFixed(2)} | ${frame.tables} tables -->\n\n${body.trim()}`,
		);
	}
	const structured = frames.flatMap((frame) => frame.structured).filter((block) => block != null);
	if (structured.length > 0) {
		sections.push(
			`<!-- structured data (schema.org) -->\n\n\`\`\`json\n${JSON.stringify(structured, null, 1).slice(0, 20_000)}\n\`\`\``,
		);
	}
	// OpenGraph is what a page without ld+json still declares about itself; the shop page
	// publishes 11 such tags and no ld+json at all.
	const og = Object.assign({}, ...frames.map((frame) => frame.og)) as Record<string, string>;
	if (Object.keys(og).length > 0) {
		const rows = Object.entries(og).map(([key, value]) => `| ${key} | ${value.replace(/\|/g, "\\|")} |`);
		sections.push(`<!-- opengraph -->\n\n| property | content |\n| --- | --- |\n${rows.join("\n")}`);
	}
	return sections.join("\n\n");
}

/**
 * Why a render came back empty, in the words of the page.
 *
 * Naming the reason is the point: "rendered and still empty" is a different fact from
 * "the site wants a login", and a caller that cannot tell them apart will retry the
 * wrong one.
 */
export function classifyEmpty(text: string): "login" | "botcheck" | "empty" {
	if (new RegExp(TUNING.empty.botPattern, "i").test(text)) return "botcheck";
	if (new RegExp(TUNING.empty.loginPattern, "i").test(text)) return "login";
	return "empty";
}

/**
 * The browser this machine has, or nothing.
 *
 * Absolute candidates first, then `PATH`, because a Firefox installed by Homebrew's
 * formula, Nix or a Flatpak wrapper sits somewhere no fixed list can predict. `exists`
 * and `path` are injected so both outcomes are testable without depending on what the
 * machine running the checks happens to have.
 */
export function findBrowser(
	configured: string | undefined,
	exists: (path: string) => boolean = existsSync,
	pathEnv: string | undefined = process.env.PATH,
): string | undefined {
	for (const candidate of [...(configured ? [configured] : []), ...TUNING.browser.candidates]) {
		if (exists(candidate)) return candidate;
	}
	for (const directory of (pathEnv ?? "").split(":").filter(Boolean)) {
		for (const name of TUNING.browser.pathNames) {
			const candidate = join(directory, name);
			if (exists(candidate)) return candidate;
		}
	}
	return undefined;
}

/**
 * Discovery in a replaceable slot, so the registration gate can be tested from both
 * sides (the same reason `magpi-handlers.ts` keeps its resolver in one).
 */
export const browserLookup = { find: findBrowser };

// ---------------------------------------------------------------- learned hosts

export interface LearnedHost {
	/** ISO timestamp of the fetch that gave it away. */
	learnedAt: string;
	/** What MagPi returned that turned out to be a shell. */
	bytes: number;
	kind: string;
}

export interface LearnedStore {
	hosts: Record<string, LearnedHost>;
}

/**
 * Hosts detection has caught serving a shell.
 *
 * A file rather than memory, because the point is the *second* visit: the first fetch of
 * a host pays for the discovery, and every session afterwards should not. It sits beside
 * the render artefacts, is plain JSON, and deleting it only costs one repeated discovery.
 */
export function learnedStorePath(): string {
	return join(homedir(), ".pi", "agent", "tmp", "magpi-render", "learned.json");
}

export function loadLearned(path = learnedStorePath()): LearnedStore {
	try {
		const parsed = JSON.parse(readFileSync(path, "utf8")) as LearnedStore;
		return parsed && typeof parsed.hosts === "object" && parsed.hosts ? { hosts: parsed.hosts } : { hosts: {} };
	} catch {
		return { hosts: {} }; // absent or corrupt: relearning costs one fetch
	}
}

export function saveLearned(store: LearnedStore, path = learnedStorePath()): void {
	mkdirSync(join(path, ".."), { recursive: true });
	writeFileSync(path, `${JSON.stringify(store, null, 1)}\n`, "utf8");
}

/** Adds a host, keeping the first sighting: the original evidence is the interesting one. */
export function learnHost(store: LearnedStore, host: string, facts: LearnedHost): LearnedStore {
	if (!host || store.hosts[host]) return store;
	return { hosts: { ...store.hosts, [host]: facts } };
}

/** Exact host, or a `*.example.com` pattern that also matches `example.com` itself. */
export function hostMatchesPattern(host: string, pattern: string): boolean {
	const target = host.toLowerCase();
	const rule = pattern.trim().toLowerCase();
	if (!rule) return false;
	if (rule.startsWith("*.")) {
		const base = rule.slice(2);
		return target === base || target.endsWith(`.${base}`);
	}
	return target === rule;
}

/**
 * Whether a URL should skip the server's HTML and go straight to the browser.
 *
 * Configured patterns are permanent; learned hosts are the automatic half. Both are
 * consulted per fetch, so a host learned mid-session takes effect on the next call
 * without a reload.
 */
export function shouldRenderHost(host: string, patterns: readonly string[], learned: LearnedStore): boolean {
	if (patterns.some((pattern) => hostMatchesPattern(host, pattern))) return true;
	return Boolean(learned.hosts[host.toLowerCase()]);
}

// ---------------------------------------------------------------- detection

/** The parts of MagPi's tool result that say whether it found a page or a shell. */
export interface FetchDetails {
	url?: string;
	handler?: string;
	kind?: string;
	contentBytes?: number;
	treePath?: string;
}

/**
 * Whether a `magpi_fetch` result is a shell worth re-reading through the browser.
 *
 * Deliberately narrow. It fires on MagPi's default webpage handler returning almost
 * nothing, and on nothing else: a specialised handler's thin answer is a different
 * failure, a cloned repo is small by design, and this extension's own handler must not
 * re-trigger itself.
 */
export function isThinFetch(details: FetchDetails | undefined, isError = false): boolean {
	if (isError || !details) return false;
	if (details.treePath) return false;
	if (!TUNING.detect.handlers.includes(details.handler ?? "")) return false;
	if (!TUNING.detect.kinds.includes(details.kind ?? "")) return false;
	if ((details.contentBytes ?? 0) >= TUNING.detect.minContentBytes) return false;
	try {
		const protocol = new URL(details.url ?? "").protocol;
		return protocol === "http:" || protocol === "https:";
	} catch {
		return false;
	}
}

/**
 * What to tell the caller after learning a host.
 *
 * The note is the whole mechanism for the first visit: nothing here can re-run MagPi's
 * tool, so the model is told that the next fetch of this host will render, and that a
 * `refresh` is needed because the shell is already cached under MagPi's TTL.
 */
export function thinNote(url: string, bytes: number): string {
	return (
		`\n\n<!-- magpi-render: this page returned ${bytes} bytes, which is a shell rather than its content. ` +
		`Its host is now on the render list, so fetching it again renders it through Firefox first: ` +
		`call magpi_fetch with refresh: true on ${url} (or magpi_fetch_rendered for a one-off). ` +
		`The empty copy is cached until then. -->`
	);
}

// ---------------------------------------------------------------- websocket

/**
 * A WebSocket client over a raw socket.
 *
 * Node's global `WebSocket` honours `HTTP(S)_PROXY`, which this machine sets globally,
 * and sends even a loopback connection through the proxy, where the upgrade fails with
 * an immediate close. Measured on this machine before this existed. Only what BiDi
 * needs is implemented: text frames, server pings, close.
 */
export class RawWebSocket {
	private socket?: Socket;
	private buffer = Buffer.alloc(0);
	private onText: (text: string) => void = () => {};
	private closed = false;

	async connect(url: string): Promise<void> {
		const target = new URL(url);
		const key = randomBytes(16).toString("base64");
		const expected = createHash("sha1")
			.update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
			.digest("base64");
		await new Promise<void>((resolve, reject) => {
			const socket = connect(Number(target.port), target.hostname, () => {
				socket.write(
					`GET ${target.pathname}${target.search} HTTP/1.1\r\n` +
						`Host: ${target.hostname}:${target.port}\r\n` +
						"Upgrade: websocket\r\nConnection: Upgrade\r\n" +
						`Sec-WebSocket-Key: ${key}\r\nSec-WebSocket-Version: 13\r\n\r\n`,
				);
			});
			socket.setNoDelay(true);
			this.socket = socket;
			let head = "";
			const onData = (chunk: Buffer) => {
				head += chunk.toString("latin1");
				const end = head.indexOf("\r\n\r\n");
				if (end === -1) return;
				const headers = head.slice(0, end);
				if (!/^HTTP\/1\.1 101/.test(headers)) {
					reject(new Error(`BiDi upgrade refused: ${headers.split("\r\n")[0]}`));
					return;
				}
				if (!headers.toLowerCase().includes(expected.toLowerCase())) {
					reject(new Error("BiDi upgrade accept key did not match"));
					return;
				}
				socket.off("data", onData);
				const rest = Buffer.from(head.slice(end + 4), "latin1");
				socket.on("data", (next) => this.receive(next));
				if (rest.length) this.receive(rest);
				resolve();
			};
			socket.on("data", onData);
			socket.on("error", (err) => reject(err));
			socket.on("close", () => {
				this.closed = true;
			});
		});
	}

	onMessage(handler: (text: string) => void): void {
		this.onText = handler;
	}

	send(text: string): void {
		if (!this.socket || this.closed) throw new Error("BiDi socket is closed");
		this.socket.write(RawWebSocket.encodeText(text));
	}

	close(): void {
		this.closed = true;
		this.socket?.destroy();
	}

	/** Client frames must be masked (RFC 6455 5.3). */
	static encodeText(text: string): Buffer {
		const payload = Buffer.from(text, "utf8");
		const mask = randomBytes(4);
		const header: number[] = [0x81];
		if (payload.length < 126) header.push(0x80 | payload.length);
		else if (payload.length < 65536) header.push(0x80 | 126, payload.length >> 8, payload.length & 0xff);
		else {
			header.push(0x80 | 127, 0, 0, 0, 0);
			header.push((payload.length >>> 24) & 0xff, (payload.length >>> 16) & 0xff, (payload.length >>> 8) & 0xff, payload.length & 0xff);
		}
		const masked = Buffer.from(payload);
		for (let i = 0; i < masked.length; i += 1) masked[i] = (masked[i] ?? 0) ^ (mask[i % 4] ?? 0);
		return Buffer.concat([Buffer.from(header), mask, masked]);
	}

	/**
	 * One frame off the front of `input`, or undefined when it is incomplete.
	 * Exported through the class so the framing can be tested without a browser.
	 */
	static decodeFrame(input: Buffer): { opcode: number; fin: boolean; payload: Buffer; rest: Buffer } | undefined {
		if (input.length < 2) return undefined;
		const first = input.readUInt8(0);
		const second = input.readUInt8(1);
		const fin = (first & 0x80) !== 0;
		const opcode = first & 0x0f;
		const masked = (second & 0x80) !== 0;
		let length = second & 0x7f;
		let offset = 2;
		if (length === 126) {
			if (input.length < 4) return undefined;
			length = input.readUInt16BE(2);
			offset = 4;
		} else if (length === 127) {
			if (input.length < 10) return undefined;
			length = Number(input.readBigUInt64BE(2));
			offset = 10;
		}
		const maskKey = masked ? input.subarray(offset, offset + 4) : undefined;
		if (masked) offset += 4;
		if (input.length < offset + length) return undefined;
		const payload = Buffer.from(input.subarray(offset, offset + length));
		if (maskKey) {
			for (let i = 0; i < payload.length; i += 1) payload[i] = (payload[i] ?? 0) ^ (maskKey[i % 4] ?? 0);
		}
		return { opcode, fin, payload, rest: Buffer.from(input.subarray(offset + length)) };
	}

	private fragments: Buffer[] = [];

	private receive(chunk: Buffer): void {
		this.buffer = Buffer.concat([this.buffer, chunk]);
		for (;;) {
			const frame = RawWebSocket.decodeFrame(this.buffer);
			if (!frame) return;
			this.buffer = frame.rest;
			if (frame.opcode === 0x9) {
				// ping -> pong, so a long render is not dropped as idle
				this.socket?.write(Buffer.concat([Buffer.from([0x8a, 0x80]), randomBytes(4)]));
				continue;
			}
			if (frame.opcode === 0x8) {
				this.close();
				return;
			}
			if (frame.opcode === 0x1 || frame.opcode === 0x0) {
				this.fragments.push(frame.payload);
				if (frame.fin) {
					const text = Buffer.concat(this.fragments).toString("utf8");
					this.fragments = [];
					this.onText(text);
				}
			}
		}
	}
}

// ---------------------------------------------------------------- injected code

function pageConfig(): string {
	return JSON.stringify({
		...TUNING.boilerplate,
		maxDepth: TUNING.extract.maxDepth,
		maxColspan: TUNING.extract.maxColspan,
		structuredTypes: TUNING.structuredTypes,
	});
}

const PROBE = '(() => JSON.stringify({ ready: document.readyState, textLen: (document.body ? document.body.innerText : "").length }))()';

function structuredScript(): string {
	return `(() => {
  const CONFIG = ${pageConfig()};
  const wanted = new RegExp(CONFIG.structuredTypes);
  const blocks = [];
  for (const node of document.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      const parsed = JSON.parse(node.textContent);
      for (const item of Array.isArray(parsed) ? parsed : [parsed]) {
        for (const entry of item && item["@graph"] ? item["@graph"] : [item]) {
          const type = entry && entry["@type"];
          if ((Array.isArray(type) ? type : [type]).some((t) => wanted.test(String(t)))) blocks.push(entry);
        }
      }
    } catch (e) {}
  }
  const og = {};
  for (const meta of document.querySelectorAll('meta[property^="og:"], meta[name^="twitter:"]')) {
    const key = meta.getAttribute("property") || meta.getAttribute("name");
    if (key && meta.content) og[key] = meta.content;
  }
  return JSON.stringify({ blocks, og });
})()`;
}

/**
 * The layout-aware converter, as a function the page can call on any root.
 *
 * Two modes, because the two callers have different information available:
 *
 *   `useLayout: true`  - the live document. Visibility comes from `getComputedStyle` and
 *                        box geometry, which is the whole reason extraction runs in the
 *                        page rather than in node.
 *   `useLayout: false` - a `DOMParser` document holding Readability's output. It has no
 *                        layout at all, so every box measures 0x0 and the geometry check
 *                        would discard the entire document. Readability has already done
 *                        boilerplate removal, so only the tag filter is needed there.
 */
function converterSource(): string {
	return `const __magpiConvert = (root, useLayout) => {
  const CONFIG = ${pageConfig()};
  const SKIP_TAG = new Set(CONFIG.skipTags);
  const SKIP_SEMANTIC = new Set(CONFIG.skipSemantic);
  const SKIP_ROLE = new RegExp(CONFIG.skipRolePattern, "i");
  const SKIP_CLASS = new RegExp(CONFIG.skipClassPattern, "i");

  const hidden = (el) => {
    if (el.getAttribute("aria-hidden") === "true") return true;
    if (!useLayout) return (el.style && el.style.display === "none") || false;
    const style = getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return true;
    const box = el.getBoundingClientRect();
    return box.width < CONFIG.minBoxPx && box.height < CONFIG.minBoxPx;
  };
  const boilerplate = (el) => {
    if (!useLayout) return false;
    if (SKIP_SEMANTIC.has(el.tagName)) return true;
    const role = el.getAttribute("role");
    if (role && SKIP_ROLE.test(role)) return true;
    const cls = typeof el.className === "string" ? el.className : "";
    return SKIP_CLASS.test(el.id || "") || SKIP_CLASS.test(cls);
  };
  const text = (node) => (node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim();
  const cell = (node) => text(node).replace(/\\|/g, "\\\\|");

  const tableToMarkdown = (table) => {
    const rows = [...table.rows].filter((r) => !hidden(r));
    if (!rows.length) return "";
    const grid = [];
    for (const row of rows) {
      const cells = [];
      let allHeader = row.cells.length > 0;
      for (const c of row.cells) {
        if (c.tagName !== "TH") allHeader = false;
        const span = Math.max(1, Math.min(CONFIG.maxColspan, c.colSpan || 1));
        cells.push(cell(c));
        for (let i = 1; i < span; i += 1) cells.push("");
      }
      if (cells.some((v) => v !== "")) grid.push({ cells, header: allHeader });
    }
    if (!grid.length) return "";
    const width = Math.max(...grid.map((r) => r.cells.length));
    const pad = (cells) => { const c = cells.slice(); while (c.length < width) c.push(""); return c; };
    let headerRows = 0;
    while (headerRows < grid.length && grid[headerRows].header) headerRows += 1;
    let head; let body;
    if (headerRows > 1) {
      const merged = new Array(width).fill("");
      for (let i = 0; i < headerRows; i += 1) {
        const cells = pad(grid[i].cells);
        for (let j = 0; j < width; j += 1) if (cells[j]) merged[j] = merged[j] ? merged[j] + " " + cells[j] : cells[j];
      }
      head = merged; body = grid.slice(headerRows).map((r) => pad(r.cells));
    } else {
      head = pad(grid[0].cells); body = grid.slice(1).map((r) => pad(r.cells));
    }
    if (width === 1) return [head[0], ...body.map((r) => r[0])].filter(Boolean).join(" ");
    const lines = ["| " + head.join(" | ") + " |", "| " + head.map(() => "---").join(" | ") + " |"];
    for (const r of body) lines.push("| " + r.join(" | ") + " |");
    return lines.join("\\n");
  };

  const out = [];
  const push = (value) => { const t = value.trim(); if (t) out.push(t); };
  const inline = (el) => {
    let s = "";
    for (const node of el.childNodes) {
      if (node.nodeType === 3) s += node.textContent;
      else if (node.nodeType === 1) {
        if (SKIP_TAG.has(node.tagName) || hidden(node)) continue;
        if (node.tagName === "A" && node.getAttribute("href")) {
          const label = text(node);
          s += label ? "[" + label + "](" + node.href + ")" : "";
        } else if (node.tagName === "BR") s += "\\n";
        else if (node.tagName === "CODE") s += "\`" + text(node) + "\`";
        else if (node.tagName === "STRONG" || node.tagName === "B") s += "**" + text(node) + "**";
        else s += inline(node);
      }
    }
    return s.replace(/[ \\t\\u00a0]+/g, " ");
  };

  let tables = 0;
  const walk = (el, depth) => {
    if (depth > CONFIG.maxDepth) return;
    for (const node of el.children) {
      if (SKIP_TAG.has(node.tagName) || hidden(node) || boilerplate(node)) continue;
      const tag = node.tagName;
      if (tag === "TABLE") { const md = tableToMarkdown(node); if (md) { tables += 1; push("\\n" + md + "\\n"); } continue; }
      if (/^H[1-6]$/.test(tag)) { push("\\n" + "#".repeat(Number(tag[1])) + " " + inline(node).trim()); continue; }
      if (tag === "LI") { push("- " + inline(node).trim()); continue; }
      if (tag === "PRE") { push("\\n\`\`\`\\n" + text(node) + "\\n\`\`\`\\n"); continue; }
      if (tag === "P" || tag === "BLOCKQUOTE") { const t = inline(node).trim(); push(tag === "BLOCKQUOTE" ? "> " + t : t); continue; }
      if (![...node.children].some((c) => !SKIP_TAG.has(c.tagName))) { push(inline(node).trim()); continue; }
      walk(node, depth + 1);
    }
  };

  if (root) walk(root, 0);
  const markdown = out.join("\\n\\n").replace(/\\n{3,}/g, "\\n\\n").trim();
  const plain = markdown
    .replace(/\\[([^\\]]*)\\]\\([^)]*\\)/g, "$1")
    .replace(/^\\|[\\s-]*\\|$/gm, "")
    .replace(/\\|/g, " ")
    .replace(/^#+\\s*/gm, "")
    .replace(/^[-*]\\s+/gm, "")
    .replace(/[\`*>]/g, "")
    .replace(/\\s+/g, " ")
    .trim();
  return { markdown, plainLen: plain.length, tables };
};`;
}

function convertScript(): string {
	return `(() => {
  ${converterSource()}
  const CONFIG = ${pageConfig()};
  let main = null;
  for (const selector of CONFIG.mainSelectors) { main = document.querySelector(selector); if (main) break; }
  main = main || document.body;
  const result = __magpiConvert(main, true);
  const visible = (document.body ? document.body.innerText : "").replace(/\\s+/g, " ").trim();
  return JSON.stringify({ ...result, visibleLen: visible.length });
})()`;
}

/** Readability's own source, injected so it runs against the live DOM. */
export function readabilityPath(): string {
	return join(homedir(), ".pi", "agent", "npm", "node_modules", "@mozilla", "readability", "Readability.js");
}

/**
 * Where `/magpi-render` leaves its output.
 *
 * A rendered page runs from 7 KB to 60 KB, which is not something to pour into a TUI,
 * and a custom message needs a registered renderer to appear at all: the first cut
 * returned one without a renderer, so the whole document vanished and only the summary
 * notification survived. A file plus its path is what MagPi does with its cache, and it
 * can be read, grepped and diffed. The name is stable per url, so a re-render overwrites
 * instead of accumulating.
 */
export function renderArtifactPath(url: string): string {
	let host = "page";
	try {
		host = new URL(url).host.replace(/[^a-z0-9.-]/gi, "-") || "page";
	} catch {
		// unparseable url: the hash still makes the name unique
	}
	const hash = createHash("sha256").update(url).digest("hex").slice(0, 8);
	return join(homedir(), ".pi", "agent", "tmp", "magpi-render", `${host}-${hash}.md`);
}

/**
 * Readability, then the same converter over its output.
 *
 * Its `textContent` was used here first, and it has no block boundaries at all: the landing page
 * landing page came out as one run-on paragraph where "Message Assistant" and the
 * sentence after it merged into the token `AssistantAn`, which also broke full-text
 * search for `Assistant`. Its `content` is HTML, so parsing that and walking it with the
 * converter restores headings, lists and tables - and no HTML reaches the document.
 */
function readableScript(source: string): string {
	return `(() => {
  ${converterSource()}
  ${source}
  let parsed = null;
  try { parsed = new Readability(document.cloneNode(true), { charThreshold: 100 }).parse(); } catch (e) { parsed = null; }
  if (!parsed || !parsed.content) return JSON.stringify({ markdown: "", plainLen: 0, tables: 0 });
  const doc = new DOMParser().parseFromString(parsed.content, "text/html");
  const result = __magpiConvert(doc.body, false);
  return JSON.stringify({ ...result, title: parsed.title || "" });
})()`;
}

// ---------------------------------------------------------------- the render

interface RenderOutcome {
	markdown: string;
	frames: number;
	settleMs: number;
	hitCap: boolean;
	responses: number;
	tables: number;
	structured: number;
}

async function render(
	url: string,
	binary: string,
	config: RenderConfig,
	signal: AbortSignal | undefined,
	onUpdate: ((text: string) => void) | undefined,
): Promise<RenderOutcome> {
	const target = new URL(url);
	const pageDomain = registrableDomain(target.host);
	const sameSiteOnly =
		TUNING.settle.contentBearing.sameSiteOnly ||
		config.sameSiteOnlyHosts.some((host) => registrableDomain(host) === pageDomain);
	const maxWaitMs = config.maxWaitMs ?? TUNING.settle.maxWaitMs;

	const profile = mkdtempSync(join(tmpdir(), "magpi-render-"));
	writeFileSync(join(profile, "user.js"), TUNING.browser.prefs.join("\n"), "utf8");
	let child: ChildProcess | undefined;
	let socket: RawWebSocket | undefined;
	const cleanup = () => {
		try {
			socket?.close();
		} catch {}
		child?.kill("SIGKILL");
		rmSync(profile, { recursive: true, force: true });
	};

	try {
		child = spawn(binary, [...TUNING.browser.args, "--profile", profile], {
			stdio: ["ignore", "pipe", "pipe"],
		});
		let stderr = "";
		const wsUrl = await new Promise<string>((resolve, reject) => {
			const timer = setTimeout(
				() => reject(new Error(`browser did not announce a BiDi port in ${TUNING.browser.startupTimeoutMs}ms`)),
				TUNING.browser.startupTimeoutMs,
			);
			child?.stderr?.on("data", (chunk: Buffer) => {
				stderr += chunk.toString();
				const match = /ws:\/\/\S+/.exec(stderr);
				if (match) {
					clearTimeout(timer);
					resolve(match[0]);
				}
			});
			child?.on("exit", (code) => reject(new Error(`browser exited with ${code}: ${stderr.slice(0, 300)}`)));
		});

		// Firefox prints the origin only; the BiDi socket lives at /session.
		socket = new RawWebSocket();
		await socket.connect(`${wsUrl.replace(/\/+$/, "")}/session`);

		let nextId = 1;
		const pending = new Map<number, { resolve: (value: unknown) => void; reject: (error: Error) => void }>();
		let lastResponseAt = Date.now();
		let responses = 0;
		let inflight = 0;
		socket.onMessage((text) => {
			let message: Record<string, unknown>;
			try {
				message = JSON.parse(text) as Record<string, unknown>;
			} catch {
				return;
			}
			const method = message.method as string | undefined;
			if (method === "network.beforeRequestSent") {
				inflight += 1;
				return;
			}
			if (method === "network.responseCompleted" || method === "network.fetchError") {
				inflight = Math.max(0, inflight - 1);
				responses += 1;
				const params = message.params as { response?: ResponseFacts; request?: { url?: string } } | undefined;
				const facts = params?.response
					? { ...params.response, url: params.response.url ?? params.request?.url }
					: undefined;
				if (isContentBearing(facts, { sameSiteOnly, pageDomain })) lastResponseAt = Date.now();
				return;
			}
			const id = message.id as number | undefined;
			if (id === undefined) return;
			const entry = pending.get(id);
			if (!entry) return;
			pending.delete(id);
			if (message.error) entry.reject(new Error(`${message.error}: ${String(message.message).slice(0, 160)}`));
			else entry.resolve(message.result);
		});

		const bidi = socket;
		const send = <T>(method: string, params: unknown = {}, timeoutMs = TUNING.browser.commandTimeoutMs): Promise<T> => {
			const id = nextId++;
			bidi.send(JSON.stringify({ id, method, params }));
			return new Promise<T>((resolve, reject) => {
				pending.set(id, { resolve: resolve as (value: unknown) => void, reject });
				setTimeout(() => {
					if (pending.delete(id)) reject(new Error(`${method} timed out after ${timeoutMs}ms`));
				}, timeoutMs).unref();
			});
		};

		await send("session.new", { capabilities: {} });
		await send("session.subscribe", {
			events: ["network.beforeRequestSent", "network.responseCompleted", "network.fetchError"],
		});
		type TreeNode = { context?: string; url?: string; children?: TreeNode[] };
		const flatten = (nodes: TreeNode[] | undefined, depth = 0, out: { context: string; url: string; depth: number }[] = []) => {
			for (const node of nodes ?? []) {
				if (typeof node.context === "string") out.push({ context: node.context, url: node.url ?? "", depth });
				flatten(node.children, depth + 1, out);
			}
			return out;
		};
		const root = flatten((await send<{ contexts: TreeNode[] }>("browsingContext.getTree", {})).contexts)[0]?.context;
		if (!root) throw new Error("browser produced no browsing context");

		const evaluate = async <T>(context: string, expression: string): Promise<T> => {
			const result = await send<{ type: string; result?: { value?: string }; exceptionDetails?: { text?: string } }>(
				"script.evaluate",
				{ expression, target: { context }, awaitPromise: false },
			);
			if (result.type === "exception") throw new Error(String(result.exceptionDetails?.text).slice(0, 200));
			return JSON.parse(result.result?.value ?? "null") as T;
		};
		const frameTree = async () => flatten((await send<{ contexts: TreeNode[] }>("browsingContext.getTree", { root })).contexts);
		const measure = async () => {
			let total = 0;
			for (const frame of await frameTree()) {
				try {
					total += (await evaluate<{ textLen: number }>(frame.context, PROBE)).textLen;
				} catch {
					// a frame mid-navigation cannot be measured; the next poll will see it
				}
			}
			return total;
		};

		const start = Date.now();
		await send("browsingContext.navigate", { context: root, url: target.href, wait: "none" }, 15_000);

		let last = -1;
		let stable = 0;
		let total = 0;
		let hitCap = true;
		while (Date.now() - start < maxWaitMs) {
			if (signal?.aborted) throw new Error("cancelled");
			await new Promise((resolve) => setTimeout(resolve, TUNING.settle.pollMs));
			total = await measure();
			stable = total === last ? stable + 1 : 0;
			last = total;
			const facts: SettleFacts = {
				elapsedMs: Date.now() - start,
				stableRounds: stable,
				quietForMs: Date.now() - lastResponseAt,
				inflight,
				totalText: total,
			};
			onUpdate?.(`rendering ${target.host}: ${total} chars, ${responses} responses`);
			if (facts.elapsedMs >= maxWaitMs || !shouldSettle(facts, maxWaitMs)) continue;
			// Believing the first "settled" is what let an earlier revision stop at 2,767
			// of the catalogue page's 14,296 characters and report success.
			await new Promise((resolve) => setTimeout(resolve, TUNING.settle.confirmMs));
			const after = await measure();
			if (after !== total) {
				last = after;
				stable = 0;
				continue;
			}
			hitCap = false;
			break;
		}
		const settleMs = Date.now() - start;

		let readabilitySource: string | undefined;
		try {
			readabilitySource = readFileSync(readabilityPath(), "utf8");
		} catch {
			readabilitySource = undefined; // Readability unavailable: the layout pass stands alone
		}

		const frames: FrameResult[] = [];
		for (const frame of await frameTree()) {
			let converted: { markdown: string; plainLen: number; tables: number; visibleLen: number };
			try {
				converted = await evaluate(frame.context, convertScript());
			} catch {
				continue;
			}
			// Furniture, not content: an ad syncframe, about:blank, or a chat widget.
			if (converted.visibleLen < TUNING.empty.frameMinChars && converted.markdown.trim().length === 0) continue;
			if (converted.visibleLen < TUNING.empty.frameMinChars && converted.plainLen < TUNING.empty.frameMinChars) continue;
			const structured = await evaluate<{ blocks: unknown[]; og: Record<string, string> }>(
				frame.context,
				structuredScript(),
			);
			const result = toFrameResult(frame, converted, structured);
			const weak = converted.tables === 0 || !TUNING.extract.tablesBeatReadability;
			if (weak && coverageOf(result) < TUNING.extract.weakCoverage && readabilitySource) {
				try {
					const readable = await evaluate<{ markdown: string; plainLen: number }>(
						frame.context,
						readableScript(readabilitySource),
					);
					if (readable.markdown) {
						result.readableMarkdown = readable.markdown;
						result.readablePlainLen = readable.plainLen;
					}
				} catch {
					// Readability threw on this document; the layout pass is the answer
				}
			}
			frames.push(result);
		}

		const markdown = assembleMarkdown(target.href, frames);
		const plain = markdown.replace(/<!--[\s\S]*?-->/g, "").replace(/\s+/g, " ").trim();
		if (plain.length < TUNING.empty.minChars) {
			const reason = classifyEmpty(plain);
			const detail =
				reason === "login"
					? "the page asks for a login"
					: reason === "botcheck"
						? "the page served a bot check"
						: hitCap
							? `nothing settled within ${maxWaitMs}ms`
							: "the rendered page held no text";
			throw new Error(
				`Rendered ${target.href} and got ${plain.length} characters: ${detail}. ` +
					"Reporting this rather than caching an empty document.",
			);
		}

		const structuredBlocks = frames.flatMap((f) => f.structured).filter((block) => block != null);
		return {
			markdown,
			frames: frames.length,
			settleMs,
			hitCap,
			responses,
			tables: frames.reduce((sum, f) => sum + f.tables, 0),
			structured: structuredBlocks.length,
		};
	} finally {
		cleanup();
	}
}

// ---------------------------------------------------------------- extension

export default async function (pi: ExtensionAPI) {
	/**
	 * Nothing is registered on a machine without Firefox.
	 *
	 * This directory is shared across machines through dotfiles, so a Linux box with no
	 * Firefox would otherwise carry a tool in every prompt that can only fail when
	 * called. A browser installed later needs a `/reload`, which extensions need anyway.
	 */
	const startup = loadConfig(process.cwd(), false);
	if (!startup.enabled) return;
	if (!browserLookup.find(startup.browserBinary)) return;

	/**
	 * TypeBox is a dependency of pi, not of this directory, and a local extension
	 * cannot resolve packages under `npm/node_modules` (measured: bare imports fail with
	 * ERR_MODULE_NOT_FOUND). A tool schema is plain JSON Schema at runtime, so the
	 * literal works whether or not the import resolves.
	 */
	let parameters: unknown;
	try {
		const { Type } = (await import("typebox")) as { Type: { Object: (p: unknown) => unknown; String: (o?: unknown) => unknown; Optional: (s: unknown) => unknown } };
		parameters = Type.Object({
			url: Type.String({ description: "URL to render (scheme optional, https assumed)" }),
		});
	} catch {
		parameters = {
			type: "object",
			properties: { url: { type: "string", description: "URL to render (scheme optional, https assumed)" } },
			required: ["url"],
		};
	}

	const normalize = (raw: string): string => (/^[a-z]+:\/\//i.test(raw) ? raw : `https://${raw}`);
	const describe = (outcome: RenderOutcome): string =>
		`${outcome.frames} frame${outcome.frames === 1 ? "" : "s"}, ${outcome.tables} tables, ${outcome.structured} schema.org blocks, settled in ${(outcome.settleMs / 1000).toFixed(1)}s` +
		`${outcome.hitCap ? " (hit the wait cap; the page may still have been loading)" : ""}`;

	const active = (ctx: ExtensionContext) => {
		const config = loadConfig(ctx.cwd, ctx.isProjectTrusted());
		if (!config.enabled) return undefined;
		// Re-checked per call: a project config can disable it, and the binary can move.
		const binary = browserLookup.find(config.browserBinary);
		return binary ? { config, binary } : undefined;
	};

	pi.registerTool({
		name: "magpi_fetch_rendered",
		label: "Web Fetch (rendered)",
		description:
			"Fetch a URL through the installed Firefox, so pages that build their content with JavaScript can be read. " +
			"Use when magpi_fetch returned a near-empty page, boilerplate only, or a shell without the data you asked for. " +
			"Waits for the page to stop changing, reads every frame (iframes included), converts tables to markdown, and " +
			"lifts schema.org data. Costs a browser launch and 6-15 seconds, so it is the escalation and not the default. " +
			"Throws rather than return an empty document, naming a login wall or bot check when that is what happened.",
		promptSnippet: "Read a JavaScript-rendered page through Firefox when magpi_fetch comes back thin",
		promptGuidelines: [
			"Reach for magpi_fetch_rendered only after magpi_fetch returns a page that is empty, boilerplate, or missing the content the page visibly has. It costs a browser launch and up to 15 seconds.",
			"Say in the answer that the content came from a rendered page, since it is a different source from the server's HTML.",
		],
		parameters: parameters as never,
		async execute(_toolCallId, params: { url: string }, signal, onUpdate, ctx) {
			const ready = active(ctx);
			if (!ready) throw new Error("magpi_fetch_rendered is unavailable: no Firefox binary was found (see magpi-render.json)");
			const url = normalize(params.url);
			const outcome = await render(url, ready.binary, ready.config, signal, (text) =>
				onUpdate?.({ content: [{ type: "text", text }] }),
			);
			return {
				content: [{ type: "text", text: `${outcome.markdown}\n\n<!-- rendered: ${describe(outcome)} -->` }],
				details: {},
			};
		},
	});

	pi.registerCommand("magpi-render", {
		description: "🦊 Render a URL through Firefox and show what a reader would see",
		async handler(args, ctx) {
			const raw = args.trim();
			if (!raw) {
				ctx.ui.notify("Usage: /magpi-render <url>", "info");
				return;
			}
			const ready = active(ctx);
			if (!ready) {
				ctx.ui.notify("No Firefox binary found; set browserBinary in magpi-render.json", "error");
				return;
			}
			try {
				const url = normalize(raw);
				const outcome = await render(url, ready.binary, ready.config, undefined, (text) =>
					ctx.ui.notify(text, "info"),
				);
				const path = renderArtifactPath(url);
				mkdirSync(join(path, ".."), { recursive: true });
				writeFileSync(path, outcome.markdown, "utf8");
				ctx.ui.notify(`🦊 ${describe(outcome)}, ${outcome.markdown.length} bytes -> ${path}`, "success");
				return;
			} catch (error) {
				ctx.ui.notify(`🦊 ${(error as Error).message}`, "error");
				return;
			}
		},
	});

	// ------------------------------------------------------------ automatic escalation

	/**
	 * Learned hosts live here after being read from disk, so `match` stays synchronous and
	 * a host learned mid-session applies to the very next fetch without a reload.
	 */
	let learned = loadLearned();

	/**
	 * Delivery goes *through* MagPi, not around it.
	 *
	 * A handler on MagPi's own extension point means MagPi does the caching: `content.md`,
	 * `meta.json` and the sqlite full-text index are written together, TTL applies, and
	 * `magpi_cached` can find the rendered text. Writing those files from here would
	 * desync the index, which its `cache.ts` updates in one place. MagPi also runs
	 * `assertPublicTarget()` before resolving a handler, so the SSRF guard is inherited
	 * rather than reimplemented.
	 */
	const renderHandler = {
		name: "render",
		description: "Pages whose content only exists after JavaScript runs, read through Firefox",
		match: (url: URL) => {
			const config = loadConfig(process.cwd(), false);
			return config.enabled && shouldRenderHost(url.hostname, config.renderHosts, learned);
		},
		fetch: async (url: URL, handlerCtx: { signal?: AbortSignal }) => {
			// Global config only: a handler runs inside MagPi and has no project-trust context.
			const config = loadConfig(process.cwd(), false);
			const binary = browserLookup.find(config.browserBinary);
			if (!binary) throw new Error("magpi-render: no Firefox binary found (see magpi-render.json)");
			const outcome = await render(url.href, binary, config, handlerCtx.signal, undefined);
			return { kind: "rendered", content: `${outcome.markdown}\n\n<!-- rendered: ${describe(outcome)} -->` };
		},
	};

	// Emitted twice for the reason `magpi-handlers.ts` documents: MagPi subscribes during
	// its own activation, extension order is not guaranteed, and registering twice is
	// idempotent because its registry replaces by name.
	const register = () => pi.events.emit("magpi:register-handler", renderHandler);
	register();
	pi.on("session_start", async () => {
		learned = loadLearned();
		register();
		return undefined;
	});

	/**
	 * Detection: notice a shell, learn the host, say so.
	 *
	 * Nothing here can re-run MagPi's tool, so the first visit to a host is annotated
	 * rather than repaired. From the second visit the handler above takes over and the
	 * result is cached like any other fetch.
	 */
	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "magpi_fetch") return undefined;
		const config = loadConfig(ctx.cwd, ctx.isProjectTrusted());
		if (!config.enabled || !config.learnHosts) return undefined;
		const details = event.details as FetchDetails | undefined;
		if (!isThinFetch(details, event.isError)) return undefined;
		let host = "";
		try {
			host = new URL(details?.url ?? "").hostname.toLowerCase();
		} catch {
			return undefined;
		}
		if (!host || shouldRenderHost(host, config.renderHosts, learned)) return undefined;
		learned = learnHost(learned, host, {
			learnedAt: new Date().toISOString(),
			bytes: details?.contentBytes ?? 0,
			kind: details?.kind ?? "",
		});
		try {
			saveLearned(learned);
		} catch {
			// an unwritable store costs a repeated discovery, not correctness
		}
		const note = thinNote(details?.url ?? host, details?.contentBytes ?? 0);
		const content = Array.isArray(event.content) ? [...event.content] : [];
		const last = content.at(-1) as { type?: string; text?: string } | undefined;
		if (last?.type === "text") content[content.length - 1] = { ...last, text: `${last.text ?? ""}${note}` };
		else content.push({ type: "text", text: note.trim() } as never);
		return { content } as never;
	});
}
