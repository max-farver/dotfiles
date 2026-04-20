# DigitalOcean custom NixOS image runbook

## Prereqs
- `doctl` authenticated (`doctl auth init`)
- Built flake contains `.#do-server-do-image`
- Target Spaces URL is publicly reachable over HTTPS

## 1) Build image
```bash
./scripts/build-do-image.sh --installable .#do-server-do-image
```

## 2) Upload artifact to Spaces
Use the writable decompressed image emitted by the build script:
- default path: `./do-image-artifacts/*.qcow2`

```bash
# optional override output dir
./scripts/build-do-image.sh --installable .#do-server-do-image --decompress-dir ./tmp-do-image
```

## 3) Import custom image
```bash
./scripts/upload-do-image.sh \
  --image-name do-server-$(date +%F) \
  --spaces-url "https://<space>.<region>.digitaloceanspaces.com/<path>/nixos-image-...qcow2.gz" \
  --region <region>
```

## 4) Wait until ready
```bash
doctl compute image list-user
```

## 5) Create droplet from custom image
```bash
doctl compute droplet create do-server-01 \
  --image <image-id-or-slug> \
  --region <region> \
  --size s-1vcpu-1gb \
  --ssh-keys <fingerprint-or-id>
```

## 6) Verify access
```bash
ssh root@<droplet-ip>
```
