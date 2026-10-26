"""Focused offline checks for OpenAlex discovery failures and empty results."""

import importlib.util
from pathlib import Path
from unittest.mock import Mock, patch

import pytest
import requests

SCRIPTS = (
    Path(__file__).resolve().parents[3] / ".github/skills/ve-constant-search/scripts"
)
spec = importlib.util.spec_from_file_location(
    "openalex_search", SCRIPTS / "openalex_search.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def response(data, error=None):
    """Build a mock OpenAlex HTTP response."""
    result = Mock()
    result.json.return_value = data
    result.raise_for_status.side_effect = error
    return result


def test_zero_results_are_success(monkeypatch):
    """Successful empty searches remain distinguishable from errors."""
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    with patch.object(helper.requests, "get", return_value=response({"results": []})):
        assert helper.search_openalex("rare parameter") == []


def test_search_http_failure_propagates(monkeypatch):
    """A request failure must not be reported as zero evidence."""
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    failure = requests.HTTPError("503")
    with patch.object(helper.requests, "get", return_value=response({}, failure)):
        with pytest.raises(requests.HTTPError, match="503"):
            helper.search_openalex("rare parameter")


def test_failed_citation_lookup_propagates(monkeypatch):
    """Do not return partial or empty citations after a failed lookup."""
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    seed = response({"id": "https://openalex.org/W1", "referenced_works": []})
    failure = response({}, requests.HTTPError("429"))
    with patch.object(helper.requests, "get", side_effect=[seed, failure]):
        with pytest.raises(requests.HTTPError, match="429"):
            helper.fetch_snowball_citations("W1")
