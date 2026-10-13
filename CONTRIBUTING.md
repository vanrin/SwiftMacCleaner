# Contributing

Thank you for looking. This is an app that deletes things, so a few rules matter more here than
they would elsewhere.

## Building and testing

The [README](README.md#building-it) says how to build. Run the unit tests before you open a pull
request:

```sh
xcodebuild test -project SwiftMacCleaner.xcodeproj -scheme SwiftMacCleaner -destination 'platform=macOS'
```

## The rules

- **Everything that removes goes through the guard.** A scanner only proposes. Removal happens in
  `SwiftMacCleaner/Clean`, and every path is put to `SafetyGuard` first. Do not delete from a
  scanner, a model or a view.
- **A change to what is offered or removed comes with a test.** So does a new rule about what must
  be left alone.
- **Tests never touch the real home folder.** They make a temporary folder and pass it in as the
  home, and where they can they hand a tool's output in as text instead of running the tool.
- **Anything run as root is one quoted script behind macOS's own password prompt.** No helper is
  installed, and nothing a user or another program can write is trusted as root.
- **English only.** The app is not localised.
- **Icons are drawn by `Tools/make-glyphs.swift`.** Change the drawing there and run the tool, not
  the files it writes.

## Commits and pull requests

Write the commit message for the person using the app: its first line says what changed for them,
and the rest says why. Keep a pull request to one change.

## Reporting a problem

For a bug, open an issue with the macOS version, what you scanned, and what the app offered or did.
For anything that could remove the wrong thing or misuse a password, see
[SECURITY.md](SECURITY.md) instead of opening a public issue.
