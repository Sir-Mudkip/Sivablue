# Image signing

Signing is not optional. `system/etc/containers/policy.json` requires every
`ghcr.io/sir-mudkip/sivablue` and `ghcr.io/sir-mudkip/sivablue-nvidia` image to
carry a valid cosign signature made with the key in
`system/usr/lib/pki/containers/sivablue.pub`. A machine will refuse to pull or
`bootc upgrade` to an image that is not correctly signed — the image ref is
`ostree-image-signed:`, set in `build/00-image-info.sh`. This defeats registry
tampering and unsigned or third-party images: an attacker who can push to (or
intercept) the registry still cannot get an unsigned or mis-signed image past
a client running this policy.

## Key setup

One-time setup for a new deployment of this repository:

```bash
cosign generate-key-pair
# Add cosign.key to GitHub repo Secrets as SIGNING_SECRET (used by build.yml)
# Ensure the PUBLIC half shipped in the image matches the private key:
cosign public-key --key cosign.key | diff - system/usr/lib/pki/containers/sivablue.pub
#   -> must be identical, or signing will not satisfy the policy
```

Use a dedicated cosign key for this image only — do not reuse a key that
signs anything else. `SIGNING_SECRET` must stay set in the repository's
GitHub Actions secrets; if it is missing or wrong, the "Sign container image"
step in `build.yml` fails and the publish fails with it, by design, rather
than shipping an image the policy would reject anyway.

Never commit `cosign.key`. It is listed in `.gitignore`; `cosign.pub` (the
public half, identical to `system/usr/lib/pki/containers/sivablue.pub`) is
committed deliberately, since clients need it and it discloses nothing about
the private key.

## Rotation

1. `cosign generate-key-pair`; replace
   `system/usr/lib/pki/containers/sivablue.pub` (and root `cosign.pub`) with
   the new public key.
2. Update `SIGNING_SECRET` with the new private key.
3. Build and publish a newly-signed image before clients drop the old key.

Ordering matters: a client only trusts the public key baked into the image it
is currently running, so the new key has to reach it via a successfully
signed image before the old key stops being used, or that machine loses the
ability to verify (and therefore pull) any further update.

## Verification

After a publish:

```bash
cosign verify --key system/usr/lib/pki/containers/sivablue.pub \
  ghcr.io/sir-mudkip/sivablue:stable          # and :…-nvidia
# Enforcement smoke test (should FAIL with a wrong key):
sudo podman pull --signature-policy ./system/etc/containers/policy.json \
  ghcr.io/sir-mudkip/sivablue:stable
```

The repository's `just verify` recipe wraps the same `cosign verify` check
against the committed `cosign.pub`, for convenience when the key is already
in the working tree.

## Residual risk

This gate stops tampered, unsigned, and third-party images. It does not stop
a fully compromised GitHub account: CI would still sign a malicious build
with the real key, because the signing step in `build.yml` runs with
whatever code and secrets that account's workflow run has access to. Closing
that gap needs controls outside this policy entirely — phishing-resistant
2FA or passkeys plus branch protection with required signed commits, a
publish-approval environment gate, or out-of-band signing with a key the
GitHub account itself cannot use.
