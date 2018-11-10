docker-koel
===========

[![automated-build-badge]][docker-hub]

A docker image with only the bare essentials needed to run [koel]. It includes
apache and a php runtime with required extensions.

Usage
-----

First start the koel server with a mysql database and music storage volume.

    docker run --name koel -p 80:80 -it 0xcaff/koel

On the first run, if the `.env` file isn't created, it will be created and the
`APP_KEY` variable will be populated.

Compose
-------

[docker-compose] can be used to start koel along with its depdencies. Just run.

    docker-compose up

On the first start (after an upgrade or initial installation), the database
needs to be migrated. Run koel init with `docker exec` in the koel runtime
container:

    docker-compose exec koel php artisan koel:init

Check out the [`./docker-compose.yml`][compose] file for more information.

[dbConfig]: https://github.com/phanan/koel/blob/baa5b7af13e7f66ff1d2df1778c65757a73e478f/config/database.php
[koel]: https://koel.phanan.net/
[compose]: ./docker-compose.yml

[docker-compose]: https://docs.docker.com/compose/

[automated-build-badge]: https://img.shields.io/docker/automated/0xcaff/koel.svg
[docker-hub]: https://hub.docker.com/r/0xcaff/koel/
