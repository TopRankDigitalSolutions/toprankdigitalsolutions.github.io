#!/usr/bin/env bash

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
home="$repo_root/index.html"
not_found="$repo_root/404.html"
expected_calendly="https://calendly.com/jpruiz114/30min"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local file=$1 text=$2
  rg -Fq "$text" "$file" || fail "missing '$text' in ${file#"$repo_root/"}"
}

for file in "$home" "$not_found" "$repo_root/CNAME" "$repo_root/robots.txt" "$repo_root/sitemap.xml"; do
  [ -f "$file" ] || fail "missing ${file#"$repo_root/"}"
done

for section_id in services engagement experience approach consultation; do
  require_text "$home" "id=\"$section_id\""
done

for heading in "Cybersecurity" "Software Development" "Applied AI" "Cloud Engineering"; do
  require_text "$home" "$heading"
done

require_text "$home" "Project delivery"
require_text "$home" "Ongoing partnership"
require_text "$home" "rel=\"canonical\""
require_text "$home" "href=\"#main-content\""
require_text "$not_found" "href=\"/\""

python3 - "$home" "$expected_calendly" <<'PY'
import json
import sys
from html.parser import HTMLParser

home_path, expected_calendly = sys.argv[1:]
expected_services = {
    "Cybersecurity",
    "Software Development",
    "Applied AI",
    "Cloud Engineering",
}


def fail(message):
    raise SystemExit(f"FAIL: {message}")


class HomepageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.anchors = []
        self.ids = set()
        self.json_ld_scripts = []
        self._anchor = None
        self._json_ld = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        element_id = attributes.get("id")
        if element_id:
            self.ids.add(element_id)
        if tag == "a":
            self._anchor = {"href": attributes.get("href", ""), "text": []}
        elif tag == "script" and attributes.get("type", "").lower() == "application/ld+json":
            self._json_ld = []

    def handle_data(self, data):
        if self._anchor is not None:
            self._anchor["text"].append(data)
        if self._json_ld is not None:
            self._json_ld.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self._anchor is not None:
            self._anchor["text"] = " ".join("".join(self._anchor["text"]).split())
            self.anchors.append(self._anchor)
            self._anchor = None
        elif tag == "script" and self._json_ld is not None:
            self.json_ld_scripts.append("".join(self._json_ld))
            self._json_ld = None


parser = HomepageParser()
with open(home_path, encoding="utf-8") as homepage:
    parser.feed(homepage.read())

calendly_anchors = [anchor for anchor in parser.anchors if anchor["href"] == expected_calendly]
if len(calendly_anchors) < 3:
    fail(f"expected at least 3 Calendly anchors, found {len(calendly_anchors)}")
if any(not anchor["text"] for anchor in calendly_anchors):
    fail("Calendly anchors must have meaningful non-empty text")

unresolved_hash_links = sorted({
    anchor["href"]
    for anchor in parser.anchors
    if anchor["href"].startswith("#")
    and len(anchor["href"]) > 1
    and anchor["href"][1:] not in parser.ids
})
if unresolved_hash_links:
    fail(f"hash-navigation anchors do not resolve: {', '.join(unresolved_hash_links)}")

if not parser.json_ld_scripts:
    fail("missing application/ld+json structured data")
try:
    structured_data = [json.loads(script) for script in parser.json_ld_scripts]
except (json.JSONDecodeError, AttributeError) as error:
    fail(f"invalid application/ld+json structured data: {error}")
organizations = [
    item
    for item in structured_data
    if isinstance(item, dict) and item.get("@type") == "Organization"
]
if len(organizations) != 1:
    fail(f"expected exactly one Organization JSON-LD object, found {len(organizations)}")

organization = organizations[0]
if organization.get("name") != "TopRank Digital Solutions":
    fail("Organization JSON-LD has an unexpected name")
if organization.get("url") != "https://toprankdigitalsolutions.com/":
    fail("Organization JSON-LD has an unexpected URL")
if set(organization.get("knowsAbout", [])) != expected_services:
    fail("Organization JSON-LD must list the four approved service names")
PY

if rg -qi 'etsy|nrcc|pacer|client logos?|our clients|clients who trust' "$home" "$not_found"; then
  fail "found a forbidden organization or direct-client implication"
fi

if rg -qi 'digital marketing|lead generation' "$home"; then
  fail "legacy positioning remains in the homepage"
fi

if rg -q 'jquery|dropotron|scrolly|breakpoints\.min|browser\.min|util\.js|calendly-inline-widget' "$home" "$not_found"; then
  fail "legacy scripts or embedded Calendly markup remain"
fi

if rg -q 'user-scalable=no' "$home" "$not_found"; then
  fail "viewport prevents user scaling"
fi

if rg -q 'fontawesome|webfonts|pic05\.jpg|banner\.jpg' "$home" "$not_found" "$repo_root/assets/css/main.css"; then
  fail "retired visual assets remain referenced"
fi

require_text "$repo_root/CNAME" "toprankdigitalsolutions.com"
require_text "$repo_root/robots.txt" "https://toprankdigitalsolutions.com/sitemap.xml"
require_text "$repo_root/sitemap.xml" "https://toprankdigitalsolutions.com/"

printf 'Site smoke checks passed.\n'
