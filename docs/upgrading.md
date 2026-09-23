# Upgrading

```bash
claude plugin marketplace update bytesnation
claude plugin update capstan@bytesnation
```

The first refreshes the marketplace catalogue and changes no installed plugin by itself. The second moves your install onto the new version and needs the marketplace-qualified name: `capstan@bytesnation` resolves, a bare `capstan` does not. Reaching for `install` instead does nothing useful: it reports the plugin is already installed and leaves the old version running. Add `-s project` if that is where you installed, then restart Claude Code.

Leave the `/plugin` auto-update toggle off, the same as for any third-party marketplace.

## 3.0.0: the board moved out

The GitHub Projects v2 tracker surface is no longer part of core. It is a second plugin, `capstan-board`, installed and configured separately. See [tracker surface](tracker.md) for what it costs and how to install it.

If your project's `capstan-tracker` already names a GitHub project, install `capstan-board@bytesnation` before running an effort or a quick on 3.0.0. If you upgrade core first and run one anyway, it stops before the interview rather than guessing which surface holds slice state:

```
surface not installed: install capstan-board@bytesnation
```

Install the plugin, reload plugins, and re-run the phase that stopped. A project that has never set `capstan-tracker` sees no change: `tracker.md` in the document home works exactly as it always has.

Once installed, `capstan-board` upgrades the same way as core:

```bash
claude plugin update capstan-board@bytesnation
```

## Moving the marketplace to a different address

No command edits a marketplace's source in place, and editing `~/.claude/plugins/known_marketplaces.json` by hand does not hold, because the next `claude plugin marketplace update` puts the old address back. Removing and re-adding is the route that sticks.

**Removing a marketplace uninstalls every plugin installed from it.** The install record empties and the marketplace clone is deleted, so the second and third commands here are the repair rather than tidying afterwards. Run the first alone and you have no Capstan:

```bash
claude plugin marketplace remove bytesnation
claude plugin marketplace add MokeyBytes/capstan
claude plugin install capstan@bytesnation --scope user
```

Use `--scope project` on the last command if that is where it was installed. `capstan@bytesnation` survives the round trip because a marketplace takes its name from the `name` field in its `marketplace.json` rather than from the repository path, so re-adding from a different address produces the same marketplace and the same plugin identifier.

The version cache under `~/.claude/plugins/cache/` is untouched throughout. A session open while you do this keeps resolving skills from the copy it already holds, and picks up the reinstall when you restart it.
