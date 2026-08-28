/**
 * magpi-handlers.ts - this machine's local MagPi fetch handlers
 *
 * One file for every handler that shadows or extends `pi-magpi`, so there is a
 * single place to look when a site starts returning junk. Each section below
 * states what was measured, since a handler that is not needed is pure liability:
 *
 * - **reddit** — Reddit closed every anonymous read path reachable from here:
 *   `www.reddit.com/*.json`, `api.reddit.com` and `oauth.reddit.com` answer 403,
 *   `old.reddit.com` 302s to `/login?reason=lor2`, `r.jina.ai` relays the block
 *   page, PullPush answers 429, public Redlib instances sit behind Anubis
 *   proof-of-work. Self-service API keys ended with the Responsible Builder Policy
 *   (r/redditdev, Nov 2025). MagPi's own handler readability-parses the login page
 *   into a 20-byte "Skip to main content" document and *reports success*, caching
 *   it for `ttlHours`. Falls back to the Arctic Shift archive instead.
 * - **discourse** — measured on a 169-reply thread at discuss.python.org: the
 *   server-rendered HTML MagPi reads carries only the first 18 posts, silently, so
 *   every long thread loses its conclusion. `/t/<id>.json?print=true` returns all
 *   169.
 * - **naver-blog** — `blog.naver.com/<id>/<logNo>` puts the post inside an iframe,
 *   so readability returns a **0-byte** document (reproduced from this cache). The
 *   mobile host renders the same post server-side.
 *
 * Shared ground rules:
 *
 * - Registration goes through MagPi's documented event
 *   (`pi.events.emit("magpi:register-handler", ...)`, see its src/index.ts). Its
 *   `registerHandler()` replaces by name, so using a built-in's name (`reddit`)
 *   shadows it. Nothing under `npm/node_modules` is patched.
 * - MagPi's own TypeScript cannot be imported — Node refuses type stripping under
 *   `node_modules`, the same wall `tests/sandbox.test.ts` hits — so its
 *   `FetchContext`/`HandlerResult` are restated here, and its `htmlToMarkdown`
 *   (readability + turndown) is unavailable. `htmlToMarkdown()` below is a small
 *   replacement, good enough for the clean fragments these handlers deal with and
 *   nowhere near readability for a whole page.
 * - A handler **throws** rather than return an empty or blocked document: MagPi
 *   then falls back to a stale cache entry if it has one and reports the error
 *   otherwise, which is the behaviour worth having.
 *
 * Notes, caveats and how to remove any of this in README.md.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------- MagPi types
//
// Structurally identical to pi-magpi's own; see the header for why they are not
// imported. `registerHandler()` only validates `{ name, match, fetch }`, so plain
// objects built here are first-class handlers.

interface FetchContext {
	mode: "light" | "full";
	entryDir: string;
	signal?: AbortSignal;
}

interface HandlerResult {
	kind: string;
	title?: string;
	content: string;
	hasTree?: boolean;
}

interface MagpiHandler {
	name: string;
	description: string;
	match: (url: URL) => boolean;
	fetch: (url: URL, ctx: FetchContext) => Promise<HandlerResult>;
}

// ---------------------------------------------------------------- shared plumbing

/** Ceiling for one HTTP call. MagPi bounds the whole handler (90s in light mode); this bounds a hung socket. */
const REQUEST_TIMEOUT_MS = 20_000;
/** Sites that serve a library user-agent a 403 serve this one the page. */
const BROWSER_UA =
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

function timeoutSignal(signal?: AbortSignal): AbortSignal {
	const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
	return signal ? AbortSignal.any([signal, timeout]) : timeout;
}

async function getJson(url: string, signal?: AbortSignal, headers: Record<string, string> = {}): Promise<unknown> {
	const res = await fetch(url, {
		signal: timeoutSignal(signal),
		headers: { accept: "application/json", ...headers },
	});
	if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
	return res.json();
}

