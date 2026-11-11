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


def access(monkeypatch, tmp_path, env_file="", **settings):
    """Resolve OpenAlex access with only the given process and .env settings."""
    for name in ("OPENALEX_API_KEY", "OPENALEX_EMAIL"):
        monkeypatch.delenv(name, raising=False)
    for name, value in settings.items():
        monkeypatch.setenv(name, value)
    (tmp_path / ".env").write_text(env_file)
    with patch.object(helper, "__file__", str(tmp_path / "scripts/openalex_search.py")):
        return helper.openalex_access()


def test_access_prefers_key_then_email_then_keyless(monkeypatch, tmp_path):
    """Use the API key when available; fall back to email, then keyless."""
    assert access(
        monkeypatch, tmp_path, OPENALEX_API_KEY="k", OPENALEX_EMAIL="a@b.org"
    ) == ("api_key", {"Authorization": "Bearer k"})
    approach, headers = access(monkeypatch, tmp_path, OPENALEX_EMAIL="a@b.org")
    assert approach == "email" and "a@b.org" in headers["User-Agent"]
    assert access(monkeypatch, tmp_path) == ("keyless", {})


def test_skill_local_env_and_process_precedence(monkeypatch, tmp_path):
    """The skill-local .env works; a process setting overrides it."""
    env_file = "# local settings\nOPENALEX_API_KEY=local\n"
    assert access(monkeypatch, tmp_path, env_file)[1]["Authorization"] == (
        "Bearer local"
    )
    assert access(monkeypatch, tmp_path, env_file, OPENALEX_API_KEY="process")[1][
        "Authorization"
    ] == ("Bearer process")


def test_credentials_stay_out_of_request_url(monkeypatch):
    """HTTP errors include the URL, so credentials must only travel in headers."""
    monkeypatch.setenv("OPENALEX_API_KEY", "secret-key")
    monkeypatch.setenv("OPENALEX_EMAIL", "researcher@example.org")
    with patch.object(
        helper.requests, "get", return_value=response({"results": []})
    ) as request:
        helper.search_openalex("parameter")

    sent = repr(request.call_args.args) + repr(request.call_args.kwargs["params"])
    assert "secret-key" not in sent and "researcher@example.org" not in sent


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
