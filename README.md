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
`trailcount.io` apex domain, with DNS still managed at Squarespace.
Deploy automation is TBD — see the umbrella project's `CUTOVER_PLAN.md`
Track C, which originally scoped this as a Squarespace landing page.

## Branding

Uses the TrailCount palette:

- `#6a9e5e` primary green
- `#1e3a18` dark green text
- `#ddd8c4` accent cream
- `#4e8040` muted green for secondary text
