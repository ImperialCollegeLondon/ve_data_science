---
description: 'Guidelines for GitHub Copilot to write comments to achieve self-explanatory code with less comments. Examples are in R and Python but it should work on any language that has comments.'
applyTo: '**'
---

# Self-explanatory Code Commenting Instructions

## Core Principle
**Write code that speaks for itself. Comment only when necessary to explain WHY, not WHAT.**
We do not need comments most of the time.

## Commenting Guidelines

### ❌ AVOID These Comment Types

**Obvious Comments**
```r
# Bad: States the obvious
counter <- 0  # Initialize counter to zero
counter <- counter + 1  # Increment counter by one
```

```python
# Bad: States the obvious
counter = 0  # Initialize counter to zero
counter += 1  # Increment counter by one
```

**Redundant Comments**
```r
# Bad: Comment repeats the code
get_user_name <- function(user) {
    return(user$name)  # Return the user's name
}
```

```python
# Bad: Comment repeats the code
def get_user_name(user):
    return user.name  # Return the user's name
```

**Outdated Comments**
```r
# Bad: Comment doesn't match the code
# Calculate tax at 5% rate
tax <- price * 0.08  # Actually 8%
```

```python
# Bad: Comment doesn't match the code
# Calculate tax at 5% rate
tax = price * 0.08  # Actually 8%
```

### ✅ WRITE These Comment Types

**Complex Business Logic**
```r
# Good: Explains WHY this specific calculation
# Apply progressive tax brackets: 10% up to 10k, 20% above
tax <- calculate_progressive_tax(income, rates = c(0.10, 0.20), thresholds = c(10000))
```

```python
# Good: Explains WHY this specific calculation
# Apply progressive tax brackets: 10% up to 10k, 20% above
tax = calculate_progressive_tax(income, rates=[0.10, 0.20], thresholds=[10000])
```

**Non-obvious Algorithms**
```r
# Good: Explains the algorithm choice
# Using Floyd-Warshall for all-pairs shortest paths
# because we need distances between all nodes
for (k in seq_len(vertices)) {
    for (i in seq_len(vertices)) {
        for (j in seq_len(vertices)) {
            # ... implementation
        }
    }
}
```

```python
# Good: Explains the algorithm choice
# Using Floyd-Warshall for all-pairs shortest paths
# because we need distances between all nodes
for k in range(vertices):
    for i in range(vertices):
        for j in range(vertices):
            # ... implementation
```

**Regex Patterns**
```r
# Good: Explains what the regex matches
# Match email format: username@domain.extension
email_pattern <- "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
```

```python
# Good: Explains what the regex matches
# Match email format: username@domain.extension
email_pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
```

**API Constraints or Gotchas**
```r
# Good: Explains external constraint
# GitHub API rate limit: 5000 requests/hour for authenticated users
rate_limiter_wait()
response <- httr::GET(github_api_url)
```

```python
# Good: Explains external constraint
# GitHub API rate limit: 5000 requests/hour for authenticated users
rate_limiter.wait()
response = requests.get(github_api_url)
```

## Decision Framework

Before writing a comment, ask:
1. **Is the code self-explanatory?** → No comment needed
2. **Would a better variable/function name eliminate the need?** → Refactor instead
3. **Does this explain WHY, not WHAT?** → Good comment
4. **Will this help future maintainers?** → Good comment

## Special Cases for Comments

### Public APIs
```r
#' Calculate compound interest using the standard formula.
#'
#' @param principal Initial amount invested
#' @param rate Annual interest rate (as decimal, e.g., 0.05 for 5%)
#' @param time Time period in years
#' @param compound_frequency How many times per year interest compounds (default: 1)
#' @returns Final amount after compound interest
calculate_compound_interest <- function(principal, rate, time, compound_frequency = 1) {
    # ... implementation
}
```

```python
def calculate_compound_interest(principal, rate, time, compound_frequency=1):
    """
    Calculate compound interest using the standard formula.

    Args:
        principal: Initial amount invested
        rate: Annual interest rate (as decimal, e.g., 0.05 for 5%)
        time: Time period in years
        compound_frequency: How many times per year interest compounds (default: 1)

    Returns:
        Final amount after compound interest
    """
    # ... implementation
```

### Configuration and Constants
```r
# Good: Explains the source or reasoning
MAX_RETRIES <- 3  # Based on network reliability studies
API_TIMEOUT <- 5000  # AWS Lambda timeout is 15s, leaving buffer
```

```python
# Good: Explains the source or reasoning
MAX_RETRIES = 3  # Based on network reliability studies
API_TIMEOUT = 5000  # AWS Lambda timeout is 15s, leaving buffer
```

### Annotations
```r
# TODO: Replace with proper user authentication after security review
# FIXME: Memory leak in production - investigate connection pooling
# HACK: Workaround for bug in library v2.1.0 - remove after upgrade
# NOTE: This implementation assumes UTC timezone for all calculations
# WARNING: This function modifies the original data frame instead of creating a copy
# PERF: Consider caching this result if called frequently in hot path
# SECURITY: Validate input to prevent SQL injection before using in query
# BUG: Edge case failure when data frame is empty - needs investigation
# REFACTOR: Extract this logic into separate utility function for reusability
# DEPRECATED: Use new_api_function() instead - this will be removed in v3.0
```

```python
# TODO: Replace with proper user authentication after security review
# FIXME: Memory leak in production - investigate connection pooling
# HACK: Workaround for bug in library v2.1.0 - remove after upgrade
# NOTE: This implementation assumes UTC timezone for all calculations
# WARNING: This function modifies the original list instead of creating a copy
# PERF: Consider caching this result if called frequently in hot path
# SECURITY: Validate input to prevent SQL injection before using in query
# BUG: Edge case failure when list is empty - needs investigation
# REFACTOR: Extract this logic into separate utility function for reusability
# DEPRECATED: Use new_api_function() instead - this will be removed in v3.0
```

## Anti-Patterns to Avoid

### Dead Code Comments
```r
# Bad: Don't comment out code
# old_function <- function() { ... }
new_function <- function() { ... }
```

```python
# Bad: Don't comment out code
# def old_function(): ...
def new_function(): ...
```

### Changelog Comments
```r
# Bad: Don't maintain history in comments
# Modified by John on 2023-01-15
# Fixed bug reported by Sarah on 2023-02-03
process_data <- function() {
    # ... implementation
}
```

```python
# Bad: Don't maintain history in comments
# Modified by John on 2023-01-15
# Fixed bug reported by Sarah on 2023-02-03
def process_data():
    # ... implementation
```

### Divider Comments
```r
# Bad: Don't use decorative comments
#=====================================
# UTILITY FUNCTIONS
#=====================================
```

```python
# Bad: Don't use decorative comments
#=====================================
# UTILITY FUNCTIONS
#=====================================
```

## Quality Checklist

Before committing, ensure your comments:
- [ ] Explain WHY, not WHAT
- [ ] Are grammatically correct and clear
- [ ] Will remain accurate as code evolves
- [ ] Add genuine value to code understanding
- [ ] Are placed appropriately (above the code they describe)
- [ ] Use proper spelling and professional language

## Summary

Remember: **The best comment is the one you don't need to write because the code is self-documenting.**
