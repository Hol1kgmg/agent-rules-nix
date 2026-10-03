# {app name}
{アプリの概要}

## 前提条件

[Nix](https://nixos.org/)（Flakes 有効）と [direnv](https://direnv.net/) がインストールされ、シェルに統合されていること。

macOS (Homebrew):

```bash
brew install nix direnv
```

Flakes の有効化:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

シェル統合 (zsh):

```bash
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
source ~/.zshrc
```

## セットアップ

```bash
direnv allow
```

ツールのインストールと Git フックの設定が一括で行われます。
以降はリポジトリのディレクトリに入るだけで自動的に環境が有効になります。

## 開発環境

`direnv` が `flake.nix` の devShell を読み込み、次のツールが PATH に入ります。

| ツール | 用途 |
|---|---|
| just | タスクランナー（[justfile](justfile)） |
| gitleaks / lefthook | pre-commit でステージ済みの差分をシークレット走査する（[lefthook.yaml](lefthook.yaml)） |
| gh / gh-dash | GitHub 操作 |
| markserv | `just docs` で Markdown を http://localhost:8080 に配信する |

エージェント用スキルは `skills.nix` の宣言から devShell 起動時に `.agents/skills` へ同期されます
（`just skills` / `just skills-list` / `just skills-update`）。独自スキルは [skills/](skills/) に置きます。

## タスク

```bash
just          # 利用可能なタスク一覧
just docs     # Markdown を http://localhost:8080 で閲覧する
```

## テンプレート同期

テンプレート元の変更と lockfile の更新は、必要なときに手動で取り込みます。

```bash
just sync      # テンプレート元の変更を取り込む
just update    # flake.lock / sources.lock.json を更新して検証する
```

`just sync` はマージコミットで取り込みます。PR 経由にする場合も **Create a merge commit** を使ってください（squash / rebase は共通祖先を壊します）。

- 設計判断の記録: [adr/](adr/)
