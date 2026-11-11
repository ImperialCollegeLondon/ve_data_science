# /// script
# requires-python = ">=3.12"
# dependencies = ["requests"]
# ///
"""---
title: Search OpenAlex for candidate parameter literature

description: |
  Search OpenAlex works or follow citations from a work ID or DOI. Return
  candidate metadata as JSON; results do not verify full-text measurements.

virtual_ecosystem_module: All
status: final
input_files: []
output_files: []
package_dependencies:
  - requests
usage_notes: |
  Run search "QUERY" or snowball --id W... from the repository root with
  uv. Access uses OPENALEX_API_KEY if set, else OPENALEX_EMAIL, else keyless.
  Each is read from the process environment, then the skill's .env. The
  access approach is reported on stderr; the key and email are never printed.
  Results go to stdout; network, HTTP, and JSON errors propagate rather than
  becoming empty results.
  This script neither downloads full text nor changes the repository.
---
"""  # noqa: D205, D400, D415

import argparse
import json
import os
import sys
from pathlib import Path

import requests


def read_setting(name):
    """Return a setting from the process environment, then the skill's .env."""
    value = os.environ.get(name, "").strip()
    if value:
        return value

    env_file = Path(__file__).resolve().parents[1] / ".env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8-sig").splitlines():
            key, separator, value = line.strip().partition("=")
            if separator and key.strip() == name:
                value = value.strip().strip("\"'")
                if value:
                    return value
    return ""


def openalex_access():
    """Return the access approach and headers: API key, then email, then keyless.

    Credentials go in headers, not the URL, so HTTP error messages cannot leak them.
    """
    if key := read_setting("OPENALEX_API_KEY"):
        return "api_key", {"Authorization": f"Bearer {key}"}
    if email := read_setting("OPENALEX_EMAIL"):
        return "email", {"User-Agent": f"ve-constant-search (mailto:{email})"}
    return "keyless", {}


def reconstruct_openalex_abstract(inverted_index):
    """Reconstruct an abstract from OpenAlex word positions."""
    if not inverted_index:
        return ""
    words = sorted(
        (position, word)
        for word, positions in inverted_index.items()
        for position in positions
    )
    return " ".join(word for _, word in words)


def request_openalex(path, params):
    """Get OpenAlex JSON; propagate HTTP, network and invalid JSON errors."""
    _, headers = openalex_access()
    response = requests.get(
        f"https://api.openalex.org/works{path}",
        headers=headers,
        params=params,
        timeout=15,
    )
    response.raise_for_status()
    return response.json()


def paper_record(item):
    """Keep source metadata for manual screening, not a verified value."""
    location = item.get("primary_location") or {}
    source = location.get("source") or {}
    authors = [
        authorship.get("author", {}).get("display_name")
        for authorship in item.get("authorships", [])
    ]
    return {
        "id": item.get("id"),
        "doi": item.get("doi"),
        "title": item.get("title") or "Untitled",
        "authors": [author for author in authors if author],
        "year": item.get("publication_year"),
        "journal": source.get("display_name") or "",
        "abstract": reconstruct_openalex_abstract(item.get("abstract_inverted_index")),
        "pdf_url": (item.get("best_oa_location") or {}).get("pdf_url")
        or location.get("pdf_url")
        or "",
        "landing_url": item.get("doi") or location.get("landing_page_url") or "",
    }


def search_openalex(query, limit=10):
    """Return OpenAlex search candidates; an empty list means a successful search."""
    if not 1 <= limit <= 50:
        raise ValueError("limit must be between 1 and 50")
    data = request_openalex("", {"search": query, "per_page": limit})
    return [paper_record(item) for item in data["results"]]


def fetch_snowball_citations(openalex_id, doi="", limit=10):
    """Fetch backward and forward citation candidates; fail on any request error."""
    if not 1 <= limit <= 50:
        raise ValueError("limit must be between 1 and 50")
    if openalex_id:
        work_id = openalex_id.rsplit("/", 1)[-1]
    elif doi:
        work_id = (
            doi if doi.startswith("https://doi.org/") else f"https://doi.org/{doi}"
        )
    else:
        raise ValueError("Provide an OpenAlex ID or DOI")
    seed = request_openalex(f"/{work_id}", {})
    references = seed.get("referenced_works", [])[:limit]
    backward = []
    if references:
        ids = "|".join(ref.rsplit("/", 1)[-1] for ref in references)
        backward = [
            paper_record(item)
            for item in request_openalex(
                "", {"filter": f"openalex_id:{ids}", "per_page": limit}
            )["results"]
        ]
    forward = [
        paper_record(item)
        for item in request_openalex(
            "", {"filter": f"cites:{seed['id'].rsplit('/', 1)[-1]}", "per_page": limit}
        )["results"]
    ]
    return {
        "seed_id": seed["id"],
        "forward_citations": forward,
        "backward_citations": backward,
    }


def main():
    """Run one search or one citation lookup and emit candidate JSON."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    search = commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=8)
    snowball = commands.add_parser("snowball")
    snowball.add_argument("--id", default="")
    snowball.add_argument("--doi", default="")
    snowball.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    print(f"OpenAlex access: {openalex_access()[0]}", file=sys.stderr)
    if args.command == "search":
        papers = search_openalex(args.query, args.limit)
        result = {"query": args.query, "count": len(papers), "papers": papers}
    else:
        result = fetch_snowball_citations(args.id, args.doi, args.limit)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
