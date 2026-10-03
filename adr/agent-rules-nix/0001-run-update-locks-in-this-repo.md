---
status: 'accepted'
date: 2026-10-03
decision-makers: 'Hol1kgmg'
---

# flake.lock を GitHub App のトークンで週次自動更新する

## Context and Problem Statement

このリポジトリは他リポジトリから flake input として参照されるライブラリで、`lib.agent-rules` は agent-skills-nix の内部関数（`mkSyncProgram`、`sourcesFromLock`）に依存する。agent-skills-nix の API が変わったとき、利用側の `nix flake update` で初めて壊れるより、このリポジトリで先に `nix flake check` が落ちる方が早く気づける。

自動更新には PR 作成と push の書き込み権限が要るが、`GITHUB_TOKEN` が作った PR は workflow を発火させない（無限ループ防止の仕様）。必須チェック `check` が付かず、auto-merge が永久に待つ。

## Decision

`update-locks.yaml` が毎週土曜 09:00 JST に `nix flake update` を実行し、`actions/create-github-app-token` で発行した短命トークンで PR を作って auto-merge する。

- App の権限は `Contents: Read and write`、`Pull requests: Read and write` のみ。Secrets は `APP_ID` と `APP_PRIVATE_KEY`
- 検証は `ci.yaml`（`contents: read`、secret なし）だけで行い、書き込み権限と同居させない
- main はルールセット `protect-main` で保護し、必須チェック `check` を通らないとマージされない。`--admin` は使わない
- action はコミット SHA で固定する（dependabot が更新する）

## Consequences

- Good, because agent-skills-nix の更新で壊れたら週次 PR の CI が落ちて分かる
- Bad, because App の鍵が漏洩した場合、インストール済みの全リポジトリに影響する。短命トークンと権限の絞り込みで抑える
- Bad, because スケジュール実行はリポジトリが 60 日間無活動だと静かに止まる。毎週 PR がマージされていれば無活動にはならない
