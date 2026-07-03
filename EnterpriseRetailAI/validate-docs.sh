#!/bin/bash

# validate-docs.sh — EnterpriseRetailAI Documentation Validator
# Validates all documentation against .doc-rules
# Usage: ./validate-docs.sh [--fix] [--verbose]

set -e
shopt -s globstar

VERBOSE=false
FIX=false
ALL_DOCS=false
ERRORS=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose) VERBOSE=true; shift ;;
    --fix) FIX=true; shift ;;
    --all) ALL_DOCS=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

get_files_to_validate() {
  local files=()

  if [[ "$ALL_DOCS" == true ]]; then
    files=(EnterpriseRetailAI-Docs/**/*.md GETTING_STARTED.md DOCUMENT_MANIFEST.md README.md SKILL_EXAMPLES.md EnterpriseRetailAI-Docs/**/*.sql)
  else
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local diff_files
      diff_files=$(git diff --name-only origin/main...HEAD 2>/dev/null || true)
      if [[ -z "$diff_files" ]] && git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        diff_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
      fi
      if [[ -z "$diff_files" ]]; then
        diff_files=$(git diff --name-only 2>/dev/null || true)
      fi
      if [[ -z "$diff_files" ]]; then
        diff_files=$(git diff --cached --name-only 2>/dev/null || true)
      fi
      if [[ -n "$diff_files" ]]; then
        while IFS= read -r file; do
          files+=("$file")
        done <<< "$diff_files"
      fi
    fi
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "No changed files detected; validating all relevant documentation files."
      files=(EnterpriseRetailAI-Docs/**/*.md GETTING_STARTED.md DOCUMENT_MANIFEST.md README.md SKILL_EXAMPLES.md EnterpriseRetailAI-Docs/**/*.sql)
    fi
  fi

  echo "${files[@]}"
}

echo "🔍 EnterpriseRetailAI Documentation Validator"
echo "=============================================="
echo ""

# Validate all markdown files in EnterpriseRetailAI-Docs/ and top-level docs
validate_markdown_files() {
  echo "📄 Validating Markdown Files..."
  
  for file in $(get_files_to_validate); do
    [ -f "$file" ] || continue
    
    basename=$(basename "$file")
    
    # Rule 1: Required metadata header
    if [[ "$basename" =~ ^(HLD|LLD|ADR)-[0-9]{3} ]]; then
      metadata_format=""

      if grep -q "| Document ID |" "$file"; then
        metadata_format="standard"
      elif [[ "$basename" =~ ^ADR-[0-9]{3} ]] && grep -qE "\| ID \| ADR-[0-9]{3} \|" "$file"; then
        metadata_format="legacy-adr"
      fi

      if [[ -z "$metadata_format" ]]; then
        echo "❌ RULE-1: Missing metadata header in $file"
        ((ERRORS++))
        continue
      fi

      if [[ "$metadata_format" == "standard" ]]; then
        # Check required metadata fields for standard docs
        for field in "Type" "Version" "Status" "Author" "Date"; do
          if ! grep -q "| $field |" "$file"; then
            echo "⚠️  RULE-1: Missing '$field' in metadata table in $file"
            ((WARNINGS++))
          fi
        done
      else
        # Allow legacy ADR metadata formats by validating key fields
        for field in "Status" "Date"; do
          if ! grep -q "| $field |" "$file"; then
            echo "⚠️  RULE-1: Missing '$field' in legacy ADR metadata table in $file"
            ((WARNINGS++))
          fi
        done
      fi
    fi
    
    # Rule 2: ADR structure validation
    if [[ "$basename" =~ ^ADR-[0-9]{3} ]]; then
      for section in "Context" "Decision" "Consequences"; do
        if ! grep -q "## .*$section" "$file"; then
          echo "⚠️  RULE-2: ADR missing section '$section' in $file"
          ((WARNINGS++))
        fi
      done
    fi
    
    # Rule 3: HLD structure validation
    if [[ "$basename" =~ ^HLD-[0-9]{3} ]]; then
      for section in "Purpose" "Architecture" "Design Rationale" "References"; do
        if ! grep -q "## .*$section" "$file"; then
          echo "⚠️  RULE-3: HLD missing section '$section' in $file"
          ((WARNINGS++))
        fi
      done
    fi
    
    # Rule 4: LLD structure validation
    if [[ "$basename" =~ ^LLD-[0-9]{3} ]]; then
      for section in "Purpose" "Architecture Overview" "Interfaces" "Data Models"; do
        if ! grep -q "## .*$section" "$file"; then
          echo "⚠️  RULE-4: LLD missing section '$section' in $file"
          ((WARNINGS++))
        fi
      done
    fi
    
    # Rule 7: Link validation
    while IFS= read -r line; do
      if [[ "$line" =~ \[.*\]\((.*)\) ]]; then
        link="${BASH_REMATCH[1]}"
        # Skip external links
        if [[ ! "$link" =~ ^http ]]; then
          target="${link%#*}"  # Remove anchor
          if [ ! -z "$target" ] && [ ! -f "$target" ]; then
            echo "❌ RULE-7: Broken link '$link' in $file"
            ((ERRORS++))
          fi
        fi
      fi
    done < "$file"
    
    [ "$VERBOSE" = true ] && echo "  ✓ $file"
  done
}

