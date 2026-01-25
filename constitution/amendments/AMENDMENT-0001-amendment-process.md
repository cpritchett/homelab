# AMENDMENT-0001: Constitutional Amendment Process

**Status:** Accepted  
**Date:** 2026-01-25  
**Rationale:** Constitution must define its own amendment procedure to establish authority

## Amendment to Constitution

Add new section **"Amendment Process"** after Principles section.

## Text

### Amendment Process

**Authority:** The constitution is the highest authority in this repository. To amend it:

1. **Propose Amendment**
   - Create amendment file: `constitution/amendments/AMENDMENT-NNNN-topic.md`
   - Use sequential numbering (0001, 0002, etc.)
   - Document rationale, affected principles, and downstream impacts

2. **Create Supporting ADR**
   - Document technical/operational rationale in `docs/adr/ADR-NNNN-topic.md`
   - Link amendment from ADR and vice versa

3. **Update Constitution**
   - Modify `constitution/constitution.md` with amendment text
   - Add amendment reference to modified section
   - Update `constitution/amendments/README.md` index

4. **Update Downstream Documents**
   - Review and update all affected contracts (`contracts/`)
   - Review and update all affected requirements (`requirements/`)
   - Update agent instructions if governance changes

5. **Approval Requirements**
   - Constitutional amendments require code owner approval
   - All CI gates must pass
   - Extended review period (minimum 24 hours)

**Amendment Format:**
```markdown
# AMENDMENT-NNNN: Short Title

**Status:** Proposed | Accepted | Superseded  
**Date:** YYYY-MM-DD  
**Rationale:** Why this amendment is needed

## Amendment to Constitution
Which section/principle is being modified

## Text
The actual amendment text (what gets added/changed in constitution)

## Downstream Impacts
- contracts/: What changes
- requirements/: What changes
- Other impacts

## References
- ADR-NNNN: [Title](../../docs/adr/ADR-NNNN-topic.md)
```

**Immutability:** Amendments are append-only. To reverse an amendment, create a new amendment that supersedes it.

## Downstream Impacts

- `contracts/`: No immediate changes required
- `requirements/`: No immediate changes required
- `docs/governance/procedures.md`: Update constitutional amendment section to reference this process
- `.github/copilot-instructions.md`: Update constitution references

## References

- Constitution: [constitution.md](../constitution.md)
- Amendment Index: [README.md](./README.md)
- Governance Procedures: [docs/governance/procedures.md](../../docs/governance/procedures.md)
