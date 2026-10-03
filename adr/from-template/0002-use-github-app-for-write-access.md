---
status: 'accepted'
date: 2026-09-19
decision-makers: 'Hol1kgmg'
---

# 書き込み権限を GitHub App の短命トークンで得る

## Context and Problem Statement

lockfile 更新のジョブ（`update-locks`）は、ブランチへの push と PR 作成に書き込み権限を要する。このジョブはテンプレート元でのみ動く（[ADR 0001](0001-sync-template-via-merge-commit.md) により、派生リポジトリは手動更新）。

`GITHUB_TOKEN` では成立しない。**`GITHUB_TOKEN` が作成した PR と push は workflow を発火させない**（無限ループ防止の仕様）。`ci.yaml` は `pull_request` トリガーなので起動せず、PR head SHA に必須チェック `check` が付かない。結果、auto-merge は必須チェック待ちで永久に止まる。

同時に、flake input（`nixpkgs`、`agent-skills-nix`）が侵害された場合に、任意コード実行がそのまま書き込み権限の奪取にならないようにしたい。`update-locks` は `nix flake update` と `nix run` を実行するため、権限と Nix の評価が同じジョブに同居する。

## Decision

`actions/create-github-app-token` で短命（1時間）のトークンを都度発行する。

- App の権限は `Contents: Read and write`、`Pull requests: Read and write` のみ。`workflows` は持たない
- ワークフローの既定は `permissions: {}`。`GITHUB_TOKEN` は一切使わない
- **検証と自動マージを別ジョブに分ける。** `nix flake check` は `ci.yaml`（`contents: read`、`persist-credentials: false`、secret なし）でのみ実行する
- ブランチ保護は迂回しない。`gh pr merge --auto` は使うが `--admin` は使わない
- action はコミット SHA で固定する。タグは付け替えられるため `@v5` や `@main` では中身が差し替わりうる

**Non-goals**

- `ci.yaml` に secret を追加しない。`pull_request` トリガーは外部の未検証コードを実行するため、secret を置いた時点で漏洩経路になる
- 派生リポジトリに App をインストールしない。`update-locks` は `if: github.repository` で止まるので、Secrets が無くても失敗しない

## Consequences

- Good, because App が作成した PR は workflow を発火させる。必須チェックが付き、auto-merge が成立する
- Good, because 長期保管する鍵をリポジトリに置かない。漏洩しても1時間で失効する
- Good, because 設定作業が必要なのはテンプレート元の1リポジトリだけで、派生リポジトリには波及しない
- Bad, because **秘密鍵が漏洩した場合の影響範囲が、インストール済みの全リポジトリに及ぶ。** deploy key はリポジトリ単位なので狭い
- Bad, because App のインストールと Secrets 登録という、コードで表現できない設定作業が残る
- Bad, because `update-locks` は書き込み権限を持ったまま `nix flake update` を実行する。flake input が侵害された場合、評価時の任意コード実行からトークンに到達しうる。権限を Contents / Pull requests に絞り、ブランチ保護と必須チェックを迂回しないことで影響を抑えている
- Bad, because 公開リポジトリでは `ci.yaml` がフォーク PR の任意コードを runner で実行する。ただし secret が無く token も読み取り専用なので漏洩経路ではなく、GitHub-hosted runner の公開リポジトリ枠は無課金。見知らぬ相手の初回 PR は GitHub 既定の first-time contributor 承認で止まるため、追加設定は置かない

## Implementation Plan

- **Affected paths**: `.github/workflows/update-locks.yaml`、`.github/workflows/ci.yaml`、リポジトリ Secrets（`APP_ID` / `APP_PRIVATE_KEY`）、GitHub App の設定
- **Dependencies**: `actions/create-github-app-token`
- **Patterns to follow**:
  - ワークフローの既定を `permissions: {}` にし、必要なジョブだけで明示的に付与する
  - トークンは step で都度発行し、`permission-contents` などで必要な範囲まで絞る
  - すべての `uses:` をコミット SHA で固定し、横に `# vN` で対応バージョンを示す
  - ブランチ保護を有効にし、必須チェックに `check` を指定する。リポジトリ設定で auto-merge を有効化する。設定しないと `--auto` は待つ相手が無く即マージになり、`update-locks` が検証を経ずに通る
- **Patterns to avoid**:
  - `ci.yaml` への secret 追加
  - `gh pr merge --admin`
  - PAT の使用

### Verification

- [ ] `grep -c secrets .github/workflows/ci.yaml` が 0
- [ ] App の権限が Contents / Pull requests の2つだけ
- [ ] ブランチ保護が有効で、必須チェックに `check` が入っている
- [ ] リポジトリ設定で auto-merge が有効
- [ ] すべての `uses:` が40桁のコミット SHA を指す

## Alternatives Considered

- **deploy key (SSH)**: リポジトリ単位なので影響範囲が狭い。deploy key による push は workflow を発火させるので必須チェックも満たせる。ただし長期鍵になり、ローテーションが要る。**対象が1リポジトリだけになったため、App の「複数リポジトリへ一括インストールできる」利点は失われている。** 次の見直しではこちらが有力
- **PAT**: 個人アカウントに紐づき、スコープも粗い。App か deploy key で代替できる
- **`gh pr merge --admin`**: ブランチ保護を無条件に迂回する
- **必須チェックを外す**: 自動マージが検証を経ずに通る
- **lockfile 更新も手動にする**: App もブランチ保護も不要になる。依存更新は定期実行が本来向いている仕事なので、テンプレート元では自動のまま残した

## More Information

- セットアップ手順: [docs/lockfile-automation.md](../../docs/lockfile-automation.md)
- 関連: [テンプレート元の変更を手動のマージコミットで取り込む](0001-sync-template-via-merge-commit.md)
- 再検討条件: 次に App の設定を触るとき、deploy key への切り替えを検討する
