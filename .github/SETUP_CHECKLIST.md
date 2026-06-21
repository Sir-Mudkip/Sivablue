# Repository Setup Checklist

## Initial Setup

### 1. Rename Template
- [ ] Update `finpilot` to your name in: Containerfile, Justfile, README.md, artifacthub-repo.yml

### 2. Enable GitHub Actions
- [ ] Settings → Actions → General → Enable workflows
- [ ] Set "Read and write permissions"

### 3. First Push
```bash
git add .
git commit -m "feat: initial customization"
git push origin main
```

### 4. Deploy
```bash
sudo bootc switch --transport registry ghcr.io/YOUR_USERNAME/YOUR_REPO:stable
sudo systemctl reboot
```

## Image Signing (REQUIRED — enforced on clients)

Signing is **not optional**: `system/etc/containers/policy.json` requires every
`ghcr.io/sir-mudkip/sivablue` and `ghcr.io/sir-mudkip/sivablue-nvidia` image to
carry a valid cosign signature made with the key in
`system/usr/lib/pki/containers/sivablue.pub`. A machine will **refuse to pull or
`bootc upgrade`** to an image that isn't correctly signed (the image ref is
`ostree-image-signed:`). This defeats registry tampering and unsigned/third-party
images.

### Key setup (one time)
```bash
cosign generate-key-pair
# Add cosign.key to GitHub repo Secrets as SIGNING_SECRET (used by build.yml)
# Ensure the PUBLIC half shipped in the image matches the private key:
cosign public-key --key cosign.key | diff - system/usr/lib/pki/containers/sivablue.pub
#   -> must be identical, or signing will not satisfy the policy
```
- Use a **dedicated** cosign key for this image only.
- `SIGNING_SECRET` must stay set; if signing fails, publishing fails by design.

### Key rotation
1. `cosign generate-key-pair`; replace `system/usr/lib/pki/containers/sivablue.pub`
   (and root `cosign.pub`) with the new public key.
2. Update `SIGNING_SECRET` with the new private key.
3. Build/publish a newly-signed image **before** clients drop the old key.

### Verify (after a publish)
```bash
cosign verify --key system/usr/lib/pki/containers/sivablue.pub \
  ghcr.io/sir-mudkip/sivablue:stable          # and :…-nvidia
# Enforcement smoke test (should FAIL with a wrong key):
sudo podman pull --signature-policy ./system/etc/containers/policy.json \
  ghcr.io/sir-mudkip/sivablue:stable
```

> ⚠️ Residual risk: this gate stops tampered/unsigned/third-party images, but it
> does **not** stop a *fully compromised GitHub account* — CI would still sign a
> malicious build with the real key. To close that gap, add phishing-resistant
> 2FA/passkeys + branch protection (required signed commits), a publish-approval
> environment gate, or out-of-band signing (a key the GitHub account can't use).

