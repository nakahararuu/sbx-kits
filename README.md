# sbx-kits

Kits that provision a Docker sandbox for a particular kind of work. A kit
installs the agent skills for a platform, the CLI tools those skills drive, and
the network policy they need — so a fresh sandbox is useful the moment it boots
instead of after an hour of setup.

```bash
./install-kit.sh --list
./install-kit.sh datadog
```

## Kits

| Kit | What it sets up |
| --- | --- |
| [`datadog`](kits/datadog) | All 39 skills from `datadog-labs/agent-skills`, the `pup` CLI plus Node/kubectl/helm/gh/ddtrace, and an allowlist covering every Datadog site and domain |

## Layout

```
install-kit.sh          entry point; dispatches to a kit's install.sh
lib/common.sh           shared helpers (platform detection, downloads, logging)
scripts/gen-settings.sh regenerates the derived settings files from kit.json
scripts/test.sh         syntax, JSON, freshness and dry-run checks
kits/<name>/
  kit.json              manifest: skills source, tool groups, domain allowlists
  install.sh            the installer
  settings.json         Claude Code sandbox settings — derived from kit.json
  settings.install.json same, plus the domains the installer itself needs
  README.md
```

## Writing a kit

A kit is a directory under `kits/` with a `kit.json` and an executable
`install.sh`. Beyond that the contract is short:

- **`install.sh` is the only entry point.** It sources `lib/common.sh`, which
  gives it `log`/`info`/`ok`/`warn`/`die`, `have`, `sbx_os`, `sbx_arch`,
  `sbx_fetch`, `sbx_extract_bin`, `sbx_pkg_install` and `sbx_version_ge`.
- **`--dry-run` must work and change nothing.** `scripts/test.sh` runs every
  kit's installer with it, so this is the smoke test.
- **Re-running must be safe.** Skip tools already on `PATH`, and merge into
  `settings.json` as a union rather than overwriting it.
- **`kit.json` owns the domain lists.** `settings.json` and
  `settings.install.json` are generated from it by `scripts/gen-settings.sh`;
  `scripts/test.sh` fails if they have drifted.
- **Nothing needs root.** Binaries go to `~/.local/bin`, larger payloads to
  `~/.local/share/sbx-kits/<kit>/`. `sbx_pkg_install` is best-effort and falls
  back to a direct download when there is no usable package manager.
- **Separate the runtime policy from the install-time one.** `settings.json`
  carries only what the skills need at runtime; whatever the installer needs to
  fetch its tools belongs in the `toolchain` group, which lands in
  `settings.install.json` instead.

## Development

```bash
./scripts/test.sh            # bash -n, jq, generated-file freshness, dry runs
./scripts/gen-settings.sh    # after editing any kit.json
```

`scripts/test.sh` runs `shellcheck` when it is installed and skips it otherwise.
