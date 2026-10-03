# Project Overview
{プロジェクトの概要を記述 (例: Dotfiles management project for macOS using Nix and Home-Manager)}

# Setup and Basic Usage
Setup instructions and basic usage are documented in [README.md](./README.md).

# Directory Structure
{※ディレクトリ構造のドキュメントが不要な場合はこのセクションごと削除}
See [{DIRECTORY_STRUCTURE_FILE}.md](./{DIRECTORY_STRUCTURE_FILE}.md) for details.

# Troubleshooting
{※トラブルシューティングのドキュメントが不要な場合はこのセクションごと削除}
- Setup and daily usage issues: See [{TROUBLESHOOTING_FILE}.md](./{TROUBLESHOOTING_FILE}.md)

# Work Rules
1. Propose implementation plan
2. Wait for approval
3. Start implementation

# Tool Usage Policy
**Prefer dedicated tools for file operations by default** (not enforced via `permissions.deny` — occasional Bash use is fine when it's genuinely more convenient):
- `ls`, `find` → `Glob` tool
- `cat`, `head`, `tail` → `Read` tool
- `grep` → `Grep` tool
- `sed`, `awk` → `Edit` tool
- File writing → `Write` tool
- `curl` → `WebFetch` tool

# Language Settings
- Responses: `.claude/settings.json` - `language`
- Thinking: English (for token reduction)