async function getHtml(url: string, signal?: AbortSignal): Promise<string> {
	const res = await fetch(url, {
		signal: timeoutSignal(signal),
		headers: { accept: "text/html,*/*", "user-agent": BROWSER_UA },
	});
	if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
	return res.text();
}

const ENTITIES: Record<string, string> = {
	amp: "&",
	lt: "<",
	gt: ">",
	quot: '"',
	apos: "'",
	nbsp: " ",
	hellip: "…",
	mdash: "—",
	ndash: "–",
	middot: "·",
	bull: "•",
	ldquo: "“",
	rdquo: "”",
	lsquo: "‘",
	rsquo: "’",
	laquo: "«",
	raquo: "»",
	deg: "°",
	times: "×",
	copy: "©",
	reg: "®",
	trade: "™",
};

export function decodeEntities(text: string): string {
	return text
		.replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
		.replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
		.replace(/&([a-z]+);/gi, (whole, name) => ENTITIES[name.toLowerCase()] ?? whole);
}

/**
 * HTML -> markdown-ish text, by regex.
 *
 * Not a readability substitute and not meant to be: it is aimed at *fragments*
 * that are already just the content (a Discourse `cooked` body, the post
 * container of a blog page). Given a whole page it keeps the navigation too.
 * Images are dropped, matching MagPi's own turndown rule — an LLM reading cached
 * text gets nothing from them.
 */
export function htmlToMarkdown(html: string): string {
	let out = html
		.replace(/<(script|style|noscript|svg|iframe)\b[^>]*>[\s\S]*?<\/\1>/gi, "")
		.replace(/<!--[\s\S]*?-->/g, "");
	out = out
		.replace(/<br\s*\/?>/gi, "\n")
		.replace(/<hr\s*\/?>/gi, "\n---\n")
		.replace(/<h([1-6])\b[^>]*>/gi, (_, level) => `\n${"#".repeat(Number(level))} `)
		.replace(/<\/h[1-6]>/gi, "\n")
		.replace(/<li\b[^>]*>/gi, "\n- ")
		.replace(/<blockquote\b[^>]*>/gi, "\n> ")
		.replace(/<\/(blockquote|li)>/gi, "\n")
		.replace(/<pre\b[^>]*>\s*<code\b[^>]*>/gi, "\n```\n")
		.replace(/<\/code>\s*<\/pre>/gi, "\n```\n")
		.replace(/<pre\b[^>]*>/gi, "\n```\n")
		.replace(/<\/pre>/gi, "\n```\n")
		.replace(/<code\b[^>]*>/gi, "`")
		.replace(/<\/code>/gi, "`")
		.replace(/<(strong|b)\b[^>]*>|<\/(strong|b)>/gi, "**")
		.replace(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi, (_, href, text) => {
			const label = text.replace(/<[^>]+>/g, "").trim();
			return label ? `[${label}](${href})` : href;
		})
		.replace(/<\/(p|div|section|article|tr|ul|ol|table|h[1-6])>/gi, "\n")
		.replace(/<img\b[^>]*>/gi, "")
		.replace(/<[^>]+>/g, "");
	return decodeEntities(out)
		.split("\n")
		.map((line) => line.replace(/[ \t\u00a0]+/g, " ").trim())
		.join("\n")
		.replace(/\n{3,}/g, "\n\n")
		.trim();
}

/** First matching capture group across several patterns, for "this editor or that editor" extraction. */
function firstMatch(html: string, patterns: RegExp[]): string | undefined {
	for (const pattern of patterns) {
		const m = pattern.exec(html);
		if (m?.[1]?.trim()) return m[1];
	}
	return undefined;
}

/**
 * Inner HTML of the `<div>` whose opening tag starts at `openTagStart`, found by
 * counting nested `div` tags.
 *
 * A non-greedy `([\s\S]*?)</div>\s*</div>` regex cannot do this and quietly gets it
 * wrong: naver's SmartEditor nests a div per component, so it stopped at the first
 * inner component and returned a *fraction* of the post (measured: 1.1 KB of a post
 * that goes on for pages). Losing the tail silently is exactly the failure this file
 * exists to prevent.
 */
