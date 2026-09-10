# ezconfig

[![Version](https://img.shields.io/badge/version-1.0.1-blue)](https://github.com/Revanfer14/ezconfig/releases)
[![Swift](https://img.shields.io/badge/swift-6.3-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A macOS CLI that pulls signing identity (`DEVELOPMENT_TEAM`,
`PRODUCT_BUNDLE_IDENTIFIER`) out of a committed `.pbxproj` and moves it into a
per-developer, gitignored `Configs/Local.xcconfig`, with a committed
`Configs/Base.xcconfig` acting as the intermediary.

## Why

Teams where every member signs with their own Individual or Personal Apple
Developer account can't share a single `DEVELOPMENT_TEAM` value in the
repository. Without a fix, every `git pull` clobbers a teammate's local
signing settings and `project.pbxproj` turns into a permanent merge-conflict
generator.

`ezconfig` retrofits an existing `.xcodeproj` to read its Team ID and bundle ID
prefix from an xcconfig layer instead of hardcoding them, so:

- `Configs/Base.xcconfig` is committed and shared — it defines the variables
  (`DEVELOPMENT_TEAM`, `BUNDLE_PREFIX`, `APP_GROUP_ID`, ...) with empty or
  placeholder values.
- `Configs/Local.xcconfig` is gitignored and generated per machine — it fills
  in each developer's real Team ID and bundle ID suffix.
- A pre-commit hook keeps signing identity from sneaking back into
  `project.pbxproj` when Xcode rewrites it.

It retrofits existing projects; it does not generate new ones and is not a
replacement for XcodeGen or Tuist.

## Requirements

- macOS 13 or later
- Xcode project (`.xcodeproj`), not yet using Swift Package Manager–only
  targets
- A valid Apple Developer signing certificate in your keychain (for `setup`)
- Git (the project must be inside a Git repository)

## Installation

### Homebrew (recommended)

```bash
brew install Revanfer14/adac9/ezconfig
```

### Build from source

```bash
git clone https://github.com/Revanfer14/ezconfig.git
cd ezconfig
swift build -c release
cp .build/release/ezconfig /usr/local/bin/ezconfig
```

## Quick start

Run once, by whoever owns the repository:

```bash
cd /path/to/YourProject
git init #if you haven't
ezconfig init
```

This reads `project.pbxproj`, extracts the current Team ID and bundle ID
prefix, writes `Configs/Base.xcconfig`, links it to every signable target,
strips the hardcoded signing identity out of the project file, and installs a
pre-commit hook. It then runs `setup` for the machine it's running on. Commit
the result:

```bash
git add .
git commit -m "chore: adopt ezconfig for per-developer signing"
```

Every other developer, once per clone:

```bash
cd /path/to/YourProject
ezconfig setup
```

This detects their Team ID from the keychain and writes a local, gitignored
`Configs/Local.xcconfig`. Open the project in Xcode — signing should resolve
automatically.

## Commands

### `ezconfig init`

Extracts signing identity from `.pbxproj` and creates `Configs/Base.xcconfig`.
Run once by the repo owner, and again any time a new target is added.

```
--path <path>       Path to the project folder (default: current directory)
--prefix <prefix>   Force a specific canonical bundle ID prefix
--dry-run           Show the plan without writing anything
--no-setup          Skip running setup for the current machine afterward
--team <team-id>    Team ID to use for the setup step after init
```

### `ezconfig setup`

Detects your Team ID from the keychain and writes `Configs/Local.xcconfig`.
Run once per clone, by every developer.

```
--path <path>       Path to the project folder (default: current directory)
--team <team-id>    Force a specific Team ID instead of detecting one
```

### `ezconfig check`

Checks whether `.pbxproj` is clean of signing identity. This is what the
pre-commit hook runs (`check --fix --staged`) before every commit.

```
--path <path>   Path to the project folder (default: current directory)
--fix           Strip and re-stage the project when it is dirty
--staged        Check the staging area instead of the file on disk
--strict        Also reject literal values in targets ezconfig does not manage
```

`--strict` cannot be combined with `--fix`.

### `ezconfig clean`

Strips signing identity out of `.pbxproj` again, without touching xcconfig,
entitlements, or `.gitignore`. Use this if Xcode writes the identity back
outside of a commit (e.g. after changing signing settings in the UI).

```
--path <path>   Path to the project folder (default: current directory)
```

### `ezconfig inspect`

Read-only. Prints the current project state and the adoption plan `init`
would apply, without writing anything.

```
--path <path>   Path to the project folder (default: current directory)
```

## How it works

1. **`init`** reads the project with XcodeProj, builds an adoption plan,
   writes `Configs/Base.xcconfig`, links it to every signable target, strips
   `DEVELOPMENT_TEAM` (at both project and target level) and rewrites
   `PRODUCT_BUNDLE_IDENTIFIER` to `$(BUNDLE_PREFIX)...`, updates companion
   references (entitlements, Info.plist, source literals), and installs a
   Git pre-commit hook.
2. **`setup`** reads your signing certificate from the keychain
   (`security find-certificate` piped through `openssl x509` to read the
   `OU=` field), derives a unique local bundle ID suffix, and writes
   `Configs/Local.xcconfig`.
3. **`check`** scans `project.pbxproj` — as text, so it can read either the
   worktree file or the staged Git blob — for signing identity that leaked
   back in, and fails the commit if it finds any.

No network calls are made. No Team ID is ever written to a log file.

## Uninstalling

`ezconfig` does not yet ship an automated `eject` command. To remove it by
hand:

1. Delete the pre-commit hook block delimited by `# >>> ezconfig >>>` and
   `# <<< ezconfig <<<` in `.git/hooks/pre-commit`.
2. In each target's Build Settings, replace `$(BUNDLE_PREFIX)...` with the
   literal bundle identifier, and set `DEVELOPMENT_TEAM` back to a literal
   Team ID (project and target level).
3. Remove the `Configs/Base.xcconfig` and `Configs/Local.xcconfig`
   references from the project, and delete the `Configs/` folder.
4. Remove the `Configs/Local.xcconfig` entry from `.gitignore`.

## Development

```bash
swift build                                  # debug build
swift build -c release                       # release build
swift run ezconfig inspect --path <project>  # run a subcommand locally
swift test                                   # run the test suite
```

Built with [swift-argument-parser](https://github.com/apple/swift-argument-parser)
and [XcodeProj](https://github.com/tuist/XcodeProj).

## Alternatives

`ezconfig` only retrofits signing identity onto an existing `.xcodeproj`. If
what you actually need is full project generation from a manifest, these are
great options:

- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [Tuist](https://github.com/tuist/tuist)
- [Xcake](https://github.com/jcavar/xcake)

## Attributions

This tool is powered by:

- [XcodeProj](https://github.com/tuist/XcodeProj)
- [swift-argument-parser](https://github.com/apple/swift-argument-parser)
- [PathKit](https://github.com/kylef/PathKit)

## License

MIT. See [LICENSE](LICENSE).
