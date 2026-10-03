{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-utils.url = "github:numtide/flake-utils";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    nur-packages.url = "github:Hol1kgmg/nur-packages";
  };

  outputs = { nixpkgs, flake-utils, agent-skills, nur-packages, ... }:
    let
      agentLib = agent-skills.lib.agent-skills;

      # スキルの取得元は ./registry/sources、有効にする ID は ./skills.nix
      sources = agentLib.sourcesFromLock {
        manifestsDir = ./registry/sources;
        lockFile = ./registry/sources.lock.json;
      } // {
        # 独自スキル。rev 固定が不要なため lock には載せない。
        local = { path = ./skills; };
      };
      catalog = agentLib.discoverCatalog sources;
      selection = agentLib.selectSkills {
        inherit catalog sources;
        allowlist = import ./skills.nix;
      };

      localTargets = {
        agents = agentLib.defaultLocalTargets.agents // { enable = true; };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        bundle = agentLib.mkBundle { inherit pkgs selection; };
      in {
        # skills.nix の宣言が解決できてバンドルが組めるかの確認（nix flake check）
        checks.skills = bundle;

        # sources から見つかった全スキル ID の一覧（skills.nix の候補）
        apps.skills-list = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "skills-list" ''
            cat ${pkgs.writeText "skill-ids" (nixpkgs.lib.concatLines (builtins.attrNames catalog))}
          ''}/bin/skills-list";
        };

        # registry/sources/*.nix を解決して sources.lock.json を更新する
        apps.skills-sources-lock = {
          type = "app";
          program = "${agentLib.mkSourceLockProgram { inherit pkgs; }}/bin/skills-sources-lock";
        };

        apps.skills-install-local = {
          type = "app";
          program = "${agentLib.mkLocalInstallProgram { inherit pkgs bundle; targets = localTargets; }}/bin/skills-install-local";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.just
            pkgs.gitleaks
            pkgs.lefthook
            pkgs.gh
            pkgs.gh-dash
            nur-packages.packages.${system}.markserv
          ];

          shellHook = ''
            lefthook install >/dev/null
          '' + agentLib.mkShellHook {
            inherit pkgs bundle;
            targets = localTargets;
            quiet = true;
          };
        };
      });
}
