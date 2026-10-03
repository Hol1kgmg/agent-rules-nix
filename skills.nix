# 有効にするスキル ID の宣言ファイル。
#
# 取得元は registry/sources/*.nix（rev は registry/sources.lock.json に固定）。
# ID 一覧は `just skills-list` で確認できる。不要なものは行ごと消す。
[
  # anthropics/skills
  "frontend-design"
  "skill-creator"
  "webapp-testing"

  # vercel/ai
  "adr-skill"

  # gist
  "cognitive-rhythm-writing"
  "japanese-tech-writing"

  # addyosmani/web-quality-skills
  "web-quality-audit"
  "performance"
  "core-web-vitals"
  "accessibility"
  "seo"
  "best-practices"

  # ./skills（独自）
]