export function sliceElement(html: string, openTagStart: number): string | undefined {
	const tagEnd = html.indexOf(">", openTagStart);
	if (tagEnd === -1) return undefined;
	const tags = /<(\/?)div\b[^>]*>/gi;
	tags.lastIndex = tagEnd + 1;
	let depth = 1;
	for (let m = tags.exec(html); m; m = tags.exec(html)) {
		depth += m[1] ? -1 : 1;
		if (depth === 0) return html.slice(tagEnd + 1, m.index);
	}
	// Unbalanced markup: everything after the container beats nothing at all.
	return html.slice(tagEnd + 1);
}

// ================================================================ reddit

/** Comments kept in a rendered thread, depth-first. Bounds an /r/all-sized thread. */
const MAX_COMMENTS = 40;
/** Per-comment body cap, in characters. */
const MAX_COMMENT_CHARS = 1500;
const ARCTIC = "https://arctic-shift.photon-reddit.com";

/** The fields used here out of reddit's (and Arctic Shift's) post object. */
export interface RedditPost {
	title?: string;
	subreddit?: string;
	author?: string;
	selftext?: string;
	score?: number;
	num_comments?: number;
	created_utc?: number;
	url?: string;
	is_self?: boolean;
}

/** One node of a comment listing: `{ kind: "t1" | "more", data: {...} }`. */
interface CommentNode {
	kind?: string;
	data?: {
		author?: string;
		body?: string;
		score?: number;
		replies?: unknown;
	};
}

export interface FlatComment {
	depth: number;
	author: string;
	score: number;
	body: string;
}

/**
 * Base36 post id out of any thread URL, `t3_` prefix tolerated:
 * `/r/sub/comments/<id>/slug/`, `/comments/<id>`, and a permalink to one comment
 * inside the thread (`/r/sub/comments/<id>/slug/<commentId>/`) all resolve to the
 * post, which is what both APIs are keyed by.
 */
export function postIdFromUrl(url: URL): string | null {
	const m = /\/comments\/(?:t3_)?([a-z0-9]{4,12})(?:\/|$)/i.exec(url.pathname);
	return m ? m[1].toLowerCase() : null;
}

/** Children of a comment listing, whatever shape `replies` arrived in (`""` when there are none). */
function childrenOf(replies: unknown): CommentNode[] {
	if (Array.isArray(replies)) return replies as CommentNode[];
	const children = (replies as { data?: { children?: unknown } } | undefined)?.data?.children;
	return Array.isArray(children) ? (children as CommentNode[]) : [];
}

/**
 * Depth-first flatten of a comment tree, capped at `max`. Both sources use
 * reddit's own nesting, with `kind: "more"` placeholders for collapsed subtrees
 * (dropped: they carry ids, not text).
 */
export function flattenComments(children: CommentNode[], max = MAX_COMMENTS): FlatComment[] {
	const out: FlatComment[] = [];
	const walk = (nodes: CommentNode[], depth: number) => {
		for (const node of nodes) {
			if (out.length >= max) return;
			if (node?.kind !== "t1" || !node.data) continue;
			const body = (node.data.body ?? "").trim();
			if (body) {
				out.push({
					depth,
					author: node.data.author ?? "[unknown]",
					score: node.data.score ?? 0,
					body: body.length > MAX_COMMENT_CHARS ? `${body.slice(0, MAX_COMMENT_CHARS)}…` : body,
				});
			}
			walk(childrenOf(node.data.replies), depth + 1);
		}
	};
	walk(children, 0);
	return out;
}

/**
 * The document MagPi caches. `source` is on the page on purpose: an Arctic Shift
 * answer is a snapshot taken when the archive crawled the thread, so its score
 * and comment count are not today's, and the model has to be able to tell.
 */
