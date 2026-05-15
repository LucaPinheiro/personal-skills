#!/usr/bin/env bash
set -euo pipefail

# validate-skills.sh — Validate all SKILL.md files in all domain directories
# Exit code = number of errors found (0 = all OK).

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIRS=("$REPO_ROOT/coding" "$REPO_ROOT/platform-engineering" "$REPO_ROOT/superpowers")
errors=0

err() {
  echo "ERROR: $1" >&2
  ((errors++))
}

info() {
  echo "  ✓ $1"
}

# --------------------------------------------------------------------------- #
# 1. Every directory under each domain dir must contain a SKILL.md
# --------------------------------------------------------------------------- #
echo "==> Checking for orphan directories (missing SKILL.md)..."
for DOMAIN_DIR in "${SKILL_DIRS[@]}"; do
  domain_name="$(basename "$DOMAIN_DIR")"
  [[ -d "$DOMAIN_DIR" ]] || continue
  for dir in "$DOMAIN_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    skill_name="$(basename "$dir")"
    if [[ ! -f "$dir/SKILL.md" ]]; then
      err "$domain_name/$skill_name/ has no SKILL.md"
    else
      info "$domain_name/$skill_name/SKILL.md exists"
    fi
  done
done

# --------------------------------------------------------------------------- #
# 2. Validate each SKILL.md
# --------------------------------------------------------------------------- #
shopt -s nullglob
ALL_SKILLS=()
for DOMAIN_DIR in "${SKILL_DIRS[@]}"; do
  [[ -d "$DOMAIN_DIR" ]] || continue
  ALL_SKILLS+=("$DOMAIN_DIR"/*/SKILL.md)
done
shopt -u nullglob

for skill_file in "${ALL_SKILLS[@]}"; do
  rel_path="${skill_file#$REPO_ROOT/}"
  echo ""
  echo "==> Validating $rel_path"

  # --- 2a. Extract YAML frontmatter ---------------------------------------- #
  # Frontmatter sits between the first two lines that are exactly '---'.
  frontmatter=$(awk '
    /^---$/ { n++ }
    n == 1 && !/^---$/ { print }
    n == 2 { exit }
  ' "$skill_file")

  if [[ -z "$frontmatter" ]]; then
    err "$rel_path: missing or empty YAML frontmatter"
    continue
  fi
  info "frontmatter block found"

  # --- 2b. Parse YAML with yq --------------------------------------------- #
  if ! echo "$frontmatter" | yq eval '.' - > /dev/null 2>&1; then
    err "$rel_path: frontmatter is not valid YAML"
    continue
  fi
  info "frontmatter is valid YAML"

  # --- 2c. Required scalar fields ----------------------------------------- #
  for field in name description license compatibility; do
    value=$(echo "$frontmatter" | yq eval ".$field // \"\"" -)
    if [[ -z "$value" ]]; then
      err "$rel_path: missing required field '$field'"
    else
      info "field '$field' present"
    fi
  done

  # --- 2d. metadata must be a non-empty map -------------------------------- #
  meta_type=$(echo "$frontmatter" | yq eval '.metadata | type' -)
  if [[ "$meta_type" != "!!map" ]]; then
    err "$rel_path: 'metadata' must be a YAML map (got $meta_type)"
  else
    meta_len=$(echo "$frontmatter" | yq eval '.metadata | length' -)
    if [[ "$meta_len" -eq 0 ]]; then
      err "$rel_path: 'metadata' map is empty"
    else
      info "metadata is a non-empty map ($meta_len keys)"
    fi
  fi

  # --- 2e. Markdown body after frontmatter is non-empty -------------------- #
  body=$(awk '
    /^---$/ { n++ }
    n >= 2 && !/^---$/ { found=1 }
    END { print found+0 }
  ' "$skill_file")

  if [[ "$body" -eq 0 ]]; then
    err "$rel_path: markdown body after frontmatter is empty"
  else
    info "markdown body is non-empty"
  fi

  # --- 2f. Fenced code blocks are balanced --------------------------------- #
  fence_count=$(grep -cE '^\s*```' "$skill_file" || true)
  if (( fence_count % 2 != 0 )); then
    err "$rel_path: unbalanced fenced code blocks ($fence_count fence markers — expected even)"
  else
    info "fenced code blocks balanced ($((fence_count / 2)) blocks)"
  fi
done

# --------------------------------------------------------------------------- #
# Summary
# --------------------------------------------------------------------------- #
echo ""
if [[ $errors -gt 0 ]]; then
  echo "FAILED: $errors error(s) found."
  exit 1
else
  echo "ALL CHECKS PASSED."
  exit 0
fi
