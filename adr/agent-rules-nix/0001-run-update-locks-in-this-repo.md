---
status: 'accepted'
date: 2026-10-03
decision-makers: 'Hol1kgmg'
---

# 派生リポジトリだが lockfile の自動更新を動かす

## Context and Problem Statement

[from-template/0002](../from-template/0002-use-github-app-for-write-access.md) は「派生リポジトリに App をインストールしない」とし、`update-locks` は `if: github.repository` でテンプレート元以外では止まる。

このリポジトリは他リポジトリから flake input として参照されるライブラリで、`lib.agent-rules` は agent-skills-nix の内部関数（`mkSyncProgram`、`sourcesFromLock`）に依存する。agent-skills-nix の API が変わったとき、利用側の `nix flake update` で初めて壊れるより、このリポジトリで先に `nix flake check` が落ちる方が早く気づける。

## Decision

`update-locks` のガードを `Hol1kgmg/agent-rules-nix` に書き換え、テンプレート元と同じ GitHub App をこのリポジトリにもインストールして `APP_ID` / `APP_PRIVATE_KEY` を登録する。手順は [docs/lockfile-automation.md](../../docs/lockfile-automation.md) のまま。

from-template/0002 の Non-goal「派生リポジトリに App をインストールしない」に対する、このリポジトリ限りの例外。from-template 側は書き換えない。

## Consequences

- Good, because agent-skills-nix の更新で壊れたら週次の PR の CI が落ちて分かる
- Bad, because App の鍵が漏洩した場合の影響範囲が 1 リポジトリ広がる
- Bad, because `just sync` でテンプレート元の `update-locks.yaml` を取り込むたびにガード行が衝突する。衝突時はこちら（`agent-rules-nix`）を採る
