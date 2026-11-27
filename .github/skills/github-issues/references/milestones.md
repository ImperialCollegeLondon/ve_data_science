# Milestones

Milestones group issues into a deliverable unit of work. Use milestone numbers
for API operations; milestones do not define issue execution order.

```bash
gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" \
  --paginate \
  --jq '.[] | {number, title, state, open_issues, closed_issues, due_on}'
```

Create, update, or change milestone state with the REST API:

```bash
gh api repos/{owner}/{repo}/milestones \
  -X POST \
  -f title="Milestone title" \
  -f description="Milestone description"
gh api repos/{owner}/{repo}/milestones/{milestone_number} \
  -X PATCH \
  -f state=closed
```

Assign or remove a milestone on an issue:

```bash
gh api repos/{owner}/{repo}/issues/{issue_number} \
  -X PATCH \
  -F milestone={milestone_number}
gh api repos/{owner}/{repo}/issues/{issue_number} \
  -X PATCH \
  -F milestone=null
```

Delete a milestone only when explicitly requested. Use issue dependencies, not
shared milestones, to represent execution ordering.
