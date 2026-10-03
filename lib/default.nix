# 公開 API（lib.agent-rules）。agent-skills-nix の skill 非依存な関数を流用し、
# rules 固有の部分だけ ./rules.nix で実装する。
{ lib, skillsLib }:

let
  rules = import ./rules.nix { inherit lib; };

  defaultLocalTargets = {
    claude = { dest = ".claude/rules"; structure = "copy-tree"; enable = false; systems = [ ]; };
  };

  # skills 側は実行ファイル名と上書き用環境変数が skills 固定なので、export 済みの
  # mkSyncProgram を直接呼んで rules 用に差し替える。
  mkLocalInstallProgram = { pkgs, bundle, targets ? defaultLocalTargets, ... }@args:
    skillsLib.mkSyncProgram ((builtins.removeAttrs args [ "targets" ]) // {
      inherit targets;
      mode = "local";
      programName = "rules-install-local";
      allowOverrides = true;
      overrideEnvVar = "AGENT_RULES_LOCAL_DESTS";
      overrideStructure = "copy-tree";
    });

  mkShellHook = { quiet ? false, ... }@args:
    ''
      ${lib.optionalString quiet "AGENT_SKILLS_QUIET=1 "}${mkLocalInstallProgram (builtins.removeAttrs args [ "quiet" ])}/bin/rules-install-local
    '';

  mkSourceLockProgram = { pkgs, manifestsDir ? "registry/rules", lockFile ? "registry/rules.lock.json", ... }@args:
    pkgs.writeShellScriptBin "rules-sources-lock" ''
      exec ${skillsLib.mkSourceLockProgram (args // { inherit manifestsDir lockFile; })}/bin/skills-sources-lock "$@"
    '';
in
rules // {
  inherit defaultLocalTargets mkLocalInstallProgram mkShellHook mkSourceLockProgram;
  inherit (skillsLib) sourcesFromLock;
}
