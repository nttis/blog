{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs: let
    forAllSystems = inputs.nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = import inputs.nixpkgs {
        system = system;
      };
    in {
      default = pkgs.mkShellNoCC {
        packages = with pkgs; [zola];
      };
    });
  };
}
