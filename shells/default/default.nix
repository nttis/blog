{pkgs, ...}:
pkgs.mkShell {
  packages = [
    pkgs.zola
  ];
}
