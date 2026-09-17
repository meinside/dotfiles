/**
 * extensions/magpi-handlers.ts holds every local MagPi handler, each of which
 * exists because a site MagPi's built-ins reach returns junk. The behaviour worth
 * pinning is the same for all of them: never hand back an empty or blocked
 * document as a success — MagPi caches whatever a handler returns, for `ttlHours`,
 * and a silent empty thread reads to the model as "this thread says nothing".
 *
 * Also covered: the id/ref parsing every handler starts with, the shapes they read
 * (reddit's `[post, comments]` pair, Arctic Shift's `{data}` envelopes, Discourse's
 * `post_stream`, naver's editor containers) and the small HTML converter they share.
 *
 * No network: `globalThis.fetch` is replaced per test with a table of canned
 * responses, so a case that hits an unexpected URL fails loudly instead of
 * silently going online. `hostResolver` is stubbed for the same reason: the redirect
 * guard resolves each hop's hostname, and a real DNS lookup would slip past a stubbed
 * `fetch`.
 */

import assert from "node:assert/strict";
import test from "node:test";
import * as handlerModule from "../extensions/magpi-handlers.ts";

type Handler = {
	name: string;
	match: (url: URL) => boolean;
	fetch: (url: URL, ctx: { mode: string; entryDir: string; signal?: AbortSignal }) => Promise<{
		kind: string;
		title?: string;
		content: string;
	}>;
};

const {
	redditHandler,
	discourseHandler,
	naverBlogHandler,
	HANDLERS,
	postIdFromUrl,
	flattenComments,
	renderThread,
	discourseTopicId,
	discourseTopicRef,
	isDiscourseHost,
	naverPostRef,
	naverPostBody,
	sliceElement,
	htmlToMarkdown,
	decodeEntities,
	hostResolver,
	isPrivateAddress,
	assertPublicHop,
	fetchGuarded,
} = handlerModule as {
	redditHandler: Handler;
	discourseHandler: Handler;
	naverBlogHandler: Handler;
	HANDLERS: Handler[];
	postIdFromUrl: (url: URL) => string | null;
	flattenComments: (
		children: unknown[],
		max?: number,
	) => Array<{ depth: number; author: string; score: number; body: string }>;
	renderThread: (
		post: Record<string, unknown>,
		comments: Array<{ depth: number; author: string; score: number; body: string }>,
		source: "reddit" | "arctic-shift",
	) => string;
	discourseTopicId: (url: URL) => string | null;
	discourseTopicRef: (url: URL) => { id: string; hasSlug: boolean } | null;
	isDiscourseHost: (hostname: string) => boolean;
	naverPostRef: (url: URL) => { blogId: string; logNo: string } | null;
	naverPostBody: (html: string) => string | undefined;
	sliceElement: (html: string, openTagStart: number) => string | undefined;
	htmlToMarkdown: (html: string) => string;
	decodeEntities: (text: string) => string;
	hostResolver: { addresses: (host: string) => Promise<string[]> };
	isPrivateAddress: (ip: string) => boolean;
	assertPublicHop: (url: URL) => Promise<void>;
	fetchGuarded: (url: string, init?: RequestInit) => Promise<Response>;
};

/** Type stripping leaves the CJS default nested one level deeper (as in guard.test.ts). */
const entry = (handlerModule as { default?: unknown }).default;
const activate = (typeof entry === "function" ? entry : (entry as { default?: unknown })?.default) as (pi: {
	events: { emit: (name: string, payload: unknown) => void };
	on: (name: string, handler: () => Promise<unknown>) => void;
}) => void;

const THREAD = new URL("https://www.reddit.com/r/meshtastic/comments/1bb3yax/what_do_you_use_meshtastic_for/");
const TOPIC = new URL("https://discuss.python.org/t/pep-832-virtual-environment-discovery/106998");
const NAVER = new URL("https://blog.naver.com/zzinddagongdol/223869551743");
const ctx = { mode: "light" as const, entryDir: "/tmp/does-not-matter" };

