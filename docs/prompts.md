# Prompt Library

Sample prompts for common repository operations. These work with GitHub Copilot, Claude, GPT, or other LLMs.

## Adding a New Domain Requirement

```
Add a new domain requirement for [DOMAIN NAME] to this homelab repo.

The requirement should cover:
- [DESCRIBE WHAT THE REQUIREMENT COVERS]
- [KEY CONSTRAINTS]

Create:
1. requirements/[domain]/spec.md with MUST/MUST NOT rules
2. requirements/[domain]/checks.md with validation criteria
3. An ADR in docs/adr/ explaining the decision

Follow the existing format in requirements/dns/ as a template.
```

## Updating an Existing Requirement

```
Update the [dns|ingress|management|overlay] requirements to add:
- [NEW RULE OR CONSTRAINT]

Make sure to:
1. Update the spec.md with the new requirement
2. Add corresponding check(s) to checks.md
3. If this is a significant change, create an ADR explaining why
```

## Adding a New ADR

```
Create an ADR for: [DECISION TITLE]

Context: [WHY THIS DECISION IS NEEDED]

The decision is: [WHAT WE'RE DOING]

Use the next available ADR number and follow the format in docs/adr/.
```

## Adding a Risk

```
Add a new risk to the risk register:

Risk: [DESCRIPTION OF THE RISK]
Impact: [Critical|High|Medium|Low]
Mitigation: [HOW WE ADDRESS THIS RISK]
```

## Reviewing for Compliance

```
Review this proposed change for compliance with the homelab contracts:

[PASTE PROPOSED CHANGE]

Check against:
1. constitution/constitution.md principles
2. contracts/invariants.md requirements
3. contracts/hard-stops.md conditions
4. Relevant requirements/ domain specs

Report any violations or concerns.
```

## Adding Infrastructure Config

```
Add a [Cloudflare tunnel|DNS zone|UniFi] configuration to infra/.

The configuration should:
- [DESCRIBE WHAT IT DOES]
- [KEY SETTINGS]

Make sure the config complies with:
- requirements/[relevant-domain]/spec.md
- contracts/invariants.md
```

## Creating a Runbook

```
Create a runbook for: [OPERATIONAL PROCEDURE]

Include:
- Prerequisites
- Step-by-step instructions
- Verification steps
- Rollback procedure if applicable

Place it in ops/runbooks/ following the template format.
```
