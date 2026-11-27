# Labels

Labels belong to a repository. Check the target repository's labels before
applying one; do not assume a label exists.

The GitHub MCP labels toolset is optional and cannot add or remove individual
labels on issues. Use the `gh` CLI for label operations.

```bash
gh label list --repo {owner}/{repo} --limit 1000
gh label create "needs-triage" \
  --repo {owner}/{repo} \
  --color FBCA04 \
  --description "Awaiting maintainer review"
gh label edit "needs-triage" --repo {owner}/{repo} --name "triage"
gh label delete "triage" --repo {owner}/{repo} --yes
```

Add or remove labels without changing the other labels on an issue:

```bash
gh issue edit {issue_number} \
  --repo {owner}/{repo} \
  --add-label "bug" \
  --remove-label "needs-triage"
```

Replace or remove all labels only when explicitly requested. `PUT` replaces the
entire set; `DELETE` clears it:

```bash
gh api repos/{owner}/{repo}/issues/{issue_number}/labels \
  -X PUT \
  -f 'labels[]=bug'
gh api repos/{owner}/{repo}/issues/{issue_number}/labels -X DELETE
```