export function renderThread(post: RedditPost, comments: FlatComment[], source: "reddit" | "arctic-shift"): string {
	const created = post.created_utc ? new Date(post.created_utc * 1000).toISOString().slice(0, 10) : "";
	const parts = [
		`# ${post.title ?? "(untitled)"}`,
		[
			`r/${post.subreddit ?? "?"}`,
			`${post.score ?? 0} points`,
			`${post.num_comments ?? 0} comments`,
			`u/${post.author ?? "[unknown]"}`,
			created,
		]
			.filter(Boolean)
			.join(" | "),
		post.url && post.is_self === false ? `link: ${post.url}` : "",
		source === "arctic-shift"
			? "source: Arctic Shift archive (snapshot; score/comment count are from crawl time, not now)"
			: "source: reddit",
		"",
		(post.selftext ?? "").trim() || "(link post)",
	];
	for (const c of comments) {
		const indent = c.depth === 0 ? "" : `${"  ".repeat(c.depth)}↳ `;
		parts.push(`\n---\n${indent}**u/${c.author}** (${c.score} points):\n${c.body}`);
	}
	if (comments.length >= MAX_COMMENTS) parts.push(`\n---\n(comment list truncated at ${MAX_COMMENTS})`);
	return parts.filter((p) => p !== "").join("\n");
}

/** The live thread: `[postListing, commentListing]`. Anything else means a redirect to a login/consent page. */
async function redditFromLive(id: string, signal?: AbortSignal): Promise<HandlerResult> {
	const payload = await getJson(`https://www.reddit.com/comments/${id}.json?raw_json=1&limit=${MAX_COMMENTS}`, signal, {
		"user-agent": BROWSER_UA,
	});
	if (!Array.isArray(payload) || payload.length < 2) throw new Error("reddit did not return a thread listing");
	const post = (payload[0] as { data?: { children?: CommentNode[] } })?.data?.children?.[0]?.data as
		| RedditPost
		| undefined;
	if (!post?.title) throw new Error("reddit returned a listing without a post");
	const comments = flattenComments(childrenOf(payload[1]));
	return { kind: "thread", title: post.title, content: renderThread(post, comments, "reddit") };
}

/**
 * Arctic Shift: post body from `/api/posts/ids`, comments from `/api/comments/tree`.
 * `fields` is not used — `permalink` is not selectable there and answers 400, and
 * the saving is irrelevant next to the comment tree.
 */
async function redditFromArchive(id: string, signal?: AbortSignal): Promise<HandlerResult> {
	const headers = { "user-agent": "pi-agent-magpi-handlers/1.0" };
	const postPayload = (await getJson(`${ARCTIC}/api/posts/ids?ids=${id}`, signal, headers)) as { data?: RedditPost[] };
	const post = postPayload?.data?.[0];
	if (!post?.title) throw new Error(`Arctic Shift has no post ${id}`);
	// A thread with no comments in the archive is a normal answer, not a failure.
	let comments: FlatComment[] = [];
	try {
		const tree = (await getJson(`${ARCTIC}/api/comments/tree?link_id=${id}&limit=${MAX_COMMENTS}`, signal, headers)) as {
			data?: CommentNode[];
		};
		comments = flattenComments(Array.isArray(tree?.data) ? tree.data : []);
	} catch {
		// keep the post body; the caller gets a thread without its replies
	}
	return { kind: "thread", title: post.title, content: renderThread(post, comments, "arctic-shift") };
}

export const redditHandler: MagpiHandler = {
	name: "reddit",
	description: "Reddit threads: post + comments via the public JSON endpoint, falling back to the Arctic Shift archive",
	match: (url) => /(^|\.)reddit\.com$/.test(url.hostname) && url.pathname.includes("/comments/"),
	async fetch(url, ctx) {
		const id = postIdFromUrl(url);
		if (!id) throw new Error(`No reddit post id in ${url.href}`);
		try {
			return await redditFromLive(id, ctx.signal);
		} catch (liveErr) {
			try {
				return await redditFromArchive(id, ctx.signal);
			} catch (archiveErr) {
				// Both messages: "403" alone reads like a bug in the handler.
				throw new Error(
					`Could not read reddit thread ${id}: live endpoint failed (${(liveErr as Error).message}), ` +
						`Arctic Shift failed (${(archiveErr as Error).message})`,
				);
			}
		}
	},
};

