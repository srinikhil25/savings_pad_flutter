# Savings Pad — Final Presentation Notes

Applied Programming, Shizuoka University. Structured to match the three
sections lecture 15 asks for, plus the demonstration.

---

## 1. Requirements for the App

**The problem.** I receive a 48,000 yen monthly scholarship for 8 months and
want all of it saved toward flight tickets for my parents to visit Japan for my
graduation. I also earn part-time. Living costs and savings come out of the same
bank account, so it is easy to spend savings by accident and only notice later.

**What the app must do.**

| # | Requirement | Why |
| --- | --- | --- |
| R1 | Track the bank balance without re-entering it every month | Entered once, then maintained from logged movements |
| R2 | Keep savings visibly separate from spending money | Spending must never silently reduce the goal |
| R3 | Warn when this month is below last month | The core problem: noticing too late |
| R4 | Work with no network | Logged on the train, in the bank, at the konbini |
| R5 | Same numbers on phone and laptop | Checked in both places |
| R6 | Attach a receipt to an entry | Evidence for a number entered days later |

**Non-goals**, decided deliberately: no per-purchase logging (I would not keep it
up, so the number would drift and become untrustworthy), and no bank API
integration.

---

## 2. Design, Behaviour and Structure

### Architecture — MVC

```
lib/
  models/       Entry, EntryKind, AppSettings      ← pure Dart, no Flutter
  utils/        calc.dart, format.dart             ← pure Dart business rules
  services/     AuthService, FirestoreService,
                LocalStore, ReceiptCamera          ← all backend contact
  controllers/  LedgerController (ChangeNotifier)  ← state + commands
  views/        Shell, Home, AddEntry, History,
                Settings, SignIn                   ← widgets only
  widgets/      TrackerCard, PaceBar, AlertBanner
```

The dependency rule is one-directional: **views → controller → services →
models**. No widget imports `FirebaseAuth` or `FirebaseFirestore`. That is what
makes the calculation layer testable without an emulator.

### The data model — one rule for everything

Every entry is `amount` yen leaving `from` and arriving at `to`:

```
outside       the world beyond my money (wages arriving, rent leaving)
pot:bank      the bank account
pot:savings   the savings stash
```

| What happened | from | to |
| --- | --- | --- |
| Scholarship arrives | `outside` | `pot:bank` |
| Move to savings | `pot:bank` | `pot:savings` |
| Rent | `pot:bank` | `outside` |
| Broke into the stash | `pot:savings` | `outside` |

```
pot balance = Σ(to == pot) − Σ(from == pot)
```

Because a transfer is a **single record**, money leaving one pot and arriving in
another can never disagree. The first design used a `direction` + `bucket` pair,
which could not express a transfer at all — the redesign is discussed in §3.

### Behaviour — the alert engine

`computeAlerts()` compares this month against last month and returns at most
three alerts, sorted by severity. Danger-level alerts also pulse the vibration
motor. The rules:

| Trigger | Level |
| --- | --- |
| Money taken out of savings this month | danger |
| This month's net saving below last month's | warning |
| Past the 25th with nothing saved | warning |
| Below the monthly target, month still running | info |
| Target hit | good |

**Pace** is judged on *finished* months only. Being on day 3 of the month should
not read as "48,000 behind".

---

## 3. Topics from Software Development / Programming

Four things worth 60 seconds each.

### (a) A modelling mistake, and the fix

v1 stored `direction: in|out` and `bucket: savings|spending`. It could not
represent *"I moved 48,000 from my account into my stash"* — only "savings went
up", with no matching decrease anywhere. Adding a bank balance exposed the hole.

Replacing two enums with two endpoints (`from`, `to`) made transfers, income and
spending the same operation, and made every balance a one-line fold. **Fewer
concepts, more expressive.**

### (b) Deleting my own code in favour of a platform guarantee

The earlier web version had ~150 lines of hand-written sync: last-write-wins
merging, an `updatedAt` comparison per record, and a push/pull reconciliation
pass. Cloud Firestore provides offline persistence and conflict resolution
natively, so all of it was deleted.

Kept: **soft deletes**. A hard delete leaves other devices unable to distinguish
"deleted elsewhere" from "not synced yet".

### (c) Security rules — improving on the lecture example

Lecture 09 gives `allow read, write: if request.auth != null` and notes it "is
not secure, but use it to simplify the exercise". Any signed-in user could read
everyone's data.

Storing under `users/{uid}/…` allows the stricter rule at no extra cost:

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

### (d) Engineering around a known platform defect

Lecture 07 slide 60 records that as of 2026.07.30 the `camera` plugin fails to
build on the Android emulator — a version mismatch with the Android NDK camera
component.

Rather than fight it, I used `image_picker`, which delegates to the platform's
own camera activity and never links those NDK libraries. Receipts are downscaled
to 900px / quality 55 and stored base64 inside the entry document, with a size
guard because a Firestore document is capped at 1 MiB.

**Trade-off, stated honestly:** base64-in-document is the right call at receipt
size and one user. At scale, Firebase Storage with a URL reference would be
correct.

---

## 4. Demonstration script

Two emulators side by side, signed into the same account.

1. **Sign in** (lecture 08) — Firebase Auth email/password.
2. **Log the scholarship** on device A → watch it appear on device B within a
   second, untouched. *This is lecture 09's realtime sync.*
3. **Move 48,000 to savings** → the account drops, the stash rises, the pace
   marker moves. Total money unchanged.
4. **Spend 30,000** → the account drops, **the stash does not move**. (R2)
5. **Take 15,000 out of savings** → red banner appears, phone vibrates. (R3)
6. **Aeroplane mode** → log an entry, UI updates immediately; re-enable, watch it
   reach the other device. *Offline persistence.* (R4)
7. **Attach a receipt** with the camera. (R6, lecture 07)
8. **Resize the window** (or rotate) → bottom nav becomes a navigation rail, then
   a two-column layout. *Lecture 04-05, one widget tree.*
9. **`flutter test`** → 18 tests pass with no emulator, showing the MVC split
   pays off.

---

## 5. Lecture coverage

| Lecture | Where |
| --- | --- |
| 02 Multi-platform debug | Runs on Android emulator and Chrome |
| 03 Dart | `models/`, `utils/calc.dart` — enums, sealed-style switch, factories, null safety |
| 04-05 Responsive design | `shell_view.dart` — `LayoutBuilder`, `NavigationRail`, `Expanded`, `Wrap`; Stateless/Stateful split |
| 04-05 State management | `provider` + `ChangeNotifier`, `context.watch` / `context.select` |
| 06 Package management | `provider`, `intl`, `shared_preferences`, `image_picker` — all from pub.dev, versions pinned in `pubspec.yaml` |
| 07 Embedded devices | `receipt_camera.dart` (camera), `alert_banner.dart` (vibration motor) |
| 08 Authentication | `auth_service.dart`, `sign_in_view.dart` |
| 09 Firestore | `firestore_service.dart` — realtime `snapshots()`, offline persistence, security rules |
| 09 JSON | `dart:convert` in `local_store.dart`, hand-written `toJson`/`fromJson` |
| MVC (syllabus) | The layering above, enforced by the one-directional dependency rule |

---

## Questions I expect

**"Why not Realtime Database?"** Firestore's per-document listeners suit a
growing list of entries; RTDB would re-send a larger subtree. Latency does not
matter here — no opponent is waiting.

**"Why base64 instead of Firebase Storage?"** Honest answer above in §3(d).

**"What would you do next?"** A monthly chart, and CSV export for tax season.