/**
 * Install a fetch stub. Keys are matched as substrings of the requested URL, so a
 * case names the endpoint it cares about ("reddit.com/comments", "/api/posts/ids")
 * rather than the full query string. A value that is an Error is thrown, mirroring a
 * network failure; a number is served as that HTTP status; a string is served as
 * `text/html` (page handlers) and anything else as JSON. A miss throws.
 */
function stubFetch(routes: Record<string, unknown>): { calls: string[]; restore: () => void } {
	const original = globalThis.fetch;
	const calls: string[] = [];
	globalThis.fetch = (async (input: string | URL) => {
		const url = String(input);
		calls.push(url);
		for (const [needle, value] of Object.entries(routes)) {
			if (!url.includes(needle)) continue;
			if (value instanceof Error) throw value;
			if (typeof value === "function") return (value as () => Response)();
			if (typeof value === "number") return new Response("blocked", { status: value });
			if (typeof value === "string") {
				return new Response(value, { status: 200, headers: { "content-type": "text/html; charset=utf-8" } });
			}
			return new Response(JSON.stringify(value), { status: 200, headers: { "content-type": "application/json" } });
		}
		throw new Error(`test stub has no route for ${url}`);
	}) as typeof fetch;
	return { calls, restore: () => (globalThis.fetch = original) };
}

/**
 * Point every hostname at one public address for the duration of a test.
 *
 * The default applies to the whole file: without it each handler case would make a
 * real DNS query through the guard, which is the one thing the `fetch` stub cannot
 * intercept. A case that cares about resolution passes its own table.
 */
function stubResolver(addresses: Record<string, string[] | Error> = {}): () => void {
	const original = hostResolver.addresses;
	hostResolver.addresses = async (host: string) => {
		const canned = addresses[host];
		if (canned instanceof Error) throw canned;
		return canned ?? ["93.184.216.34"]; // a public address, so an unnamed host passes
	};
	return () => {
		hostResolver.addresses = original;
	};
}

stubResolver();

/** A `location` redirect, for the routes above: `{ "host/path": redirect(302, "https://...") }`. */
const redirect = (status: number, location: string) => () =>
	new Response(null, { status, headers: { location } });

const listing = (children: unknown[]) => ({ data: { children } });
const comment = (author: string, body: string, score = 1, replies: unknown = "") => ({
	kind: "t1",
	data: { author, body, score, replies },
});

// ---------------------------------------------------------------- matching and ids

test("reddit matches thread urls and nothing else", () => {
	for (const href of [
		"https://www.reddit.com/r/meshtastic/comments/1bb3yax/what_do_you_use_meshtastic_for/",
		"https://old.reddit.com/comments/1bb3yax",
		"https://reddit.com/r/x/comments/abcd1/t/",
	]) {
		assert.ok(redditHandler.match(new URL(href)), `${href} should match`);
	}
	for (const href of [
		"https://www.reddit.com/r/meshtastic/", // subreddit listing: the default webpage handler's job
		"https://www.reddit.com/user/spez",
		"https://notreddit.com/r/x/comments/abcd1/t/",
		"https://reddit.com.evil.example/r/x/comments/abcd1/",
	]) {
		assert.ok(!redditHandler.match(new URL(href)), `${href} should not match`);
	}
});

test("post id is read from every thread url shape", () => {
	const cases: Array<[string, string | null]> = [
		["https://www.reddit.com/r/meshtastic/comments/1bb3yax/what_do_you_use_meshtastic_for/", "1bb3yax"],
		["https://www.reddit.com/r/meshtastic/comments/1bb3yax", "1bb3yax"],
		["https://www.reddit.com/comments/1bb3yax/", "1bb3yax"],
		// permalink to one comment inside the thread: still keyed by the post
		["https://www.reddit.com/r/meshtastic/comments/1bb3yax/slug/kucbxwr/", "1bb3yax"],
		["https://www.reddit.com/r/meshtastic/comments/t3_1bb3yax/slug/", "1bb3yax"],
		["https://www.reddit.com/r/meshtastic/comments/", null],
		["https://www.reddit.com/r/meshtastic/s/AbCdEfGh", null],
	];
	for (const [href, expected] of cases) {
		assert.equal(postIdFromUrl(new URL(href)), expected, href);
	}
});

