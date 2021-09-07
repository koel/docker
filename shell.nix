let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6cc260cfd60f094500b79e279069b499806bf6d8.tar.gz";
    sha256 = "0vak6jmsd33a7ippnrypqmsga1blf3qzsnfy7ma6kqrpp9k26cf6";
  };
in { pkgs ? import "${nixpkgs}" {} }:

with pkgs; mkShellNoCC {
    buildInputs = [
        docker-compose
        coreutils
        gawk
        gitMinimal
        gnugrep
        gnumake
        goss
        dgoss
    ];

    # Use the SSH client provided by the system (FHS only) to avoid issues with Fedora default settings
    GIT_SSH = if lib.pathExists "/usr/bin/ssh" then "/usr/bin/ssh" else "ssh";
}
