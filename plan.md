# agent-rules-nix 設計メモ

agent skill と同じ流儀（manifest + lock で rev 固定 → devShell 起動時に同期）で、他リポジトリの agent rules（`.claude/rules/*.md`）を取り込む仕組みの設計メモ。別リポジトリ `Hol1kgmg/agent-rules-nix` として実装する。

agent-skills-nix の **fork ではない**。agent-skills-nix を flake input として依存し、skill 非依存の関数をそのまま呼ぶ。rules 固有の部分だけを新規に書く。fork が必要になるのは「スコープ外」のマーカーファイル名を変えたい場合のみ。

## 背景

- このリポジトリでは [agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix) を使い、`registry/sources/*.nix` + `registry/sources.lock.json` + `skills.nix` でスキルを宣言的に管理している（[flake.nix](./flake.nix)）。
- agent-skills-nix は `SKILL.md` を持つディレクトリしか扱わない。rules（単一 Markdown ファイル）を配る target も discovery もない。
- 調査した rev: `flake.lock` の `agent-skills` ノード（store path `/nix/store/cn507c6ws7m6qksxdizq5zidw446pnvz-source`）。

## agent-skills-nix から流用できるもの

ソースを読んだ結果、以下は skill 非依存で、そのまま呼べる。

| 関数 | 場所 | 流用理由 |
|---|---|---|
| `sourcesFromLock { manifestsDir; lockFile; }` | `lib/source-registry.nix` | manifest と npins lock を読み、`{ <name> = { path; subdir; filter; idPrefix; }; }` を返す。`path` は fetch 済みの store path。SKILL.md は見ていない |
| `mkSourceLockProgram { pkgs; }` | 同上 | `registry/*.nix` を解決して lock を書く実行ファイル。引数で manifests dir / lock path を受ける |
| `mkLocalInstallProgram { pkgs; bundle; targets; }` | `lib/targets.nix` | `bundle`（store 上のディレクトリ）を `targets.<name>.dest` に rsync する。中身は問わない |
| `mkShellHook { pkgs; bundle; targets; quiet; }` | 同上 | 上の devShell 用ラッパ |
| `scripts/sync.sh` | ランタイム | `copy-tree` は `rsync -aL --delete`。dest に `.agent-skills-managed.json` マーカーを書く |

新規に書くのは **discovery / selection / bundle の 3 関数と targets の既定値** だけ。

### 注意点

- `sync.sh` のマーカーファイル名は `.agent-skills-managed.json` 固定、`managedBy` も `agent-skills-nix` 固定。`.claude/rules/` に JSON が 1 つ置かれるが、Claude Code は `*.md` しか読まないので無害。
- `mkSourceLockProgram` の引数（manifests dir / lock file の指定方法）は実装時に `lib/source-registry.nix` 300 行目以降を確認する。

## agent-rules-nix の設計

### ルールの定義

- source の `subdir` 直下にある `*.md` 1 ファイル = 1 ルール。
- ルール ID = ファイル名から `.md` を除いたもの。`idPrefix` があれば `<prefix>/<name>`。
- frontmatter（Claude Code の `paths:` など）は加工せずそのまま配る。
- `filter.nameRegex` は ID に対して適用。`maxDepth` はルールには不要なので無視（または 0 固定）。

### リポジトリ構成

```
agent-rules-nix/
  flake.nix          # inputs: nixpkgs, agent-skills; outputs.lib.agent-rules
  lib/
    default.nix      # 公開 API の集約
    rules.nix        # discoverCatalog / selectRules / mkBundle
    targets.nix      # defaultLocalTargets
  README.md
```

### 公開 API（`lib.agent-rules`）

skill 側と同名にして、利用側の flake.nix を対称に書けるようにする。

| 関数 | 実装 |
|---|---|
| `sourcesFromLock` | agent-skills-nix を再エクスポート |
| `mkSourceLockProgram` | 同上（program 名は `rules-sources-lock` に変える） |
| `discoverCatalog sources` | 新規。各 source の `path + "/" + subdir` を `readDir` し、`*.md` を列挙。ID 重複は throw |
| `selectRules { catalog; allowlist; }` | 新規。allowlist の ID を catalog から引く。未知 ID は throw |
| `mkBundle { pkgs; selection; }` | 新規。`runCommand` で `$out/<id>.md` に source のファイルを symlink |
| `defaultLocalTargets` | `{ claude = { dest = ".claude/rules"; structure = "copy-tree"; enable = false; systems = [ ]; }; }` |
| `mkLocalInstallProgram` / `mkShellHook` | agent-skills-nix の同名関数に `targets = defaultLocalTargets` を既定で渡すだけ |

### 実装スケッチ

