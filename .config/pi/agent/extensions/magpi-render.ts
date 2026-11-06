/**
 * magpi-render.ts - reading pages whose content only exists after JavaScript runs
 *
 * `magpi_fetch` reads the server's HTML. When a site builds its content in the browser,
 * that HTML is a shell, and MagPi caches the footer it extracted from it as a successful
 * `article`. This drives the installed Firefox over WebDriver BiDi, waits for the page to
 * stop changing, and extracts what a reader would see. Two ways in:
 *
 *   - inside `magpi_fetch`: a replacement for MagPi's `webpage` handler renders in the
 *     same call when the HTML is a shell or leaves content in frames (`webpageHandler`);
 *   - on request: the `magpi_fetch_rendered` tool and `/magpi-render <url>`.
 *
 * Design notes for anyone changing this file:
 *
 *   - **Every tunable is in TUNING, with the measurement that set it.** Change a value
 *     with new evidence, not taste.
 *   - **Readability is a candidate, not the extractor.** It drops tables, which on a
 *     catalogue page are the content; see `TUNING.extract`.
 *   - **Extraction runs in the page**, so visibility comes from `getComputedStyle` and box
 *     geometry rather than from guessing at tag names.
 *   - **An empty result throws.** MagPi caches whatever it is handed, and a rendered shell
 *     reads to the model as "this page says nothing".
 *   - **No site-specific code.** A site's internal API has no compatibility promise and is
 *     the first thing it blocks; rendering consumes the page the way the site intends.
 *   - **The browser is a child process, outside `pi-sandbox`**, which enforces at the
 *     `bash` tool, so this works with `allowBrowserProcess: false`. A launch from
 *     sandboxed `bash` does not (README, "MagPi renderer").
 *   - Nothing under `npm/node_modules` is patched; MagPi is extended through its own
 *     handler registration.
 */