# Validate SQL files
validate_sql_files() {
  echo ""
  echo "🗄️  Validating SQL DDL Files..."
  
  for file in $(get_files_to_validate); do
    [ -f "$file" ] || continue
    [[ "$file" == *.sql ]] || continue
    
    # Rule 6: Check for comments
    if ! grep -q "^--" "$file"; then
      echo "⚠️  RULE-6: SQL file missing header comments: $file"
      ((WARNINGS++))
    fi
    
    [ "$VERBOSE" = true ] && echo "  ✓ $file"
  done
}

# Validate naming conventions
validate_naming() {
  echo ""
  echo "📝 Validating Naming Conventions..."
  
  for file in $(get_files_to_validate); do
    [ -f "$file" ] || continue
    [[ "$file" == *.md ]] || continue
    basename=$(basename "$file")
    
    # Rule 8: ADR naming
    if [[ "$basename" == ADR* ]] && ! [[ "$basename" =~ ^ADR-[0-9]{3}_.*\.md$ ]]; then
      echo "❌ RULE-8: ADR file has invalid naming: $basename"
      ((ERRORS++))
    fi
    
    # Rule 8: HLD naming
    if [[ "$basename" == HLD* ]] && ! [[ "$basename" =~ ^HLD-[0-9]{3}_.*\.md$ ]]; then
      echo "❌ RULE-8: HLD file has invalid naming: $basename"
      ((ERRORS++))
    fi
    
    # Rule 8: LLD naming
    if [[ "$basename" == LLD* ]] && ! [[ "$basename" =~ ^LLD-[0-9]{3}_.*\.md$ ]]; then
      echo "❌ RULE-8: LLD file has invalid naming: $basename"
      ((ERRORS++))
    fi
    
    [ "$VERBOSE" = true ] && echo "  ✓ $basename"
  done
}

# Validate key navigation files exist
validate_navigation() {
  echo ""
  echo "🧭 Validating Navigation Files..."
  
  files_required=(
    "AGENTS.md"
    "QUICK_REFERENCE.md"
    "DOCUMENT_MANIFEST.md"
    "GETTING_STARTED.md"
    "validate-docs.sh"
    "README.md"
    ".doc-rules"
    ".github/copilot-instructions.md"
  )
  
  for file in "${files_required[@]}"; do
    if [ ! -f "$file" ]; then
      echo "❌ Missing required navigation file: $file"
      ((ERRORS++))
    else
      [ "$VERBOSE" = true ] && echo "  ✓ $file"
    fi
  done
}

# Validate skills exist
validate_skills() {
  echo ""
  echo "🎯 Validating Copilot Skills..."
  
  skills_required=(
    ".copilot/skills/mlops-drift-analysis/SKILL.md"
    ".copilot/skills/multitenancy-isolation/SKILL.md"
    ".copilot/skills/offline-first-architecture/SKILL.md"
    ".copilot/skills/integration-architecture/SKILL.md"
    ".copilot/skills/security-compliance/SKILL.md"
    ".copilot/skills/data-architecture/SKILL.md"
    ".copilot/skills/performance-scaling/SKILL.md"
  )
  
  for file in "${skills_required[@]}"; do
    if [ ! -f "$file" ]; then
      echo "⚠️  Missing skill file: $file"
      ((WARNINGS++))
    else
      [ "$VERBOSE" = true ] && echo "  ✓ $file"
    fi
  done
}

# Main execution
validate_markdown_files
validate_sql_files
validate_naming
validate_navigation
validate_skills

# Optionally run markdownlint when available
if command -v markdownlint >/dev/null 2>&1; then
  echo ""
  echo "📏 Running markdownlint..."
  find EnterpriseRetailAI-Docs -name "*.md" -print0 | xargs -0 markdownlint || {
    echo "❌ markdownlint reported issues"
    ((ERRORS++))
  }
else
  echo ""
  echo "⚠️ markdownlint not installed; skipped markdown linting"
fi

# Summary
echo ""
echo "=============================================="
echo "📊 Validation Summary"
echo "=============================================="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
  echo "❌ Validation FAILED ($ERRORS errors found)"
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo "⚠️  Validation PASSED with warnings ($WARNINGS warnings)"
  exit 0
else
  echo "✅ Validation PASSED"
  exit 0
fi
