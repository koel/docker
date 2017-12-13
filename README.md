docker-koel
===========

[![automated-build-badge]][docker-hub]

A docker image with only the bare essentials needed to run [koel]. It includes
apache and a php runtime with required extensions.

Usage
-----

First start the koel server with a mysql database and music storage volume.

    docker run --name koel -p 80:80 -it 0xcaff/koel

On the first run, if the `.env` file isn't created, `koel:init` will be run and
the `APP_KEY` variable will be populated.

To see an example of running koel and a database with docker-compose, check out
the [`./docker-compose.yml`][compose] file.

[dbConfig]: https://github.com/phanan/koel/blob/baa5b7af13e7f66ff1d2df1778c65757a73e478f/config/database.php
[koel]: https://koel.phanan.net/
[compose]: ./docker-compose.yml

[automated-build-badge]: https://img.shields.io/docker/automated/0xcaff/koel.svg
[docker-hub]: https://hub.docker.com/r/0xcaff/koel/
