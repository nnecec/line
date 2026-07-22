# Plan 004: Clean up CI Development cert material

> **Drift check**: `git diff --stat 2205ed1..HEAD -- scripts/release/install_development_cert.sh .github/workflows/publish.yml`
> Never print or commit secret values (P12 passwords, base64 cert contents).

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `2205ed1`, 2026-07-22

## Why this matters

Publish CI decodes a Development `.p12` to disk and imports with `security import … -A`
(allow all applications). The `.p12` is never deleted; keychain is not torn down on
job end. Widens blast radius on compromised runners.

## Current state

`scripts/release/install_development_cert.sh` (~28–59):

```bash
printf '%s' "$APPLE_DEVELOPMENT_CERT_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"
...
security import "$CERTIFICATE_PATH" \
  -P "$P12_PASSWORD" \
  -A \
  ...
```

Used by `.github/workflows/publish.yml`.

## Commands

| Purpose | Command | Expected |
|---------|---------|----------|
| Shell syntax | `bash -n scripts/release/install_development_cert.sh` | exit 0 |
| Grep | `rg -n "rm|trap|-A|CERTIFICATE_PATH" scripts/release/install_development_cert.sh` | shows cleanup + no bare -A if removed |

## Scope

**In scope**:
- `scripts/release/install_development_cert.sh`
- `.github/workflows/publish.yml` only if needed for explicit cleanup step / trap documentation

**Out of scope**:
- Changing signing identity type (Apple Development stays)
- App source

## Git workflow

- Branch: `advisor/004-ci-cert-cleanup`
- Commit: `ci: remove Development cert material after import`

## Steps

### Step 1: Delete p12 after import

After successful `security import`, add:

```bash
rm -f "$CERTIFICATE_PATH"
```

Use `trap` so even failure paths remove the file:

```bash
cleanup() {
  rm -f "$CERTIFICATE_PATH"
}
trap cleanup EXIT
```

Place trap after CERTIFICATE_PATH is set, before decode.

### Step 2: Narrow private-key ACL

Replace `-A` with partition-list-based access already applied after import. Preferred:

```bash
security import "$CERTIFICATE_PATH" \
  -P "$P12_PASSWORD" \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
# then existing set-key-partition-list
```

If codesign fails without `-A` in GitHub-hosted macOS (you may not be able to verify live), keep a comment that partition-list is required and use:

```bash
security import ... -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/productbuild
```

instead of `-A`.

Do **not** echo passwords.

### Step 3: Optional keychain teardown helper

Add commented or optional section / second script function documenting:

```bash
# After signing job: security delete-keychain "$KEYCHAIN_PATH"
```

If `publish.yml` has a clear place after packaging, add a step `security delete-keychain` with `if: always()` — only if KEYCHAIN_PATH is exported as env for later steps (script already echoes KEYCHAIN_PATH=).

Read publish.yml for how identity is consumed; only add teardown if safe.

**Verify**: `bash -n` passes; no secrets in diff

## Done criteria

- [ ] `.p12` removed on EXIT after use
- [ ] No unrestricted `-A` without compensating restriction (prefer remove -A)
- [ ] `bash -n` clean
- [ ] No secret values in committed files

## STOP conditions

- Unclear how publish.yml consumes KEYCHAIN_PATH and teardown would break publish mid-job

## Maintenance notes

- Any new CI signing path must reuse this script, not raw import
