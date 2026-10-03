# lockfile の自動更新 — セットアップ手順

テンプレート元 (`Hol1kgmg/claude-temp`) でのみ必要な設定。

`update-locks` が毎週土曜 09:00 JST に走り、`flake.lock` と `registry/sources.lock.json` を更新する PR を作る。`ci.yaml` の `nix flake check` が通ると auto-merge される。`workflow_dispatch` で手動実行もできる。

固定ブランチ `update-locks` を使うため、マージされずに残っても PR の本数は増えない。

派生リポジトリでは `if: github.repository` で workflow がスキップされるので、この設定は要らない。lockfile は `just update` で手動更新する。同じ自動化を派生リポジトリにも入れたくなった場合は、以下の手順がそのまま使える。

**なぜこの構成なのかは [adr/from-template/0002](../adr/from-template/0002-use-github-app-for-write-access.md) にある。**

## 1. GitHub App

権限は `Contents: Read and write` と `Pull requests: Read and write` のみ。このリポジトリにインストールし、`APP_ID` と `APP_PRIVATE_KEY` を Secrets に登録する。

`GITHUB_TOKEN` では成立しない。それが作成した PR は workflow を発火させないため、必須チェックが付かず auto-merge が永久に止まる。

## 2. ブランチ保護

main を保護し、必須チェックに `check` を指定する。リポジトリ設定で auto-merge を有効化する。

設定しないと `--auto` は待つ相手が無く即マージになり、lockfile の更新が検証を経ずに通る。

## 既知の弱点

**スケジュール実行はリポジトリが60日間無活動になると自動停止する。** 静かに止まるため気づきにくい。lockfile の PR が毎週マージされていれば無活動にはならないので自立するが、何かの理由で一度止まると復帰しない。

`ci.yaml` は PR が持ち込んだ flake を `nix flake check` で評価する。secrets を持たず token も読み取り専用なので漏洩経路にはならず、公開リポジトリの GitHub-hosted runner には課金も発生しない。見知らぬ相手の初回 PR は GitHub 既定の first-time contributor 承認で止まるため、追加の設定は要らない。外部コントリビュータが実際に現れたら Settings → Actions の `Require approval for all external contributors` を検討する。
