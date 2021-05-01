{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/c8dff328e51f62760bf646bc345e3aabcfd82046.tar.gz") {} }:

pkgs.mkShell {
    buildInputs = [
		pkgs.docker-compose
        pkgs.coreutils
        pkgs.gawk
        pkgs.gitMinimal
        pkgs.gnugrep
        pkgs.gnumake
    ];

    # Use the SSH client provided by the system (FHS only) to avoid issues with Fedora default settings
    GIT_SSH = if pkgs.lib.pathExists "/usr/bin/ssh" then "/usr/bin/ssh" else "ssh";
}
