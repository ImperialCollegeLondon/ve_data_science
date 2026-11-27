"""Offline checks for authorized PDF downloads and provenance."""

import importlib.util
import json
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

import pytest
import requests

SCRIPT = (
    Path(__file__).resolve().parents[3]
    / ".github/skills/ve-constant-search/scripts/download_authorized_pdf.py"
)
spec = importlib.util.spec_from_file_location("download_authorized_pdf", SCRIPT)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class Response:
    """Provide a small streaming HTTP response without network access."""

    def __init__(
        self,
        content=b"%PDF-1.7\nexample",
        content_type="application/pdf",
        redirect=False,
    ):
        self.content = content
        self.headers = {"Content-Type": content_type}
        self.is_redirect = redirect
        self.status_code = 200

    def __enter__(self):
        """Open the mock response."""
        return self

    def __exit__(self, *_args):
        """Close the mock response."""
        return False

    def raise_for_status(self):
        """Simulate a successful status."""

    def iter_content(self, chunk_size):
        """Yield response content."""
        yield self.content


@contextmanager
def mock_response(response):
    """Replace HTTP access for one download."""
    with patch.object(helper.requests, "get", return_value=response) as get:
        yield get


def test_download_saves_pdf_and_provenance(tmp_path):
    """Save a valid PDF once with its source, DOI, timestamp, and digest."""
    output = tmp_path / "paper.pdf"
    url = "https://example.org/paper.pdf"
    with mock_response(Response()) as get:
        result = helper.download_authorized_pdf(url, output, "10.1000/example")
    assert output.read_bytes() == b"%PDF-1.7\nexample"
    assert json.loads((tmp_path / "paper.pdf.json").read_text()) == result
    assert result["source_url"] == url
    assert result["doi"] == "10.1000/example"
    assert result["http_status"] == 200
    assert len(result["sha256"]) == 64
    assert result["retrieved_at"]
    get.assert_called_once_with(url, timeout=30, stream=True, allow_redirects=False)
    with pytest.raises(FileExistsError):
        helper.download_authorized_pdf(url, output)


@pytest.mark.parametrize(
    ("response", "reason"),
    [
        (Response(content=b"<html>login</html>"), "PDF signature"),
        (Response(content_type="text/html"), "application/pdf"),
        (Response(redirect=True), "Redirected"),
        (Response(content=b""), "Empty PDF"),
    ],
)
def test_rejected_response_leaves_no_files(tmp_path, response, reason):
    """Never retain failed downloads or metadata."""
    with mock_response(response):
        with pytest.raises(ValueError, match=reason):
            helper.download_authorized_pdf(
                "https://example.org/paper.pdf", tmp_path / "paper.pdf"
            )
    assert list(tmp_path.iterdir()) == []


def test_http_failure_leaves_no_files(tmp_path):
    """HTTP errors remain failures, not inaccessible evidence."""
    response = Response()
    with patch.object(
        response, "raise_for_status", side_effect=requests.HTTPError("403")
    ):
        with mock_response(response):
            with pytest.raises(requests.HTTPError, match="403"):
                helper.download_authorized_pdf(
                    "https://example.org/paper.pdf", tmp_path / "paper.pdf"
                )
    assert list(tmp_path.iterdir()) == []


def test_rejects_non_https_before_network(tmp_path):
    """Reject unsafe or unspecified sources without making a request."""
    with patch.object(helper.requests, "get") as get:
        with pytest.raises(ValueError, match="HTTPS"):
            helper.download_authorized_pdf(
                "http://example.org/paper.pdf", tmp_path / "paper.pdf"
            )
    get.assert_not_called()