// ================================================================ discourse

/** Posts rendered from a topic. Discourse threads run to hundreds; the tail is rarely the point. */
const MAX_POSTS = 60;
/** Per-post cap, in characters. */
const MAX_POST_CHARS = 2500;

interface DiscoursePost {
	username?: string;
	name?: string;
	post_number?: number;
	created_at?: string;
	cooked?: string;
}

interface DiscourseTopic {
	title?: string;
	posts_count?: number;
	created_at?: string;
	category_id?: number;
	post_stream?: { posts?: DiscoursePost[] };
}

/**
 * Topic id out of a canonical Discourse URL: `/t/<slug>/<id>`, optionally with a
 * post number (`/t/<slug>/<id>/14`). The slug-less `/t/<id>` form is accepted too.
 */
export function discourseTopicId(url: URL): string | null {
	const m = /^\/t\/(?:[^/]+\/)?(\d+)(?:\/\d+)?\/?$/.exec(url.pathname);
	return m ? m[1] : null;
}

export function renderTopic(topic: DiscourseTopic, host: string): string {
	const posts = (topic.post_stream?.posts ?? []).slice(0, MAX_POSTS);
	const total = topic.posts_count ?? posts.length;
	const lines = [
		`# ${topic.title ?? "(untitled)"}`,
		[host, `${total} posts`, (topic.created_at ?? "").slice(0, 10)].filter(Boolean).join(" | "),
		"",
	];
	for (const post of posts) {
		const who = post.name && post.name !== post.username ? `${post.username} (${post.name})` : (post.username ?? "?");
		const body = htmlToMarkdown(post.cooked ?? "");
		lines.push(
			`\n---\n**#${post.post_number ?? "?"} ${who}** ${(post.created_at ?? "").slice(0, 10)}\n` +
				(body.length > MAX_POST_CHARS ? `${body.slice(0, MAX_POST_CHARS)}…` : body),
		);
	}
	if (total > posts.length) {
		lines.push(`\n---\n(${total - posts.length} further posts not included; cap is ${MAX_POSTS})`);
	}
	return lines.join("\n");
}

/**
 * Matched by URL shape, not by host: Discourse is self-hosted on arbitrary domains
 * and there is no way to know from the URL alone. `/t/<slug>/<number>` is specific
 * enough in practice — NodeBB uses `/topic/<id>/<slug>`, Flarum `/d/<slug>-<id>`,
 * phpBB `viewtopic.php` — and a site that shape-matches without being Discourse
 * gets a clear error rather than a wrong document, since a handler cannot hand the
 * URL back to MagPi's default one.
 */
export const discourseHandler: MagpiHandler = {
	name: "discourse",
	description: "Discourse forum topics: the whole thread via /t/<id>.json, not just the ~20 posts in the crawler HTML",
	match: (url) => discourseTopicId(url) !== null,
	async fetch(url, ctx) {
		const id = discourseTopicId(url);
		if (!id) throw new Error(`No Discourse topic id in ${url.href}`);
		let topic: DiscourseTopic;
		try {
			// print=true returns the whole stream (up to 1000 posts) in one request
			// instead of the 20-post window the topic endpoint gives by default.
			topic = (await getJson(`${url.origin}/t/${id}.json?print=true`, ctx.signal, {
				"user-agent": BROWSER_UA,
			})) as DiscourseTopic;
		} catch (err) {
			throw new Error(
				`${url.href} looks like a Discourse topic but ${url.host} did not answer /t/${id}.json ` +
					`(${(err as Error).message}); if it is not Discourse, this handler should not match it`,
			);
		}
		if (!topic?.post_stream?.posts?.length) throw new Error(`Discourse topic ${id} came back without posts`);
		return { kind: "thread", title: topic.title, content: renderTopic(topic, url.host) };
	},
};

// ================================================================ naver blog

