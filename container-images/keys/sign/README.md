# Signing Keys

These keys are for **testing only**. Do not use them in production.

## Cosign

Primary key pair (`cosign.key` / `cosign.pub`) generated with:

```bash
COSIGN_PASSWORD=just1testing2password3 cosign generate-key-pair
```

Second key pair (`cosign2.key` / `cosign2.pub`) generated with:

```bash
COSIGN_PASSWORD=just1testing2password3key2 cosign generate-key-pair
```

This second key is used to produce images signed with a *different* key,
so tests can verify that verification rejects a wrong-key signature.

The `COSIGN_PASSWORD` and `COSIGN_PASSWORD_KEY2` secrets must be configured
in the GitHub repo for the workflow to work.

## GPG ("simple signing")

The GPG key was generated with:

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: Github Runner
Name-Email: git@runner.com
Expire-Date: 0
%commit
EOF
```

Exported with:

```bash
gpg --export-secret-key git@runner.com > github-runner.keys
```

The CI imports it before signing:

```bash
gpg --batch --import keys/sign/github-runner.keys
```
