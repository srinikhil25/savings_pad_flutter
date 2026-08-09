# Savings Pad (Flutter)

Track a monthly scholarship toward a savings goal, synced across every device
you sign in on. Built for Applied Programming, Faculty of Informatics,
Shizuoka University.

## Two trackers, one rule

1. **In the account** — the bank balance. Entered once, maintained from there.
2. **Savings stash** — the money that is not to be touched, and what it is for.

Spending comes out of the account and never moves the stash. If a month's
saving falls below the month before it, the home screen says so — and the phone
buzzes.

## Running it

```bash
flutter pub get
flutter run
```

### Firebase setup (required before sign-in works)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

That generates `lib/firebase_options.dart`. Until then the app still launches
and shows a setup screen rather than crashing.

Then, in the Firebase console:

1. **Authentication → Sign-in method → Email/Password → Enable.**
2. **Firestore Database → Create database** (production mode,
   `asia-northeast1` / Tokyo).
3. **Firestore → Rules** — paste [`firestore.rules`](firestore.rules) and
   publish.

## Architecture (MVC)

```
lib/
  models/       Entry, EntryKind, AppSettings      pure Dart, no Flutter imports
  utils/        calc.dart, format.dart             business rules + formatting
  services/     AuthService, FirestoreService,     everything that touches
                LocalStore, ReceiptCamera          a backend or the hardware
  controllers/  LedgerController                   ChangeNotifier, via Provider
  views/        Shell, Home, AddEntry, History,    widgets only
                Settings, SignIn, SetupNeeded
  widgets/      TrackerCard, PaceBar, AlertBanner  reusable pieces
```

Dependencies point one way: **views → controller → services → models**. No
widget imports Firebase, which is why the whole calculation layer is testable
with no emulator:

```bash
flutter test
```

## Data model

Every entry is `amount` yen leaving `from` and arriving at `to`, where each end
is `outside`, `pot:bank`, or `pot:savings`:

```
pot balance = Σ(to == pot) − Σ(from == pot)
```

A transfer between pots is a single record, so the two sides can never drift.

Stored in Firestore as:

```
users/{uid}/entries/{entryId}
users/{uid}/settings/app
```
