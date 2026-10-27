# AGENTS.md — Development Rules

## Authority

Before making changes, read `PROJECT_BRIEF.md` and all relevant documents in `docs/`.

Treat the project brief as the source of product requirements. Treat approved architecture decision records as the source of approved technical decisions.

If requirements conflict, identify the conflict instead of silently choosing an interpretation.

## Decision-making

You are responsible for technical investigation and implementation.

You must not ask the project owner to choose between programming languages, libraries, database engines, or architectural patterns unless a business constraint genuinely requires their input.

Investigate technical alternatives yourself and recommend the most appropriate option.

Ask the project owner only when the answer materially affects product scope, privacy, business rules, budget, or another decision that cannot be safely inferred.

For significant decisions, record:

- Context and problem.
- Alternatives considered.
- Decision.
- Advantages and disadvantages.
- Consequences.
- Conditions that would justify reconsideration.

## Engineering rules

- Inspect existing code before editing it.
- Prefer small, focused changes.
- Avoid unnecessary dependencies.
- Do not duplicate business logic across UI components.
- Keep calculations deterministic and independently testable.
- Isolate external APIs behind appropriate interfaces.
- Validate all external data.
- Handle network failures and missing data explicitly.
- Do not hardcode API secrets.
- Never expose private user data through public endpoints.
- Do not implement fake integrations presented as production-ready.
- Do not use placeholder data without clearly identifying it.
- Do not introduce microservices without a demonstrated need.
- Do not perform broad rewrites without an approved technical reason.
- Preserve existing working functionality unless a change is required.

## Maps and external services

Before integrating any mapping provider, verify its current documentation, licensing, pricing, regional functionality, and storage restrictions.

Do not assume that a public website, an SDK, and an API provide the same permissions or capabilities.

Do not scrape services or bypass access restrictions as a substitute for an approved API.

Keep provider-specific data separate from internal domain models.

If a required capability is unavailable, document the limitation and propose a viable alternative.

## Data integrity

Every externally sourced fact must have a traceable source where feasible.

Prices, opening hours, promotions, route estimates, and occupancy information must not be fabricated.

Represent unavailable values as unknown rather than zero.

Distinguish estimates from verified values.

Record timestamps and provenance where freshness matters.

## Privacy

Personal notes and private tags are private by default.

Do not include note content in public endpoints, logs, analytics, or third-party requests unless explicitly justified and approved.

Enforce access controls on the server where server-side storage exists.

Do not assume that hiding a UI element is an access-control mechanism.

## Workflow

Work in small, verifiable increments.

Before implementation, state the goal and acceptance criteria.

After implementation:

1. Run relevant tests.
2. Run formatting and static analysis where available.
3. Run the relevant build.
4. Inspect the diff.
5. Update documentation.
6. Report actual results and unresolved issues.

If a command cannot run because of a missing SDK, API key, or environment dependency, report the exact blocker. Do not claim the check passed.

Do not silently skip failed checks.

## Scope control

Implement the approved phase only.

Do not add unrelated features, speculative abstractions, unnecessary AI functionality, or unrequested redesigns.

If a requirement suggests substantial additional cost or complexity, explain the trade-off before expanding scope.

## Completion reports

Every completed task must include:

- Summary of changes.
- Files changed.
- Tests and commands actually executed.
- Build status.
- Known limitations.
- Remaining work.
- Recommended next step.
