#!/usr/bin/env bash
# Verifies a Python project has been set up according to the dev-rails-setup-guide-python-nix.md checklist.
# Usage: bash check-python-project-setup.sh [project-dir]

set -euo pipefail

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1 (manual check required)"; }

echo "Checking project at: $(pwd)"
echo "────────────────────────────────────────────────────"

# 1. Package renamed from zamazingo (exclude DEV_RAILS.md which references it as a placeholder)
if grep -r --include="*.py" --include="*.toml" --include="*.nix" --include="*.md" \
     -l "zamazingo" . 2>/dev/null | grep -qv ".git\|DEV_RAILS.md"; then
  fail "Package still named 'zamazingo' — run create-python-project.sh"
else
  ok "Package renamed from 'zamazingo'"
fi

# 2. flake.nix exists (prerequisite for 'nix develop')
if [[ -f "flake.nix" ]]; then
  ok "flake.nix present (nix develop should work)"
else
  fail "flake.nix not found"
fi

# 3. nox passes all five sessions (only run if nox is on PATH)
if command -v nox &>/dev/null; then
  echo "    Running nox (this may take a moment)..."
  if nox --nocolor &>/dev/null; then
    ok "nox passes all five sessions"
  else
    fail "nox: one or more sessions failed (run 'nox' for details)"
  fi
else
  skip "nox not on PATH — are you inside 'nix develop'?"
fi

# 4. pre-commit in flake.nix buildInputs
if [[ -f "flake.nix" ]] && grep -q "pkgs.pre-commit" flake.nix; then
  ok "pre-commit present in flake.nix buildInputs"
else
  fail "pre-commit not found in flake.nix — add 'pkgs.pre-commit' to buildInputs"
fi

# 5. .pre-commit-config.yaml exists and runs nox
if [[ -f ".pre-commit-config.yaml" ]]; then
  if grep -q "nox" .pre-commit-config.yaml; then
    ok ".pre-commit-config.yaml exists and references nox"
  else
    fail ".pre-commit-config.yaml exists but does not reference nox"
  fi
else
  fail ".pre-commit-config.yaml not found"
fi

# 6. pre-commit hooks installed (.git/hooks/pre-commit exists and is non-empty)
if [[ -s ".git/hooks/pre-commit" ]]; then
  ok "pre-commit hook installed (.git/hooks/pre-commit exists)"
else
  fail "pre-commit hook not installed — run 'pre-commit install' inside nix develop"
fi

# 7. Pre-commit fires on test commit — manual
skip "Pre-commit fires on test commit"

# 8. prd/ and plans/ directories present
for dir in prd plans; do
  if [[ -d "$dir" ]]; then
    ok "'$dir/' directory present"
  else
    fail "'$dir/' directory missing"
  fi
done

# 9. CLAUDE.md exists and Out of scope section is customised
if [[ -f "CLAUDE.md" ]]; then
  if grep -q "## Out of scope" CLAUDE.md; then
    # Check that the section has some content beyond the placeholder line
    out_of_scope_content=$(awk '/^## Out of scope/,/^## /' CLAUDE.md | grep -v "^## " | grep -v "^\s*$" | grep -v "^\s*-\s*\[list anything" | head -1 || true)
    if [[ -n "$out_of_scope_content" ]]; then
      ok "CLAUDE.md 'Out of scope' section is customised"
    else
      fail "CLAUDE.md 'Out of scope' section still has placeholder content — customise it"
    fi
  else
    fail "CLAUDE.md missing '## Out of scope' section"
  fi
else
  fail "CLAUDE.md not found"
fi

# 10. /do-work skill present (bundled in project template)
if [[ -f ".claude/skills/do-work/SKILL.md" ]]; then
  ok "/do-work skill present (.claude/skills/do-work/SKILL.md)"
else
  fail "/do-work skill missing — check .claude/skills/do-work/SKILL.md"
fi

# 11. Matt Pocock skills installed (per-project, in .claude/skills/)
COMMUNITY_SKILLS=(
  "grill-me"
  "grill-with-docs"
  "write-a-skill"
  "tdd"
  "to-prd"
  "to-issues"
  "diagnose"
  "zoom-out"
  "triage"
  "improve-codebase-architecture"
  "setup-matt-pocock-skills"
)
for skill in "${COMMUNITY_SKILLS[@]}"; do
  if [[ -d ".claude/skills/$skill" ]]; then
    ok "Matt Pocock skill '$skill' installed (.claude/skills/$skill)"
  else
    fail "Matt Pocock skill '$skill' missing — run 'npx skills@latest add mattpocock/skills'"
  fi
done

# 11b. Machine-level skills installed (global, in ~/.claude/skills/)
MACHINE_SKILLS=(
  "setup-dev-rails"
  "omarchy"
)
for skill in "${MACHINE_SKILLS[@]}"; do
  if [[ -d "${HOME}/.claude/skills/$skill" ]]; then
    ok "Machine skill '$skill' installed (~/.claude/skills/$skill)"
  else
    fail "Machine skill '$skill' missing — run 'bash install.sh' from https://github.com/grmhay/claudesetup"
  fi
done

# 12. /skills verification — manual
skip "Verified '/skills' lists all skills in Claude Code (open Claude Code and run /skills)"

# 13. GitHub issues enabled — check via gh CLI
if command -v gh &>/dev/null; then
  if gh issue list &>/dev/null 2>&1; then
    ok "GitHub issues accessible for this repo"
  else
    fail "GitHub issues not accessible — ensure issues are enabled and 'gh auth login' is done"
  fi
else
  skip "gh CLI not found — manually verify GitHub issues are enabled for this repo"
fi

echo "────────────────────────────────────────────────────"
echo -e "Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}  ${YELLOW}$(grep -c SKIP <<< "$(declare -f skip)" || true) skipped (manual)${NC}"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
