# Security

SwiftMacCleaner removes files and, for a few steps, runs a script as root after macOS has asked for
the password. A mistake in either is a security problem, and is worth reporting in private.

## What to report

- A way to make the app remove, or offer to remove, something outside what its review sheet shows.
- A path that gets past `SafetyGuard` when it should not.
- Anything that lets another program or a file on disk steer what runs as root: in
  `Shell.runAsAdministrator`, `SystemLogs.command` or `Uninstaller.systemCommand`.
- A request to the network that sends more than the README says.

## How to report it

Use **Report a vulnerability** under the repository's Security tab on GitHub, which opens a private
advisory. Please do not open a public issue for it.

Say which version or commit you looked at, what you did, and what happened. A small example that
shows the problem helps most.

## Which versions

Only the newest commit on `main` is looked after.
