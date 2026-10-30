# /// script
# requires-python = ">=3.12"
# dependencies = ["requests"]
# ///
"""Download one approved PDF URL; this does not verify its scientific contents."""

import argparse
import hashlib
import json
import os
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlparse

import requests


def download_authorized_pdf(url, output_path, doi=""):
    """Save a PDF and return its provenance after access and rights are checked."""
    parsed = urlparse(url)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.password
    ):
        raise ValueError(
            "Provide a specific HTTPS PDF URL approved for access and retention"
        )

    output = Path(output_path)
    if output.exists() or output.with_suffix(output.suffix + ".json").exists():
        raise FileExistsError("PDF or provenance file already exists")
    if not output.parent.is_dir():
        raise FileNotFoundError(f"Output directory does not exist: {output.parent}")

    with requests.get(url, timeout=30, stream=True, allow_redirects=False) as response:
        response.raise_for_status()
        if response.is_redirect:
            raise ValueError(
                "Redirected to a different URL; review that URL separately"
            )
        if (
            response.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
            != "application/pdf"
        ):
            raise ValueError("Response is not application/pdf")

        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temp:
                temp_path = Path(temp.name)
                digest = hashlib.sha256()
                first_chunk = True
                for chunk in response.iter_content(chunk_size=65536):
                    if not chunk:
                        continue
                    if first_chunk and not chunk.startswith(b"%PDF-"):
                        raise ValueError("Response lacks a PDF signature")
                    first_chunk = False
                    digest.update(chunk)
                    temp.write(chunk)
                if first_chunk:
                    raise ValueError("Empty PDF response")

            metadata = {
                "source_url": url,
                "doi": doi,
                "retrieved_at": datetime.now(UTC).isoformat(),
                "http_status": response.status_code,
                "sha256": digest.hexdigest(),
                "access_outcome": "downloaded; full text not verified",
            }
            metadata_path = output.with_suffix(output.suffix + ".json")
            with metadata_path.open("x", encoding="utf-8") as record:
                json.dump(metadata, record, indent=2)
                record.write("\n")
            try:
                os.link(temp_path, output)
            except Exception:
                metadata_path.unlink()
                raise
            return metadata
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)


def main():
    """Download one user-approved PDF URL without following other links."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="Approved HTTPS PDF URL from OpenAlex or the user")
    parser.add_argument("output_path", help="New PDF path (parent must exist)")
    parser.add_argument("--doi", default="", help="DOI for provenance")
    args = parser.parse_args()
    print(
        json.dumps(
            download_authorized_pdf(args.url, args.output_path, args.doi), indent=2
        )
    )


if __name__ == "__main__":
    main()
