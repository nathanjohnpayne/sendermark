---
spec_id: sendermark
tested: false
reason: implementation spec for product code that does not exist yet; the Swift package and its test target arrive with #14, and each module issue adds the tests for its own section
---

# Sendermark implementation spec

Feature: how this repository implements the Sendermark PRD. It states the module boundaries of `SendermarkCore`, the command-line surface, where state lives, and the invariants every write must keep.

## Authority and conventions

The product requirements are the PRD, version v0.4, canonical in the docs vault and mirrored read-only at `docs/projects/sendermark/prds/sendermark.md`. The interface is drawn in `plans/sendermark-wireframes.html`. Both reach `main` through #1; this spec references them and does not copy or edit them. Where this spec and the PRD differ, the PRD wins and this spec is corrected.

This spec adds no requirement. Every statement below is traced to the PRD or to an issue, in one of three forms:

- `§ Heading` (with an item number where the section is numbered) cites a PRD section by its heading.
- "PRD silent; settled by #N" marks a point the PRD does not cover and an issue does. The issue's acceptance criteria are the requirement; this spec only records where it lives.
- "Open point O-N" marks a point that neither the PRD nor an issue settles, or where an issue and the PRD disagree. These are listed in [Open points](#open-points) and are not decided here.

Wireframe decisions and questions are cited by their ids (D-01 to D-11, Q-01 to Q-07), as § Interface names them.

## Scope and phasing

Sendermark is a native Swift Mac utility built as a `SendermarkCore` package with a `sendermark` command-line tool first and the Mac app second (§ Decisions 1 and 6; § Architecture). The build order is § Build plan: Phase 0 proves the platform, Phase 1 is the CLI for logos, Phase 2 the CLI for senders, Phase 3 the Mac app, Phase 4 the P1 attribution work. The empty package and its CI may be set up during Phase 0 provided they ship no product behaviour and touch no real contact or message (§ Build plan, Phase 0; #14).

Scheduled, unattended runs exist only in the app bundle, not the bare CLI (§ Decisions 6; #41). The app (P1, § Requirements) is a second front end over the same `SendermarkCore`; its screens are specified by § Interface and the wireframes, not by this spec.

## Module boundaries

The modules are those named in § Architecture. The § Architecture diagram places the CLI and the app over `SendermarkCore`, and places access to Contacts, Messages, Logo.dev and Twilio in its modules.

| Module | Owns | PRD | Issues |
|---|---|---|---|
| `ContactsStore` | Reading company cards through `Contacts.framework`, and the personal-number exclusion index. The single write path every feature uses: backup gate, container rule, field allowlist, journal, readback, rate limit. Card creation. | § Architecture; § Company resolution; § Contact write rules | #16, #20, #33 |
| `MessagesReader` | A consistent read-only snapshot of `chat.db`, and every SQL query against the Messages schema. Returns each sending handle raw, with the service and region Messages recorded, counts, first and last dates, and message text. | § Architecture, Messages access; § How the platform behaves; § Risks | #26 |
| `LogoClient` | Logo.dev: the secret-key API lookup and the download from the URL it returns (saved logos), CDN preview URLs with the publishable key (display only), and the flag endpoint. Keychain storage of both Logo.dev keys. | § Architecture; § Decisions 7; § Logo pipeline 1, 3, 5 and 8; § Logo.dev: what the test showed | #18 |
| `LogoNormalizer` | Turning a downloaded image into the bytes to write, with Core Graphics, or a reason it cannot. Reporting whether it returned the image unchanged, padded it or re-encoded it: PRD silent; settled by #19. | § Architecture; § Logo pipeline 4 | #19 |
| `Attribution` | Signals, scoring and shared-sender detection over classified candidates. Makes no network request. | § Architecture; § Sender discovery and attribution; § Decisions 5 | #29 |
| `PhoneLookup` | Twilio Lookup as supporting evidence. P1, off by default, and not scaffolded until its issue. | § Architecture; § Decisions 8; § Requirements, P1 | #52; #14 excludes it |
| `State` | The SQLite store holding resolutions, proposals and the journal: the five § Data model tables. A schema version and migrations: PRD silent; settled by #15. | § Architecture, State; § Data model | #15 |

Boundary rules:

1. All SQL against the Messages schema lives in `MessagesReader`, so a schema change breaks one module and fails closed while the logo commands keep working (§ Risks, "Apple changes the Messages database schema"; #26).
2. Every Contacts write goes through `ContactsStore`'s one write path; no other module calls `Contacts.framework` to save (PRD silent; settled by #20).
3. The only network peers are Logo.dev and, when turned on, Twilio Lookup; there are no analytics and no telemetry (§ Architecture, Network). `Attribution` makes no request (PRD silent beyond § Decisions 5; settled by #29). Sendermark makes no request to the Short Code Registry; it only links to it (§ Requirements, P0).
4. `LogoClient` has no code path that writes a CDN response to disk (§ Decisions 7; #18).
5. Secrets are read from and written to the Keychain only (§ Architecture, Secrets).

Several responsibilities the issues assign to "`SendermarkCore`" are not placed in a named module by the PRD: domain resolution (#21), handle canonicalization and classification (#27), the seed map (#28), proposal generation (#30), startup reconciliation (#58), undo (#23), the writer lock (#65) and private file creation and cleanup (#64). See open point O-1.

## Command-line surface

The executable is `sendermark` (§ User flow). At scaffold it has `--help` and `--version` only, and `--help` never lists a command that is not implemented (PRD silent; settled by #14).

Commands the PRD names:

| Command | What it does | PRD | Issues |
|---|---|---|---|
| `sendermark scan` | Reads Contacts and Messages and reports company cards, domains resolved or ambiguous, logo status per card, and unattributed business senders with message counts. Changes nothing; two runs with no change in between print identical output. | § User flow 1; § Requirements, P0 | #17, #30 |
| `sendermark logos --apply` | Writes normalized, approved logos to resolved cards and prints a summary of what changed. | § User flow 3; § Logo pipeline | #22 |
| `sendermark logos` (without `--apply`) | Writes nothing. PRD silent; settled by #22 (dry default). | — | #22 |
| `sendermark logos --take-over` | Hands one card whose photo the owner changed back to Sendermark. | § Logo pipeline 6 | #22 |
| `sendermark review` | Walks the proposal queue one proposal at a time and records a decision: approve, reject, reassign, skip, or mark as shared sender. Prints in the order of the app's Review screen. | § User flow 4; § Decisions 6; D-02, D-04, D-08 | #31 |
| `sendermark undo <run>` | Reverts every change a run made, per the undo invariants below. | § Contact write rules; § Requirements, P0 | #23 |
| `sendermark undo <change>` | Reverts one change the same way. | § Contact write rules | #23 |

Behaviour the PRD or an issue requires but neither names as a command: confirming a domain for a card without a confident one (§ User flow 2; #21), the first-logo before-and-after sheet (§ Logo pipeline 7; #24), applying approved senders and creating cards (§ User flow 5; #32, #33), the `.vcf` backup export (§ Contact write rules; #20), deriving seed-map entries from existing cards (#28), listing runs and changes with their ids (#23), listing what is stored and deleting it all (#64), and deleting history for a run, before a date, or entirely (§ Architecture, Privacy lifecycle; #64). See open point O-2 for their names and O-3 for how the CLI shows an image.

Lock discipline across commands (§ Contact write rules, "One writer at a time"; #65): applying, undoing, reconciling and cleaning up require the writer lock, and a process that does not hold it does none of them. Reporting which run holds the lock and since when, and letting `scan`, run listing and the review queue run without it: PRD silent; settled by #65.

## Where state lives

| What | Where | PRD | Issues |
|---|---|---|---|
| State database | `~/Library/Application Support/Sendermark/state.sqlite`. Overridable for tests, and no test touches the real directory: PRD silent; settled by #15 | § Architecture, State | #15 |
| Logo cache | `~/Library/Application Support/Sendermark/logo-cache/`; contents unspecified (O-6) | § Architecture, State | — |
| Contacts backups | `~/Library/Application Support/Sendermark/backups/`, one dated `.vcf` export | § Architecture, State; § Contact write rules | #20 |
| Logo.dev keys, Twilio credentials | Keychain; never in the repository or the state file. Never in logs or test fixtures: PRD silent; settled by #18 and #52 | § Architecture, Secrets | #18, #52 |
| A company's domain | The card's URL field, so the key survives a lost state file; also `company` | § Company resolution | #21 |
| Messages snapshot | A private file that lives only for the run that made it; its directory is unspecified (O-6) | § Architecture, Messages access and Privacy lifecycle | #26 |
| Personal-number exclusion index | Holds phone numbers from non-company cards and nothing else. Memory only, never written to the state store: PRD silent; settled by #16 | § Sender discovery and attribution, Handles | #16 |
| Seed map | A hand-maintained file in the repository. Only entries the owner approved for commit are committed: PRD silent; settled by #28 | § Sender discovery and attribution, Signals 1 | #28 |
| Writer lock and logs | Unspecified (O-6) | § Contact write rules; § Architecture, Privacy lifecycle | #65, #64 |

Contact identifiers are local to this Mac, which is acceptable because the Mac is the only writer (§ Architecture, State). Which identifier is stored, for linked cards in particular, is settled by #60 before the read and write paths rely on one (#16, #20).

The tables and their key fields are § Data model: `company`, `logo`, `sender`, `proposal` and `journal`. They are not restated here. The store carries a schema version; opening an older database migrates it or fails with a clear error and never drops data silently (PRD silent; settled by #15). The canonical handle defined in § Sender discovery and attribution, Handles, is the one key used by the seed map, `sender`, `proposal` and approvals.

Lifecycle (§ Architecture, Privacy lifecycle; #64): the directory is mode 0700 and its files 0600. Leftovers from an interrupted run are deleted at the next start, and only by the process holding the writer lock (§ Contact write rules). Never deleting a file that belongs to a run still in progress: PRD silent; settled by #26, #64 and #65. The state file keeps no message text beyond the redacted samples review shows, and drops them when the proposal is decided. A change's before-image is kept until the owner deletes it, so undo has no expiry. The full backup has its own shorter retention, whose period is proposed and approved in #64, and deleting it does not affect undo. Deleting history ends undo for those changes, and Sendermark says so before it deletes.

## Invariants every write must keep

### Every Contacts write

- **INV-1 Container.** Write only to the default, writable container, which is not necessarily iCloud; skip read-only directories (§ Contact write rules; #16, #20, #60).
- **INV-2 Field allowlist.** A write may set only the photo, the URL and sender numbers; a card Sendermark creates also gets the organization name and the organization contact type, and nothing else (§ Contact write rules; #20, #33).
- **INV-3 Owner's numbers.** Never remove or relabel a number Sendermark did not add (§ Contact write rules).
- **INV-4 Notes.** Never read or write the Notes field (§ Contact write rules).
- **INV-5 Person cards.** Never read person cards for logos and never modify them (§ What Sendermark is not). The only data taken from them is the phone-number index (§ Sender discovery and attribution, Handles).
- **INV-6 Backup first.** Before the first write ever, all contacts are exported to a dated `.vcf`; the first applying run refuses to proceed until it exists (§ Contact write rules; § Requirements, P0).
- **INV-7 Journal.** Each write is journaled as prepared, with the before-state of the fields it changes including the prior image and nothing more of the card, before the save; and as applied only after the card is read back (§ Contact write rules; § Data model, `journal`; #20). That a failed save leaves the card as it was and marks the row failed: PRD silent beyond the `failed` state in § Data model; settled by #20.
- **INV-8 Reconcile first.** At every start, before any write, prepared rows are resolved by reading the card: one that matches neither state is reported as needing attention, left alone, and keeps its before-image. A photo counts as written when it decodes to the same picture (§ Contact write rules; #58). That applying commands refuse to run while a row needs attention: PRD silent; settled by #22 and #32.
- **INV-9 One writer.** The CLI, the app and a scheduled run share one lock; a process without it neither writes, reconciles nor cleans up (§ Contact write rules; #65).
- **INV-10 Rate.** No more than 15 cards a minute (§ Contact write rules).
- **INV-11 Undoable.** Every change can be undone (§ Product goals 4); after a crash at any point in a write, every change that reached Contacts can still be undone (§ Requirements, P0; #58).

### Logo writes

- **INV-12 Source.** Every image written to a card was downloaded from the URL the secret-key API returned; no CDN image is ever saved, and no monogram or 404 result is ever written (§ Decisions 7; § Logo pipeline 1 and 3; § Requirements, P0).
- **INV-13 Shape.** Every written image is square, opaque and under 200 KB; an opaque tile is written as delivered and a transparent one is flattened; no mark is clipped by the circular or rounded-square avatar (§ Logo pipeline 4; § Requirements, P0). Where no-clipping and byte identity conflict, no-clipping wins (PRD silent; settled by #19).
- **INV-14 Quality gate.** A logo whose source is a small raster, below 256 px on its short side, is held as "Needs a look" and not written (§ Logo pipeline 2; § Requirements, P0). That it is a named constant: PRD silent; settled by #22.
- **INV-15 First-logo approval.** No card receives its first Sendermark logo without an approval bound to the hash of the exact normalized image, which may be given only after that image has been displayed. If the image changes afterwards, display and approval are both cleared and nothing is written (§ Decisions 3; § Logo pipeline 7; #24).
- **INV-16 Later changes.** A change to an approved logo is held for the same review until the owner decides otherwise (§ Decisions 3; § Open questions, Product; #61, #22, #41).
- **INV-17 Unchanged source.** An unchanged `etag` means no download and no write; a second run with no upstream change performs zero writes (§ Logo pipeline 5; § Requirements, P0).
- **INV-18 Manual photos.** If a card's photo does not match the hash Sendermark last wrote, skip the card, flag it once, and write to it again only after `--take-over` (§ Logo pipeline 6; § Requirements, P0).
- **INV-19 Domains.** A domain from a name lookup is never written until the owner confirms it; a confirmed domain is written to the card's URL field and never asked again (§ Company resolution; § User flow 2; § Requirements, P0). Likely duplicates are reported, never merged (§ Company resolution).

### Sender writes

- **INV-20 Approval.** No phone number is written to any card without an explicit approval recorded in `proposal` (§ Trust model; § Requirements, P0).
- **INV-21 Binding and recheck.** An approval is bound to the evidence and to the destination card's identifier, name and domain. Before writing, Sendermark rechecks all of them and whether the number has since appeared on another card; anything changed returns to review (§ Trust model; § Data model, `proposal`; #31, #32).
- **INV-22 Trust bars.** Proposals obey § Trust model per sender type: email and iMessage senders are never proposed; toll-free and ten-digit numbers need the stated evidence and are approved one at a time, never in a batch; a sender whose link domains conflict is never proposed and is listed as suspicious, and has no add action (§ Trust model; § Requirements, P0; D-04; #30, #31).
- **INV-23 Shared senders.** A handle whose messages name two or more distinct brands is marked shared and never proposed for a company card (§ Sender discovery and attribution, Shared senders; § Requirements, P0).
- **INV-24 Number form.** Numbers are added with the one custom label `text alerts`; numeric handles are stored as digits only and non-numeric handles verbatim; senders are compared on canonical handles, never on bare digits or display formatting (§ Contact write rules; § What the manual cards show; § Sender discovery and attribution, Handles). A handle that cannot be made canonical is skipped and reported, never guessed (§ Sender discovery and attribution, Handles).
- **INV-25 Shared-card warning.** Until reply routing is shown, review warns before a number joins a card that already has another sender (§ How the platform behaves; #59, #31).

### Undo

- **INV-26 Scope.** Undo touches only fields Sendermark itself changed, and never a later edit: a Sendermark field edited since the change is reported as a conflict and keeps its newer value. Restoring the whole card byte for byte is not promised (§ Contact write rules; § Requirements, P0). See O-4 for the override flag #23 adds.
- **INV-27 Created cards.** Undoing a card Sendermark created deletes it only when the card is unchanged since; a card that has changed is kept, with just Sendermark's fields reverted (§ Contact write rules). See O-4.
- **INV-28 Undo is a write.** An undo is itself journaled and goes through the same backup gate, rate limit and lock (PRD silent; settled by #23).

### Things never written

- **INV-29 Messages.** The live Messages database is opened read-only and is never written, checkpointed or vacuumed; every wait on it is bounded so that a busy database ends the run instead of blocking Messages; the database and its `-wal` and `-shm` files are never copied separately (§ Architecture, Messages access; § What Sendermark is not; #26). Sendermark never sends, deletes or modifies a message (§ What Sendermark is not).
- **INV-30 Scan.** `sendermark scan` writes nothing, and Contacts and Messages modification dates are unchanged after it (§ User flow 1; § Requirements, P0). See O-5 for whether this covers Sendermark's own state store.
- **INV-31 Logs.** Logs carry no message text, no contact name and no full handle (§ Architecture, Privacy lifecycle; #64).

## Open points

Points the PRD does not settle and no issue settles yet, or where an issue and the PRD disagree. None is decided here.

| Id | Point | Where it arises | Status |
|---|---|---|---|
| O-1 | Which module owns domain resolution, handle canonicalization and classification, the seed map, proposal generation, startup reconciliation, undo, the writer lock, and private file creation and cleanup. The issues say only "`SendermarkCore`"; the § Architecture module list does not place them. Also unplaced: whether Keychain access is shared by `LogoClient` and `PhoneLookup`. The PRD defines no dependencies between modules. | § Architecture; #18, #21, #23, #27, #28, #30, #52, #58, #64, #65 | Open; no issue settles it |
| O-2 | Names and arguments of the commands the PRD does not name: domain confirmation, the first-logo sheet, sender apply and card creation, backup, seed-map derivation, run and change listing, storage listing and deletion, history deletion. For every command, the output format and exit codes; and the format of run and change ids. | § User flow; #20, #21, #23, #24, #28, #32, #33, #64 | Open; no issue names them |
| O-3 | How the CLI displays the exact normalized image for the first-logo sheet, so that display can be recorded per card with its hash. | § Logo pipeline 7; #24 | Open; #24 requires display but not the medium |
| O-4 | #23 lets the owner pass a per-change flag that overwrites a later edit, and #23 and #33 revert a changed created card's own fields only with that flag. § Contact write rules says undo reports the conflict instead of overwriting and reverts the own fields of a changed created card; § Requirements, P0 says undo "overwrites no later edit". | § Contact write rules; § Requirements, P0; #23, #33 | Open; issue and PRD disagree |
| O-5 | Whether "scan writes nothing" covers Sendermark's own state store and the snapshot file. #27 stores `sender` rows and #30 writes `proposal` rows and the scan's sender section; #26 writes a temporary snapshot. | § User flow 1; § Requirements, P0; #26, #27, #30 | Open; issue and PRD may disagree |
| O-6 | Locations not given: the Messages snapshot's directory, the writer lock, and logs. Contents and retention of `logo-cache/`, beyond the rule that no CDN image is saved. | § Architecture, State and Privacy lifecycle; #26, #64, #65 | Open; no issue settles it |
| O-7 | Data the issues require that § Data model does not list: the Twilio result cache (#52), the mark that keeps an undone logo from being replaced until it changes at the source (#23), and the lock holder's run and process (#65). | § Data model; #23, #52, #65 | Open; tables or columns not defined |
| O-8 | Which Logo.dev service serves the name lookup and `redirect=404` that resolution uses, and whether it spends credit. #21 relies on #18 for both; #18 lists no name-lookup method, and the PRD records `redirect=404` among CDN results. | § Company resolution 3; § Logo.dev: what the test showed; #18, #21 | Open; no issue settles it |
| O-9 | What counts as a "strong signal" for a short-code proposal, and how `proposal.confidence` is computed from signals given "in order of weight". | § Trust model; § Sender discovery and attribution, Signals; § Data model; #29, #30 | Open; no issue defines it |
| O-10 | Lists the PRD names but does not enumerate: consumer mail domains, link shorteners, and the rule that recognizes a toll-free number. Also the value of the margin inside the circular safe area. | § Company resolution 2; § Sender discovery and attribution, Candidates and Signals 2; § Logo pipeline 4; #19, #21, #27, #29 | Open; no issue enumerates them |
| O-11 | What the `reassign` review action does to a proposal. | § User flow 4; #31 | Open; #31 gives it a key only |
| O-12 | How the installed tool locates the seed map, which the PRD places in the repository. | § Sender discovery and attribution, Signals 1; #28 | Open; no issue settles it |

Points that are open in the PRD and have an issue that will settle them. Until then, the PRD's stated default holds:

| Point | PRD | Settled by | Default until then |
|---|---|---|---|
| Whether Contacts preserves an image as written | § Open questions, Platform | #11 | Readback is recorded and compared by decoded picture (#20, #58) |
| Which number a reply reaches in a merged conversation | § How the platform behaves; § Open questions, Platform | #59 | No promise; review warns (INV-25) |
| Default container, linked-card identifiers, identifier stability | § Contact write rules; § Open questions, Platform | #60 | Stored identifiers are not relied on before #60 |
| Whether a changed approved logo applies without review, attended or not | § Decisions 3; § Open questions, Product | #61 | Held for review (INV-16) |
| Outgoing-data policy for the language-model pass | § Decisions 5; § Open questions, Product | #62 | The pass stays off and is not built |
| Whether an `attributedBody` decoder is needed in P0 | § Open questions, Engineering | #12 | Unread text is counted and reported (#26) |
| How the app gets Full Disk Access for scheduled runs | § Open questions, Engineering | #36 | No scheduled runs before the app bundle |
| `text alerts` for every sender or labels by purpose | § Open questions, Product; Q-03 | — (no issue) | `text alerts` (§ Contact write rules) |
| A generic card for shared verification senders | § Open questions, Product | — (no issue; #29 leaves them bare in the first release) | Left bare |
| What a "Needs a look" logo offers | Q-06 | #38 (decided: use my own image; frame to be drawn) | Held, not written |
