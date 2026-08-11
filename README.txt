TopRank Digital Solutions
=========================

Static website for https://toprankdigitalsolutions.com/.

The site is intentionally framework-free and deploys through GitHub Pages.
Core production files:

- index.html — homepage content, metadata, structured data, and analytics
- 404.html — branded missing-page fallback
- assets/css/main.css — responsive visual system
- tests/site-smoke.sh — repeatable content and deployment checks

Run the smoke checks from the repository root:

    tests/site-smoke.sh

For local review, serve the repository with any static HTTP server and verify
the homepage and 404 page at mobile, tablet, and desktop widths.
