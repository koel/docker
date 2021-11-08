let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/7053541084bf5ce2921ef307e5585d39d7ba8b3f.tar.gz";
    sha256 = "1flhh5d4zy43x6060hvzjb5hi5cmc51ivc0nwmija9n8d35kcc4x";
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
