# ルールの discovery / selection / bundle。
# source は agent-skills-nix の sourcesFromLock が返す { path; subdir; filter; idPrefix; } か、
# local 用の { path = ./rules; }（他は省略可）。
{ lib }:

let
  inherit (builtins) readDir match attrNames attrValues;

  discoverSource = name: cfg:
    let
      subdir = cfg.subdir or ".";
      root = if subdir == "." then cfg.path else cfg.path + "/${subdir}";
      entries =
        if builtins.pathExists root then readDir root
        else throw "agent-rules: source '${name}' path ${toString root} does not exist";
      mdFiles = builtins.filter
        (f: entries.${f} == "regular" && match ".*\\.md" f != null && lib.toLower f != "readme.md")
        (attrNames entries);
      prefix = cfg.idPrefix or null;
      regex = cfg.filter.nameRegex or null;
      toRule = f:
        let base = lib.removeSuffix ".md" f;
        in {
          id = if prefix == null then base else "${prefix}/${base}";
          source = name;
          file = root + "/${f}";
        };
    in
    builtins.filter (r: regex == null || match regex r.id != null) (map toRule mdFiles);

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

  # fetchTarball 由来の path は context を持たない文字列なので、builtins.path で
  # ファイル単位に store へ取り込んでから参照する。
  mkBundle = { pkgs, selection, name ? "agent-rules-bundle" }:
    let
      storeFile = r: builtins.path {
        path = r.file;
        name = lib.strings.sanitizeDerivationName (baseNameOf r.file);
      };
    in
    pkgs.runCommand name { preferLocalBuild = true; } ''
      mkdir -p "$out"
      ${lib.concatMapStringsSep "\n" (r: ''
        mkdir -p "$out/$(dirname ${lib.escapeShellArg r.id})"
        ln -s ${lib.escapeShellArg "${storeFile r}"} "$out/${r.id}.md"
      '') (attrValues selection)}
    '';
in
{ inherit discoverCatalog selectRules mkBundle; }
