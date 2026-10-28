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


def test_missing_email_points_to_setup(monkeypatch, tmp_path):
    """A missing contact address reports where to find exact setup steps."""
    monkeypatch.delenv("OPENALEX_EMAIL", raising=False)
    with patch.object(helper, "__file__", str(tmp_path / "scripts/openalex_search.py")):
        with pytest.raises(ValueError, match="Configure OpenAlex"):
            helper.get_openalex_email()


def test_skill_local_email_without_process_variable(monkeypatch, tmp_path):
    """The skill-local file works regardless of the working directory."""
    monkeypatch.delenv("OPENALEX_EMAIL", raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text("# local settings\nOPENALEX_EMAIL=local@example.org\n")
    monkeypatch.chdir(tmp_path / "..")

    with patch.object(helper, "__file__", str(tmp_path / "scripts/openalex_search.py")):
        assert helper.get_openalex_email() == "local@example.org"


def test_process_email_takes_precedence(monkeypatch, tmp_path):
    """An explicit process setting overrides the skill-local file."""
    monkeypatch.setenv("OPENALEX_EMAIL", "process@example.org")
    (tmp_path / ".env").write_text("OPENALEX_EMAIL=local@example.org\n")

    with patch.object(helper, "__file__", str(tmp_path / "scripts/openalex_search.py")):
        assert helper.get_openalex_email() == "process@example.org"


def test_zero_results_are_success(monkeypatch):
    """Successful empty searches remain distinguishable from errors."""
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    with patch.object(helper.requests, "get", return_value=response({"results": []})):
        assert helper.search_openalex("rare parameter") == []


def test_search_defaults_to_compact_batch(monkeypatch):
    """Default searches stay small and omit citation lists from output."""
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    item = {
        "id": "https://openalex.org/W1",
        "title": "Candidate",
        "referenced_works": ["https://openalex.org/W2"],
    }
    with patch.object(
        helper.requests, "get", return_value=response({"results": [item]})
    ) as request:
        papers = helper.search_openalex("parameter")

    assert request.call_args.kwargs["params"]["per_page"] == 10
    assert "referenced_works" not in papers[0]


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