/**
 * `blogId` and `logNo` out of every shape naver uses: the pretty
 * `/<blogId>/<logNo>`, the query form `PostView.naver?blogId=..&logNo=..`, and the
 * `?Redirect=Log&logNo=..` variant.
 */
export function naverPostRef(url: URL): { blogId: string; logNo: string } | null {
	const qBlog = url.searchParams.get("blogId");
	const qLog = url.searchParams.get("logNo");
	if (qBlog && qLog && /^\d+$/.test(qLog)) return { blogId: qBlog, logNo: qLog };
	const segments = url.pathname.split("/").filter(Boolean);
	if (segments.length >= 2 && /^\d+$/.test(segments[1])) return { blogId: segments[0], logNo: segments[1] };
	if (segments.length === 1 && qLog && /^\d+$/.test(qLog)) return { blogId: segments[0], logNo: qLog };
	return null;
}

/**
 * The post container, by editor generation: SmartEditor ONE (`se-main-container`),
 * the older SmartEditor 2 (`postViewArea`), then the mobile wrapper. Falling back
 * to the whole document would drag naver's chrome in, so a miss is an error.
 */
export function naverPostBody(html: string): string | undefined {
	const containers = [
		/<div[^>]+class="[^"]*se-main-container[^"]*"[^>]*>/i,
		/<div[^>]+id="postViewArea"[^>]*>/i,
		/<div[^>]+class="[^"]*post_ct[^"]*"[^>]*>/i,
	];
	for (const pattern of containers) {
		const m = pattern.exec(html);
		if (!m) continue;
		const body = sliceElement(html, m.index);
		if (body?.trim()) return body;
	}
	return undefined;
}

function naverTitle(html: string): string | undefined {
	const raw = firstMatch(html, [
		/<div[^>]+class="[^"]*se-title-text[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
		/<meta\s+property="og:title"\s+content="([^"]*)"/i,
		/<title>([\s\S]*?)<\/title>/i,
	]);
	return raw ? htmlToMarkdown(raw).split("\n")[0] : undefined;
}

/**
 * The desktop host frames the post in an iframe, so MagPi's readability pass
 * returns an empty document (0 bytes, reproduced from this cache). The mobile host
 * serves the same post inline, which is what this reads — for both hosts, so the
 * result does not depend on which URL was pasted.
 */
export const naverBlogHandler: MagpiHandler = {
	name: "naver-blog",
	description: "Naver blog posts via the mobile host, whose HTML is not iframe-wrapped like the desktop one's",
	match: (url) => /(^|\.)blog\.naver\.com$/.test(url.hostname),
	async fetch(url, ctx) {
		const ref = naverPostRef(url);
		if (!ref) throw new Error(`No naver blog post in ${url.href} (expected /<blogId>/<logNo>)`);
		const target = `https://m.blog.naver.com/${ref.blogId}/${ref.logNo}`;
		const html = await getHtml(target, ctx.signal);
		const body = naverPostBody(html);
		if (!body) {
			throw new Error(
				`Could not find the post container in ${target}; naver changed its markup or the post is private`,
			);
		}
		const markdown = htmlToMarkdown(body);
		if (!markdown) throw new Error(`Post container in ${target} held no text`);
		const title = naverTitle(html);
		return {
			kind: "article",
			title,
			content: `${title ? `# ${title}\n\n` : ""}source: ${target}\n\n${markdown}`,
		};
	},
};

// ---------------------------------------------------------------- extension

export const HANDLERS: MagpiHandler[] = [redditHandler, discourseHandler, naverBlogHandler];

export default function (pi: ExtensionAPI) {
	// Emitted twice on purpose. MagPi subscribes while its own extension is
	// activated, and activation order between extensions is not guaranteed, so the
	// immediate emit is a no-op if it has not subscribed yet and session_start is
	// the point where every extension is up. registerHandler() replaces by name, so
	// registering twice is idempotent — and it re-registers after /reload.
	const register = () => {
		for (const handler of HANDLERS) pi.events.emit("magpi:register-handler", handler);
	};
	register();
	pi.on("session_start", async () => {
		register();
		return undefined;
	});
}
