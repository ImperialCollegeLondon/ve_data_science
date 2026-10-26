# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "requests",
#     "curl-cffi",
#     "pymupdf4llm",
#     "pymupdf",
#     "beautifulsoup4",
# ]
# ///

"""Search and screen literature with OpenAlex and optional Google Scholar.

Run from the repository root with `uv run` and a command such as `search` or
`seed-reviews`. See the skill's SKILL.md for the workflow and email setup.
OpenAlex requests need `OPENALEX_EMAIL` from the process environment or a local
`.env` file; no address is bundled with this script.
"""

import argparse
import json
import math
import os
import sys

import fitz
import pymupdf4llm
import requests
from bs4 import BeautifulSoup
from curl_cffi import requests as cffi_requests


def load_env_variables():
    """Read local .env files without replacing process environment variables.

    Check the script directory, skill directory, and its parent, in that order.
    Each file is read as KEY=VALUE lines, not shell commands.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.abspath(os.path.join(script_dir, ".env")),
        os.path.abspath(os.path.join(script_dir, "..", ".env")),
        os.path.abspath(os.path.join(script_dir, "..", "..", ".env")),
    ]
    for env_path in candidates:
        if os.path.exists(env_path):
            try:
                with open(env_path, encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            k, v = k.strip(), v.strip()
                            if (v.startswith('"') and v.endswith('"')) or (
                                v.startswith("'") and v.endswith("'")
                            ):
                                v = v[1:-1]
                            if k not in os.environ:
                                os.environ[k] = v
            except Exception:
                pass


def get_openalex_email():
    """Return the configured contact email or fail before an OpenAlex request."""
    load_env_variables()
    email = os.environ.get("OPENALEX_EMAIL", "").strip()
    if not email:
        raise ValueError("Set OPENALEX_EMAIL in the environment or skill .env file")
    return email


def get_serpapi_key():
    load_env_variables()
    return os.environ.get("SERPAPI_API_KEY", "")


def reconstruct_openalex_abstract(inverted_index):
    """Reconstruct abstract string from OpenAlex abstract_inverted_index."""
    if not inverted_index or not isinstance(inverted_index, dict):
        return ""
    word_positions = []
    for word, positions in inverted_index.items():
        for pos in positions:
            word_positions.append((pos, word))
    word_positions.sort(key=lambda x: x[0])
    return " ".join(w[1] for w in word_positions)


def load_publisher_config():
    """Load publisher_quality.json configuration."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.abspath(
        os.path.join(script_dir, "..", "config", "publisher_quality.json")
    )
    if os.path.exists(config_path):
        try:
            with open(config_path, encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(
                f"Warning: Could not read publisher_quality.json: {e}", file=sys.stderr
            )
    return {
        "flagged_publishers": {
            "MDPI": {"weight_multiplier": 0.6, "flag": "Scrutinize review rigour."},
            "Hindawi": {
                "weight_multiplier": 0.5,
                "flag": "Paper-mill retractions history.",
            },
            "OMICS": {"weight_multiplier": 0.1, "flag": "Predatory publisher."},
        },
        "trusted_repositories": [
            "arXiv",
            "bioRxiv",
            "PubMed",
            "ScienceDirect",
            "Springer",
            "Wiley",
        ],
    }


def search_openalex(query, limit=25):
    """Search OpenAlex REST API for works matching query."""
    email = get_openalex_email()
    headers = {"User-Agent": f"AiSkillsDeepLit/1.0 (mailto:{email})"}
    url = "https://api.openalex.org/works"
    params = {"search": query, "per_page": min(limit, 50), "mailto": email}
    results = []
    try:
        resp = requests.get(url, headers=headers, params=params, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        for item in data.get("results", []):
            primary_loc = item.get("primary_location") or {}
            source = primary_loc.get("source") or {}
            publisher = source.get("host_organization_name") or ""
            journal = source.get("display_name") or ""

            authorships = item.get("authorships", [])
            authors = [
                a.get("author", {}).get("display_name")
                for a in authorships
                if a.get("author", {}).get("display_name")
            ]

            abstract = reconstruct_openalex_abstract(
                item.get("abstract_inverted_index")
            )

            pdf_url = ""
            best_oa = item.get("best_oa_location") or {}
            if best_oa.get("pdf_url"):
                pdf_url = best_oa.get("pdf_url")
            elif primary_loc.get("pdf_url"):
                pdf_url = primary_loc.get("pdf_url")

            results.append(
                {
                    "id": item.get("id"),
                    "doi": item.get("doi"),
                    "title": item.get("title") or "Untitled",
                    "authors": authors,
                    "year": item.get("publication_year"),
                    "journal": journal,
                    "publisher": publisher,
                    "abstract": abstract,
                    "citation_count": item.get("cited_by_count", 0),
                    "pdf_url": pdf_url,
                    "landing_url": item.get("doi")
                    or primary_loc.get("landing_page_url")
                    or "",
                    "referenced_works": item.get("referenced_works", []),
                    "source_api": "openalex",
                }
            )
    except Exception as e:
        print(f"Notice: OpenAlex search error: {e}", file=sys.stderr)
    return results


def search_google_scholar(query, limit=20, start=0):
    """Search Google Scholar via SerpAPI with pagination support."""
    api_key = get_serpapi_key()
    if not api_key:
        return []
    url = "https://serpapi.com/search"
    params = {
        "engine": "google_scholar",
        "api_key": api_key,
        "q": query,
        "num": min(limit, 20),
        "start": start,
    }
    results = []
    try:
        resp = requests.get(url, params=params, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        organic = data.get("organic_results", [])
        for idx, item in enumerate(organic):
            pub_info = item.get("publication_info", {})
            summary = pub_info.get("summary", "")

            pdf_url = ""
            for res in item.get("resources", []):
                if (
                    res.get("file_format") == "PDF"
                    or "pdf" in res.get("title", "").lower()
                ):
                    pdf_url = res.get("link")
                    break

            inline = item.get("inline_links", {})
            cited_by = inline.get("cited_by", {})
            cite_count = cited_by.get("total", 0) if isinstance(cited_by, dict) else 0

            results.append(
                {
                    "id": f"scholar_{item.get('result_id', idx + start)}",
                    "doi": "",
                    "title": item.get("title") or "",
                    "authors": [summary],
                    "year": None,
                    "journal": summary,
                    "publisher": "",
                    "abstract": item.get("snippet") or "",
                    "citation_count": cite_count,
                    "pdf_url": pdf_url,
                    "landing_url": item.get("link") or "",
                    "referenced_works": [],
                    "source_api": "google_scholar",
                }
            )
    except Exception as e:
        print(f"Notice: Scholar search error: {e}", file=sys.stderr)
    return results


def deep_search(query, limit=40):
    """Perform combined deep search across OpenAlex and Google Scholar."""
    all_results = []
    seen_titles = set()

    # 1. Fetch OpenAlex results (up to limit/2)
    alex_res = search_openalex(query, limit=limit // 2)
    for r in alex_res:
        norm_title = (r.get("title") or "").lower().strip()
        if norm_title and norm_title not in seen_titles:
            seen_titles.add(norm_title)
            all_results.append(r)

    # 2. Fetch Google Scholar results across pages 0 and 20
    scholar_res_p1 = search_google_scholar(query, limit=20, start=0)
    scholar_res_p2 = (
        search_google_scholar(query, limit=20, start=20) if limit > 20 else []
    )

    for r in scholar_res_p1 + scholar_res_p2:
        norm_title = (r.get("title") or "").lower().strip()
        if norm_title and norm_title not in seen_titles:
            seen_titles.add(norm_title)
            all_results.append(r)

    return all_results[:limit]


def screen_and_score_papers(papers, target_terms, min_relevance=0.15):
    """Score papers on relevance, citations, recency, and publisher quality."""
    pub_config = load_publisher_config()
    flagged_pub_map = pub_config.get("flagged_publishers", {})

    terms = [t.lower().strip() for t in target_terms if t.strip()]
    scored = []

    for paper in papers:
        title = (paper.get("title") or "").lower()
        abstract = (paper.get("abstract") or "").lower()
        text = f"{title} {abstract}"

        # 1. Relevance Score (Keyword match ratio)
        matched_terms = [t for t in terms if t in text]
        rel_score = len(matched_terms) / max(len(terms), 1)

        # 2. Citation Tier Score (Log-scaled citation boost with base)
        cites = paper.get("citation_count") or 0
        cite_score = min(
            1.0, math.log10(cites + 1) / 4.0
        )  # 0 cites -> 0.0, 1000 cites -> ~0.75, 10k -> 1.0

        # 3. Recency Factor
        year = paper.get("year")
        recency_score = 0.5
        if year:
            curr_year = 2026
            diff = curr_year - year
            if diff <= 3:
                recency_score = 1.0
            elif diff <= 10:
                recency_score = 0.8
            elif diff <= 20:
                recency_score = 0.5
            else:
                recency_score = 0.3

        # 4. Publisher Quality & Warning Flags
        pub_name = (paper.get("publisher") or "").strip()
        journal_name = (paper.get("journal") or "").strip()

        pub_multiplier = 1.0
        pub_flag = ""

        for flag_name, flag_info in flagged_pub_map.items():
            if (
                flag_name.lower() in pub_name.lower()
                or flag_name.lower() in journal_name.lower()
            ):
                pub_multiplier = flag_info.get("weight_multiplier", 0.6)
                pub_flag = flag_info.get("flag", "Flagged publisher")
                break

        # Composite Score Calculation
        raw_composite = (
            (rel_score * 0.50) + (cite_score * 0.30) + (recency_score * 0.20)
        )
        final_score = round(raw_composite * pub_multiplier, 4)

        # PRISMA Classification
        is_included = rel_score >= min_relevance and final_score >= 0.15
        exclusion_reason = ""
        if not is_included:
            if rel_score < min_relevance:
                exclusion_reason = "Low relevance in abstract/title screening"
            else:
                exclusion_reason = "Composite score below threshold"

        scored.append(
            {
                "id": paper.get("id"),
                "doi": paper.get("doi"),
                "title": paper.get("title"),
                "authors": paper.get("authors"),
                "year": paper.get("year"),
                "journal": paper.get("journal"),
                "publisher": paper.get("publisher"),
                "abstract": paper.get("abstract"),
                "citation_count": cites,
                "pdf_url": paper.get("pdf_url"),
                "landing_url": paper.get("landing_url"),
                "scores": {
                    "relevance": round(rel_score, 3),
                    "citation_tier": round(cite_score, 3),
                    "recency": round(recency_score, 3),
                    "publisher_multiplier": pub_multiplier,
                    "final_composite": final_score,
                },
                "publisher_flag": pub_flag,
                "prisma_status": "included" if is_included else "excluded",
                "exclusion_reason": exclusion_reason,
                "matched_terms": matched_terms,
            }
        )

    scored.sort(key=lambda x: x["scores"]["final_composite"], reverse=True)
    return scored


def fetch_snowball_citations(openalex_id, doi="", limit=10):
    """Fetch forward (citing) and backward (referenced) citations via OpenAlex API."""
    email = get_openalex_email()
    headers = {"User-Agent": f"AiSkillsDeepLit/1.0 (mailto:{email})"}

    target_id = openalex_id
    if not target_id and doi:
        target_id = f"https://doi.org/{doi}"

    if not target_id:
        return {"forward_citations": [], "backward_citations": []}

    # Standardize OpenAlex ID format
    clean_id = target_id.split("/")[-1]

    forward_results = []
    backward_results = []

    # 1. Backward Citations (works referenced by this paper)
    try:
        url_work = f"https://api.openalex.org/works/{clean_id}"
        resp = requests.get(
            url_work, headers=headers, params={"mailto": email}, timeout=15
        )
        if resp.status_code == 200:
            work_data = resp.json()
            ref_ids = work_data.get("referenced_works", [])[:limit]
            if ref_ids:
                # Fetch details for referenced works
                ref_filter = "|".join([r.split("/")[-1] for r in ref_ids])
                resp_refs = requests.get(
                    "https://api.openalex.org/works",
                    headers=headers,
                    params={
                        "filter": f"openalex_id:{ref_filter}",
                        "per_page": limit,
                        "mailto": email,
                    },
                    timeout=15,
                )
                if resp_refs.status_code == 200:
                    for item in resp_refs.json().get("results", []):
                        abstract = reconstruct_openalex_abstract(
                            item.get("abstract_inverted_index")
                        )
                        backward_results.append(
                            {
                                "id": item.get("id"),
                                "doi": item.get("doi"),
                                "title": item.get("title") or "Untitled",
                                "year": item.get("publication_year"),
                                "citation_count": item.get("cited_by_count", 0),
                                "abstract": abstract,
                                "relation": "referenced_by_seed",
                            }
                        )
    except Exception as e:
        print(f"Notice: Backward snowballing error: {e}", file=sys.stderr)

    # 2. Forward Citations (works citing this paper)
    try:
        url_cites = "https://api.openalex.org/works"
        resp_cites = requests.get(
            url_cites,
            headers=headers,
            params={
                "filter": f"cites:{clean_id}",
                "per_page": limit,
                "sort": "cited_by_count:desc",
                "mailto": email,
            },
            timeout=15,
        )
        if resp_cites.status_code == 200:
            for item in resp_cites.json().get("results", []):
                abstract = reconstruct_openalex_abstract(
                    item.get("abstract_inverted_index")
                )
                forward_results.append(
                    {
                        "id": item.get("id"),
                        "doi": item.get("doi"),
                        "title": item.get("title") or "Untitled",
                        "year": item.get("publication_year"),
                        "citation_count": item.get("cited_by_count", 0),
                        "abstract": abstract,
                        "relation": "cites_seed",
                    }
                )
    except Exception as e:
        print(f"Notice: Forward snowballing error: {e}", file=sys.stderr)

    return {
        "seed_id": clean_id,
        "forward_citations": forward_results,
        "backward_citations": backward_results,
    }


def download_paper(url, output_path):
    """Download PDF or HTML paper file."""
    dir_name = os.path.dirname(output_path)
    if dir_name and not os.path.exists(dir_name):
        os.makedirs(dir_name, exist_ok=True)

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    print(f"Downloading from {url} to {output_path}...", file=sys.stderr)
    try:
        response = requests.get(url, headers=headers, stream=True, timeout=15)
        response.raise_for_status()
        with open(output_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"Download complete! Saved to {output_path}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"Notice: Download failed for {url} ({e})", file=sys.stderr)
        if os.path.exists(output_path):
            try:
                os.remove(output_path)
            except Exception:
                pass
        return False


def extract_file_text(file_path, page_range=None):
    """Extract text/markdown from PDF, HTML, or TXT file."""
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    ext = os.path.splitext(file_path)[1].lower()

    if ext == ".pdf":
        try:
            doc = fitz.open(file_path)
            total_pages = len(doc)
            md_text = pymupdf4llm.to_markdown(doc)
            print(
                f"--- PDF Document: {os.path.basename(file_path)} (Total Pages: {total_pages}) ---\n"
            )
            print(md_text)
        except Exception as e:
            print(f"Error reading PDF: {e}", file=sys.stderr)
            sys.exit(1)
    elif ext in [".html", ".htm"]:
        try:
            with open(file_path, encoding="utf-8", errors="ignore") as f:
                content = f.read()
            soup = BeautifulSoup(content, "html.parser")
            for tag in soup(["script", "style", "nav", "header", "footer", "aside"]):
                tag.decompose()
            text = soup.get_text(separator="\n")
            lines = [line.strip() for line in text.split("\n") if line.strip()]
            clean_text = "\n".join(lines)
            print(f"--- HTML Document: {os.path.basename(file_path)} ---\n")
            print(clean_text)
        except Exception as e:
            print(f"Error reading HTML: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        try:
            with open(file_path, encoding="utf-8", errors="ignore") as f:
                content = f.read()
            print(f"--- Document: {os.path.basename(file_path)} ---\n")
            print(content)
        except Exception as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            sys.exit(1)


def smart_download_paper(url, output_path, doi=None, email=None):
    """Try Europe PMC, the source URL, then Unpaywall for full text.

    The Unpaywall fallback uses the supplied email, or `OPENALEX_EMAIL` if none
    is supplied. Earlier download attempts do not need an email.
    """
    dir_name = os.path.dirname(output_path)
    if dir_name and not os.path.exists(dir_name):
        os.makedirs(dir_name, exist_ok=True)

    abs_outpath = os.path.abspath(output_path)

    if not doi and url and "10." in url:
        try:
            parts = url.split("10.")
            doi_candidate = "10." + parts[1].split()[0].split("?")[0].rstrip("/")
            if "/" in doi_candidate and len(doi_candidate) > 7:
                doi = doi_candidate
        except Exception:
            pass

    # Tier 1: Europe PMC API Lookup if DOI available
    if doi:
        print(f"[Tier 1] Querying Europe PMC API for DOI: {doi}...", file=sys.stderr)
        try:
            epmc_url = f'https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:"{doi}"&resultType=core&format=json'
            r = requests.get(epmc_url, timeout=10)
            if r.status_code == 200:
                data = r.json()
                results = data.get("resultList", {}).get("result", [])
                if results:
                    ft_list = (
                        results[0].get("fullTextUrlList", {}).get("fullTextUrl", [])
                    )
                    pmc_pdf_url = None
                    pmc_html_url = None
                    for ft in ft_list:
                        if ft.get("documentStyle") == "pdf":
                            pmc_pdf_url = ft.get("url")
                        elif ft.get("documentStyle") == "html":
                            pmc_html_url = ft.get("url")

                    target_epmc = pmc_pdf_url or pmc_html_url
                    if target_epmc:
                        print(
                            f"[Tier 1 Success] Downloading from Europe PMC link: {target_epmc}",
                            file=sys.stderr,
                        )
                        res = cffi_requests.get(
                            target_epmc,
                            impersonate="chrome124",
                            timeout=15,
                            allow_redirects=True,
                        )
                        if res.status_code == 200 and (
                            res.content.startswith(b"%PDF") or len(res.content) > 10000
                        ):
                            with open(abs_outpath, "wb") as f:
                                f.write(res.content)
                            print(
                                f"Download complete! Saved to {abs_outpath}",
                                file=sys.stderr,
                            )
                            return True
        except Exception as e:
            print(f"[Tier 1 Warning] Europe PMC lookup failed: {e}", file=sys.stderr)

    # Tier 2: Direct GET via curl_cffi Browser TLS Impersonation
    if url:
        print(
            f"[Tier 2] Fetching primary URL via curl_cffi (Chrome TLS spoof): {url}...",
            file=sys.stderr,
        )
        try:
            res = cffi_requests.get(
                url, impersonate="chrome124", timeout=15, allow_redirects=True
            )
            if res.status_code == 200 and res.content.startswith(b"%PDF"):
                with open(abs_outpath, "wb") as f:
                    f.write(res.content)
                print(f"Download complete! Saved to {abs_outpath}", file=sys.stderr)
                return True
            elif res.status_code == 200:
                try:
                    soup = BeautifulSoup(res.content, "html.parser")
                    meta_pdf = soup.find(
                        "meta", {"name": "citation_pdf_url"}
                    ) or soup.find("meta", {"property": "citation_pdf_url"})
                    if meta_pdf and meta_pdf.get("content"):
                        pdf_link = meta_pdf.get("content")
                        print(
                            f"[Tier 2 Meta PDF] Found citation_pdf_url: {pdf_link}",
                            file=sys.stderr,
                        )
                        res2 = cffi_requests.get(
                            pdf_link,
                            impersonate="chrome124",
                            timeout=15,
                            allow_redirects=True,
                        )
                        if res2.status_code == 200 and res2.content.startswith(b"%PDF"):
                            with open(abs_outpath, "wb") as f:
                                f.write(res2.content)
                            print(
                                f"Download complete! Saved to {abs_outpath}",
                                file=sys.stderr,
                            )
                            return True
                except Exception:
                    pass
        except Exception as e:
            print(f"[Tier 2 Warning] curl_cffi download failed: {e}", file=sys.stderr)

    # Tier 3: Unpaywall API Fallback
    if doi:
        print(f"[Tier 3] Querying Unpaywall API for DOI: {doi}...", file=sys.stderr)
        try:
            unpaywall_email = email or get_openalex_email()
            unpaywall_url = f"https://api.unpaywall.org/v2/{doi}"
            r = requests.get(
                unpaywall_url, params={"email": unpaywall_email}, timeout=10
            )
            if r.status_code == 200:
                data = r.json()
                best_oa = data.get("best_oa_location") or {}
                oa_pdf_url = best_oa.get("pdf_url") or best_oa.get("url_for_pdf")
                if not oa_pdf_url:
                    for loc in data.get("oa_locations") or []:
                        if loc.get("pdf_url"):
                            oa_pdf_url = loc.get("pdf_url")
                            break

                if oa_pdf_url:
                    print(
                        f"[Tier 3 Success] Downloading from Unpaywall OA link: {oa_pdf_url}",
                        file=sys.stderr,
                    )
                    res = cffi_requests.get(
                        oa_pdf_url,
                        impersonate="chrome124",
                        timeout=15,
                        allow_redirects=True,
                    )
                    if res.status_code == 200 and (
                        res.content.startswith(b"%PDF") or len(res.content) > 10000
                    ):
                        with open(abs_outpath, "wb") as f:
                            f.write(res.content)
                        print(
                            f"Download complete! Saved to {abs_outpath}",
                            file=sys.stderr,
                        )
                        return True
        except Exception as e:
            print(f"[Tier 3 Warning] Unpaywall lookup failed: {e}", file=sys.stderr)

    print(
        f"Error: Unable to download paper for {url or doi} across all 3 tiers.",
        file=sys.stderr,
    )
    return False


def download_paper(url, output_path, doi=None):
    return smart_download_paper(url, output_path, doi=doi)


def safe_filename(name):
    """Generate safe filename from title or string."""
    clean = "".join(c if c.isalnum() or c in "._- " else "_" for c in name)
    clean = "_".join(clean.split())
    return clean[:80]


def format_citation_markdown(paper):
    """Format markdown citation with clickable web/DOI link."""
    authors = paper.get("authors") or []
    year = paper.get("year") or "n.d."
    doi = paper.get("doi") or ""
    landing_url = paper.get("landing_url") or ""
    title = paper.get("title") or "Untitled"

    link = (
        doi
        if doi.startswith("http")
        else (f"https://doi.org/{doi}" if doi else landing_url)
    )

    if len(authors) == 1:
        author_str = authors[0].split()[-1] if authors[0] else "Anonymous"
    elif len(authors) == 2:
        a1 = authors[0].split()[-1] if authors[0] else ""
        a2 = authors[1].split()[-1] if authors[1] else ""
        author_str = f"{a1} & {a2}"
    elif len(authors) > 2:
        a1 = authors[0].split()[-1] if authors[0] else "Et al"
        author_str = f"{a1} et al."
    else:
        author_str = "Anonymous"

    citation_text = f"{author_str} ({year})"
    if link:
        return f"[{citation_text}]({link})"
    return citation_text


def run_pipeline(criteria_path, outdir, limit=40, max_downloads=25):
    """Master orchestrator command: search, screen, snowball, download, and compile pipeline results."""
    abs_outdir = os.path.abspath(outdir)
    os.makedirs(abs_outdir, exist_ok=True)

    # 1. Read criteria
    if os.path.exists(criteria_path):
        with open(criteria_path, encoding="utf-8") as f:
            criteria_data = json.load(f)
    else:
        # Fallback if raw JSON string passed
        try:
            criteria_data = json.loads(criteria_path)
        except Exception:
            criteria_data = {
                "search_queries": [criteria_path],
                "target_terms": [criteria_path],
            }

    search_queries = (
        criteria_data.get("search_queries")
        or criteria_data.get("queries")
        or [criteria_data.get("topic", "literature review")]
    )
    target_terms = (
        criteria_data.get("target_terms")
        or criteria_data.get("terms")
        or search_queries
    )
    min_relevance = float(criteria_data.get("min_relevance", 0.15))

    print("--- Starting Deep Literature Review Pipeline ---", file=sys.stderr)
    print(f"Output Directory: {abs_outdir}", file=sys.stderr)
    print(f"Search Queries: {search_queries}", file=sys.stderr)
    print(f"Target Terms: {target_terms}", file=sys.stderr)

    # 2. Deep Search across queries
    all_raw_papers = []
    seen_titles = set()

    for q in search_queries:
        res = deep_search(
            q, limit=limit // len(search_queries) if len(search_queries) > 1 else limit
        )
        for p in res:
            norm = (p.get("title") or "").strip().lower()
            if norm and norm not in seen_titles:
                seen_titles.add(norm)
                all_raw_papers.append(p)

    # 3. Screen and score papers
    screened_papers = screen_and_score_papers(
        all_raw_papers, target_terms, min_relevance
    )

    # 4. Snowballing on top seed papers
    included_papers = [p for p in screened_papers if p["prisma_status"] == "included"]
    seed_papers = included_papers[:3]
    snowballed_records = []

    for seed in seed_papers:
        alex_id = seed.get("id")
        doi = seed.get("doi")
        if alex_id or doi:
            snow_res = fetch_snowball_citations(alex_id, doi, limit=5)
            for sb in snow_res.get("forward_citations", []) + snow_res.get(
                "backward_citations", []
            ):
                norm = (sb.get("title") or "").strip().lower()
                if norm and norm not in seen_titles:
                    seen_titles.add(norm)
                    snowballed_records.append(sb)

    if snowballed_records:
        screened_snow = screen_and_score_papers(
            snowballed_records, target_terms, min_relevance
        )
        screened_papers.extend(screened_snow)
        screened_papers.sort(key=lambda x: x["scores"]["final_composite"], reverse=True)
        included_papers = [
            p for p in screened_papers if p["prisma_status"] == "included"
        ]

    excluded_papers = [p for p in screened_papers if p["prisma_status"] == "excluded"]

    # 5. Batch Download PDFs for top included papers (up to max_downloads)
    to_download = included_papers[:max_downloads]
    download_count = 0

    for idx, paper in enumerate(to_download):
        pdf_url = paper.get("pdf_url")
        doi = paper.get("doi")

        year_str = str(paper.get("year") or "nd")
        first_auth = (
            (paper.get("authors") or ["anon"])[0].split()[-1]
            if paper.get("authors")
            else "anon"
        )
        short_title = safe_filename(paper.get("title") or f"paper_{idx}")[:30]
        filename = f"{safe_filename(first_auth)}_{year_str}_{short_title}.pdf"
        dest_path = os.path.join(abs_outdir, filename)

        if download_paper(pdf_url, dest_path, doi=doi):
            paper["local_pdf_path"] = dest_path
            paper["local_pdf_url"] = f"file://{dest_path}"
            download_count += 1
        else:
            paper["local_pdf_path"] = ""
            paper["local_pdf_url"] = ""

    # 6. Format Markdown Citations & Evidence Matrix Rows
    evidence_matrix = []
    for paper in included_papers:
        citation_md = format_citation_markdown(paper)
        paper["markdown_citation"] = citation_md

        pdf_link = (
            f"[PDF](file://{paper['local_pdf_path']})"
            if paper.get("local_pdf_path")
            else "No PDF"
        )
        doi_link = (
            f"[DOI/Web]({paper['doi'] if paper.get('doi') else paper.get('landing_url')})"
            if (paper.get("doi") or paper.get("landing_url"))
            else "-"
        )

        evidence_matrix.append(
            {
                "citation": citation_md,
                "title": paper.get("title"),
                "year": paper.get("year"),
                "journal": paper.get("journal") or paper.get("publisher") or "Unknown",
                "citation_count": paper.get("citation_count", 0),
                "composite_score": paper["scores"]["final_composite"],
                "publisher_flag": paper.get("publisher_flag", ""),
                "doi_link": doi_link,
                "pdf_link": pdf_link,
                "abstract_snippet": (paper.get("abstract") or "")[:250] + "...",
            }
        )

    total_found_count = len(all_raw_papers) + len(snowballed_records)
    read_abstracts_count = max(0, len(screened_papers) - download_count)

    pipeline_result = {
        "outdir_abs": abs_outdir,
        "pdf_directory_url": f"file://{abs_outdir}",
        "prisma_summary": {
            "total_identified": total_found_count,
            "total_searched": len(all_raw_papers),
            "total_screened": len(screened_papers),
            "total_included": len(included_papers),
            "total_excluded": len(excluded_papers),
            "total_snowballed": len(snowballed_records),
            "read_only_for_abstracts": read_abstracts_count,
            "read_in_full": download_count,
        },
        "included_papers": included_papers,
        "excluded_papers": excluded_papers,
        "evidence_matrix": evidence_matrix,
    }

    result_path = os.path.join(abs_outdir, "pipeline_results.json")
    with open(result_path, "w", encoding="utf-8") as f:
        json.dump(pipeline_result, f, indent=2)

    print("\nPipeline execution complete!", file=sys.stderr)
    print(f"Results saved to: {result_path}", file=sys.stderr)
    return pipeline_result


def seed_reviews(topic, outdir, limit=15):
    """Stage 1 Seed Discovery Command: Performs search for review papers and compiles proposed_criteria.json in 1 command."""
    abs_outdir = os.path.abspath(outdir)
    os.makedirs(abs_outdir, exist_ok=True)

    query = f"{topic} review OR meta-analysis"
    print(f"--- Running Stage 1 Seed Discovery for '{topic}' ---", file=sys.stderr)

    raw_reviews = deep_search(query, limit=limit)

    terms_set = set()
    topic_words = [w.lower().strip() for w in topic.split() if len(w) > 2]
    terms_set.update(topic_words)

    seed_summary = []
    for r in raw_reviews:
        title = r.get("title") or ""
        abstract = r.get("abstract") or ""
        text = f"{title} {abstract}"
        words = [w.lower().strip(".,;:()[]\"'") for w in text.split() if len(w) > 4]
        for w in words:
            if w not in [
                "review",
                "analysis",
                "study",
                "results",
                "paper",
                "methods",
                "using",
                "between",
                "across",
                "species",
                "data",
                "effects",
            ]:
                terms_set.add(w)

        seed_summary.append(
            {
                "title": title,
                "authors": r.get("authors"),
                "year": r.get("year"),
                "citation_count": r.get("citation_count"),
                "abstract_snippet": abstract[:300] + "..." if abstract else "",
            }
        )

    extracted_terms = list(sorted(terms_set))[:15]

    proposed_criteria = {
        "topic": topic,
        "search_queries": [topic, f"{topic} mechanisms", f"{topic} empirical evidence"],
        "target_terms": extracted_terms if extracted_terms else topic_words,
        "min_relevance": 0.15,
        "seed_reviews_found": len(seed_summary),
    }

    criteria_path = os.path.join(abs_outdir, "proposed_criteria.json")
    with open(criteria_path, "w", encoding="utf-8") as f:
        json.dump(proposed_criteria, f, indent=2)

    summary_path = os.path.join(abs_outdir, "seed_reviews.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(seed_summary, f, indent=2)

    print(
        f"Seed discovery complete! Criteria saved to: {criteria_path}", file=sys.stderr
    )
    return {
        "status": "success",
        "outdir_abs": abs_outdir,
        "criteria_json": criteria_path,
        "seed_reviews_json": summary_path,
        "proposed_criteria": proposed_criteria,
        "seed_reviews": seed_summary,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Deep Literature Review Helper Utility"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Seed Reviews Command
    p_seed = subparsers.add_parser(
        "seed-reviews",
        help="Perform Stage 1 seed discovery and generate candidate search criteria JSON",
    )
    p_seed.add_argument("topic", help="Literature review topic query")
    p_seed.add_argument("--outdir", required=True, help="Target output directory")
    p_seed.add_argument(
        "--limit", type=int, default=15, help="Max seed reviews to analyze"
    )

    # Master Pipeline Command
    p_pipe = subparsers.add_parser(
        "run-pipeline", help="Run master unified literature review pipeline end-to-end"
    )
    p_pipe.add_argument(
        "--criteria", required=True, help="Path to approved criteria JSON file"
    )
    p_pipe.add_argument(
        "--outdir", required=True, help="Target output directory for PDFs and results"
    )
    p_pipe.add_argument(
        "--limit",
        type=int,
        default=40,
        help="Max paper records to retrieve (default: 40)",
    )
    p_pipe.add_argument(
        "--max-downloads",
        type=int,
        default=25,
        help="Max PDFs to download (default: 25)",
    )

    # Search command
    p_search = subparsers.add_parser(
        "search", help="Perform deep multi-database search"
    )
    p_search.add_argument("query", help="Search query string")
    p_search.add_argument(
        "--limit",
        type=int,
        default=40,
        help="Max paper records to retrieve (default: 40)",
    )

    # Screen command
    p_screen = subparsers.add_parser(
        "screen", help="Score and screen papers against candidate terms"
    )
    p_screen.add_argument(
        "--input", required=True, help="JSON file containing raw paper records"
    )
    p_screen.add_argument(
        "--terms", required=True, help="Comma-separated list of target criteria terms"
    )
    p_screen.add_argument(
        "--min-relevance", type=float, default=0.15, help="Minimum relevance threshold"
    )

    # Snowball command
    p_snowball = subparsers.add_parser(
        "snowball", help="Fetch forward and backward citations for seed paper"
    )
    p_snowball.add_argument("--id", help="OpenAlex ID (e.g. W2741809807)")
    p_snowball.add_argument("--doi", help="DOI string (e.g. 10.1038/nature01234)")
    p_snowball.add_argument(
        "--limit", type=int, default=10, help="Max citations per direction"
    )

    # Download command
    p_dl = subparsers.add_parser("download", help="Download paper PDF")
    p_dl.add_argument("url", help="Download URL")
    p_dl.add_argument("output_path", help="Target output file path")
    p_dl.add_argument("--doi", help="Optional DOI for open access fallback resolution")

    # Extract command
    p_ext = subparsers.add_parser("extract", help="Extract text from PDF")
    p_ext.add_argument("file_path", help="PDF file path")

    args = parser.parse_args()

    if args.command == "seed-reviews":
        res = seed_reviews(args.topic, args.outdir, args.limit)
        print(json.dumps(res, indent=2))
    elif args.command == "run-pipeline":
        res = run_pipeline(args.criteria, args.outdir, args.limit, args.max_downloads)
        print(
            json.dumps(
                {
                    "status": "success",
                    "outdir_abs": res["outdir_abs"],
                    "pdf_directory_url": res["pdf_directory_url"],
                    "prisma_summary": res["prisma_summary"],
                    "pipeline_results_json": os.path.join(
                        res["outdir_abs"], "pipeline_results.json"
                    ),
                },
                indent=2,
            )
        )
    elif args.command == "search":
        results = deep_search(args.query, args.limit)
        print(
            json.dumps(
                {"query": args.query, "count": len(results), "papers": results},
                indent=2,
            )
        )
    elif args.command == "screen":
        with open(args.input, encoding="utf-8") as f:
            data = json.load(f)
        papers = data.get("papers", data) if isinstance(data, dict) else data
        terms = [t.strip() for t in args.terms.split(",")]
        screened = screen_and_score_papers(papers, terms, args.min_relevance)
        print(
            json.dumps(
                {
                    "terms": terms,
                    "total": len(screened),
                    "included": len(
                        [p for p in screened if p["prisma_status"] == "included"]
                    ),
                    "papers": screened,
                },
                indent=2,
            )
        )
    elif args.command == "snowball":
        snowball_res = fetch_snowball_citations(args.id, args.doi, args.limit)
        print(json.dumps(snowball_res, indent=2))
    elif args.command == "download":
        download_paper(args.url, args.output_path, doi=args.doi)
    elif args.command == "extract":
        extract_file_text(args.file_path)


if __name__ == "__main__":
    main()
