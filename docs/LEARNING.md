# Federated-lite category learning

Opt-in, privacy-first, all logic on the phone. Two parts: a **global merchant map** that makes categorisation better out of the box, and an optional **contribution** ("Help improve categories") that lets people send back which merchants they confirmed. Code: `lib/core/learning/`. Free: no new packages, no paid services.

## 0. Your own merchant memory (on this phone, always on)

Separate from the shared map and from contribution: every "yes, that is
right" swipe and every deliberate category fix votes for a category under the
merchant's normalised key (`lib/core/learning/merchant_memory.dart`). It is
stored in local preferences and is never uploaded. A deliberate fix (or two
agreeing confirmations) is enough to apply it; contradicting yourself lowers
confidence so a mixed merchant stops guessing. Order of precedence at capture:
your explicit rules, then this memory, then the built-in dictionary, then the
shared map. Payments filled this way carry the `learned` tag and the detail
sheet says so, with a one-tap Forget. "Just this one" is treated as an
exception and is not learned.

## 1. Global merchant map

`assets/merchant_map.json`: `{version, schema, updated, entries: {merchant key: category key}}`. Seeded with a few hundred common UAE merchants and spelling variants (public knowledge, no user data; regenerate with `python3 tool/gen_merchant_map.py` and bump `VERSION`). Keys are normalised (lower case, single spaced); categories are the default category keys (never `custom`). Invalid entries are skipped on load, a file with no valid version is rejected.

**Categorisation order** (`CategoryResolver`, `lib/core/engine/rule_engine.dart`):

1. the person's own rules (always win),
2. the built-in merchant dictionary,
3. the global map (`source = 'global_map'`),
4. nothing: uncategorised, so it shows up in Review.

Lookup is an exact key match, else the longest whole-word prefix (at least 5 characters, so "carrefour city centre" finds "carrefour"). A category the person does not have is skipped.

**Update path.** `GlobalMerchantMapLoader.load()` returns the bundled map, or a stored refreshed copy if its `version` is higher. `offerRefreshed(json, current)` validates a downloaded file and stores it only if valid, non-empty and newer. Fetching is **not wired up** in this build; the intended source is the catalog distribution endpoint, as a static file next to the card catalog (for example `GET <catalog base>/merchant_map.json`, same shape as the asset). Whoever adds the fetch calls `offerRefreshed` from the same place that checks for a catalog update, and restarts the resolver (the map is read at app start).

## 2. Contribution (off by default)

Settings > Privacy > **Help improve categories**. A separate switch from "Share anonymous usage" (separate storage key `learning.opt_in`, neither implies the other). Next to it, **See what would be shared** shows the queue exactly as the batcher sees it.

**Collected** (only while on): when the person confirms a category, by recategorising a payment (not "just this payment") or by a Review swipe, the app stores `(normalised merchant key, category key)` plus the payment id as a local de-duplication marker. A payment counts once; recategorising it again moves it. The marker never leaves the phone.

**What can leave the phone**: a batch of `{k: merchant key, c: category key, n: count}` and the map version. Nothing else: no amounts, dates, accounts, user ids, install ids, payment ids, device info or raw text. The analytics id is not used.

**Filter** (`privacy_filter.dart`), applied on recording, on load of the stored queue, in the preview and again when a batch is built:

- Always rejected, even for a known merchant: not normalised, over 40 characters or 5 words, `@`, `http`/`www`/`://`, `+`, any run of more than 3 digits or more than 4 digits in total (phone numbers, IBANs, card and reference numbers), transfer words (`transfer`, `iban`, `salary`, `payroll`, `atm`, `cheque`, ...), control characters and symbols.
- A key that exactly matches a global-map entry is accepted.
- Otherwise it must be plain lower-case letters, contain a business word (`llc`, `trading`, `pharmacy`, `cafe`, `supermarket`, ...), and contain no title or name particle (`mr`, `bin`, `abu`, ...) and no common first name from a built-in list.
- Categories that point at people or accounts are never contributed: `salary`, `family`, `savings`, `cc_payment`, `car_loan`, `home_loan`, `rent`, `other`, `custom`.

**Noise and thresholds** (`ContributionBatcher`): only pairs confirmed on at least 2 different payments; each eligible pair is left out at random with probability 0.25 (so a server can never be sure a given install confirmed a pair, and corrects for it in aggregate); counts are capped at 3; order is shuffled. Every eligible pair is removed from the queue after an attempt that succeeded, whether it was sent or left out, so a retry never re-rolls the dice.

**Schedule.** At most one batch per 7 days (clock starts when the switch is turned on), tried when the app is opened or resumed. A failed upload keeps the queue and is retried on the next open.

**Opt-out** deletes the queue, the clock and the stored copy immediately, and leftover queue data found without consent is wiped on start. "Delete everything waiting" in the preview clears the queue and keeps the switch on.

**Analytics.** `learning_opt_in {enabled: yes/no}`, through the schema gate only (and only if the person also opted in to anonymous usage). Never the merchants or counts.

## 3. Transport and endpoint contract

`ContributionTransport` (`contribution_transport.dart`): `enabled` and `send(batch) -> bool`. This build ships only `DisabledContributionTransport` (`enabled == false`: nothing is ever sent, the preview says so) and `MemoryContributionTransport` for tests. **The backend endpoint now exists** (pulse PR "Learning: anonymous category contributions": `POST /v1/category-contributions`, `GET /v1/merchant-map`) and `HttpContributionTransport` (`http_learning.dart`) is used whenever the build has an API base URL. Contract:

```
POST <base>/v1/category-contributions
Content-Type: application/json
(no cookies, no Authorization header, no user or install id; the client must not attach one)

{"format": 1, "map_version": 7, "pairs": [{"k": "spinneys", "c": "groceries", "n": 2}]}

200/204  accepted (client forgets the batch)
4xx/5xx  not accepted (client keeps the queue and retries at the next open)
```

Server expectations: validate `format`, keys and category keys against the same rules as the filter (reject the whole batch if any pair fails); store only aggregates (`k`, `c`, summed `n`, week), never per-request rows with IP or timestamps beyond the week; drop IP logs; promote a `(k, c)` into the next `merchant_map.json` only when many distinct requests agree (suggested: at least 20 and a clear majority, after de-biasing the 25% leave-out) and after a human review. Because there is no id, the server cannot de-duplicate one install, so cap each request at 200 pairs.

## Limits

- The HTTP transport and the map refresh are covered by unit tests with a fake server only; promoting aggregates into `data/learning/merchant_map.json` is a manual review step on the backend repo.
- The "looks like a business" and "person-like" checks are heuristics. A person's name that is not in the built-in list, written with a business word, could pass ("Zubair Trading"); known-merchant keys are the safe path, and the 2-confirmation threshold and review of promotions on the server are the backstops. Non-Latin names are rejected by the character rule unless they are in the map.
- Randomised leave-out gives plausible deniability per pair, not formal differential privacy; there is no budget across weeks.
- Only merchants whose normalised name differs from the raw descriptor are affected by normalisation; the key is the normalised merchant name the app already shows.
- The map is read at app start; a refreshed map applies on next launch.
- A "just this payment" choice is not counted; a Review "looks right" swipe is counted as a confirmation of the payment's current category.
