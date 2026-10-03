# agent-rules-nix

他リポジトリの agent rules（`.claude/rules/*.md`）を manifest + lock で rev 固定し、devShell 起動時に同期する Nix ライブラリ。
[agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix) と同じ流儀で、skill 非依存の関数はそこから流用している（fork ではない）。

- 1 ルール = source の `subdir` 直下にある `*.md` 1 ファイル（`README.md` は除く）。ID はファイル名から `.md` を除いたもの（`idPrefix` があれば `<prefix>/<name>`）。
- frontmatter（Claude Code の `paths:` など）は加工せずそのまま配る。

## 公開 API（`lib.agent-rules`）

| 関数 | 内容 |
|---|---|
| `sourcesFromLock { manifestsDir; lockFile; }` | agent-skills-nix のものをそのまま再 export |
| `discoverCatalog sources` | 各 source の `*.md` を列挙して `{ <id> = { id; source; file; }; }` を返す。ID 重複は throw |
| `selectRules { catalog; allowlist; }` | allowlist の ID を catalog から引く。未知 ID は throw |
| `mkBundle { pkgs; selection; }` | `$out/<id>.md` に各ファイルを並べた derivation |
| `defaultLocalTargets` | `{ claude = { dest = ".claude/rules"; structure = "copy-tree"; enable = false; }; }` |
| `mkLocalInstallProgram { pkgs; bundle; targets; }` | `rules-install-local` 実行ファイル。上書き用環境変数は `AGENT_RULES_LOCAL_DESTS` |
| `mkShellHook { pkgs; bundle; targets; quiet; }` | devShell 用ラッパ |
| `mkSourceLockProgram { pkgs; }` | `rules-sources-lock` 実行ファイル。既定で `registry/rules/*.nix` → `registry/rules.lock.json` |

同期の実体は agent-skills-nix の `sync.sh` なので、同期先には `.agent-skills-managed.json` マーカーが置かれる。Claude Code は `*.md` しか読まないため無害。

## 利用側の構成

```
registry/rules/*.nix          # 取得元 manifest（書式は agent-skills-nix の registry/sources と同じ）
registry/rules.lock.json      # rev 固定（nix run .#rules-sources-lock で生成）
rules.nix                     # 有効化するルール ID の一覧
rules/                        # 独自ルール（lock に載せない local source）
.claude/rules/                # 同期先。.gitignore に追加する
```

```nix
inputs.agent-rules.url = "github:Hol1kgmg/agent-rules-nix";

# let 内
rulesLib = agent-rules.lib.agent-rules;
ruleSources = rulesLib.sourcesFromLock {
  manifestsDir = ./registry/rules;
  lockFile = ./registry/rules.lock.json;
} // { local = { path = ./rules; }; };
ruleCatalog = rulesLib.discoverCatalog ruleSources;
ruleSelection = rulesLib.selectRules { catalog = ruleCatalog; allowlist = import ./rules.nix; };
ruleTargets = { claude = rulesLib.defaultLocalTargets.claude // { enable = true; }; };

# eachDefaultSystem 内
rulesBundle = rulesLib.mkBundle { inherit pkgs; selection = ruleSelection; };
checks.rules = rulesBundle;
apps.rules-sources-lock.program = "${rulesLib.mkSourceLockProgram { inherit pkgs; }}/bin/rules-sources-lock";
apps.rules-install-local.program = "${rulesLib.mkLocalInstallProgram { inherit pkgs; bundle = rulesBundle; targets = ruleTargets; }}/bin/rules-install-local";
shellHook = ... + rulesLib.mkShellHook { inherit pkgs; bundle = rulesBundle; targets = ruleTargets; quiet = true; };
```

## このリポジトリでの開発

開発環境は Nix で管理していない。検証は `nix flake check` だけで、[examples/rules/](examples/rules/) からバンドルが組めることを CI で確認する。

`flake.lock` は毎週土曜に [update-locks](.github/workflows/update-locks.yaml) が PR を作って auto-merge する（[adr/agent-rules-nix/0001](adr/agent-rules-nix/0001-run-update-locks-in-this-repo.md)）。元の設計メモは [plan.md](plan.md)。

## スコープ外

- Cursor / Copilot 向けの拡張子・frontmatter 変換
- ルールごとの target 制限
- Home-Manager module（`~/.claude/rules` への配布）
- マーカーファイル名の `agent-rules` 化（sync.sh を fork しないと変えられない）
