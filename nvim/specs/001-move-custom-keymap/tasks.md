# Tasks: Move Custom Keymap Definitions

**Input**: Design documents from `/specs/001-move-custom-keymap/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `lua/`, `config/` at repository root
- Paths below assume the Neovim configuration structure from plan.md

## Phase 3.1: Setup
- [x] T001 Create baseline startup time measurement in specs/001-move-custom-keymap/baseline.log
- [x] T002 Backup current keymaps.lua to config/keymaps.lua.backup
- [x] T003 [P] Set up performance measurement scripts in scripts/performance/

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [x] T004 [P] Execute contract test T001-keymap-functionality.md (should fail)
- [x] T005 [P] Execute contract test T002-startup-performance.md (should fail)
- [x] T006 [P] Execute contract test T003-plugin-loading.md (should fail)
- [x] T007 [P] Execute contract test T004-keymap-organization.md (should fail)
- [x] T008 [P] Execute contract test T005-behavior-consistency.md (should fail)

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [x] T009 [P] Move mini.files keymaps to lua/plugins/mini/files.lua
- [ ] T010 [P] Move LSP keymaps to lua/plugins/lsp.lua
- [ ] T011 [P] Move Flash keymaps to lua/plugins/general.lua
- [ ] T012 [P] Move Git keymaps to lua/plugins/git.lua
- [ ] T013 [P] Move Yanky keymaps to lua/plugins/utils/ (create if needed)
- [ ] T014 [P] Move Neotest keymaps to lua/plugins/neotest.lua
- [ ] T015 [P] Move DAP keymaps to lua/plugins/ (create debug.lua if needed)
- [ ] T016 [P] Move Grug-Far keymaps to lua/plugins/general.lua
- [ ] T017 [P] Move SQL/DBUI keymaps to lua/plugins/sql.lua
- [x] T018 [P] Move mini.pick keymaps to lua/plugins/mini/pick.lua
- [ ] T019 Clean up config/keymaps.lua (remove migrated keymaps)
- [ ] T020 [P] Add proper lazy loading configuration to all modified plugin files
- [ ] T021 [P] Test keymap functionality in each plugin file individually

## Phase 3.4: Integration
- [ ] T022 Validate all keymaps work after migration
- [ ] T023 Test plugin loading behavior (on-demand loading)
- [ ] T024 Measure startup performance improvement
- [ ] T025 Verify behavior consistency with pre-migration state
- [ ] T026 Update documentation and comments for migrated keymaps
- [ ] T027 Test keymap conflicts and resolve any issues

## Phase 3.5: Polish
- [ ] T028 [P] Create migration documentation in docs/keymap-migration.md
- [ ] T029 Performance optimization and fine-tuning
- [ ] T030 [P] Update README or configuration documentation
- [ ] T031 Final validation against all contract tests
- [ ] T032 Clean up backup files and temporary files

## Dependencies
- Tests (T004-T008) before implementation (T009-T021)
- T009-T018 can run in parallel [P] (different plugin files)
- T019 depends on T009-T018 completion
- T022-T027 depend on T019-T021 completion
- Polish (T028-T032) after all integration tasks

## Parallel Example
```
# Launch plugin keymap migration tasks together:
Task: "Move mini.files keymaps to lua/plugins/mini/files.lua"
Task: "Move LSP keymaps to lua/plugins/lsp.lua"  
Task: "Move Flash keymaps to lua/plugins/general.lua"
Task: "Move Git keymaps to lua/plugins/git.lua"
Task: "Move Yanky keymaps to lua/plugins/utils/"
Task: "Move Neotest keymaps to lua/plugins/neotest.lua"
Task: "Move DAP keymaps to lua/plugins/"
Task: "Move Grug-Far keymaps to lua/plugins/general.lua"
Task: "Move SQL/DBUI keymaps to lua/plugins/sql.lua"
Task: "Move mini.pick keymaps to lua/plugins/mini/pick.lua"
```

## Notes
- [P] tasks = different plugin files, no dependencies
- Verify contract tests fail before implementing
- Test each plugin file individually after migration
- Keep backup of original keymaps.lua for rollback
- Measure performance before and after migration

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each requirement → implementation task
   
2. **From Data Model**:
   - Keymap Configuration entity → migration tasks
   - Plugin Configuration entity → plugin file tasks
   
3. **From User Stories**:
   - Each user story → integration test [P]
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Migration → Integration → Polish
   - Plugin files can be processed in parallel

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All contracts have corresponding tests
- [ ] All plugin files have migration tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent (different plugin files)
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task