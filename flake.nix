{
  description = "Declarative agent rules (.claude/rules/*.md) with manifest + lock pinned sources, built on agent-skills-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
  };

  outputs = { nixpkgs, agent-skills, ... }:
    let
      inherit (nixpkgs) lib;
      rulesLib = import ./lib { inherit lib; skillsLib = agent-skills.lib.agent-skills; };
    in
    {
      lib.agent-rules = rulesLib;

      # examples/rules からバンドルが組めることを CI で検証する
      checks = lib.genAttrs lib.systems.flakeExposed (system: {
        rules-example = rulesLib.mkBundle {
          pkgs = nixpkgs.legacyPackages.${system};
          selection = rulesLib.selectRules {
            catalog = rulesLib.discoverCatalog { local = { path = ./examples/rules; }; };
            allowlist = [ "sample" ];
          };
        };
      });
    };
}
