docker-koel
===========

A docker image with only the bare essentials needed to run koel. It includes
apache and a php runtime with required extensions.

Usage
-----

First, start the koel server. The server is exposed on port 80. Tell koel where
your database using the environment variables documented here in koel's
[config/database.php][dbConfig] file. Make sure your database and music storage
location are acessible to the container.

    docker run --name koel -p 80:80 0xcaff/docker-koel

If this is the first time running koel, the database will need to be initialized
by running `php artisan koel:init`.

    docker exec -it koel php artisan koel:init

[dbConfig]: https://github.com/phanan/koel/blob/baa5b7af13e7f66ff1d2df1778c65757a73e478f/config/database.php
