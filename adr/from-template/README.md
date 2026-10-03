# ADR — テンプレート元の決定

テンプレート元 (`Hol1kgmg/claude-temp`) が所有する。同期で降ってくるため、派生リポジトリでは編集しない。書き換えたくなったら `adr/` 直下に新しい ADR を作り、`superseded by` で繋ぐ。ここを直接編集すると次の同期で衝突する。

## 規約

ADR は決定そのものと、その背景・帰結を記録する。コードを読めば分かることは書かない。コードを読んでも分からないことだけを書く。

- ファイル名: `NNNN-verb-phrase.md`。連番はディレクトリごとに振る。日付は frontmatter の `date:` に持たせる（ファイル名に入れると同日の複数 ADR が意図した順に並ばない）
- 番号は決定した順に振り、欠番や再利用はしない。ADR を指すときは番号ではなくパスで呼ぶ（`from-template/` と `adr/` 直下で番号が重なるため）
- status: `proposed` → `accepted` / `rejected`、のち `deprecated` / `superseded`
- 置き換えるときは新しい ADR を作り、双方向にリンクする。過去の記述は書き換えない

## ADRs

| # | ADR | status |
|---|---|---|
| 0001 | [テンプレート元の変更を手動のマージコミットで取り込む](0001-sync-template-via-merge-commit.md) | accepted |
| 0002 | [書き込み権限を GitHub App の短命トークンで得る](0002-use-github-app-for-write-access.md) | accepted |

lockfile 自動更新のセットアップ手順は [docs/lockfile-automation.md](../../docs/lockfile-automation.md) にある。
