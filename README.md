# TrailCount homepage

Static landing page for `trailcount.io` — product-level brand presence,
tenant-agnostic. Replaces the original plan to host this on Squarespace.

## Layout

```
homepage/
├── index.html                       single-page site, inline CSS
├── trailcount-logo-primary.svg      hero logo (mirrored from branding/trailcount/)
├── trailcount-icon.svg              tab favicon SVG fallback
├── favicon.ico                      multi-resolution favicon
└── README.md                        this file
```

No build step. Edit `index.html` directly. The TrailCount brand assets
here are mirrored copies from the umbrella project's `branding/trailcount/`
— if the source SVGs there change, re-copy them in.

## Deploy

The site is served from AWS (S3 + CloudFront + ACM cert) on the
`trailcount.io` apex domain, with DNS managed at Squarespace
(DNS-only — no Squarespace hosting plan).

Terraform under `terraform/` is the source of truth. To deploy a
content change:

```bash
cd terraform
AWS_PROFILE=trail-admin terraform apply
```

A `null_resource` in `s3.tf` keyed on a hash of the homepage files
(`index.html`, `favicon.ico`, `trailcount-icon.svg`,
`trailcount-logo-primary.svg`) re-runs `aws s3 sync` whenever any of
those changes, then invalidates the CloudFront cache. So editing the
HTML and running `terraform apply` is the full deploy.

## Email forwarding

The same Terraform stack also wires up `contact@trailcount.io` →
`craigmcg.acc@gmail.com` via SES inbound + a Python Lambda
(`terraform/lambda/forwarder.py`) + SES outbound. The forwarder
rewrites `From` to `forwarder@trailcount.io` and preserves the
original sender in `Reply-To`. SES is in sandbox mode — sufficient
for forwarding to a single verified Gmail; expanding to other
recipients would require either verifying each one or filing an
AWS support request to leave sandbox.

## Branding

Uses the TrailCount palette:

- `#6a9e5e` primary green
- `#1e3a18` dark green text
- `#ddd8c4` accent cream
- `#4e8040` muted green for secondary text
