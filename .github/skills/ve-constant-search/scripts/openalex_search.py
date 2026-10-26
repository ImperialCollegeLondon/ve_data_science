# /// script
# requires-python = ">=3.12"
# dependencies = ["requests"]
# ///
"""Search OpenAlex and follow citations without downloading or scoring papers."""

import argparse
import json
import os

import requests


def get_openalex_email():
    """Return the user-provided contact address or fail before searching."""
    email = os.environ.get("OPENALEX_EMAIL", "").strip()
    if not email:
        raise ValueError("Set OPENALEX_EMAIL in the process environment")
    return email


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
    email = get_openalex_email()
    response = requests.get(
        f"https://api.openalex.org/works{path}",
        headers={"User-Agent": f"ve-constant-search (mailto:{email})"},
        params={**params, "mailto": email},
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
        "referenced_works": item.get("referenced_works", []),
    }


def search_openalex(query, limit=25):
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
    search.add_argument("--limit", type=int, default=25)
    snowball = commands.add_parser("snowball")
    snowball.add_argument("--id", default="")
    snowball.add_argument("--doi", default="")
    snowball.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    if args.command == "search":
        papers = search_openalex(args.query, args.limit)
        result = {"query": args.query, "count": len(papers), "papers": papers}
    else:
        result = fetch_snowball_citations(args.id, args.doi, args.limit)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
