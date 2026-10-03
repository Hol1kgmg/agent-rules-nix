---
status: 'accepted'
date: 2026-09-19
decision-makers: 'Hol1kgmg'
---

# テンプレート元の変更を手動のマージコミットで取り込む

## Context and Problem Statement

このリポジトリをテンプレートとして生成した派生リポジトリは、テンプレート元のその後の更新を受け取る手段を持たない。

GitHub のテンプレート生成は fork と異なり履歴を共有しない。生成直後のリポジトリは初期コミット1つだけを持ち、テンプレート元との共通祖先が存在しないため、通常の `git merge upstream/main` は「refusing to merge unrelated histories」で拒否される。

初回のみ `--allow-unrelated-histories` でマージすると、そのマージコミットが共通祖先になる。以降は通常のマージとして扱える。裏を返すと、**取り込みはマージコミットである必要がある**。squash マージや rebase で履歴を平坦化すると第2親が失われ、次回の取り込みで再び共通祖先を失う。一度そうなると毎回ツリー全体が衝突する。

取り込みを定期実行で自動化するか、必要なときに手で行うかが論点になる。自動化すると、派生リポジトリごとに GitHub App のインストールと Secrets 登録、ブランチ保護と auto-merge の設定、squash マージの無効化が必要になる。また、テンプレート元の workflow ロジックを派生リポジトリへ届ける仕組み（reusable workflow の分離、SHA pin、リリースタグ、Dependabot による pin 伝播）も付随して要る。

一方で、自動化が実際に買っているものは通知である。マージ作業そのものは `git fetch && git merge` の2コマンドで、衝突したときは結局手元での解決が必要になる。

## Decision

取り込みは派生リポジトリの持ち主が必要なときに手で行う。`justfile` の `sync` レシピとして配る。

```bash
just sync
```

- `upstream` リモートが無ければ追加し、`upstream/main` を取得してマージする
- 初回のみ `--allow-unrelated-histories` が必要。2回目以降は指定しても無害なので、条件分岐は置かない
- 衝突したらその場で解決する。手元のマージなので、解決結果がそのまま成果物になる

**Non-goals**

- 定期実行しない。環境テンプレートは動く状態で固定されていることに価値があり、触らないリポジトリへ変化要因を注入し続ける理由が無い
- squash マージをリポジトリ設定で禁止しない。手元でマージして push する運用では squash される経路が無いため、設定による強制が要らない
- `.github/workflows/` を同期対象外にしない。テンプレート元の workflow は `if: github.repository == 'Hol1kgmg/claude-temp'` で自分自身でのみ動くので、降ってきても害が無い

## Consequences

- Good, because 派生リポジトリ側に設定作業が一切要らない。App も Secrets もブランチ保護も不要
- Good, because squash マージの禁止という、リポジトリ全体の運用方針に及ぶ制約が消える
- Good, because workflow の所有を分離する仕組み一式（reusable workflow、SHA pin、リリースタグ、pin の伝播）が不要になる
- Bad, because **テンプレート元が変わったことに気づく手段が無い。** 派生リポジトリが自分の管理下にある前提に依存している
- Bad, because 取り込まない期間が長いほど、一度の差分が大きくなる。衝突の主な発生箇所は `skills.nix`（派生リポジトリごとに内容が変わるため）

## Implementation Plan

- **Affected paths**: `justfile`（`sync` レシピ）
- **Dependencies**: なし
- **Patterns to follow**:
  - マージコミットで取り込む。`just sync` は手元でマージするため、PR を経由しない
  - PR 経由で取り込む場合は **Create a merge commit** を使う。squash と rebase は使わない
- **Patterns to avoid**:
  - `git merge --squash` / `git rebase` での取り込み
  - 派生リポジトリでの `.github/workflows/` の削除（ガードで止まるため不要）

### Verification

- [ ] 生成直後の派生リポジトリで `just sync` が成功する
- [ ] 2回目以降の `just sync` の差分が、ツリー全体ではなく実際の変更だけになっている
- [ ] 派生リポジトリで `update-locks` workflow がスキップされる

## Alternatives Considered

- **定期実行で PR を作る**: 通知になるが、派生リポジトリごとの設定作業、squash 禁止、workflow 伝播の仕組みが付随する。買っているものが通知だけなのに対して値段が高い
- **fork で運用する**: 履歴を共有するのでマージは素直だが、1アカウントにつき同一 upstream からの fork は1つだけ。派生リポジトリを複数作れない
- **flake input 化する**: `registry/sources` や skill 解決ロジックを output として公開すれば `nix flake update` で追従できる。ただし `justfile` や `AGENTS.md` のような素のファイルは配れないため、結局 merge との併用になる

## More Information

- 関連: [書き込み権限を GitHub App の短命トークンで得る](0002-use-github-app-for-write-access.md)
- 再検討条件: 自分が日常的に触らない派生リポジトリが増えたら、通知手段（テンプレート元の Watch、または定期実行）を再検討する