import { type ChildProcess, spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { connect, type Socket } from "node:net";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ════════════════════════════════════════════════════════════════════════════════
//  TUNING
//
//  The measurement that set each value is named beside it. "The catalogue page" is a
//  Next.js parts catalogue whose payload is 11 tables; "the shop page" an electronics
//  product page whose reviews and Q&A live in same-site iframes.
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
		 * A request open longer than this stops counting as in flight: it is a long poll or
		 * a beacon that never answers, not data on its way. This is also the longest a single
		 * data request is waited for, so too short loses a slow API's content silently and too
		 * long only costs time on pages with a request that never ends.
		 * Not measured: how long legitimate requests take. Measured cost: on a furniture shop's
		 * home page a same-site bot-check script never answered, so the page, stable from
		 * ~4.5 s, settled at 9.9 s.
		 */
		staleRequestMs: 8_000,
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
		 * Measured renders settle in 4-15 s.
		 */
		maxWaitMs: 25_000,
		/**
		 * A page this short that matches `empty.botPattern` does not settle before the cap. A
		 * JS challenge ("Just a moment...") holds still for seconds before it navigates to the
		 * real page, and stability alone would return the challenge. Longer pages are read as
		 * articles mentioning one of the words, which must not wait out the cap.
		 * Not measured against a real challenge. The cost: a short hard block ("Access
		 * denied") waits out the cap.
		 */
		challengeMaxChars: 1_000,
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
			 * arrives. Losing content is invisible; waiting too long is not. `TUNING.block`
			 * keeps the worst third-party traffic off the timer instead, and
			 * `magpi-render.json`'s `sameSiteOnlyHosts` turns this on per host.
			 */
			sameSiteOnly: false,
		},
	},

	/**
	 * Scrolling while the page settles, so content that loads on sight gets loaded.
	 *
	 * A block behind an `IntersectionObserver` reads "loading..." until it is scrolled to.
	 * Steps run in every frame, moving the largest scroller (the window, or an app layout's own scrolling `div`). Settling waits
	 * until every frame is at its end or the screens run out, so an endless feed stops
	 * growing after `maxScreens` instead of holding the turn.
	 */
	scroll: {
		/**
		 * 12 screens at two per poll take 6 polls, about `minWaitMs`, so a page that settles
		 * anyway is not held back by its own length. Measured: one screen per poll held the
		 * 9-screen shop page back 5 s.
		 */
		maxScreens: 12,
		screensPerPoll: 2,
		/** Between the screens of one poll, so an `IntersectionObserver` sees each viewport. */
		gapMs: 120,
		/** Of the scroller's height, so consecutive viewports overlap and nothing is jumped over. */
		viewportFraction: 0.9,
	},

	/**
	 * Third-party requests failed before they leave the browser.
	 *
	 * Measured: 80 of the catalogue page's 245 responses were third-party (datadog RUM,
	 * criteo, channel.io) and kept the idle timer from settling for 1.5 s; channel.io's chat
	 * widget is also a frame of its own. Every request is intercepted over BiDi and continued
	 * unless its host matches below, which costs one loopback round trip per request.
	 *
	 * Matched as a domain and its subdomains, and never against the page's own registrable
	 * domain, so reading amplitude.com itself still loads amplitude.com. Ads and analytics
	 * only: nothing here serves content a reader would see.
	 */
	block: {
		enabled: true,
		hosts: [
			"adnxs.com", "ads-twitter.com", "adservice.google.com", "amazon-adsystem.com", "amplitude.com",
			"analytics.tiktok.com", "bat.bing.com", "browser-intake-datadoghq.com", "channel.io", "clarity.ms",
			"criteo.com", "criteo.net", "crazyegg.com", "datadoghq-browser-agent.com", "doubleclick.net",
			"facebook.net", "fullstory.com", "google-analytics.com", "googleadservices.com",
			"googlesyndication.com", "googletagmanager.com", "hotjar.com", "hotjar.io", "intercom.io",
			"intercomcdn.com", "mixpanel.com", "moatads.com", "nr-data.net", "outbrain.com",
			"px.ads.linkedin.com", "pubmatic.com", "quantserve.com", "rubiconproject.com",
			"scorecardresearch.com", "segment.com", "segment.io", "snap.licdn.com", "taboola.com",
			"wcs.naver.net", "groobee.io",
		],
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
		/**
		 * `FORM` is deliberately absent: a page wrapped whole in one form (JSP and ASP.NET
		 * sites do this) lost everything. Measured: a statute page's frame holds 144,599
		 * characters inside `<form id="searchForm">` and rendered to 70. The controls are
		 * skipped one by one instead, and a search form is `role=search`.
		 */
		skipTags: [
			"SCRIPT", "STYLE", "NOSCRIPT", "SVG", "CANVAS", "TEMPLATE", "LINK", "META", "HEAD",
			"IFRAME", "FRAME", "OBJECT", "EMBED", "AUDIO", "VIDEO",
			"SELECT", "OPTION", "BUTTON", "INPUT", "TEXTAREA", "LABEL",
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

	/** schema.org types worth lifting out of ld+json. */
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
		/**
		 * Launches tried when Firefox exits before announcing its BiDi port.
		 * Measured: about 1 render in 150 fails within a second, Firefox exiting 0 with only
		 * its headless banner on stderr, and succeeds when called again; cause unknown. A
		 * startup timeout is not retried: it has already cost 20 s.
		 */
		startupAttempts: 2,
		startupRetryDelayMs: 1_000,
		commandTimeoutMs: 30_000,
		/**
		 * One browser per render, killed afterwards. A pooled instance would save the
		 * measured 1.3 s startup, which is small next to a 6-15 s render and not worth
		 * the lifetime bugs until it is.
		 */
		reuse: false,
		/**
		 * Browsers alive at once; later renders queue. MagPi fetches a batch of URLs in
		 * parallel and any of them may escalate, so this bounds a batch of shells to two
		 * Firefox processes. Not measured: a queued render still counts against MagPi's 90 s
		 * per-fetch deadline, which is what keeps this above one.
		 */
		maxConcurrent: 2,
	},

	/** Refusing to return a shell. */
	empty: {
		/** Below this many characters, a rendered page has told us nothing. */
		minChars: 200,
		/**
		 * A frame with less visible text than this is furniture, not content.
		 * Measured: a chat widget's frame renders 22 characters; the shop page's smallest
		 * content frame (Q&A) has 1,499.
		 */
		frameMinChars: 200,
		/** Signals in the rendered text that name *why* it is empty. */
		loginPattern: "(로그인|로그인이 필요|sign in|log in|login required|create an account)",
		botPattern: "(are you a robot|captcha|cloudflare|just a moment|access denied|unusual traffic)",
	},

	/**
	 * Noticing that `magpi_fetch` came back with a shell, after the fact: the fallback for
	 * when MagPi's internals cannot be loaded (`loadMagpiInternals`). `minContentBytes` is
	 * also the thin-answer threshold of `escalation()`.
	 *
	 * Detection reads MagPi's own `details` (`contentBytes`, `handler`, `kind`) rather than
	 * its preview text, so formatting changes upstream cannot fool it.
	 */
	detect: {
		/**
		 * A `webpage` result smaller than this is a shell, not a page.
		 * Measured: a landing page cached 0 bytes under a healthy title, the catalogue page
		 * 315 bytes of footer. No byte threshold catches a partial loss; frames do, in
		 * `escalation()`.
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

	/**
	 * Deciding, inside MagPi's own fetch, that its answer needs the browser.
	 *
	 * This replaces MagPi's `webpage` handler with one that reads the same HTML and keeps
	 * MagPi's markdown, but also reads what MagPi throws away - the page's frames, its
	 * framework mount point, the data its scripts were handed - and renders in the same
	 * call when those say the answer is incomplete. See `escalation()` for the rules.
	 */
	escalate: {
		/**
		 * Asked of every server. Sites behind Cloudflare's "Markdown for Agents" answer in
		 * markdown; everything else ignores it and sends HTML.
		 * Measured: blog.cloudflare.com returned 18,334 bytes of markdown with front matter,
		 * where MagPi's own extraction of the HTML kept 9,403 characters.
		 */
		accept: "text/markdown, text/html;q=0.9, */*;q=0.8",
		/** MagPi's own cap on a response body. */
		maxBodyChars: 5 * 1024 * 1024,
		/**
		 * Framework mount points. Empty in the server's HTML means the page is built in the
		 * browser, whatever else (header, footer, noscript) the server sent around it.
		 */
		appRootIds: ["root", "app", "__next", "__nuxt", "___gatsby", "svelte", "q-app", "main-app"],
		/**
		 * Prose embedded in the page's data is used instead of rendering only past this much.
		 * Below it, the strings are as likely to be labels and SEO text as the content.
		 * Measured: no shell so far clears it (the most was 650 characters of headlines), so
		 * they render; the server-rendered pages that carry 20 KB of copy are not shells.
		 */
		embeddedMinChars: 1_500,
		embeddedMaxChars: 20_000,
		/** A string shorter than this is a label, not prose. CJK packs more per character. */
		proseMinChars: 30,
		proseMinCjkChars: 12,
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
 * two-part public suffixes; a correct answer needs the Public Suffix List. It tells a
 * page's own site from third parties: the idle timer, the tracker block, content frames.
 * `api.kr.example.com` and `kr.example.com` both reduce to `example.com`.
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

/** Whether a request's host is on `TUNING.block.hosts` and not the page's own site. */
export function isBlockedHost(host: string, pageDomain: string): boolean {
	const target = host.toLowerCase();
	if (!target || registrableDomain(target) === pageDomain) return false;
	return TUNING.block.hosts.some((entry) => target === entry || target.endsWith(`.${entry}`));
}

export interface SettleFacts {
	elapsedMs: number;
	stableRounds: number;
	quietForMs: number;
	inflight: number;
	totalText: number;
	/** The page reads like a bot check; see `isChallenge`. */
	challenge?: boolean;
	/** A frame can still scroll to load more; see `TUNING.scroll`. */
	scrolling?: boolean;
}

/** The settle rule, kept separate from the loop so its truth table can be tested. */
export function shouldSettle(facts: SettleFacts, maxWaitMs = TUNING.settle.maxWaitMs): boolean {
	if (facts.elapsedMs >= maxWaitMs) return true; // caller reports the cap as suspicious
	return (
		facts.elapsedMs >= TUNING.settle.minWaitMs &&
		facts.stableRounds >= TUNING.settle.stableRounds &&
		facts.quietForMs >= TUNING.settle.networkIdleMs &&
		facts.inflight === 0 &&
		facts.totalText > 0 &&
		!facts.challenge &&
		!facts.scrolling
	);
}

/** Whether the page on screen is a bot check that may still navigate to the real one. */
export function isChallenge(text: string, totalText: number): boolean {
	return totalText < TUNING.settle.challengeMaxChars && classifyEmpty(text) === "botcheck";
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
 * One frame's numbers and payload, assembled field by field: spreading `{ blocks, og }`
 * into this shape type-checks and leaves `structured` undefined, silently dropping the
 * page's ld+json.
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

/**
 * Coverage against the rendered-text yardstick, at most 1.
 *
 * On a page measured through `innerText` it cannot exceed 1, since the extraction reads a
 * subset of the same text. A page with shadow roots is measured by walking text nodes,
 * whose whitespace counts differently: a fully read web-component page measured 1.02.
 */
export function coverageOf(frame: Pick<FrameResult, "plainLen" | "visibleLen">): number {
	return frame.visibleLen > 0 ? Math.min(1, frame.plainLen / frame.visibleLen) : 0;
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
	// OpenGraph is what a page without ld+json still declares about itself.
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
 * The reason given for an empty render. The document's HTTP status rides along because
 * an empty 404 and an empty 403 read the same on screen but call for different next
 * steps: a corrected URL, or another source.
 */
export function emptyDetail(
	reason: ReturnType<typeof classifyEmpty>,
	hitCap: boolean,
	maxWaitMs: number,
	status?: number,
): string {
	const detail =
		reason === "login"
			? "the page asks for a login"
			: reason === "botcheck"
				? "the page served a bot check"
				: hitCap
					? `nothing settled within ${maxWaitMs}ms`
					: "the rendered page held no text";
	return status === undefined ? detail : `${detail} (HTTP ${status})`;
}

/** Firefox quit before announcing its BiDi port: the one startup failure worth retrying. */
export class BrowserExited extends Error {}

/** Runs `start` again after a `BrowserExited`, up to `attempts` times in all. */
export async function retryStartup<T>(
	start: () => Promise<T>,
	attempts: number = TUNING.browser.startupAttempts,
	delayMs: number = TUNING.browser.startupRetryDelayMs,
): Promise<T> {
	for (let attempt = 1; ; attempt++) {
		try {
			return await start();
		} catch (error) {
			if (!(error instanceof BrowserExited) || attempt >= attempts) throw error;
			await new Promise((resolve) => setTimeout(resolve, delayMs));
		}
	}
}

/**
 * The browser this machine has, or nothing.
 *
 * Absolute candidates first, then `PATH`, because a Firefox installed by Homebrew's
 * formula, Nix or a Flatpak wrapper sits somewhere no fixed list can predict. `exists`
 * and `pathEnv` are injected so both outcomes are testable without depending on what the
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
 * a host pays for the discovery, and every session afterwards should not. It is plain
 * JSON, and deleting it only costs one repeated discovery.
 */
export function learnedStorePath(): string {
	return join(xdgDir("XDG_STATE_HOME", ".local/state"), "learned.json");
}

/** Learned hosts are state, render artefacts are cache; neither belongs in the dotfiles-tracked agent dir. */
function xdgDir(variable: "XDG_STATE_HOME" | "XDG_CACHE_HOME", fallback: string): string {
	return join(process.env[variable] || join(homedir(), fallback), "pi", "magpi-render");
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

// ---------------------------------------------------------------- escalation

/** What the server's HTML says about whether MagPi's markdown is the whole page. */
export interface PageSignals {
	/** A framework mount point (`TUNING.escalate.appRootIds`) with nothing in it. */
	emptyRoot: boolean;
	/** `<script>` elements that run code. Undefined when unknown, which counts as some. */
	scripts?: number;
	/** Same-site iframes with a visible size: content the server's HTML does not include. */
	frames: string[];
	/** Prose from the data the page hands its scripts (hydration state, ld+json). */
	embedded: string;
}

export const NO_SIGNALS: PageSignals = { emptyRoot: false, frames: [], embedded: "" };

const attribute = (tag: string, name: string): string | undefined => {
	const match = new RegExp(`\\s${name}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, "i").exec(tag);
	return match ? (match[2] ?? match[3] ?? match[4] ?? "") : undefined;
};

/**
 * Same-site iframes a reader would see. A player from another site (YouTube) and a
 * zero-size form target are not content; the shop page's review and Q&A frames are.
 */
function contentFrames(html: string, pageUrl: URL): string[] {
	const site = registrableDomain(pageUrl.hostname);
	const frames: string[] = [];
	for (const [tag] of html.matchAll(/<iframe\b[^>]*>/gi)) {
		const src = attribute(tag, "src");
		if (!src) continue;
		let target: URL;
		try {
			target = new URL(src.replace(/&amp;/g, "&"), pageUrl);
		} catch {
			continue;
		}
		if (target.protocol !== "http:" && target.protocol !== "https:") continue;
		if (registrableDomain(target.hostname) !== site) continue;
		if (["width", "height"].some((name) => /^\s*[01](px)?\s*$/i.test(attribute(tag, name) ?? ""))) continue;
		const style = attribute(tag, "style") ?? "";
		if (/display\s*:\s*none|visibility\s*:\s*hidden|(^|;)\s*(width|height)\s*:\s*[01](px)?\s*(;|$)/i.test(style)) continue;
		frames.push(target.href);
	}
	return frames;
}

const CJK = /[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]/g;

/** Keys whose strings are never prose: identifiers, links, styling. */
const NON_PROSE_KEYS = /^(@context|@type|@id|id|key|url|href|src|image|logo|icon|sameAs|className|class|style|slug|path|type|sku|gtin\d*|mpn|locale|lang)$/i;

/** A Tailwind-style class list reads like words to a length check, and is not. */
const looksLikeClassList = (text: string): boolean => {
	const tokens = text.split(" ");
	return tokens.every((token) => /^[a-z0-9:_\-[\]/.%!@#()]+$/.test(token)) && tokens.some((token) => /[-:]/.test(token));
};

/**
 * Whether a string from page data reads as text a person wrote. Flight data carries CSS
 * rules, font stacks and generated class names beside the copy; each rule removes one.
 */
export function isProse(raw: string): boolean {
	const text = raw.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
	if (/^(https?:|\/|\$|data:|#|\{|\[)/.test(text)) return false;
	if (/[{}]|=>|function\s*\(|\b[a-z-]+:[#\w(]/.test(text)) return false;
	const words = text.split(" ");
	if ((text.match(/,/g) ?? []).length > words.length * 0.4) return false;
	if (words.filter((word) => /_|\d\p{L}|\p{L}\d/u.test(word)).length > words.length * 0.3) return false;
	if ((text.match(CJK) ?? []).length >= TUNING.escalate.proseMinCjkChars) return true;
	if (text.length < TUNING.escalate.proseMinChars || words.length < 4) return false;
	if ((text.match(/\p{L}/gu) ?? []).length / text.length < 0.6) return false;
	return !looksLikeClassList(text);
}

const decodeBasicEntities = (text: string): string =>
	text
		.replace(/&quot;/g, '"')
		.replace(/&#39;|&apos;/g, "'")
		.replace(/&lt;/g, "<")
		.replace(/&gt;/g, ">")
		.replace(/&nbsp;/g, " ")
		.replace(/&amp;/g, "&");

/**
 * Prose from the data a page hands its scripts, in document order, deduplicated.
 *
 * MagPi deletes every `<script>` before extracting, which is right for code and wrong for
 * these: ld+json, `__NEXT_DATA__`, `__NUXT_DATA__` and any other `application/json`
 * block, Next.js app-router flight data (`self.__next_f.push`), and the
 * `window.__INITIAL_STATE__ = {...}` convention. Framework-shaped, not site-shaped: no
 * selector here names a site.
 */
export function embeddedText(html: string): string {
	const found: string[] = [];
	const seen = new Set<string>();
	const add = (raw: string) => {
		const text = decodeBasicEntities(raw.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
		if (!seen.has(text) && isProse(text)) {
			seen.add(text);
			found.push(text);
		}
	};
	const collect = (value: unknown, key = "", depth = 0): void => {
		if (depth > 40 || NON_PROSE_KEYS.test(key)) return;
		if (typeof value === "string") add(value);
		else if (Array.isArray(value)) for (const item of value) collect(item, key, depth + 1);
		else if (value && typeof value === "object") {
			for (const [name, item] of Object.entries(value)) collect(item, name, depth + 1);
		}
	};
	const parse = (text: string): unknown => {
		try {
			return JSON.parse(text);
		} catch {
			return undefined;
		}
	};
	let flight = "";
	for (const [, attrs, body] of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
		if (/\btype\s*=\s*["']?application\/(ld\+)?json/i.test(attrs)) {
			collect(parse(body.trim()) ?? parse(decodeBasicEntities(body.trim())));
			continue;
		}
		for (const [, literal] of body.matchAll(/self\.__next_f\.push\(\[\d+,\s*("(?:[^"\\]|\\.)*")\]\)/g)) {
			const chunk = parse(literal);
			if (typeof chunk === "string") flight += chunk;
		}
		const state = /^\s*window\.__[A-Z_]+__\s*=\s*([[{][\s\S]*?)\s*;?\s*$/.exec(body);
		if (state) collect(parse(state[1]));
	}
	// Flight data is rows of JSON with React elements inside; their string literals are the text.
	for (const [literal] of flight.matchAll(/"(?:[^"\\]|\\.){12,}"/g)) {
		const text = parse(literal);
		if (typeof text === "string") add(text);
	}
	return found.join("\n\n").slice(0, TUNING.escalate.embeddedMaxChars);
}

/** Everything `escalation()` needs from the server's HTML, read without a browser. */
export function pageSignals(html: string, pageUrl: URL): PageSignals {
	const ids = TUNING.escalate.appRootIds.map((id) => id.replace(/[$_]/g, "\\$&")).join("|");
	// A comment may not run past its own `-->`, or a server-rendered root that opens with
	// comments matches a later `--></div>` and reads as empty.
	const emptyRoot = new RegExp(
		`<(div|main|section)\\b[^>]*\\sid\\s*=\\s*["'](${ids})["'][^>]*>\\s*(<!--(?:(?!-->)[\\s\\S])*-->\\s*)*</\\1>`,
		"i",
	).test(html);
	const scripts = [...html.matchAll(/<script\b([^>]*)>/gi)].filter(
		([, attrs]) => !/\btype\s*=\s*["']?(application\/(ld\+)?json|text\/(template|x-template|html))/i.test(attrs),
	).length;
	return { emptyRoot, scripts, frames: contentFrames(html, pageUrl), embedded: embeddedText(html) };
}

export type EscalationAction = "keep" | "embedded" | "render";

/**
 * Whether MagPi's markdown stands, is completed from the page's data, or needs the browser.
 *
 *   1. An empty mount point: the page is built in the browser, so whatever MagPi found is
 *      the furniture around it (the catalogue page's 315 bytes were its footer).
 *   2. A thin answer from a page that runs scripts. A page without any cannot build
 *      content later, so it is just short. One script is enough: example.com's adds
 *      its translations.
 *   3. Same-site frames, which hold content the HTML does not, however long the HTML is.
 *
 * The first two can be answered from the page's data when there is enough of it; the
 * third cannot, since the frames' content is not in this document at all.
 */
export function escalation(
	contentBytes: number,
	signals: PageSignals,
): { action: EscalationAction; reason: string } {
	const enoughData = signals.embedded.length >= TUNING.escalate.embeddedMinChars;
	if (signals.emptyRoot) {
		return { action: enoughData ? "embedded" : "render", reason: "the page's mount point is empty in the server's HTML" };
	}
	if (contentBytes < TUNING.detect.minContentBytes && signals.scripts !== 0) {
		return {
			action: enoughData ? "embedded" : "render",
			reason: `the server's HTML held ${contentBytes} bytes of text and runs scripts`,
		};
	}
	if (signals.frames.length > 0) {
		const count = signals.frames.length;
		return { action: "render", reason: `${count} same-site frame${count === 1 ? "" : "s"} hold content the HTML does not` };
	}
	return { action: "keep", reason: "" };
}

/** A markdown response's title, from its front matter or its first heading. */
export function markdownTitle(markdown: string): string | undefined {
	const front = /^---\n([\s\S]*?)\n---/.exec(markdown);
	const fromFront = front ? /^title:\s*(.+)$/m.exec(front[1])?.[1] : undefined;
	const title = fromFront ?? /^#\s+(.+)$/m.exec(markdown)?.[1];
	return title?.trim().replace(/^["']|["']$/g, "") || undefined;
}

// ---------------------------------------------------------------- websocket

/**
 * A WebSocket client over a raw socket.
 *
 * Node's global `WebSocket` honours `HTTP(S)_PROXY`, which this machine sets globally,
 * and sends even a loopback connection through the proxy, where the upgrade fails with
 * an immediate close. `NO_PROXY=localhost,127.0.0.1` would fix that too; this keeps the
 * renderer independent of it. Only what BiDi needs is implemented: text frames, server
 * pings, close.
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

/**
 * Visible text length, the yardstick for both settling and coverage.
 *
 * `innerText` does not see into shadow roots: on msn.com, web components throughout,
 * `body.innerText` is 0 characters. Adding each shadow root's `innerText` is not enough
 * either, since text slotted into a nested component belongs to neither (it missed two
 * thirds of msn.com). So a page with any shadow root is measured by walking the composed
 * tree; a page without one keeps `innerText`, which is cheaper.
 */
const VISIBLE_TEXT = `const __magpiVisibleLen = () => {
  const body = document.body;
  if (!body) return 0;
  let shadowed = false;
  for (const el of body.querySelectorAll("*")) if (el.shadowRoot) { shadowed = true; break; }
  if (!shadowed) return body.innerText.replace(/\\s+/g, " ").trim().length;
  let total = 0;
  const walk = (node) => {
    const slotted = node.tagName === "SLOT" && node.assignedNodes ? node.assignedNodes({ flatten: true }) : [];
    const children = node.shadowRoot ? node.shadowRoot.childNodes : slotted.length ? slotted : node.childNodes;
    for (const child of children) {
      if (child.nodeType === 3) total += child.textContent.replace(/\\s+/g, " ").length;
      else if (child.nodeType === 1 && !/^(STYLE|SCRIPT|NOSCRIPT|TEMPLATE|LINK)$/.test(child.tagName)) {
        const style = getComputedStyle(child);
        if (style.display !== "none" && style.visibility !== "hidden") walk(child);
      }
    }
  };
  walk(body);
  return total;
};`;

/**
 * One scroll step in this frame; true once nothing is left to scroll.
 *
 * The window when the document scrolls; otherwise the largest element that scrolls on its
 * own, which is how app layouts (a fixed shell around one scrolling pane) are built. The
 * choice is kept on the window so later steps do not search again.
 */
const SCROLL_STEP = `const __magpiScrollStep = (fraction) => {
  let scroller = window.__magpiScroller;
  if (!scroller || !scroller.isConnected) {
    const doc = document.scrollingElement || document.documentElement;
    scroller = doc && doc.scrollHeight > innerHeight + 2 ? doc : null;
    if (!scroller && document.body) {
      for (const el of document.body.querySelectorAll("*")) {
        if (el.scrollHeight <= el.clientHeight + 2 || el.clientHeight < innerHeight / 2) continue;
        if (!/^(auto|scroll|overlay)$/.test(getComputedStyle(el).overflowY)) continue;
        if (!scroller || el.clientHeight * el.clientWidth > scroller.clientHeight * scroller.clientWidth) scroller = el;
      }
    }
    window.__magpiScroller = scroller;
  }
  if (!scroller) return true;
  const before = scroller.scrollTop;
  scroller.scrollTop = before + Math.max(1, scroller.clientHeight * fraction);
  return scroller.scrollTop === before || scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 2;
};`;

/** Measures a frame, scrolling it `TUNING.scroll.screensPerPoll` screens first while `scroll` is set. */
function probeScript(scroll: boolean): string {
	const { screensPerPoll, gapMs, viewportFraction } = TUNING.scroll;
	return `(async () => {
  ${VISIBLE_TEXT}
  ${SCROLL_STEP}
  let atEnd = true;
  if (${scroll}) {
    for (let i = 0; i < ${screensPerPoll}; i += 1) {
      if (i > 0) await new Promise((resolve) => setTimeout(resolve, ${gapMs}));
      atEnd = __magpiScrollStep(${viewportFraction});
      if (atEnd) break;
    }
  }
  const text = document.body ? document.body.innerText : "";
  return JSON.stringify({ ready: document.readyState, textLen: __magpiVisibleLen(), head: (document.title + " " + text).slice(0, 1000), atEnd });
})()`;
}

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

  // The composed tree: a shadow host's children are its shadow root's, and a slot's are
  // the nodes assigned to it (or its fallback when none are). Light children a shadow root
  // does not slot are not rendered, and are not read.
  const nodesOf = (el) => {
    if (el.shadowRoot) return [...el.shadowRoot.childNodes];
    if (el.tagName === "SLOT" && el.assignedNodes) {
      const assigned = el.assignedNodes({ flatten: true });
      if (assigned.length) return assigned;
    }
    return [...el.childNodes];
  };
  const kids = (el) => nodesOf(el).filter((node) => node.nodeType === 1);
  // Elements whose innerText would miss text: shadow hosts, slots, and everything above
  // them. Everything else keeps innerText, so a page without shadow DOM reads as through it.
  const composed = new Set();
  const mark = (scope) => {
    for (const el of scope.querySelectorAll("*")) {
      if (!el.shadowRoot) continue;
      for (let node = el; node; node = node.parentNode || node.host) composed.add(node);
      for (const slot of el.shadowRoot.querySelectorAll("slot")) {
        for (let node = slot; node && node !== el.shadowRoot; node = node.parentNode) composed.add(node);
      }
      mark(el.shadowRoot);
    }
  };
  if (useLayout && root) mark(root.ownerDocument || document);

  const hidden = (el) => {
    if (el.getAttribute("aria-hidden") === "true") return true;
    if (!useLayout) return (el.style && el.style.display === "none") || false;
    const style = getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return true;
    // A slot, and any element styled away from its own box, measures 0x0 while its
    // children render: the geometry test would drop all of them.
    if (style.display === "contents") return false;
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
  const flatText = (node) => {
    let s = "";
    for (const child of nodesOf(node)) {
      if (child.nodeType === 3) s += child.textContent;
      else if (child.nodeType === 1 && !SKIP_TAG.has(child.tagName) && !hidden(child)) s += " " + text(child) + " ";
    }
    return s;
  };
  const text = (node) => (composed.has(node) ? flatText(node) : node.innerText || node.textContent || "").replace(/\\s+/g, " ").trim();
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
    for (const node of nodesOf(el)) {
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
    for (const node of kids(el)) {
      if (SKIP_TAG.has(node.tagName) || hidden(node) || boilerplate(node)) continue;
      const tag = node.tagName;
      if (tag === "TABLE") { const md = tableToMarkdown(node); if (md) { tables += 1; push("\\n" + md + "\\n"); } continue; }
      if (/^H[1-6]$/.test(tag)) { push("\\n" + "#".repeat(Number(tag[1])) + " " + inline(node).trim()); continue; }
      if (tag === "LI") { push("- " + inline(node).trim()); continue; }
      if (tag === "PRE") { push("\\n\`\`\`\\n" + text(node) + "\\n\`\`\`\\n"); continue; }
      if (tag === "P" || tag === "BLOCKQUOTE") { const t = inline(node).trim(); push(tag === "BLOCKQUOTE" ? "> " + t : t); continue; }
      if (!kids(node).some((c) => !SKIP_TAG.has(c.tagName))) { push(inline(node).trim()); continue; }
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
  ${VISIBLE_TEXT}
  const CONFIG = ${pageConfig()};
  let main = null;
  for (const selector of CONFIG.mainSelectors) { main = document.querySelector(selector); if (main) break; }
  main = main || document.body;
  const result = __magpiConvert(main, true);
  return JSON.stringify({ ...result, visibleLen: __magpiVisibleLen() });
})()`;
}

/** Readability's own source, injected so it runs against the live DOM. */
export function readabilityPath(): string {
	return join(npmRoot(), "@mozilla", "readability", "Readability.js");
}

/**
 * Where `/magpi-render` leaves its output.
 *
 * A rendered page runs from 7 KB to 60 KB, too much for a TUI, and a custom message
 * without a registered renderer does not appear at all. A file can be read, grepped and
 * diffed; the name is stable per url, so a re-render overwrites instead of accumulating.
 */
export function renderArtifactPath(url: string): string {
	let host = "page";
	try {
		host = new URL(url).host.replace(/[^a-z0-9.-]/gi, "-") || "page";
	} catch {
		// unparseable url: the hash still makes the name unique
	}
	const hash = createHash("sha256").update(url).digest("hex").slice(0, 8);
	return join(xdgDir("XDG_CACHE_HOME", ".cache"), `${host}-${hash}.md`);
}

/**
 * Readability, then the same converter over its output.
 *
 * Not its `textContent`, which has no block boundaries: adjacent blocks merge into one
 * token ("Assistant" + "An" -> `AssistantAn`), breaking full-text search too. Its
 * `content` is HTML, so walking that with the converter keeps headings, lists and
 * tables, and no HTML reaches the document.
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

export interface RenderOutcome {
	markdown: string;
	frames: number;
	settleMs: number;
	hitCap: boolean;
	responses: number;
	/** Requests failed by `TUNING.block`. */
	blocked: number;
	tables: number;
	structured: number;
}

export function describeOutcome(outcome: RenderOutcome): string {
	return (
		`${outcome.frames} frame${outcome.frames === 1 ? "" : "s"}, ${outcome.tables} tables, ${outcome.structured} schema.org blocks, ` +
		`${outcome.blocked} trackers blocked, settled in ${(outcome.settleMs / 1000).toFixed(1)}s` +
		`${outcome.hitCap ? " (hit the wait cap; the page may still have been loading)" : ""}`
	);
}

/** `TUNING.browser.maxConcurrent` browsers at once; the rest wait their turn in order. */
const browserSlots = { running: 0, waiting: [] as (() => void)[] };

async function withBrowserSlot<T>(work: () => Promise<T>): Promise<T> {
	if (browserSlots.running >= TUNING.browser.maxConcurrent) {
		await new Promise<void>((resolve) => browserSlots.waiting.push(resolve));
	}
	browserSlots.running += 1;
	try {
		return await work();
	} finally {
		browserSlots.running -= 1;
		browserSlots.waiting.shift()?.();
	}
}

function render(
	url: string,
	binary: string,
	config: RenderConfig,
	signal: AbortSignal | undefined,
	onUpdate: ((text: string) => void) | undefined,
): Promise<RenderOutcome> {
	return withBrowserSlot(() => renderNow(url, binary, config, signal, onUpdate));
}

async function renderNow(
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
		const wsUrl = await retryStartup(() => {
			child?.kill("SIGKILL");
			const launched = spawn(binary, [...TUNING.browser.args, "--profile", profile], {
				stdio: ["ignore", "pipe", "pipe"],
			});
			child = launched;
			let stderr = "";
			return new Promise<string>((resolve, reject) => {
				const timer = setTimeout(
					() => reject(new Error(`browser did not announce a BiDi port in ${TUNING.browser.startupTimeoutMs}ms`)),
					TUNING.browser.startupTimeoutMs,
				);
				launched.stderr?.on("data", (chunk: Buffer) => {
					stderr += chunk.toString();
					const match = /ws:\/\/\S+/.exec(stderr);
					if (match) {
						clearTimeout(timer);
						resolve(match[0]);
					}
				});
				launched.on("exit", (code) => {
					clearTimeout(timer);
					reject(new BrowserExited(`browser exited with ${code}: ${stderr.slice(0, 300)}`));
				});
			});
		});

		// Firefox prints the origin only; the BiDi socket lives at /session.
		socket = new RawWebSocket();
		await socket.connect(`${wsUrl.replace(/\/+$/, "")}/session`);

		let nextId = 1;
		const pending = new Map<number, { resolve: (value: unknown) => void; reject: (error: Error) => void }>();
		let lastResponseAt = Date.now();
		let responses = 0;
		let blocked = 0;
		/**
		 * Requests in flight, by id, with their start time for `TUNING.settle.staleRequestMs`.
		 * Not a counter: a failed request may never report back (measured: blocked
		 * doubleclick requests from a YouTube frame sent no `network.fetchError`, holding the
		 * page to the cap). A failed request leaves when it is failed; a redirect keeps its id.
		 */
		const inflight = new Map<string, number>();
		const pendingRequests = () => {
			const cutoff = Date.now() - TUNING.settle.staleRequestMs;
			let count = 0;
			for (const startedAt of inflight.values()) if (startedAt > cutoff) count += 1;
			return count;
		};
		/** Last navigation response per browsing context; redirects overwrite their 3xx. */
		const navigationStatus = new Map<string, number>();
		socket.onMessage((text) => {
			let message: Record<string, unknown>;
			try {
				message = JSON.parse(text) as Record<string, unknown>;
			} catch {
				return;
			}
			const method = message.method as string | undefined;
			if (method === "network.beforeRequestSent") {
				const params = message.params as { isBlocked?: boolean; request?: { request?: string; url?: string } } | undefined;
				const request = params?.request?.request;
				if (request && !inflight.has(request)) inflight.set(request, Date.now());
				if (params?.isBlocked && request) {
					let host = "";
					try {
						host = new URL(params.request?.url ?? "").hostname;
					} catch {
						// not a URL with a host: let it through
					}
					const fail = isBlockedHost(host, pageDomain);
					if (fail) {
						blocked += 1;
						inflight.delete(request);
					}
					// A request already gone (navigated away, cancelled) answers "no such request".
					send(fail ? "network.failRequest" : "network.continueRequest", { request }).catch(() => {});
				}
				return;
			}
			if (method === "network.responseCompleted" || method === "network.fetchError") {
				responses += 1;
				const params = message.params as
					| { context?: string; navigation?: string | null; response?: ResponseFacts; request?: { request?: string; url?: string } }
					| undefined;
				if (params?.request?.request) inflight.delete(params.request.request);
				if (params?.navigation && params.context && params.response) {
					navigationStatus.set(params.context, params.response.status);
				}
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
		// Every request pauses until the handler above continues or fails it.
		if (TUNING.block.enabled) await send("network.addIntercept", { phases: ["beforeRequestSent"] });
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

		const evaluate = async <T>(context: string, expression: string, awaitPromise = false): Promise<T> => {
			const result = await send<{ type: string; result?: { value?: string }; exceptionDetails?: { text?: string } }>(
				"script.evaluate",
				{ expression, target: { context }, awaitPromise },
			);
			if (result.type === "exception") throw new Error(String(result.exceptionDetails?.text).slice(0, 200));
			return JSON.parse(result.result?.value ?? "null") as T;
		};
		const frameTree = async () => flatten((await send<{ contexts: TreeNode[] }>("browsingContext.getTree", { root })).contexts);
		let heads = "";
		let screens = 0;
		let endPolls = 0;
		let scrolledToEnd = TUNING.scroll.maxScreens === 0;
		const measure = async (scroll = false) => {
			let total = 0;
			let atEnd = true;
			const seen: string[] = [];
			for (const frame of await frameTree()) {
				try {
					const probe = await evaluate<{ textLen: number; head: string; atEnd: boolean }>(
						frame.context,
						probeScript(scroll),
						true,
					);
					total += probe.textLen;
					atEnd &&= probe.atEnd;
					seen.push(probe.head);
				} catch {
					// a frame mid-navigation cannot be measured; the next poll will see it
				}
			}
			heads = seen.join(" ");
			// Counted only once there is text: a page still loading has nothing to scroll and
			// would read as already at its end. The end has to be seen twice, since a step can
			// land there just before more is appended.
			if (scroll && total > 0) {
				screens += TUNING.scroll.screensPerPoll;
				endPolls = atEnd ? endPolls + 1 : 0;
				scrolledToEnd = endPolls >= 2 || screens >= TUNING.scroll.maxScreens;
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
			total = await measure(!scrolledToEnd);
			stable = total === last ? stable + 1 : 0;
			last = total;
			const facts: SettleFacts = {
				elapsedMs: Date.now() - start,
				stableRounds: stable,
				quietForMs: Date.now() - lastResponseAt,
				inflight: pendingRequests(),
				totalText: total,
				challenge: isChallenge(heads, total),
				scrolling: !scrolledToEnd,
			};
			onUpdate?.(`rendering ${target.host}: ${total} chars, ${responses} responses, ${blocked} blocked`);
			if (facts.elapsedMs >= maxWaitMs || !shouldSettle(facts, maxWaitMs)) continue;
			// The first "settled" can be a pause: on the catalogue page it fell at 2,767 of
			// 14,296 characters.
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
			const detail = emptyDetail(classifyEmpty(plain), hitCap, maxWaitMs, navigationStatus.get(root));
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
			blocked,
			tables: frames.reduce((sum, f) => sum + f.tables, 0),
			structured: structuredBlocks.length,
		};
	} finally {
		cleanup();
	}
}

// ---------------------------------------------------------------- MagPi's webpage handler

/** A MagPi handler as its registry sees one, without importing MagPi's types. */
export interface MagpiHandlerLike {
	name: string;
	description?: string;
	match(url: URL): boolean;
	fetch(url: URL, ctx: MagpiFetchContext): Promise<MagpiResult>;
}

export interface MagpiFetchContext {
	mode: "light" | "full";
	entryDir: string;
	signal?: AbortSignal;
	exec: unknown;
}

export interface MagpiResult {
	kind: string;
	title?: string;
	content: string;
	hasTree?: boolean;
}

/** The four pieces of MagPi this file builds on; `loadMagpiInternals()` finds them. */
export interface MagpiInternals {
	/** MagPi's own catch-all, for everything that is not plain HTML. */
	defaultHandler: MagpiHandlerLike;
	/** Name of the built-in handler MagPi would choose for a URL; "webpage" when none claims it. */
	builtinFor(url: URL): string;
	/** MagPi's GET: its user agent, its timeout, `FetchError` on a non-2xx status. */
	httpGet(url: string, signal?: AbortSignal, headers?: Record<string, string>): Promise<Response>;
	/** MagPi's HTML-to-markdown, so an unescalated page reads exactly as MagPi would have. */
	htmlToMarkdown(html: string, url?: string): { title?: string; markdown: string };
}

/**
 * Where MagPi's source sits: beside this file's directory, under the agent dir's npm root.
 *
 * Relative to this file rather than `~/.pi/agent`, because that spelling is `EPERM` to
 * `bash` under `pi-sandbox` while this one is not, so the same code runs from a test.
 */
const npmRoot = (): string => fileURLToPath(new URL("../npm/node_modules/", import.meta.url));

/**
 * MagPi's internals, imported by path; undefined when that fails.
 *
 * There is no other way to reach them: MagPi exposes registration, not its handlers. pi
 * loads extensions through jiti, which resolves MagPi's `./handler.js` specifiers to its
 * `.ts` sources (node's own type stripping refuses files under `node_modules`, so a
 * plain node test gets undefined here). The imports are fresh copies, which is safe
 * because none of the four keeps state. A MagPi update that moves them leaves the
 * original handler in place; `tests/magpi-render.test.ts` loads them through pi's jiti
 * to say so before that happens.
 */
export async function loadMagpiInternals(root = join(npmRoot(), "pi-magpi", "src")): Promise<MagpiInternals | undefined> {
	try {
		// One at a time: these import each other, and loading them concurrently under jiti
		// failed with "Cannot access 'defaultFetch' before initialization".
		const handler = await import(join(root, "handlers", "handler.ts"));
		const html = await import(join(root, "html.ts"));
		const defaults = await import(join(root, "handlers", "default.ts"));
		const registry = await import(join(root, "handlers", "registry.ts"));
		const internals = {
			defaultHandler: defaults.defaultHandler as MagpiHandlerLike,
			builtinFor: (url: URL) => (registry.resolveHandler(url) as MagpiHandlerLike).name,
			httpGet: handler.httpGet as MagpiInternals["httpGet"],
			htmlToMarkdown: html.htmlToMarkdown as MagpiInternals["htmlToMarkdown"],
		};
		const complete =
			internals.defaultHandler?.name === "webpage" &&
			typeof internals.defaultHandler.fetch === "function" &&
			typeof registry.resolveHandler === "function" &&
			typeof internals.httpGet === "function" &&
			typeof internals.htmlToMarkdown === "function";
		return complete ? internals : undefined;
	} catch {
		return undefined;
	}
}

const plainLength = (markdown: string): number => markdown.replace(/<!--[\s\S]*?-->/g, "").replace(/\s+/g, " ").trim().length;

async function readCapped(response: Response): Promise<string> {
	const text = await response.text();
	return text.length > TUNING.escalate.maxBodyChars ? text.slice(0, TUNING.escalate.maxBodyChars) : text;
}

/** The `llms.txt` files MagPi's defaultFetch looks for before a page, in its order. */
export function llmsProbes(url: URL, mode: MagpiFetchContext["mode"]): string[] {
	if (mode === "full") return ["llms-full.txt", "llms.txt"];
	return url.pathname === "/" ? ["llms.txt"] : [];
}

export interface WebpageDeps {
	magpi: MagpiInternals;
	/** Handlers other extensions registered with MagPi; whichever claims a URL keeps it. */
	others: () => Iterable<MagpiHandlerLike>;
	enabled: () => boolean;
	/** A renderer for this call, or undefined when no browser is available now. */
	renderer: () => ((url: URL, signal?: AbortSignal) => Promise<RenderOutcome>) | undefined;
}

/**
 * MagPi's `webpage` handler, with the escalation built in.
 *
 * Registered under MagPi's own name, so MagPi's registry drops its copy (it replaces by
 * name) and the label in MagPi's output and cache stays `webpage`. Registration puts it
 * first, ahead of every built-in and of extension handlers registered earlier, so it
 * claims a URL only where none of them would: what is left over is exactly what MagPi's
 * catch-all would have had.
 *
 * The fetch reads the page once, with `Accept: text/markdown` first, and converts HTML
 * with MagPi's own converter. Anything else - an error status, a PDF, JSON, plain text -
 * goes to MagPi's handler untouched, which keeps its Wayback fallback.
 */
export function webpageHandler(deps: WebpageDeps): MagpiHandlerLike {
	const { magpi } = deps;

	const escalate = async (url: URL, base: MagpiResult, signals: PageSignals, signal?: AbortSignal): Promise<MagpiResult> => {
		const { action, reason } = escalation(Buffer.byteLength(base.content, "utf8"), signals);
		if (action === "keep") return base;
		if (action === "embedded") {
			return {
				...base,
				content:
					`${base.content}\n\n<!-- magpi-render: ${reason}, but the page's own data carries its text, read below ` +
					`without a browser. Order and context may be lost; magpi_fetch_rendered reads it as displayed. -->\n\n` +
					`## Text from the page's embedded data\n\n${signals.embedded}`,
			};
		}
		const renderer = deps.renderer();
		if (!renderer) return base;
		try {
			const outcome = await renderer(url, signal);
			// Rendering found less than the HTML had: the frames were empty, or the page
			// served the browser something else. MagPi's answer is the better one.
			if (plainLength(outcome.markdown) <= plainLength(base.content)) return base;
			return {
				kind: "rendered",
				title: base.title,
				content: `${outcome.markdown}\n\n<!-- rendered because ${reason}: ${describeOutcome(outcome)} -->`,
			};
		} catch (error) {
			const message = (error as Error).message.replace(/--+>?/g, "-");
			return { ...base, content: `${base.content}\n\n<!-- magpi-render: ${reason}, and rendering failed: ${message} -->` };
		}
	};

	const handler: MagpiHandlerLike = {
		name: "webpage",
		description: `${magpi.defaultHandler.description ?? "Generic webpage"}; rendered through Firefox when the HTML is a shell or leaves content in frames`,
		match: (url: URL) => {
			if (!deps.enabled() || magpi.builtinFor(url) !== "webpage") return false;
			for (const other of deps.others()) {
				try {
					if (other !== handler && other.match(url)) return false;
				} catch {
					// a handler that throws in match() is MagPi's to report, not ours
				}
			}
			return true;
		},
		fetch: async (url: URL, ctx: MagpiFetchContext) => {
			// MagPi's `llms.txt` probe, repeated: handing the URL to its defaultFetch instead
			// would cost a second GET of the page for the signals (4.5 s on one slow site). A
			// test fails if MagPi changes the probe.
			for (const name of llmsProbes(url, ctx.mode)) {
				try {
					const probe = await magpi.httpGet(`${url.origin}/${name}`, ctx.signal);
					const text = await readCapped(probe);
					if (!/html/i.test(probe.headers.get("content-type") ?? "") && text.trim()) return { kind: "llms-txt", content: text };
				} catch {
					// the site does not publish it
				}
			}
			let response: Response;
			try {
				response = await magpi.httpGet(url.href, ctx.signal, { accept: TUNING.escalate.accept });
			} catch {
				return magpi.defaultHandler.fetch(url, ctx);
			}
			const type = response.headers.get("content-type") ?? "";
			if (/text\/markdown/i.test(type)) {
				const markdown = (await readCapped(response)).trim();
				return escalate(url, { kind: "article", title: markdownTitle(markdown), content: markdown }, NO_SIGNALS, ctx.signal);
			}
			if (!/html/i.test(type)) {
				await response.body?.cancel().catch(() => {});
				return magpi.defaultHandler.fetch(url, ctx);
			}
			const html = await readCapped(response);
			const page = magpi.htmlToMarkdown(html, url.href);
			return escalate(url, { kind: "article", title: page.title, content: page.markdown }, pageSignals(html, url), ctx.signal);
		},
	};
	return handler;
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
	const describe = describeOutcome;

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

	// ------------------------------------------------------------ MagPi handlers

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

	/**
	 * Every handler other extensions give MagPi, by name as MagPi keeps them, so the
	 * webpage handler can stand back from their URLs. A handler registered before this
	 * extension loaded is seen when it re-registers at `session_start`, as
	 * `magpi-handlers.ts` does; one that never re-registers would be shadowed.
	 */
	const others = new Map<string, MagpiHandlerLike>();
	pi.events.on("magpi:register-handler", (handler: unknown) => {
		const candidate = handler as MagpiHandlerLike | undefined;
		if (candidate && typeof candidate.name === "string" && typeof candidate.match === "function") {
			others.set(candidate.name, candidate);
		}
	});

	const magpi = await loadMagpiInternals();
	const webpage = magpi
		? webpageHandler({
				magpi,
				others: () => [...others.values()].filter((handler) => handler !== renderHandler),
				enabled: () => loadConfig(process.cwd(), false).enabled,
				renderer: () => {
					// Global config only, as for the render handler above.
					const config = loadConfig(process.cwd(), false);
					const binary = browserLookup.find(config.browserBinary);
					return binary ? (url, signal) => render(url.href, binary, config, signal, undefined) : undefined;
				},
			})
		: undefined;

	// Emitted twice for the reason `magpi-handlers.ts` documents: MagPi subscribes during
	// its own activation, extension order is not guaranteed, and registering twice is
	// idempotent because its registry replaces by name. The webpage handler goes first so
	// the render handler, registered after it, stands in front of it.
	const register = () => {
		if (webpage) pi.events.emit("magpi:register-handler", webpage);
		pi.events.emit("magpi:register-handler", renderHandler);
	};
	register();
	pi.on("session_start", async () => {
		learned = loadLearned();
		register();
		return undefined;
	});

	/**
	 * Fallback detection, for when MagPi's internals could not be loaded: notice a shell,
	 * learn the host, say so. Nothing here can re-run MagPi's tool, so the first visit is
	 * annotated rather than repaired; from the second the render handler takes over.
	 *
	 * Off while the webpage handler runs. It sees every page this would, and a thin answer
	 * it lets through runs no scripts or already failed in the browser; learning that host
	 * would only send the next visit to the same failure.
	 */
	pi.on("tool_result", async (event, ctx) => {
		if (webpage || event.toolName !== "magpi_fetch") return undefined;
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