// ---------------------------------------------------------------- comment trees

test("comment tree is flattened depth-first with depth kept", () => {
	const flat = flattenComments([
		comment("a", "top", 5, listing([comment("b", "reply", 2, listing([comment("c", "deep", 1)]))])),
		{ kind: "more", data: { children: ["x", "y"] } },
		comment("d", "second top", 3),
	]);
	assert.deepEqual(
		flat.map((c) => [c.depth, c.author, c.body]),
		[
			[0, "a", "top"],
			[1, "b", "reply"],
			[2, "c", "deep"],
			[0, "d", "second top"],
		],
	);
});

test("flatten drops empty bodies and honours the cap", () => {
	const flat = flattenComments([comment("a", "kept"), comment("b", "   "), comment("c", "also kept")], 2);
	assert.deepEqual(
		flat.map((c) => c.author),
		["a", "c"],
	);
});

// ---------------------------------------------------------------- rendering

test("archive provenance is stated in the document, live is not confused with it", () => {
	const post = { title: "T", subreddit: "meshtastic", author: "u", score: 7, num_comments: 20, selftext: "body" };
	const archived = renderThread(post, [], "arctic-shift");
	assert.match(archived, /^# T$/m);
	assert.match(archived, /r\/meshtastic \| 7 points \| 20 comments \| u\/u/);
	assert.match(archived, /source: Arctic Shift archive \(snapshot/);
	assert.equal(renderThread(post, [], "reddit").includes("Arctic Shift"), false);
	assert.match(renderThread(post, [], "reddit"), /source: reddit/);
});

test("link posts keep their target, self posts do not gain one", () => {
	const base = { title: "T", subreddit: "s", selftext: "" };
	const link = renderThread({ ...base, is_self: false, url: "https://example.com/x" }, [], "reddit");
	assert.match(link, /link: https:\/\/example\.com\/x/);
	const self = renderThread({ ...base, is_self: true, url: "https://reddit.com/self" }, [], "reddit");
	assert.equal(self.includes("link:"), false);
	assert.match(self, /\(link post\)/); // empty selftext still says something
});

// ---------------------------------------------------------------- fetch paths

test("live reddit is preferred and the archive is left alone", async () => {
	const stub = stubFetch({
		"reddit.com/comments": [
			listing([{ kind: "t3", data: { title: "Live title", subreddit: "meshtastic", score: 7, selftext: "live body" } }]),
			listing([comment("alice", "live comment", 4)]),
		],
	});
	try {
		const result = await redditHandler.fetch(THREAD, ctx);
		assert.equal(result.title, "Live title");
		assert.match(result.content, /source: reddit/);
		assert.match(result.content, /\*\*u\/alice\*\* \(4 points\)/);
		assert.equal(
			stub.calls.some((u) => u.includes("arctic-shift")),
			false,
			"archive must not be queried when the live endpoint answers",
		);
	} finally {
		stub.restore();
	}
});

test("a 403 from reddit falls back to the archive instead of failing", async () => {
	const stub = stubFetch({
		"reddit.com/comments": 403,
		"/api/posts/ids": {
			data: [{ title: "Archived title", subreddit: "meshtastic", score: 7, num_comments: 20, selftext: "archived body" }],
		},
		"/api/comments/tree": { data: [comment("bob", "archived comment", 2)] },
	});
	try {
		const result = await redditHandler.fetch(THREAD, ctx);
		assert.equal(result.title, "Archived title");
		assert.match(result.content, /archived body/);
		assert.match(result.content, /\*\*u\/bob\*\* \(2 points\)/);
		assert.match(result.content, /source: Arctic Shift archive/);
	} finally {
		stub.restore();
	}
});

test("a login redirect served as 200 is not accepted as a thread", async () => {
	// What reddit actually does from this network: the JSON path answers with
	// something that is not a [post, comments] pair. The built-in handler turned
	// that page into a 20-byte "Skip to main content" success; this must not.
	const stub = stubFetch({
		"reddit.com/comments": { kind: "Listing", data: { children: [] } },
		"/api/posts/ids": { data: [{ title: "Archived title", subreddit: "s", selftext: "archived body" }] },
		"/api/comments/tree": { data: [] },
	});
	try {
		const result = await redditHandler.fetch(THREAD, ctx);
		assert.match(result.content, /source: Arctic Shift archive/);
		assert.match(result.content, /archived body/);
	} finally {
		stub.restore();
	}
});

test("a thread the archive has not crawled still returns the post body", async () => {
	const stub = stubFetch({
		"reddit.com/comments": 403,
		"/api/posts/ids": { data: [{ title: "Archived title", subreddit: "s", selftext: "archived body" }] },
		"/api/comments/tree": 500,
	});
	try {
		const result = await redditHandler.fetch(THREAD, ctx);
		assert.match(result.content, /archived body/);
		assert.equal(result.content.includes("points):"), false);
	} finally {
		stub.restore();
	}
});

test("both sources failing throws, naming both, and never returns a document", async () => {
	const stub = stubFetch({ "reddit.com/comments": 403, "/api/posts/ids": 429 });
	try {
		await assert.rejects(
			() => redditHandler.fetch(THREAD, ctx),
			(err: Error) => {
				assert.match(err.message, /1bb3yax/);
				assert.match(err.message, /403/);
				assert.match(err.message, /429/);
				return true;
			},
		);
	} finally {
		stub.restore();
	}
});

test("a url without a post id fails before any request", async () => {
	const stub = stubFetch({});
	try {
		const bare = new URL("https://www.reddit.com/comments/");
		await assert.rejects(() => redditHandler.fetch(bare, ctx), /No reddit post id/);
		assert.deepEqual(stub.calls, []);
	} finally {
		stub.restore();
	}
});

// ---------------------------------------------------------------- redirect guard

test("private and public addresses are told apart", () => {
	for (const ip of [
		"127.0.0.1",
		"10.1.2.3",
		"172.16.0.1",
		"172.31.255.255",
		"192.168.1.1",
		"169.254.169.254", // the cloud metadata endpoint this exists for
		"100.64.0.1",
		"0.0.0.0",
		"::1",
		"::",
		"fd00::1",
		"fe80::1",
		"::ffff:127.0.0.1", // v4-mapped loopback
	]) {
		assert.equal(isPrivateAddress(ip), true, `${ip} should be private`);
	}
	for (const ip of ["8.8.8.8", "93.184.216.34", "172.32.0.1", "192.169.0.1", "100.128.0.1", "2606:4700::1111"]) {
		assert.equal(isPrivateAddress(ip), false, `${ip} should be public`);
	}
});

test("a hop to a literal private address is refused before the request is made", async () => {
	const stub = stubFetch({});
	try {
		await assert.rejects(() => fetchGuarded("http://169.254.169.254/latest/meta-data/"), /private address/);
		await assert.rejects(() => fetchGuarded("http://localhost:8080/"), /loopback/);
		await assert.rejects(() => fetchGuarded("file:///etc/passwd"), /only http and https/);
		// Bracketed v6 literals: the host arrives as "[::1]" and has to be unwrapped first.
		await assert.rejects(() => assertPublicHop(new URL("http://[::1]:9200/")), /private address/);
		await assert.doesNotReject(() => assertPublicHop(new URL("https://[2606:4700::1111]/")));
		// Refused means refused: no request was attempted for any of them.
		assert.deepEqual(stub.calls, []);
	} finally {
		stub.restore();
	}
});

test("a redirect into a private address is refused, which fetch's own follow would not do", async () => {
	const stub = stubFetch({ "example.com/post": redirect(302, "http://192.168.0.10/admin") });
	try {
		await assert.rejects(() => fetchGuarded("https://example.com/post"), /192\.168\.0\.10 is a private address/);
		// The first hop was made (it is public); the second never was.
		assert.deepEqual(stub.calls, ["https://example.com/post"]);
	} finally {
		stub.restore();
	}
});

test("a hop whose public name resolves to a private address is refused", async () => {
	const restoreResolver = stubResolver({ "rebind.example": ["127.0.0.1"] });
	const stub = stubFetch({ "example.com/post": redirect(307, "https://rebind.example/inside") });
	try {
		await assert.rejects(
			() => fetchGuarded("https://example.com/post"),
			/rebind\.example resolves to 127\.0\.0\.1/,
		);
		assert.deepEqual(stub.calls, ["https://example.com/post"]);
	} finally {
		stub.restore();
		restoreResolver();
	}
});

test("an ordinary redirect is still followed, relative location included", async () => {
	const stub = stubFetch({
		"example.com/old": redirect(301, "/new"),
		"example.com/new": "<html><body>arrived</body></html>",
	});
	try {
		const res = await fetchGuarded("https://example.com/old");
		assert.equal(res.status, 200);
		assert.match(await res.text(), /arrived/);
		assert.deepEqual(stub.calls, ["https://example.com/old", "https://example.com/new"]);
	} finally {
		stub.restore();
	}
});

test("a redirect loop ends in an error rather than a hang", async () => {
	const stub = stubFetch({ "example.com/loop": redirect(302, "https://example.com/loop") });
	try {
		await assert.rejects(() => fetchGuarded("https://example.com/loop"), /More than 5 redirects/);
		assert.equal(stub.calls.length, 6); // the initial request plus the five hops allowed
	} finally {
		stub.restore();
	}
});

test("a name that does not resolve is left to the request, not refused here", async () => {
	const restoreResolver = stubResolver({ "gone.example": new Error("ENOTFOUND") });
	const stub = stubFetch({ "gone.example": new Error("connect ECONNREFUSED") });
	try {
		// The guard passes it through, so the failure the caller sees is the real one.
		await assert.rejects(() => fetchGuarded("https://gone.example/thing"), /ECONNREFUSED/);
	} finally {
		stub.restore();
		restoreResolver();
	}
});

test("a 3xx without a location is the server's answer, not a hop", async () => {
	const stub = stubFetch({ "example.com/weird": () => new Response("no location here", { status: 302 }) });
	try {
		const res = await fetchGuarded("https://example.com/weird");
		assert.equal(res.status, 302);
	} finally {
		stub.restore();
	}
});

test("the handlers go through the guard, so a redirected page cannot reach localhost", async () => {
	// naver's mobile host answering with a redirect to a private address: the handler
	// must fail, not read whatever is listening there.
	const stub = stubFetch({ "m.blog.naver.com": redirect(302, "http://127.0.0.1:9200/_search") });
	try {
		await assert.rejects(() => naverBlogHandler.fetch(NAVER, ctx), /127\.0\.0\.1 is a private address/);
	} finally {
		stub.restore();
	}
});

// ---------------------------------------------------------------- shared html converter

test("entities are decoded, named and numeric", () => {
	const decoded = decodeEntities("a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39; &#x2764; &nbsp;f");
	assert.equal(decoded, `a & b <c> "d" 'e' ❤  f`);
	// &middot; turned up unconverted in a live naver title, hence the wider table.
	assert.equal(decodeEntities("제조&middot;유통&middot;판매"), "제조·유통·판매");
	// An unknown entity is left alone rather than silently eaten.
	assert.equal(decodeEntities("&frobnicate; &amp;"), "&frobnicate; &");
});

test("html converter keeps structure and drops what an LLM cannot use", () => {
	const md = htmlToMarkdown(
		'<h2>Heading</h2><p>Some <strong>bold</strong> and <a href="https://example.com">a link</a>.</p>' +
			"<ul><li>one</li><li>two</li></ul><pre><code>code()</code></pre>" +
			'<blockquote>quoted</blockquote><p>line<br>break</p><img src="x.png" alt="pic">' +
			"<script>evil()</script><style>.a{}</style>",
	);
	assert.match(md, /^## Heading$/m);
	assert.match(md, /Some \*\*bold\*\* and \[a link\]\(https:\/\/example\.com\)\./);
	assert.match(md, /^- one$/m);
	assert.match(md, /^- two$/m);
	assert.match(md, /```\ncode\(\)\n```/);
	assert.match(md, /^> quoted$/m);
	assert.match(md, /^line\nbreak$/m);
	for (const gone of ["evil()", ".a{}", "x.png", "pic"]) {
		assert.equal(md.includes(gone), false, `${gone} should not survive`);
	}
	// No tag survives. `>` on its own is allowed: it is the blockquote marker above.
	assert.equal(/<\/?[a-z][^>]*>/i.test(md), false, `a tag survived: ${md}`);
});

// ---------------------------------------------------------------- discourse

test("discourse claims a topic on shape plus corroboration, not shape alone", () => {
	for (const href of [
		// A slug: every canonical Discourse url has one, whatever the host.
		"https://discuss.python.org/t/pep-832-virtual-environment-discovery/106998",
		"https://discuss.python.org/t/pep-832-virtual-environment-discovery/106998/14",
		"https://linux.do/t/topic/123456",
		"https://forum.kicad.info/t/some-topic/12345",
		// No slug, but the host names Discourse itself.
		"https://discourse.nixos.org/t/12345/",
		"https://meta.discourse.org/t/1",
		"https://klipper.discourse.group/t/9999",
	]) {
		assert.ok(discourseHandler.match(new URL(href)), `${href} should match`);
	}
	for (const href of [
		// Measured collision: V2EX is a busy forum, is not Discourse, and its topic urls
		// are exactly the slug-less shape. The old shape-only rule claimed them, which
		// made a readable page unreadable — a handler cannot delegate back to MagPi.
		"https://www.v2ex.com/t/1012345",
		"https://www.v2ex.com/t/1012345#reply5",
		"https://example.com/t/12345",
		"https://discuss.python.org/c/ideas/6", // category listing
		"https://discuss.python.org/latest",
		"https://community.nodebb.org/topic/17545/some-slug", // NodeBB
		"https://discuss.flarum.org/d/1234-some-slug", // Flarum
		"https://example.com/t/slug/notanumber",
	]) {
		assert.ok(!discourseHandler.match(new URL(href)), `${href} should not match`);
	}
});

test("the host patterns follow Discourse's own naming, and nothing wider", () => {
	for (const host of [
		"discourse.nixos.org",
		"discuss.python.org",
		"meta.discourse.org",
		"klipper.discourse.group",
		"DISCUSS.EXAMPLE.COM", // case is not a distinction
	]) {
		assert.ok(isDiscourseHost(host), `${host} should read as Discourse`);
	}
	for (const host of [
		"www.v2ex.com",
		"forums.swift.org", // Discourse, but `forums.` is XenForo's and phpBB's too
		"forum.example.com",
		"discourseish.example.com", // prefix must be the whole label
		"notdiscourse.org",
		"example.discourse.group.evil.com", // suffix must be the end
	]) {
		assert.ok(!isDiscourseHost(host), `${host} should not read as Discourse`);
	}
});

test("discourse topic id survives every url shape", () => {
	const cases: Array<[string, string | null]> = [
		["https://discuss.python.org/t/some-slug/106998", "106998"],
		["https://discuss.python.org/t/some-slug/106998/", "106998"],
		["https://discuss.python.org/t/some-slug/106998/42", "106998"],
		["https://discuss.python.org/t/106998", "106998"],
		["https://discuss.python.org/t/some-slug/106998/42/extra", null],
		// A numeric first segment is the topic, never a slug: /t/<id>/<post number>.
		// One regex with an optional leading group reads this the other way round.
		["https://discuss.python.org/t/123/456", "123"],
	];
	for (const [href, expected] of cases) {
		assert.equal(discourseTopicId(new URL(href)), expected, href);
	}
	assert.deepEqual(discourseTopicRef(new URL("https://discuss.python.org/t/123/456")), {
		id: "123",
		hasSlug: false,
	});
	assert.deepEqual(discourseTopicRef(new URL("https://linux.do/t/topic/123456")), {
		id: "123456",
		hasSlug: true,
	});
});

test("discourse reads the whole stream, which is the point of the handler", async () => {
	// The measured failure: the server-rendered HTML MagPi reads carries 18 of 169
	// posts. print=true is what returns the rest, so the request must ask for it.
	const stub = stubFetch({
		"/t/106998.json": {
			title: "PEP 832",
			posts_count: 3,
			created_at: "2026-04-15T22:20:00.000Z",
			post_stream: {
				posts: [
					{
						username: "barry",
						name: "Barry Scott",
						post_number: 1,
						created_at: "2026-04-15T22:20:00.000Z",
						cooked: "<p>first</p>",
					},
					{ username: "pf_moore", post_number: 2, created_at: "2026-04-16T12:09:00.000Z", cooked: "<p>second</p>" },
					{ username: "steve", post_number: 169, created_at: "2026-04-20T08:00:00.000Z", cooked: "<p>last word</p>" },
				],
			},
		},
	});
	try {
		const result = await discourseHandler.fetch(TOPIC, ctx);
		assert.equal(result.title, "PEP 832");
		assert.match(stub.calls[0], /\/t\/106998\.json\?print=true$/);
		assert.match(result.content, /^# PEP 832$/m);
		assert.match(result.content, /discuss\.python\.org \| 3 posts \| 2026-04-15/);
		assert.match(result.content, /\*\*#1 barry \(Barry Scott\)\*\* 2026-04-15/);
		assert.match(result.content, /\*\*#2 pf_moore\*\*/); // no display name: not padded with one
		assert.match(result.content, /last word/);
	} finally {
		stub.restore();
	}
});

test("a shape match that is not discourse says so instead of inventing a document", async () => {
	const stub = stubFetch({ "/t/106998.json": 404 });
	try {
		await assert.rejects(() => discourseHandler.fetch(TOPIC, ctx), (err: Error) => {
			assert.match(err.message, /looks like a Discourse topic/);
			assert.match(err.message, /discuss\.python\.org/);
			assert.match(err.message, /404/);
			return true;
		});
	} finally {
		stub.restore();
	}
});

test("an empty stream is an error, not an empty thread", async () => {
	const stub = stubFetch({ "/t/106998.json": { title: "PEP 832", post_stream: { posts: [] } } });
	try {
		await assert.rejects(() => discourseHandler.fetch(TOPIC, ctx), /came back without posts/);
	} finally {
		stub.restore();
	}
});

// ---------------------------------------------------------------- naver blog

test("naver matches its blog host and reads the post ref from every url shape", () => {
	assert.ok(naverBlogHandler.match(new URL("https://blog.naver.com/zzinddagongdol/223869551743")));
	assert.ok(naverBlogHandler.match(new URL("https://m.blog.naver.com/zzinddagongdol/223869551743")));
	assert.ok(!naverBlogHandler.match(new URL("https://cafe.naver.com/x/123")));
	assert.ok(!naverBlogHandler.match(new URL("https://blog.naver.com.evil.example/a/1")));

	const expected = { blogId: "zzinddagongdol", logNo: "223869551743" };
	for (const href of [
		"https://blog.naver.com/zzinddagongdol/223869551743",
		"https://m.blog.naver.com/zzinddagongdol/223869551743",
		"https://blog.naver.com/PostView.naver?blogId=zzinddagongdol&logNo=223869551743",
		"https://blog.naver.com/zzinddagongdol?Redirect=Log&logNo=223869551743",
	]) {
		assert.deepEqual(naverPostRef(new URL(href)), expected, href);
	}
	assert.equal(naverPostRef(new URL("https://blog.naver.com/zzinddagongdol")), null);
});

test("naver post body is found for both editor generations", () => {
	const one = naverPostBody('<body><div class="se-main-container"><p>new editor</p></div></div></body>');
	assert.match(String(one), /new editor/);
	const two = naverPostBody('<body><div id="postViewArea"><p>old editor</p></div></div></body>');
	assert.match(String(two), /old editor/);
	assert.equal(naverPostBody("<body><p>no container at all</p></body>"), undefined);
});

test("the whole post survives nested components, not just the first one", () => {
	// The bug this pins was found live: SmartEditor wraps every component in its own
	// div, so a non-greedy `...</div>\s*</div>` regex returned 1.1 KB of a post that
	// runs for pages. Silently losing the tail is the failure mode this file is for.
	const html =
		'<html><body><div class="wrap"><div class="se-main-container">' +
		'<div class="se-component"><div class="se-module"><p>first component</p></div></div>' +
		'<div class="se-component"><div class="se-module"><p>middle component</p></div></div>' +
		'<div class="se-component"><div class="se-module"><p>last component</p></div></div>' +
		"</div><footer>naver chrome</footer></div></body></html>";
	const body = String(naverPostBody(html));
	for (const kept of ["first component", "middle component", "last component"]) {
		assert.match(body, new RegExp(kept), `${kept} should survive`);
	}
	// The container ends where it ends: naver's own chrome stays out.
	assert.equal(body.includes("naver chrome"), false);
});

test("unbalanced markup returns the remainder rather than nothing", () => {
	const body = sliceElement('<div class="se-main-container"><p>text with no close</p>', 0);
	assert.match(String(body), /text with no close/);
	assert.equal(sliceElement("<div unterminated", 0), undefined);
});

test("naver is read from the mobile host whichever host was asked for", async () => {
	const html =
		'<html><head><meta property="og:title" content="제목입니다"></head><body>' +
		'<div class="se-main-container"><p>본문 &amp; 내용</p><p>둘째 줄</p></div></div></body></html>';
	const stub = stubFetch({ "m.blog.naver.com": html });
	try {
		const result = await naverBlogHandler.fetch(NAVER, ctx);
		assert.equal(stub.calls.length, 1);
		assert.equal(stub.calls[0], "https://m.blog.naver.com/zzinddagongdol/223869551743");
		assert.equal(result.title, "제목입니다");
		assert.match(result.content, /^# 제목입니다$/m);
		assert.match(result.content, /^source: https:\/\/m\.blog\.naver\.com\//m);
		assert.match(result.content, /본문 & 내용/);
		assert.match(result.content, /둘째 줄/);
	} finally {
		stub.restore();
	}
});

test("naver markup drift is reported, not returned as an empty post", async () => {
	// This is the regression the handler exists for: MagPi's readability pass turned
	// the desktop iframe page into a 0-byte document and called it a success.
	const stub = stubFetch({ "m.blog.naver.com": "<html><body><p>login wall</p></body></html>" });
	try {
		await assert.rejects(() => naverBlogHandler.fetch(NAVER, ctx), /Could not find the post container/);
	} finally {
		stub.restore();
	}
});

test("a post container with markup but no text is an error too", async () => {
	const stub = stubFetch({
		"m.blog.naver.com": '<html><body><div class="se-main-container"><img src="a.png"><br></div></div></body></html>',
	});
	try {
		await assert.rejects(() => naverBlogHandler.fetch(NAVER, ctx), /held no text/);
	} finally {
		stub.restore();
	}
});

// ---------------------------------------------------------------- registration

test("every handler is registered, at load and at session_start", () => {
	const emitted: Array<[string, unknown]> = [];
	const events: Array<[string, () => Promise<unknown>]> = [];
	activate({
		events: { emit: (name, payload) => emitted.push([name, payload]) },
		on: (name, handler) => events.push([name, handler]),
	});
	assert.deepEqual(new Set(emitted.map(([name]) => name)), new Set(["magpi:register-handler"]));
	// Names matter: pi-magpi's registerHandler() replaces a handler with the same
	// name, which is how `reddit` shadows the built-in instead of racing it, and how
	// the new names avoid colliding with one.
	assert.deepEqual(
		emitted.map(([, payload]) => (payload as { name: string }).name),
		["reddit", "discourse", "naver-blog"],
	);
	assert.equal(emitted.length, HANDLERS.length);
	assert.deepEqual(
		events.map(([name]) => name),
		["session_start"],
	);
});

test("no two handlers claim the same url", () => {
	for (const href of [
		"https://www.reddit.com/r/meshtastic/comments/1bb3yax/slug/",
		"https://discuss.python.org/t/some-slug/106998",
		"https://blog.naver.com/zzinddagongdol/223869551743",
	]) {
		const claimed = HANDLERS.filter((h) => h.match(new URL(href))).map((h) => h.name);
		assert.equal(claimed.length, 1, `${href} claimed by ${claimed.join(", ") || "nothing"}`);
	}
});
