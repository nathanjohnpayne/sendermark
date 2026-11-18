---
tags:
  - sendermark
  - prd
  - macos
  - contacts
---
<!--
generated_by: scripts/project-doc-sync.sh
do_not_edit: true
source_repo: nathanjohnpayne/docs
source_path: projects/sendermark/prds/sendermark.md
source_ref: 6a56f25378eebae928fc1970cf3ae183aa0efbc5
project: sendermark
document_class: prd
document_slug: sendermark
sync_direction: central-to-repo
-->

# Sendermark—Product Requirements Document

Version: v0.4
Author: Nathan Payne
Status: Draft
Last updated: November 17, 2026

---

Sendermark keeps the company cards in my Contacts current—a clean, high-resolution logo and every number that company texts from—so business texts in Messages show a name and a logo, and one company is one conversation.

Wordmark: sender|mark
Favicon: s|

**Name (2026-11-17):** renamed from the working title Callsign in v0.2. `callsign.app` has been registered since 2018, and Callsign Inc ships an authentication app under that name—too close to a tool that decides which senders to trust. I registered `sendermark.app` on November 17, 2026, and found no conflicting trademark or App Store listing for the name.

**Interface:** wireframes for the Mac app, in light and dark appearance, are in [sendermark-wireframes.html](sendermark-wireframes.html), in this folder.

**Safety review (v0.4, 2026-11-17):** the write, snapshot, first-logo, sender-identity and privacy contracts were tightened after a review of this document and its tickets. Messages is read from a consistent snapshot; every first logo is approved against the exact image saved; senders are matched on canonical handles; approvals are rechecked when applied; undo reverts Sendermark's changes without overwriting later edits and survives a crash; reply routing is treated as unproven; and local files have a stated privacy lifecycle.

