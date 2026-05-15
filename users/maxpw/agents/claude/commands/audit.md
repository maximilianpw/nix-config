# Comprehensive Code Audit

Perform a deep, structured audit. Determine the mode from the user's message:

| Mode | What it covers |
|------|---------------|
| **diff** (default) | Uncommitted + staged changes (`git diff HEAD`) |
| **branch** | Changes between current branch and `main`/`master` |
| **repo** | Full repository scan |

If no qualifier is given, default to **diff**. If the diff is empty, fall back to **repo**.

## Gather Context

1. Read `AGENTS.md` / `CLAUDE.md` at the repo root (if they exist) to learn project-specific rules.
2. Read `package.json`, `tsconfig.json`, or equivalent config files to understand the stack.
3. For **diff/branch**: run `git diff --stat` first to see scope, then full diff for changed files.
4. For **repo**: enumerate source files, then sample key files (entry points, configs, routers, services).

## Audit Checklist

Run each category. For diff/branch mode, focus on changed code and its immediate context. For repo mode, scan broadly.

### 🔒 Security
- Hardcoded secrets, API keys, tokens, passwords
- SQL injection, XSS, command injection vectors
- Missing input validation / sanitization at boundaries
- PII logging (tokens, passwords, payment data in logs)
- Missing authentication / authorization checks
- Insecure crypto, CORS misconfiguration

### 🐛 Bugs & Correctness
- Null/undefined dereferences, unhandled promise rejections
- Off-by-one errors, race conditions
- Swallowed exceptions (empty catch blocks)
- Incorrect type assertions / unsafe casts (`as any`)
- Dead code indicating incomplete refactors
- Missing error handling on I/O operations

### 🏗️ Architecture & Design
- SOLID violations (god classes, tight coupling)
- Circular dependencies
- Business logic in wrong layer
- Inconsistent patterns across similar modules

### ⚡ Performance
- N+1 query patterns
- Missing pagination on list endpoints
- Unbounded loops or memory allocations
- Synchronous blocking in async contexts

### 📝 Code Quality
- Missing or outdated JSDoc on public APIs
- `console.log` in production code (should use structured logging)
- Inconsistent naming conventions
- Overly complex functions
- Missing tests for new/changed behavior
- Import order violations

### 🔧 Configuration & DevOps
- Secrets in config files or environment defaults
- Missing environment variable validation
- Dockerfile issues (running as root, missing health checks)

## Report Format

```
# 🔍 Audit Report — [mode] mode

**Scope**: [what was audited]
**Files scanned**: [count]
**Severity summary**: 🔴 Critical: N | 🟠 High: N | 🟡 Medium: N | 🔵 Low: N | ✅ Info: N

---

## 🔴 Critical Issues
1. **[category]** — [file:line]: summary
   > Explanation and recommended fix

## 🟠 High Issues
...

## 🟡 Medium Issues
...

## 🔵 Low Issues
...

## ✅ What Looks Good
- Things done well

---

## Recommendations
1. Prioritized next steps
```

### Severity Definitions
- 🔴 **Critical**: Security vulnerabilities, data loss risks, production-breaking bugs
- 🟠 **High**: Bugs likely to surface, significant design issues
- 🟡 **Medium**: Code quality issues, minor bugs, missing tests
- 🔵 **Low**: Style issues, minor improvements, nitpicks
- ✅ **Info**: Observations, things done well

## Rules

- Be **specific**: always cite file paths and line numbers.
- Be **actionable**: every issue must include a concrete fix suggestion.
- Be **honest**: if nothing is wrong, say so.
- **Respect project conventions** from AGENTS.md / CLAUDE.md.
- Keep the report scannable.

After the report, ask: "Would you like me to fix any of these issues? (e.g., 'fix #1' or 'fix all critical')"
