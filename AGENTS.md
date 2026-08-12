# Agent Guidelines

## Documentation Governance

Before writing, modifying, or archiving documentation, read and follow
`docs/dev/documentation/index.md`. Do not create, edit, move, or delete
files inside `docs/dev/documentation/`; propose changes there as written
recommendations for a human maintainer to apply.

## Repository Contracts

The governance rules treat these files as optional contracts. This
repository currently uses none of them:

- No `CHANGELOG.md`: changelog update rules do not apply.
- No `CONTRIBUTING.md`: contributor workflow lives in `docs/dev/` only.
- No `docs/adr/`: record architectural rationale in `docs/explanation/`.
- No `docs/reference/glossary.md`: keep terminology local to each doc.

If one of these files is added later, update this list and the matching
rules become active.

## Operational Conventions

- Treat this repository as the source of truth. Deploy changes to
  `/etc/nftables/xray-tproxy.nft` and the systemd unit with
  `sudo install ...` followed by a service restart; do not edit the
  deployed copies directly.
- Do not commit diagnostic reports (`xray-tproxy-diagnose-*.txt`); they
  are covered by `.gitignore`.
- Never commit `xray-config/client/config-*.json` other than
  `config-example.json` — those files carry real server credentials and
  are covered by `.gitignore`. Rotate credentials immediately if one is
  ever committed.
- `xray-tproxy.nft` changes should keep the bypass semantics documented in
  `docs/reference/traffic-selection.md` in sync.