**Logo.dev (2026-11-17):** tested with my publishable key, then with one call to the secret-key API, and the download question is answered—see [Logo.dev: what the test showed](#logodev-what-the-test-showed). Logos saved to a card must come from the secret-key API, not the image CDN. That changes the logo pipeline, the schedule, and the cost.

## Contents

- [What Sendermark is](#what-sendermark-is)
- [The problem](#the-problem)
- [What the manual cards show](#what-the-manual-cards-show)
- [Product goals](#product-goals)
- [What Sendermark is not](#what-sendermark-is-not)
- [Decisions](#decisions)
- [How the platform behaves](#how-the-platform-behaves)
- [Logo.dev: what the test showed](#logodev-what-the-test-showed)
- [Core user stories](#core-user-stories)
- [User flow](#user-flow)
- [Company resolution](#company-resolution)
- [Logo pipeline](#logo-pipeline)
- [Sender discovery and attribution](#sender-discovery-and-attribution)
- [Trust model](#trust-model)
- [Contact write rules](#contact-write-rules)
- [Interface](#interface)
- [Architecture](#architecture)
- [Data model](#data-model)
- [Requirements](#requirements)
- [Success metrics](#success-metrics)
- [Risks](#risks)
- [Open questions](#open-questions)
- [Build plan](#build-plan)
- [Sources](#sources)

## What Sendermark is

A Mac utility that does two jobs against the system Contacts database:

1. **Logos.** Finds every company card, resolves it to a domain, fetches the current logo from Logo.dev, normalizes it for how Contacts and Messages crop avatars, and writes it to the card. Reruns on a schedule and replaces a logo only when the source has changed.
2. **Senders.** Reads my own Messages history, finds the short codes, toll-free numbers, and long codes that businesses text from, attributes each to a company, and proposes adding it to that company's card—creating the card if none exists.

iCloud carries the result to the iPhone, iPad, and Watch. There is no iOS app.

## The problem

Business texts arrive from bare numbers. Vanguard, Chase, and American Express each text from several short codes—one for fraud alerts, another for verification codes, another for appointments or marketing—so Messages shows a stack of unnamed five- and six-digit threads with gray placeholder avatars. Fixing this by hand works: a company card with a logo and all of that company's numbers makes Messages show the name and logo and, in my experience, fold those numbers into one conversation. But doing it by hand means finding a decent logo, cropping it, and noticing each new sender number as it appears. I have done this for a few dozen companies and it does not stay done: logos change, and companies add sender numbers without notice.

## What the manual cards show

Five screenshots of the current manual state (Contacts and Messages on macOS 26, November 17, 2026) set the requirements:

| Observation | Requirement it drives |
|---|---|
| The American Express logo is upscaled and soft; the A.P.C. wordmark runs past both edges of the avatar | Fetch at the largest size available and scale the mark inside a safe area |
| Alliant uses a full lockup with wordmark; Apple uses a mark only | Pick one treatment—the square mark—for every card |
| American Express carries three sender numbers, Apple three, A.P.C. two toll-free numbers, Alliant one | A card must hold any number of senders, of mixed types |
| Sender numbers are labeled `mobile`, `phone`, and `other` with no pattern | Use one label for Sendermark-added senders so they are distinguishable from numbers I added |
| Contacts displays short codes with a hyphen (`228-01`) | Store digits only; never trust display formatting; compare canonical forms, not bare digits |
| One handle on the Apple card is not purely numeric | Store handles exactly as Messages reports them; do not assume digits |
| The Vanguard thread shows order confirmations, transfers, and appointment reminders in one conversation with a logo | This is the target experience |

## Product goals

1. Every company card has a current, correctly cropped logo without my involvement.
2. Every legitimate business sender in my Messages history is attached to exactly one company card.
3. No number reaches a company card unless I approved it.
4. Every change Sendermark makes can be undone.
5. Weekly upkeep takes under five minutes of my attention.

## What Sendermark is not

- **Not an iOS app.** iOS gives third-party apps no access to Messages history, so sender discovery cannot run there. The Mac does the work; iCloud distributes it.
- **Not a spam or phishing filter.** It attributes senders I already receive texts from. It does not judge whether a message is safe.
- **Not a public short-code directory.** The sender map is built from my own history. Sharing or crowdsourcing it is out of scope.
- **Not a manager for people.** Person cards are never read for logos or modified.
- **Not a Messages client.** It never sends, deletes, or modifies messages, and it opens the Messages database read-only.
- **Not for RCS for Business senders.** Those arrive with a carrier-verified name and logo; Sendermark leaves them alone.

## Decisions

These are recommendations, recorded so they can be challenged.

1. **Mac only, native Swift.** `Contacts.framework` is the only supported path that writes contact images and syncs them properly, and the Messages database exists in readable form only on the Mac. A web stack or a script driving Contacts through AppleScript would be slower to build correctly, not faster.
2. **My own Messages history is the source of truth for senders—not a registry.** The U.S. Short Code Registry has a web lookup but, as far as I can find, no public API, and it does not cover toll-free or ten-digit senders at all. The numbers that matter are, by definition, the ones that have texted me. Outside sources corroborate; they do not attribute (decision 8).
3. **A card's first logo is reviewed once; numbers require approval every time (revised in v0.4).** The original ask was for both to be automatic. A wrong logo is cosmetic and reversible, so it gets one review: the first logo on any card—one that has a photo, one that has none, or one Sendermark creates—is approved against the exact image that will be saved. Whether a later change to an approved logo applies without review is an open question. A wrong number is not: attaching a scammer's number to the Chase card gives every future text from it the Chase name, the Chase logo, a place in the trusted Chase conversation, and—with Screen Unknown Senders on—a promotion from the Unknown Senders folder to the main inbox with notifications. Sendermark automates discovery and evidence; I make the call.
4. **Square mark, not lockup.** One treatment for every card. Wordmarks are illegible at avatar size.
5. **Deterministic attribution first; no message text leaves the Mac in v1.** Business texts contain verification codes, balances, and account suffixes. Sender prefixes and link domains attribute most senders without a model. An LLM pass is P1 and off by default. Redacting digit runs does not remove names, email addresses, link tokens, or every code, so the pass stays off until an outgoing-data policy says exactly what may leave the Mac.
6. **Start as a CLI; add the Mac app second.** The risky parts are platform behavior, not interface. The CLI proves them in days. Scheduled, unattended runs wait for the app bundle, because macOS privacy permissions for a bare binary launched by `launchd` are awkward. The app is designed now so that the CLI's `review` output follows the same order as the app's review screen (see [Interface](#interface)).
7. **Saved logos come from the Logo.dev API; the CDN is for previews (added in v0.3).** Logo.dev licenses storing only what its secret-key API returns. So every image written to a card is fetched through the API at up to 2¢ a company, and the image CDN is used only to show logos on screen. Because each check costs credit and the free plan cannot buy more, logos are checked monthly and senders weekly.
8. **Outside lookups are supporting evidence only (added in v0.2).** There is no API that maps a sender to a company. Twilio Lookup can say whether a toll-free or ten-digit number is a real toll-free line or a disposable internet number, and sometimes return a caller name; that is enough to strengthen or block a proposal, never enough to make one. It is P1, off by default, and sends only the phone number. Short codes get a link to the official registry lookup, opened in the browser—no scraping of third-party directories.

## How the platform behaves

Facts the design depends on. Sources are listed at the end.

- **Identity in Messages comes from Contacts.** A sender whose handle matches a number on a card shows that card's name and photo. Cards marked as a company render with a rounded-square avatar in Messages on macOS 26.
- **Conversation merging is undocumented.** My manual cards show several numbers on one card appearing as one conversation. Apple Community threads report the same since iOS 13, but Apple documents no such feature and other sources say it does not exist. Sendermark's second goal depends on this, so it was the first thing verified: on November 17, 2026, the American Express card's three short codes showed as one conversation on macOS 27.2.1 and on iOS 27.2.1. Messages still stores one chat per short code in `chat.db`; the merging happens when it displays them.
- **Reply routing in a merged conversation is not established.** The same community reports say a reply of `STOP` or `1` goes to whichever number texted last. That is tested in Phase 0 with senders mixed; until it is shown, Sendermark does not promise that a reply reaches the intended number, and review warns before a number joins a card that already has another sender. Messages does not show which number a reply will go to. The four replies in my Amex history each went to the most recent sender, but that sender also held nearly all the history, so they do not prove the rule.
- **iCloud limits.** A contact photo may be at most 224 KB and a whole card 256 KB; JPEG, PNG, BMP, and GIF are accepted. One third-party developer reports that editing more than 15–20 contacts within a few minutes can trigger iCloud throttling.
- **Logo.dev** has two services with different rules: an image CDN for display, called with a publishable key, and an API for files you may keep, called with a secret key. Details and test results are in the next section.
- **Messages history** is a SQLite database at `~/Library/Messages/chat.db`. Reading it requires Full Disk Access for the reading process. The `handle` table holds sender identifiers. Message text is sometimes only in the `attributedBody` blob rather than the `text` column.
- **Short codes** are leased through the registry CTIA administers (operated by GCH Technologies since January 1, 2026) and vetted annually. Texting `HELP` to a short code returns the registered company name. Toll-free and ten-digit senders have no comparable public lookup.
- **Twilio Lookup** is pay-per-query with no monthly minimum: Line Type Intelligence (mobile, landline, fixed or non-fixed VoIP, toll-free) is $0.008 a request, and caller name is $0.01 a request for U.S. numbers only. Both on one number cost $0.018; 200 numbers checked once cost about $3.60. Caller name is voice caller-ID data, so coverage of numbers that only send texts will be patchy. It takes full phone numbers and is not expected to accept short codes (untested).
- **RCS for Business** has been reaching iPhone since iOS 18.1 on supported carriers, with verified sender names and logos. It will erode this problem over time, but only for brands that migrate; verification codes and alerts still overwhelmingly arrive as SMS.
- **Screen Unknown Senders** (iOS 26, opt-in) treats any sender saved in Contacts as known. Sendermark therefore improves delivery of wanted business texts as a side effect—and raises the cost of a wrong attribution.

## Logo.dev: what the test showed

Tested November 17, 2026, with my publishable key against the image CDN. The secret-key API was called once the same day, for `americanexpress.com`; see [What the API returned](#what-the-api-returned).

### The download question

**Can Sendermark save a Logo.dev logo into a contact card? Yes, but only a logo fetched through the secret-key API—not one fetched from the CDN.**

- **Technically** nothing stops it. The CDN returns an ordinary 800×800 PNG that can be written to disk.
- **Under Logo.dev's rules** the CDN is for display. Its self-hosting page says every plan may store the images the API returns, and says not to download from the CDN to build your own copy. Its pricing page says the same of API results.
- **The API call** is `GET https://api.logo.dev/v2/brands/logo?domain=<domain>` with `Authorization: Bearer <secret key>`. It returns a temporary download URL (valid about 24 hours), an `etag` that identifies the version, and the source image's dimensions and format. `size`, `format`, and `theme` go on the download URL. The download URL is itself on the CDN host, `img.logo.dev`, so the rule is about where a URL came from, not its host: save only from the URL the API returned.
- **Cost.** Logo.dev's docs say 2 credits (2¢) a lookup, billed once per domain per 24 hours. The one call made reported `credits-charged: 1` in its response headers; the dashboard has not been read to see which is billed, so the figures here keep 2¢ as the upper bound. A 404 or a 202 is free, and so is the download itself. The free plan includes $5 of credit a month—about 250 lookups—and cannot buy more; it must upgrade first. Logo-change webhooks are not on the free plan.
- **For 62 company cards** a full check costs at most $1.24. Monthly fits the free plan; weekly ($5.33 a month) does not.
- **Conflicting copies of the docs exist.** Third-party summaries and an older copy of the docs say self-hosting needs a Pro or Enterprise plan. The current self-hosting and pricing pages say every plan. I am going by the current pages; I am not a lawyer, and a one-line email to Logo.dev would settle it.

### What the CDN returned

| Check | Result |
|---|---|
| 19 real domains at `size=800&format=png` | All returned 800×800 PNG, 26–211 KB, in under a second |
| Size cap | A request for 1600 returned 800 |
| Formats | `jpg`, `png`, `webp` all work; an 800 px JPEG of the same logo was 65 KB against 84 KB for PNG |
| Cache header | `Cache-Control: max-age=86400` (24 hours) |
| Background | 16 of 19 were opaque square tiles, full-bleed colour or with their own margin; 3 had transparent backgrounds |
| iCloud limit | All 19 were under the 224 KB photo limit; one (211 KB) was over my 200 KB target |
| Unknown domain | Status 202 and a generated monogram; with `fallback=404`, status 404 |
| `redirect=404` | Returned 404 for `alliantcreditunion.com` (which redirects to `.org`) and for `apc.com` |
| Quality | One of 19 (`elanfinancialservices.com`) came back as an enlarged fragment of a logo |

### What the API returned

One lookup, for `americanexpress.com`, returned HTTP 200. Everything is nested under `data`, with a separate `metadata` object.

| Field | Type | Value seen |
|---|---|---|
| `data.object`, `data.kind` | string | `image`, `logo` |
| `data.brand_id` | string | `brand_` plus 26 characters |
| `data.status` | string | `ready` |
| `data.url` | string | The temporary download URL: `https://img.logo.dev/assets/<opaque token>`, with no query string |
| `data.etag` | string | 64 hex characters |
| `data.blurhash` | string | 36 characters |
| `data.source.width`, `data.source.height` | integer | 200, 200 |
| `data.source.format` | string | `jpg` |
| `data.source.has_transparency`, `data.source.is_vector` | boolean | false, false |
| `data.last_updated_at` | string, ISO 8601 with offset | 2024-08-28 |
| `data.expires_at` | string, ISO 8601 UTC | About 24.4 hours after the call |
| `metadata.request_id` | string | `request_` plus 26 characters |
| `metadata.resolution` | object | `type` `domain`, `value` the domain, `method` `direct`, `context` empty |

| Check | Result |
|---|---|
| The download URL as returned | 128×128 JPEG, 11 KB |
| The download URL with `?size=800&format=png` | 800×800 PNG, no alpha channel, 187 KB |
| Source image | 200×200 JPEG, so the 800×800 PNG is a four-times upscale; the quality gate in the [logo pipeline](#logo-pipeline) would hold this logo as "Needs a look" |
| Credit | `credits-charged: 1` on the lookup; no charge header on either download |
| Rate limit | `ratelimit-limit: 100`, `ratelimit-reset: 60`: 100 requests per 60 seconds |

### Where it returned the wrong company

| Lookup | Returned |
|---|---|
| Domain `apc.fr` | A.P.C., the clothing brand—correct |
| Domain `apc.com` | Schneider Electric |
| Name "A.P.C." | An unrelated mark |
| Name "APC" | A.P.C., the clothing brand |
| Name "Chase" | A JPMorgan Chase & Co. wordmark, not the Chase mark |
| Name "Alliant" | Alliant Insurance Services (`alliant.com`), not the credit union |
| Domain `lendingclub.com` | A mark reading "happen—Part of Accenture", which looks like a different company |

Three conclusions follow. Lookup by name cannot choose a logo. A correct domain usually, but not always, returns the right logo, so a person has to see each logo once. And the logos arrive as finished square tiles, so the 70 percent shrink that v0.1 planned would have made most of them worse.

## Core user stories

- As the owner of a few hundred contacts, I want every company card to carry a sharp, current logo so that business threads are recognizable at a glance.
- As someone who gets texts from a new short code, I want Sendermark to tell me which company it belongs to and show me why, so that I can approve it in one keystroke.
- As someone who gets texts from a company with no card, I want Sendermark to offer to create the card with the right name, domain, logo, and number.
- As someone cautious about phishing, I want numbers that are easy to spoof held to a higher bar than short codes, so that a convincing scam text cannot inherit a bank's identity.
- As someone who has hand-tuned some cards, I want Sendermark to leave any photo I set myself alone.
- As someone who makes mistakes, I want to revert any run, or any single change, without losing anything I have edited since.

## User flow

1. **Scan.** `sendermark scan` reads Contacts and the Messages database and writes nothing. Output: company cards found, domains resolved or ambiguous, logo status per card, and a list of unattributed business senders with message counts.
2. **Resolve.** For each company card without a confident domain, Sendermark shows candidates and I pick one. The answer is saved to the card's URL field and never asked again.
3. **Apply logos.** `sendermark logos --apply` writes normalized logos to resolved cards. A card's first logo needs my approval on the contact sheet; a summary lists what changed.
4. **Review senders.** `sendermark review` walks the proposal queue. Each proposal shows the handle, its type, the proposed company, message count, first and last seen, two redacted sample messages, and the evidence. Short-code proposals include a link to the official registry lookup. Keys: approve, reject, reassign, skip, mark as shared sender.
5. **Apply senders.** Approved proposals are written to cards; new cards are created where needed.
6. **Maintain.** A weekly run looks for new senders and signals only if proposals are waiting. A monthly run checks every company's logo and replaces the ones that changed.

## Company resolution

A card is a company when its contact type is organization, or when it has an organization name and no given or family name.

The domain is the durable key for a company. Resolution order:

1. A URL already on the card.
2. The domain of an email address on the card, excluding consumer mail domains.
3. Logo.dev name lookup, as a suggestion requiring confirmation. While resolving, `redirect=404` flags a domain that only redirects elsewhere, so the canonical domain is the one stored.

Name lookup is never trusted alone, and the test bore that out: "A.P.C." by name returned an unrelated mark, `apc.com` returned Schneider Electric, and "Alliant" returned the insurance broker rather than the credit union. A wrong domain produces a confident, wrong logo.

Once confirmed, the domain is written to the card's URL field, so the card itself carries the key and the answer survives a lost state file.

Likely duplicates ("Chase" and "Chase Bank" resolving to one domain) are reported, not merged. Merging cards is my job in v1.

## Logo pipeline

Revised in v0.3 after the Logo.dev test, and in v0.4 so that every first logo is reviewed against the exact image saved.

1. **Look up** the logo through the API by domain. A 404 means no logo: leave the card alone and report it. A 202 means the brand is still being indexed: retry after 30 seconds, for at most five minutes. A 402 means the month's credit is spent: stop the check and say so.
2. **Gate on quality.** If the source image the API reports is a small raster—below 256 px on its short side, a threshold to tune—hold the logo as "Needs a look" instead of applying it.
3. **Download** from the temporary URL the API returned, adding `size=800&format=png`; without them it returns a 128×128 JPEG. That URL is on the CDN host, so the test is where the URL came from: never save an image from a URL built with the publishable key.
4. **Normalize** only where needed:
   - Leave an opaque square tile as delivered. Most arrive finished, and shrinking them makes them worse.
   - Flatten a transparent logo onto white, or onto black when the mark itself is light.
   - Add padding only when the mark touches the edge of the canvas, so that the circle crop Contacts uses cannot clip it. A square survives a circle crop at 1/√2 (about 70.7 percent) of the diameter.
   - Re-encode until the file is under 200 KB, leaving margin below iCloud's 224 KB limit.
5. **Compare.** Store the `etag`. On later checks, an unchanged `etag` means no download and no write.
6. **Respect manual photos.** If the card's current photo does not match the hash Sendermark last wrote, I changed it. Skip the card, flag it once, and offer `--take-over` for that card.
7. **Review every first logo.** No card receives its first Sendermark logo without my approval, whether it already has a photo, has none, or was just created. A before-and-after contact sheet shows the exact normalized image that will be saved, fetched through the API, and I approve in bulk or per card. Each approval is bound to that image's hash; if the image differs at write time, nothing is written and the card returns to the sheet. This is the one moment every logo is seen by a person, which is the only defence against a right domain returning the wrong company's mark.
8. **Report a bad logo.** A wrong or poor logo can be flagged to Logo.dev through its free flag endpoint.

On-screen previews—candidate logos during domain resolution, the before-and-after sheet—load from the CDN with the publishable key and are not saved.

## Sender discovery and attribution

**Candidates.** Every handle in the Messages database that has sent me a message and is one of: short code (five or six digits), toll-free number, ten-digit long code not matching a person card, or a non-numeric sender ID. Handles already on a company card are confirmed, not re-proposed.

**Handles.** Each handle keeps its raw form, exactly as Messages reports it, and gains a canonical form: E.164 for a number with a country code, the same for a number without one only when Messages records its region, and digits plus region for a short code, because one short code in two countries is two senders. Two handles are the same sender only when their canonical forms match; bare digits do not show that `+1 415…` and `415…` are one number. Only SMS handles are candidates. Numbers on person cards are excluded through an index that holds those numbers and nothing else from the cards. A handle that cannot be made canonical is skipped and reported, never guessed.

**Signals**, in order of weight:

1. **Seed map.** A hand-maintained file in the repository mapping known handles to domains, seeded from the cards I have already built by hand.
2. **Link domains.** The registrable domain of URLs in the sender's messages (`vanguard.com`). Link shorteners are ignored, not treated as a match.
3. **Sender prefix.** A consistent leading brand string ("Vanguard Msg:", "Chase Sapphire Preferred Visa:").
4. **Company name in body**, matched against existing company cards.
5. **Volume and history.** Number of messages and the span between first and last. Supporting evidence only.

**Shared senders.** Some short codes send verification codes for many unrelated brands. If a handle's messages name two or more distinct brands, Sendermark marks it shared and never proposes it for a company card.

**Reassignment.** Short codes are leased and can change hands. If a confirmed sender starts producing signals for a different company, Sendermark proposes removing it from the old card rather than silently moving it.

**No attribution.** A sender with no signal stays in an "unattributed" list. Sendermark does not guess.

## Trust model

| Sender type | Spoofing and acquisition risk | Rule in v1 |
|---|---|---|
| Short code | Leased, carrier-vetted, expensive | Proposed on one strong signal; batch approval allowed |
| Toll-free number | Cheap to obtain; verification is light | Proposed only with a link-domain match or seed-map entry, plus at least three messages over at least seven days; approved one at a time. Twilio Lookup result shown when enabled; a non-fixed VoIP line type blocks the proposal |
| Ten-digit long code | Cheap and disposable; the main smishing channel | Same bar as toll-free; proposal carries a visible warning |
| Email address or iMessage sender | Trivially spoofable identity | Never proposed |
| Any sender whose link domains conflict with the proposed company | — | Never proposed; listed as suspicious |

Nothing is written without approval in v1. An approval is a decision about the evidence and the destination I saw, so it is bound to both. Before a number is written, Sendermark rechecks the evidence, the destination card, and whether the number has since appeared on another card; anything that changed goes back to review. Brand names and links in a message are signals, not proof of who sent it. Auto-approval for short codes with a seed-map match is a P2 option, to be considered only after a month with zero reverts.

## Contact write rules

- Write only to the default, writable container. That is not necessarily iCloud, and a contact linked across accounts has more than one underlying identifier; both are tested on my real store in Phase 0 before stored identifiers are relied on. Skip read-only directories.
- Mark created cards as organizations. Set the organization name, the URL, the logo, and the sender numbers—nothing else.
- Add sender numbers with one custom label, `text alerts`. Never remove or relabel a number I added.
- Store handles as digits only for numeric senders; store non-numeric handles verbatim.
- Do not use the card's Notes field. Reading and writing notes requires a special entitlement, and it is my space.
- Before the first write ever, export all contacts to a dated `.vcf` backup.
- Journal every write with the card's prior state, including the prior image, so that `sendermark undo <run>` and `sendermark undo <change>` can reverse it. Undo reverts the fields Sendermark changed and leaves every later edit alone; where one of those fields has been edited since, it reports the conflict instead of overwriting. It does not promise the whole card back byte for byte: whether Contacts returns an image exactly as written is still being tested.
- Contacts and the journal cannot commit as one transaction. Each write is journaled as prepared before the save and as applied only after the card is read back. At every start, before any write, rows left prepared by a crash are resolved by reading the card; one that matches neither state is reported and left alone.
- Batch writes—no more than 15 cards per minute—to stay clear of iCloud throttling.

## Interface

Wireframes: [plans/sendermark-wireframes.html](https://github.com/nathanjohnpayne/sendermark/blob/main/plans/sendermark-wireframes.html) in `nathanjohnpayne/sendermark`. Open the file from disk; it is self-contained.

The app has two surfaces—a main window and a menu-bar popover—and seven screens:

| Screen | Job |
|---|---|
| Review | One sender, its evidence, one decision. Queue sorted into ready to approve, needs a judgement, and held back |
| Companies | Every company card with its logo status; the first-run sheet for replacing existing photos |
| Company page | The logo in both crops with the crop guides; the website; the numbers on the card |
| Senders | Every number that has texted me and what Sendermark concluded about it |
| Activity | Every change, each with Undo; each run can be undone whole |
| Settings | Weekly sender scan, monthly logo check, Logo.dev keys, the two off-by-default lookups, backup, access |
| First run | Contacts access, Full Disk Access, key, backup—then a scan that changes nothing |

Every frame is drawn in light and dark appearance. Companies in the frames are real, and their logos load live from Logo.dev's CDN when a publishable key is pasted into the file's Logos control; no key or logo is stored in the file. The wireframes add eleven design decisions (D-01 to D-11) and seven open questions (Q-01 to Q-07), listed at the end of that file. The one that changes this document: risk changes the controls, not only the colour—short codes can be batch-approved, toll-free and ten-digit numbers cannot, and a suspicious sender has no add button at all.

## Architecture

```
sendermark (CLI) ─┐
                 ├─ SendermarkCore (Swift package)
Sendermark.app ─┘     ├─ ContactsStore    Contacts.framework, read and write
(Mac app, P1)         ├─ MessagesReader   chat.db snapshot, read-only SQLite
                      ├─ LogoClient       Logo.dev API (saved logos) and CDN (previews)
                      ├─ LogoNormalizer   Core Graphics
                      ├─ Attribution      signals, scoring, shared-sender detection
                      ├─ PhoneLookup      Twilio Lookup, optional (P1)
                      └─ State            SQLite: resolutions, proposals, journal
```

- **Messages access.** Take a consistent snapshot of `chat.db` and query the snapshot: SQLite's online backup API from a read-only connection, or an atomic filesystem snapshot. Do not copy the database and its `-wal` and `-shm` files separately, because Messages can write or checkpoint between the copies. The rule is not to modify or disrupt Messages: open the live database read-only, never write or checkpoint it, and bound every wait so that a busy database ends the run instead of blocking Messages. The snapshot is tested while Messages is receiving.
- **Permissions.** Contacts access and Full Disk Access. In the CLI phase both are granted to the terminal. The app bundle carries its own usage descriptions and its own grants, which is what makes scheduled runs workable.
- **Secrets.** The Logo.dev secret and publishable keys and, when enabled, the Twilio credentials live in the Keychain, never in the repository or the state file.
- **State.** `~/Library/Application Support/Sendermark/`: `state.sqlite`, `logo-cache/`, `backups/`. Contact identifiers are local to this Mac, which is acceptable because the Mac is the only writer.
- **Network.** Logo.dev, and Twilio Lookup when I turn it on. No analytics, no telemetry.
- **Privacy lifecycle.** Sendermark's directory is private to my account (mode 0700, files 0600). A Messages snapshot lives only for the run that made it, and leftovers from an interrupted run are deleted at the next start. The state file keeps no message text beyond the redacted samples that review shows, and drops those when the proposal is decided. Backups and journal images have a stated retention, and nothing is deleted while a change that depends on it can still be undone. Logs carry no message text, no contact name, and no full handle.

## Data model

| Table | Key fields |
|---|---|
| `company` | contact identifier, organization name, domain, resolution source, confirmed at |
| `logo` | contact identifier, brand id, etag, written hash, written at, last checked, status (current, missing, manual, needs a look, pending) |
| `sender` | handle, type (short code, toll-free, long code, other), first seen, last seen, message count, status (confirmed, proposed, rejected, shared, suspicious, unattributed) |
| `proposal` | handle, proposed domain, signals as JSON, confidence, decision, decided at |
| `journal` | run ID, change ID, contact identifier, operation, before-state vCard, after-state hash, timestamp |

## Requirements

### P0—must have

- **Scan without writing.** `sendermark scan` produces the full report and changes nothing.
  - [ ] Running scan twice with no intervening changes produces identical output.
  - [ ] Contacts and Messages modification dates are unchanged after a scan.
- **Domain resolution with confirmation.**
  - [ ] A card with a URL resolves without a prompt.
  - [ ] A card resolved by name lookup is never written until I confirm the domain.
  - [ ] The confirmed domain appears in the card's URL field on the iPhone after sync.
- **Logo fetch, normalize, write.**
  - [ ] Every written image is square, opaque, and under 200 KB.
  - [ ] No monogram or 404 result is ever written.
  - [ ] Every image written to a card was downloaded through the secret-key API; no CDN image is ever saved.
  - [ ] A full logo check makes at most one lookup per company and stops with a clear message when credit runs out.
  - [ ] A logo whose source is below the quality threshold is held as "Needs a look" and not written.
  - [ ] A transparent logo is flattened; an opaque tile is written as delivered.
  - [ ] No mark is clipped by the circular list avatar or the rounded-square Messages avatar on Mac and iPhone.
  - [ ] A second run with no upstream change performs zero writes.
  - [ ] A card whose photo I changed by hand is skipped and reported.
- **Sender discovery and proposals.**
  - [ ] Every handle that has texted me and is not on a card appears as proposed, shared, suspicious, or unattributed.
  - [ ] Each proposal shows its evidence and two sample messages with digit runs of four or more redacted.
  - [ ] A handle naming two or more brands is never proposed for a company card.
  - [ ] Toll-free and long-code proposals cannot be batch-approved.
  - [ ] Each short-code proposal links to the official Short Code Registry lookup; Sendermark makes no request to it.
- **Apply with approval.**
  - [ ] No phone number is written to any card without an explicit approval recorded in `proposal`.
  - [ ] Approving a sender for a company with no card creates an organization card with name, URL, logo, and number.
- **Backup, journal, undo.**
  - [ ] The first applying run refuses to proceed until a `.vcf` backup exists.
  - [ ] `sendermark undo <run>` reverts every change the run made, including the previous image, and overwrites no later edit.
  - [ ] After a crash at any point in a write, every change that reached Contacts can still be undone.

### P1—should have

- Mac app (main window and menu-bar item) per the wireframes: review queue, before-and-after logo sheet, and a weekly scheduled run that signals only when proposals are waiting.
- Twilio Lookup for toll-free and ten-digit proposals, off by default.
  - [ ] Only the phone number is sent; each number is looked up once and the result cached.
  - [ ] Line type and caller name appear as an evidence row and never create a proposal alone.
  - [ ] A non-fixed VoIP line type moves the sender to suspicious.
  - [ ] Short codes are never sent to the lookup.
- A "Sendermark" contact list containing every managed card.
- LLM attribution for unattributed senders, off by default and not built until the outgoing-data policy is decided, with the model's reasoning shown as evidence.
- Reassignment detection for senders whose signals change company.
- Duplicate-company report with a guided merge.
- Dark-mode-aware logo choice where Logo.dev offers a variant.

### P2—could have

- Auto-approval for short codes that match the seed map.
- Email sender avatars for Mail, using the same company cards.
- Export of the seed map as a shareable vCard pack.
- A second logo provider as fallback for domains Logo.dev lacks.

## Success metrics

| Metric | Target | When |
|---|---|---|
| Company cards with a Sendermark-managed or deliberately manual logo | 95 percent or more | After first full run |
| Business SMS threads from the last 90 days showing a name and logo | 90 percent or more | 30 days in |
| Wrong attributions applied (measured as sender reverts) | Zero | Ongoing |
| Weekly review time | Under five minutes | From week two |
| iCloud sync errors or throttling events caused by a run | Zero | Ongoing |
| Hand edits to company logos after adoption | Fewer than one a month | 90 days in |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Conversation merging is undocumented and may not behave the same on every OS version, or may change | Half the value proposition | Verified in Phase 0 on macOS 27.2.1 and iOS 27.2.1; check again after each major OS release, and if it stops, ship logos and names only and say so |
| A scam sender is attached to a trusted card | Phishing texts inherit a bank's identity and bypass unknown-sender screening | Approval for every number; higher bar for toll-free and long codes; conflicting link domains block a proposal |
| Wrong domain yields a wrong logo | Confident, wrong branding | Name lookup always needs confirmation; domain stored on the card |
| Logo.dev credit runs out—the free plan has $5 a month and cannot buy more | Logo checks stop until the month renews | Monthly checks ($1.24 for 62 companies); stop cleanly on a 402; move to the Startup plan if the list passes about 250 companies |
| A correct domain returns a poor or wrong logo | Confident, wrong branding | Quality gate on the source image; every first logo approved against the exact image saved; flag bad logos to Logo.dev |
| Bulk writes trigger iCloud throttling or sync conflicts | Stalled or duplicated cards | Rate-limit writes; `.vcf` backup; journal and undo |
| Apple changes the Messages database schema | Sender discovery breaks | Isolate all queries in one module; fail closed with a clear error; logos keep working |
| Full Disk Access is a broad grant for a small utility | Larger blast radius if the tool misbehaves | Read-only snapshot access; no network calls except Logo.dev and the optional phone lookup; open source for my own review |
| RCS for Business makes this unnecessary | Shrinking payoff | Accept it. SMS short codes will persist for years, and the logo half is independent of messaging |
| A leased short code changes hands | Stale attribution | Reassignment detection (P1); last-seen dates in the report |

## Open questions

- [x] **Legal/terms.** Does Logo.dev permit saving a logo into a contact card? Yes, through the secret-key API on any plan; not from the CDN. See [Logo.dev: what the test showed](#logodev-what-the-test-showed).
- [x] **Blocking—platform.** Call the secret-key logo endpoint once and confirm the response shape, the size of the source images, and the credit charge. Run on November 17, 2026; see [What the API returned](#what-the-api-returned). The header reported 1 credit where the docs say 2; the dashboard has not been read.
- [x] **Blocking—platform.** Does one card with several sender numbers produce one conversation on current macOS and iOS, for SMS short codes specifically? Yes: the American Express card's three short codes show as one conversation on macOS 27.2.1 and iOS 27.2.1, checked November 17, 2026.
- [ ] **Platform.** Does writing `imageData` through `Contacts.framework` preserve the image as written, or does Contacts re-crop or recompress it?
- [ ] **Platform.** Which number does a reply go to in a merged conversation when the most recent sender is not the one with the most history?
- [ ] **Platform.** Which container is my default, which identifier does a linked contact report, and does an identifier survive an edit, a sync, a merge, or a delete and re-create?
- [ ] **Product.** When an approved logo changes at the source, is the new one applied and listed, or held for review? Is the answer the same for an unattended run?
- [ ] **Product.** What is the outgoing-data policy for the LLM pass: what is removed, what is sent at all, and which providers are acceptable?
- [ ] **Product.** Should the label be `text alerts` for every sender, or should Sendermark label by purpose (verification, fraud, marketing)? Purpose labels are nicer and add a classification problem.
- [ ] **Product.** Should shared verification senders get a generic "Verification codes" card, or stay bare?
- [x] **Product.** Register `sendermark.app`, and check trademarks and the App Store for the name before anything is published. Registered November 17, 2026; no conflict found.
- [ ] **Engineering.** How does the app bundle obtain Full Disk Access cleanly for a scheduled run, and is a Developer ID signature needed for the grant to persist across builds?
- [ ] **Engineering.** How much of my history has message text only in `attributedBody`, and is a decoder needed in P0?

## Build plan

**Phase 0—prove the platform (one to two days).** No product code. Answer the two blocking questions (the merge check and one call to the Logo.dev API), write one normalized logo to one card through `Contacts.framework` and check it on the Mac and the iPhone, test which number a reply goes to when senders are mixed, test my real contact containers and identifiers, and dump the top 50 unattached business handles from `chat.db` with counts. If merging fails, cut the "one conversation" goal before building anything.

**Phase 1—CLI, logos (about a week).** `scan`, domain resolution, logo pipeline, backup, journal, undo. Ship when every company card has a correct logo.

**Phase 2—CLI, senders (about a week).** Discovery, signals, seed map built from existing cards, `review`, apply, card creation.

**Phase 3—Mac app.** Built from the wireframes: review queue, companies, activity with undo, scheduled runs, the menu-bar item, contact list.

**Phase 4—P1 attribution.** Twilio Lookup, LLM pass, reassignment detection, duplicate report.

## Sources

- [Logo.dev—Logo CDN overview and parameters](https://www.logo.dev/docs/logo-images/introduction)
- [Logo.dev—API reference](https://www.logo.dev/docs/api-reference/introduction)
- [Logo.dev—Pricing](https://logo.dev/pricing)
- [Logo.dev—Attribution](https://www.logo.dev/docs/platform/attribution)
- [Logo.dev—Self-hosting logos](https://www.logo.dev/docs/platform/self-hosting.md)
- [Logo.dev—API credits](https://www.logo.dev/docs/platform/credits.md)
- [Logo.dev—Get a logo (API)](https://www.logo.dev/docs/api-reference/logos/get-a-logo.md)
- [Logo.dev—Fair use](https://logo.dev/docs/platform/fair-use)
- [Apple Support—Limits for iCloud Contacts, Calendars, Reminders, Bookmarks, and Maps](https://support.apple.com/en-la/103188)
- [BusyMac—Using BusyContacts with iCloud (throttling report)](https://support.busymac.com/help/77662-using-busycontacts-with-icloud)
- [iMessage database format notes](https://glama.ai/mcp/servers/@jonmmease/jons-mcp-imessage/blob/3af876d28c0efe9f24b18db9936155308736c4b9/docs/IMESSAGE_DATABASE_FORMAT.md)
- [Fatbobman—Deep dive into iMessage](https://fatbobman.com/en/posts/deep-dive-into-imessage/)
- [U.S. Short Code Registry—What is a short code?](https://www.usshortcodes.com/about-short-codes/)
- [Vero—A guide to SMS short code lookups](https://www.getvero.com/resources/a-guide-to-sms-short-code-lookups/)
- [Twilio—Lookup API pricing](https://www.twilio.com/en-us/user-authentication-identity/pricing/lookup)
- [Twilio—Line Type Intelligence](https://www.twilio.com/docs/lookup/v2-api/line-type-intelligence)
- [Sinch—Apple support for RCS](https://sinch.com/blog/apple-support-rcs/)
- [Twilio—What businesses need to know about iOS 26](https://www.twilio.com/en-us/blog/insights/trends/potential-ios-26-update-communications-implications)
- [Apple Community—Text messages being linked on a contact's multiple numbers](https://discussions.apple.com/thread/250694424)
- [Apple Community—Same contact, different numbers, one thread](https://discussions-jp-prz.apple.com/thread/254158144)
