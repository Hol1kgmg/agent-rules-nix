{
  description = "Declarative agent rules (.claude/rules/*.md) with manifest + lock pinned sources, built on agent-skills-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
  };

  outputs = { nixpkgs, agent-skills, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      rulesLib = import ./lib { inherit lib; skillsLib = agent-skills.lib.agent-skills; };

      # examples/rules を自分自身の .claude/rules に同期して dogfood する
      ruleCatalog = rulesLib.discoverCatalog { local = { path = ./examples/rules; }; };
      ruleSelection = rulesLib.selectRules { catalog = ruleCatalog; allowlist = [ "sample" ]; };
      ruleTargets = { claude = rulesLib.defaultLocalTargets.claude // { enable = true; }; };
    in
    {
      lib.agent-rules = rulesLib;

      checks = forAllSystems (system: {
        rules-example = rulesLib.mkBundle { pkgs = nixpkgs.legacyPackages.${system}; selection = ruleSelection; };
      });

      apps = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          rules-install-local = {
            type = "app";
            program = "${rulesLib.mkLocalInstallProgram {
              inherit pkgs;
              bundle = rulesLib.mkBundle { inherit pkgs; selection = ruleSelection; };
              targets = ruleTargets;
            }}/bin/rules-install-local";
          };
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShell {
            packages = [ pkgs.just pkgs.gitleaks pkgs.lefthook pkgs.gh ];
            shellHook = ''
              lefthook install >/dev/null
            '' + rulesLib.mkShellHook {
              inherit pkgs;
              bundle = rulesLib.mkBundle { inherit pkgs; selection = ruleSelection; };
              targets = ruleTargets;
              quiet = true;
            };
          };
        });
    };
}
