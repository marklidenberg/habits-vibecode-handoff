# Habits

A habit tracker for the iPhone: habits as rows, days as columns, a tap to mark the day.

A vibe-coded skeleton: copy its shape for your own app.

The sections below are for the agent: it runs every step, asking the user only for what it can't do itself.

## What's inside

### The app's features

- SwiftUI, iOS 26, Liquid Glass, dark only
- The model in its own Swift package: `@Observable` store, `Codable` items
- Storage: one JSON file in iCloud Drive
  - Synced across devices, merged by item — the newer wins, deletions kept
  - Watched by `NSFilePresenter`: another device's change shows at once
  - On the device alone where iCloud is off, moved into iCloud once it is on
  - Visible in the Files app and Finder
- A scrollable grid: rows × days, pinch or buttons to zoom
- A tree beside it: groups that fold, resizable by a grip
- Drag to reorder, into a group too
- Sheets: an item's editor, a day's value and note
- An emoji picker: the full set, searchable
- Settings: an accent color, a cell style, a sound
- Sounds synthesized by `AVAudioEngine`, no audio files
- An archive: searched, restored, deleted
- Export through the share sheet, gzipped; import from Files
- `-demo` at launch: sample data in memory
- A Python CLI on the Mac over the same file
- Signed installs on the iPhone by one script

### How to use it

```
Habits/             The SwiftUI app: views, iCloud sync, the demo data
HabitsKit/          The model: a Swift package, tested on the Mac
HabitsUITests/      Every flow on the simulator, a screenshot of each screen
cli/                `habits.py`: the data file, edited from the Mac
scripts/            `install.sh`: build, sign, install on the iPhone
Habits.xcodeproj    The app and its UI tests
.env.example        The user's ids: team, bundle id, API key, iPhone
```

- The model's tests: `(cd HabitsKit && swift test)`
- The UI tests, screenshots in the `.xcresult`:
  ```sh
  xcodebuild test -project Habits.xcodeproj -scheme Habits \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    CODE_SIGNING_ALLOWED=NO
  ```
- The CLI and its test:
  ```sh
  BUNDLE_ID=<bundle id> uv run cli/habits.py --help
  uvx pytest cli
  ```
- On the iPhone: `scripts/install.sh`, `.env` filled
- `-demo` at launch: sample data in memory, the real file untouched

## How to build a similar app from scratch

### Prerequisites

Check each; where missing, install it or ask the user to:

- Xcode, the iOS platform: `xcodebuild -version`, `xcrun simctl list runtimes`
- `brew install uv`
- The user's Apple Developer Program membership: paid, iCloud needs it
  - Their Apple ID in Xcode → Settings → Accounts
- An App Store Connect API key, Admin: appstoreconnect.apple.com → Users and Access → Integrations → Team Keys
  - Its `.p8` in `~/.appstoreconnect/private_keys/`
- The iPhone: plugged in once, trusted, Settings → Privacy & Security → Developer Mode on
  - Xcode → Window → Devices and Simulators: «Connect via network», for Wi-Fi

### Identity

Ask the user for the app's ids, then write them in:

- The app's name: the targets, the folders, `CFBundleDisplayName`
- The bundle id, e.g. `com.<them>.<app>`: `PRODUCT_BUNDLE_IDENTIFIER` in the project
- `.env`, copied from `.env.example`
  - `TEAM_ID`: developer.apple.com/account → Membership
  - `BUNDLE_ID`: the bundle id
  - `API_KEY_ID`, `API_ISSUER_ID`: the API key's page
  - `DEVICE_UDID`: `xcrun devicectl list devices`

### Idea

Ask the user:

- The one screen, in a sentence: «habits as rows, days as columns, a tap marks the day»
- What it stores: one JSON file in iCloud Drive, synced by iOS, no server

### Mockup

- An HTML mockup of the screen: dark, phone-sized
- Several variants side by side; the user picks one
- Iterate on it until approved — no Swift yet

### Implement

- The model in `<App>Kit`
  - A plain `Codable` struct per thing
  - One `@Observable` store: every change saved at once
- A SwiftUI view per screen, the store by `.environment`
- `-demo`: sample data for tests and screenshots
- Sync: iCloud Documents
  - The container `iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)`: the entitlements, `Info.plist`
  - The file watched by `NSFilePresenter`, merged by item, the newer wins
- The CLI: the same file from the Mac

One feature at a time, its tests with it.

### Test

- The model: a test per rule, before the code
- The UI: an XCUITest per flow, launched with `-demo`
  - Accessibility identifiers on what it taps
  - A screenshot of every screen: read them back, fix what's off
- All green before the user sees it

### Install

- `scripts/install.sh`: signed, on the iPhone, by cable or Wi-Fi
  - The first run registers the App ID and the iCloud container
- Ask the user to open the app and try it

### Configure

The user's data, added or updated after the install:

- Ask the user what to add or change
- Change it in the app's data file, not by hand on the phone
  - A CLI over the file, on the Mac: `list`, `add`, `edit`, `delete` — built with the model, tested
  - The app picks the change up through iCloud
- A new kind of data: the model, the file format, the CLI and their tests updated together
- Ask the user to check it in the app
