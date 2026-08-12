# Contributor Documentation

Contributor-only documentation. User documentation lives under
`docs/how-to/`, `docs/reference/`, and `docs/explanation/`; do not mix the
two.

## Pages

| Page | Purpose |
|------|---------|
| [Project Layout](project-layout.md) | Repository tree map and where new files go |
| [Documentation Governance](documentation/index.md) | Rules for organizing, writing, and reviewing docs |

## Notes

- The repository has no automated test suite. Verification is manual; see
  [How to Verify the Setup](../how-to/verify-the-setup.md).
- The repository has no release process yet; deployments are done by hand
  with `sudo install ...` followed by a service restart.
