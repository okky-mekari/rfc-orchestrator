#!/usr/bin/env bash
# Installs the RFC Orchestrator agents and skills into ~/.claude
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${HOME}/.claude/agents"
SKILLS_DIR="${HOME}/.claude/skills"

mkdir -p "${AGENTS_DIR}" "${SKILLS_DIR}"

# Warn about overwrites before doing anything
conflicts=()
for f in "${KIT_DIR}"/agents/*.md; do
  [ -e "${AGENTS_DIR}/$(basename "$f")" ] && conflicts+=("agents/$(basename "$f")")
done
for d in "${KIT_DIR}"/skills/*/; do
  name="$(basename "$d")"
  [ -e "${SKILLS_DIR}/${name}" ] && conflicts+=("skills/${name}")
done

if [ "${#conflicts[@]}" -gt 0 ]; then
  echo "The following already exist in ~/.claude and will be OVERWRITTEN:"
  printf '  %s\n' "${conflicts[@]}"
  read -r -p "Continue? [y/N] " answer
  case "${answer}" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

cp "${KIT_DIR}"/agents/*.md "${AGENTS_DIR}/"
cp -R "${KIT_DIR}"/skills/* "${SKILLS_DIR}/"

agent_count="$(find "${KIT_DIR}/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
skill_count="$(find "${KIT_DIR}/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
echo "Installed:"
echo "  ${agent_count} agents  -> ${AGENTS_DIR}"
echo "  ${skill_count} skills  -> ${SKILLS_DIR}"
echo
echo "Start a new Claude Code session, then run: /rfc-orchestrator"
