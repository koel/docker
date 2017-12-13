docker-koel
===========

A docker image with only the bare essentials needed to run [koel]. It includes
apache and a php runtime with required extensions.

Usage
-----

First, start the koel server. The server is exposed on port 80. Tell koel where
your database using the environment variables documented in koel's
[config/database.php][dbConfig] file. Make sure your database and music storage
location are acessible in the container.

    docker run --name koel -p 80:80 0xcaff/docker-koel

If this is the first time running koel, the database will need to be initialized
by running `php artisan koel:init`.

    docker exec -it koel php artisan koel:init

Sometimes `koel:init` doesn't generate an `APP_KEY`. This will need to be
done for each container. The `APP_KEY` is used to encrypt sessions. If it isn't
there, 5xx errors will happen sometimes.

    docker exec -it koel /bin/bash
    # echo "APP_KEY=$(php artisan key:generate --show)" >> .env

To see an example of running koel and a database with docker-compose, check out
the [`./docker-compose.yml`][compose] file.

[dbConfig]: https://github.com/phanan/koel/blob/baa5b7af13e7f66ff1d2df1778c65757a73e478f/config/database.php
[koel]: https://koel.phanan.net/
[compose]: ./docker-compose.yml