```nix
# lib/rules.nix
{ lib }:
let
  inherit (builtins) readDir match attrNames;

  discoverSource = name: cfg:
    let
      root = if cfg.subdir == "." then cfg.path else cfg.path + "/${cfg.subdir}";
      entries = readDir root;
      mdFiles = builtins.filter
        (f: entries.${f} == "regular" && match ".*\\.md" f != null)
        (attrNames entries);
      toRule = f:
        let
          base = lib.removeSuffix ".md" f;
          id = if (cfg.idPrefix or null) == null then base else "${cfg.idPrefix}/${base}";
        in
        { inherit id; source = name; file = root + "/${f}"; };
      rules = map toRule mdFiles;
      regex = cfg.filter.nameRegex or null;
    in
    builtins.filter (r: regex == null || match regex r.id != null) rules;

  discoverCatalog = sources:
    lib.foldlAttrs
      (acc: name: cfg:
        lib.foldl'
          (inner: r:
            if inner ? ${r.id}
            then throw "agent-rules: duplicate rule id '${r.id}' in '${name}' and '${inner.${r.id}.source}'"
            else inner // { ${r.id} = r; })
          acc
          (discoverSource name cfg))
      { }
      sources;

  selectRules = { catalog, allowlist }:
    lib.genAttrs allowlist
      (id: catalog.${id} or (throw "agent-rules: unknown rule id '${id}'"));

  mkBundle = { pkgs, selection, name ? "agent-rules-bundle" }:
    pkgs.runCommand name { preferLocalBuild = true; } ''
      mkdir -p "$out"
      ${lib.concatMapStringsSep "\n" (r: ''
        mkdir -p "$out/$(dirname ${lib.escapeShellArg r.id})"
        ln -s ${lib.escapeShellArg "${r.file}"} "$out/${r.id}.md"
      '') (builtins.attrValues selection)}
    '';
in
{ inherit discoverCatalog selectRules mkBundle; }
```

```nix
# flake.nix（agent-rules-nix 側）
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
  };
  outputs = { nixpkgs, agent-skills, ... }:
    let
      lib = nixpkgs.lib;
      skillsLib = agent-skills.lib.agent-skills;
      rules = import ./lib/rules.nix { inherit lib; };
      defaultLocalTargets = {
        claude = { dest = ".claude/rules"; structure = "copy-tree"; enable = false; systems = [ ]; };
      };
    in
    {
      lib.agent-rules = rules // {
        inherit defaultLocalTargets;
        inherit (skillsLib) sourcesFromLock mkSourceLockProgram;
        mkLocalInstallProgram = args: skillsLib.mkLocalInstallProgram ({ targets = defaultLocalTargets; } // args);
        mkShellHook = args: skillsLib.mkShellHook ({ targets = defaultLocalTargets; } // args);
      };
    };
}
```

`r.file` を文字列補間すると `builtins.path` 相当で store にコピーされる。source 全体ではなくファイル単位になるので skill 側の safe-root 処理は不要。

## 利用側（このリポジトリ）の構成

skills と完全対称にする。

```
registry/rules/*.nix          # 取得元 manifest（書式は registry/sources と同じ）
registry/rules.lock.json      # rev 固定
rules.nix                     # 有効化するルール ID の一覧
rules/                        # 独自ルール（lock に載せない local source）
.claude/rules/                # 同期先。.gitignore に追加
```

`flake.nix` への追加:

```nix
inputs.agent-rules.url = "github:Hol1kgmg/agent-rules-nix";

# let 内
rulesLib = agent-rules.lib.agent-rules;
ruleSources = rulesLib.sourcesFromLock {
  manifestsDir = ./registry/rules;
  lockFile = ./registry/rules.lock.json;
} // { local = { path = ./rules; subdir = "."; filter = { }; idPrefix = null; }; };
ruleCatalog = rulesLib.discoverCatalog ruleSources;
ruleSelection = rulesLib.selectRules { catalog = ruleCatalog; allowlist = import ./rules.nix; };
ruleTargets = { claude = rulesLib.defaultLocalTargets.claude // { enable = true; }; };

# eachDefaultSystem 内
rulesBundle = rulesLib.mkBundle { inherit pkgs; selection = ruleSelection; };
checks.rules = rulesBundle;
apps.rules-list = ...;            # attrNames ruleCatalog を出す（skills-list と同形）
apps.rules-sources-lock = ...;    # rulesLib.mkSourceLockProgram
apps.rules-install-local = ...;   # rulesLib.mkLocalInstallProgram { inherit pkgs; bundle = rulesBundle; targets = ruleTargets; }
shellHook = ... + rulesLib.mkShellHook { inherit pkgs; bundle = rulesBundle; targets = ruleTargets; quiet = true; };
```

justfile への追加: `rules` / `rules-list` / `rules-update`。`update` レシピに `nix run .#rules-sources-lock` を足す。

`.claude/skills` が `.agents/skills` への symlink なのと違い、rules は Claude 専用なので `.claude/rules` に直接置く。

## 実装手順

1. `~/dev/github.com/Hol1kgmg/agent-rules-nix` を作成し、上のスケッチを書く。
2. `rules/` に 1 ファイル置いた `examples/` で `nix flake check` と `nix run .#rules-install-local` を通す。
3. GitHub に public repo を作って push。
4. このリポジトリに input・`registry/rules`・`rules.nix`・justfile・`.gitignore` を追加。
5. README.md の「エージェント用スキル」の段落に rules の一文を足す。

## スコープ外（必要になったら追加）

- Cursor（`.cursor/rules/*.mdc`）/ Copilot（`.github/instructions/*.instructions.md`）向けの形式変換。target を足すだけで配置はできるが、拡張子と frontmatter が異なる。
- skill 側の `agents` に相当する、ルールごとの target 制限。
- Home-Manager module（グローバル `~/.claude/rules` への配布）。
- マーカーファイル名の `agent-rules` 化。sync.sh を fork しないと変えられない。
