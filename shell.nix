{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/5dbd28d75410738ee7a948c7dec9f9cb5a41fa9d.tar.gz") {} }:

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
