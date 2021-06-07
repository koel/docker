{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/ffb7cfcfad15e3bff9d05336767e59ee6ee24cb6.tar.gz") {} }:

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
