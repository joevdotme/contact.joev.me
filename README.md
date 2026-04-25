# contact.joev.me

NFC-friendly vCard hosting on S3. Tap a tag → URL → `Content-Type: text/vcard` → iOS and Android both prompt to import the contact. No app required on either platform.

## How it works

1. An S3 bucket named `<subdomain>.<domain>` hosts the VCF file with `Content-Type: text/vcard`
2. A Route 53 CNAME points the subdomain at the S3 website endpoint
3. An NFC tag stores only the URL — the correct content-type header handles the rest on both iOS and Android

## Prerequisites

- AWS account with a domain in Route 53
- AWS IAM user with the permissions listed below
- An NFC tag (NTAG215 or NTAG216 recommended — NTAG213 is too small for a full VCF)

## Fork & customize

1. Fork this repo
2. Edit `config.env` with your values (see below)
3. Rename or replace `joe_violago.vcf` with your own VCF file
4. Add your AWS credentials as GitHub secrets (see below)
5. Run the **Provision S3 Bucket + DNS** workflow once from the Actions tab
6. Program your NFC tag with: `http://<SUBDOMAIN>.<DOMAIN>/<your-file>.vcf`

After that, any push to `main` that touches a `.vcf` file triggers an automatic re-deploy.

## config.env

All non-secret configuration lives in [`config.env`](config.env) at the repo root. Edit this file to customize for your fork — no GitHub UI settings required.

| Variable | Description |
|----------|-------------|
| `AWS_REGION` | AWS region for the S3 bucket |
| `DOMAIN` | Root domain (must have a hosted zone in Route 53) |
| `SUBDOMAIN` | Subdomain prefix — bucket will be `<SUBDOMAIN>.<DOMAIN>` |
| `VCF_FILE` | Filename of the VCF in the repo |

## GitHub secrets

The only things that must be set in **Settings → Secrets and variables → Actions → Secrets** are the AWS credentials:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM secret access key |

## IAM permissions

The IAM user needs the following actions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:HeadBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketWebsite",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<SUBDOMAIN>.<DOMAIN>",
        "arn:aws:s3:::<SUBDOMAIN>.<DOMAIN>/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZonesByName",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "*"
    }
  ]
}
```

## Makefile reference

All variables can be overridden on the command line, e.g. `make deploy REGION=us-west-2`.

| Target | Description |
|--------|-------------|
| `make provision` | Create S3 bucket + public access policy + website config + CNAME record (idempotent) |
| `make deploy` | Upload VCF to S3 with correct content-type and no-cache headers |
| `make destroy` | Remove CNAME record, empty bucket, delete bucket |
| `make s3` | S3 steps only (skips DNS) |
| `make dns` | DNS CNAME upsert only (skips S3) |
| `make dns-destroy` | Remove CNAME record only |

## NFC tag

Write a single **URI record** to the tag pointing to:

```
http://<SUBDOMAIN>.<DOMAIN>/<VCF_FILE>
```

A single URL record is all you need — do not write a vCard record alongside it. Android's NFC dispatcher reads the first record only, so a second vCard record will be silently ignored. The `Content-Type: text/vcard` header served by S3 is what triggers the "Add to Contacts" prompt on both platforms.

Recommended tags: NTAG215 (504 bytes) or NTAG216 (888 bytes).
