# Third Party Attribution

This project includes adapted/copied components (skills, prompts, configs) from external repositories. Full credit to original authors.

New skill entries are added by `/cts-import-skill` (see README's [Add a New Skill](README.md#add-a-new-skill)) as part of importing an external skill into `.claude/skills/`. Each entry records the source repo, original file path, author, license, and a short "Changes" list of any adaptation made for the Node.js/TypeScript stack.

---

## Skills

### caveman

- Source: https://github.com/mattpocock/skills
- Original file: /caveman/SKILL.md
- Author: Matt Pocock (@mattpocock)
- License: [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE)

### Changes

- Adapted for Node.js / TypeScript stack
- Adjusted formatting rules
- Integrated into local agent workflow

---

### grill-me

- Source: https://github.com/mattpocock/skills
- Original file: /skills/productivity/grill-me/SKILL.md
- Author: Matt Pocock (@mattpocock)
- License: [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE)

### Changes

- Upstream `grill-me` is now a thin wrapper delegating to a separate `grilling` skill; folded `grilling`'s body (also MIT, same repo, /skills/productivity/grilling/SKILL.md) into a single self-contained `grill-me` skill — CTS prefers dependency-free skills and wave 1 only calls for importing `grill-me`
- Rewrote description to CTS's what+when+NOT-for bar with EN/UA triggers

---

### handoff

- Source: https://github.com/mattpocock/skills
- Original file: /skills/productivity/handoff/SKILL.md
- Author: Matt Pocock (@mattpocock)
- License: [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE)

### Changes

- Dropped `argument-hint`/`disable-model-invocation` frontmatter (not used by CTS's skill convention)
- Rewrote description to CTS's what+when+NOT-for bar with EN/UA triggers
- Generalized "temporary directory of the user's OS" to "temporary/scratch directory for this session"

---

### tdd

- Source: https://github.com/mattpocock/skills
- Original file: /skills/engineering/tdd/SKILL.md (+ tests.md, mocking.md)
- Author: Matt Pocock (@mattpocock)
- License: [MIT](https://github.com/mattpocock/skills/blob/main/LICENSE)

### Changes

- Reformatted code examples to `singleQuote: true` per this project's `.prettierrc`
- Rewrote description to CTS's what+when+NOT-for bar with EN/UA triggers and explicit dedup notes vs. `vitest-testing`/`test-master`

---

### superpowers

- Source: https://github.com/obra/superpowers
- Author: Jesse Vincent (@obra)
- License: [MIT](https://github.com/obra/superpowers/blob/main/LICENSE)

### Adapted Content

- **`test-master/references/testing-anti-patterns.md`** — adapted from obra/superpowers; test quality issues, common mock anti-patterns.
- **`debugging-wizard/references/systematic-debugging.md`** — adapted from obra/superpowers; systematic debugging methodology and worksheets.

### Changes

- Both files extracted and re-licensed under CTS's standard attribution (THIRD_PARTY.md) instead of inline obra plugin references.
- Reformatted code examples and worksheets to align with Node.js/TypeScript stack conventions.

### Historical Note

The skills `plan-writing` (task breakdown, dependencies, verification) and the `tdd` skill's "Iron Laws" reference file have since been replaced. `plan-writing` is now covered by `rules/task-authoring.md` (CTS-native task file conventions); `tdd` skill's red-green-refactor discipline is the definitive version per the CLAUDE.md quality-gate pipeline.

---

## Notes

- All third-party content used according to respective licenses
- Original authors retain copyright under their respective licenses
- Changes: see git history for full diff
