let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/32bfa39ab4508e201939888e10feeecd61c25108.tar.gz";
    sha256 = "050x039dvck8srka8iahdk40j6knrh52i3wjknmwx98q86kv29wq";
  };
in { pkgs ? import "${nixpkgs}" {} }:

with pkgs; mkShell {
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
