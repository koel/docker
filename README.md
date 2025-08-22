koel/docker
===========

[![docker-pulls-badge]][docker-hub] ![Continuous testing and deployment](https://github.com/koel/docker/workflows/Continuous%20testing%20and%20deployment/badge.svg)

A docker image with only the bare essentials needed to run [koel]. It includes Apache and a PHP runtime with required extensions.

> [!IMPORTANT]
> This container does not include a database. It **requires** another container to handle the database.

## Usage

Since [Koel supports many databases][koel-requirements] you are free to choose any Docker image that hosts one of those databases.

`koel/docker` (this image) has been tested with MariaDB/MySQL and PostgreSQL.

### Run with docker-compose and MariaDB/MySQL

[docker-compose] is the easiest way to get started. It will start both the database container and this image.
Clone this repository and edit `docker-compose.mysql.yml`. **Make sure to replace passwords !**

Check out the [`./docker-compose.mysql.yml`](<./docker-compose.mysql.yml>) file for more details.

Then run `docker-compose`:

```bash
docker-compose -f ./docker-compose.mysql.yml up -d
```

### Run with docker-compose and PostgreSQL

Clone this repository and edit `docker-compose.postgres.yml`. **Make sure to replace passwords !**

Check out the [`./docker-compose.postgres.yml`](<./docker-compose.postgres.yml>) file for more details.

Then run `docker-compose`:

```bash
docker-compose -f ./docker-compose.postgres.yml up -d
```

## The `koel:init` command

This command is automatically ran when the container starts, but can be disabled if you want to do some manual adjustments first. As such it is often sufficient to provide the needed env variables to the container to setup koel.

For the first installation and every subsequent upgrade, you will need to run the `koel:init` command, which handles migrations and other setup tasks.
For instance, during the first run, this command will generate the `APP_KEY`, create the default admin user, and initialize the database. For subsequent runs, it will apply any new migrations and update the database schema as needed.

In order to run this command, you first need to `exec` into the container (replace `<container_name_for_koel>` with the name of your running Koel container):

```bash
docker exec --user www-data -it <container_name_for_koel> sh
```

Once inside the container, run the `koel:init` command:

```bash
# --no-assets option tells the init command to skip building the front-end assets, 
# as they have already been built and included in the Koel's installation archive.
$ php artisan koel:init --no-assets
```

When prompted, provide `database` as the database host, `koel` as both the database name and username, and the password you set when 
creating the database container.

### Default admin account

During the first `koel:init`, Koel creates the default admin account for you. The credentials are as follows:

* Email: `admin@koel.dev`
* Password: `KoelIsCool`

For security purposes, run the following command to update the account's password **before using Koel**:

```bash
docker exec -it <container_name_for_koel> php artisan koel:admin:change-password
```

You can also update the account (including the email) using the web interface after logging in.

### Run manually with MariaDB/MySQL

Create a docker network. It will be shared by Koel and its database.

```bash
docker network create --attachable koel-net
```

Create a database container. Here we will use [mariadb].

```bash
docker run -d --name database \
    -e MYSQL_ROOT_PASSWORD=<root_password> \
    -e MYSQL_DATABASE=koel \
    -e MYSQL_USER=koel \
    -e MYSQL_PASSWORD=<koel_password> \
    --network=koel-net \
    -v koel_db:/var/lib/mysql \
    mariadb:10.11
```

Create the koel container on the same network so they can communicate

```bash
docker run -d --name koel \
    -p 80:80 \
    -e DB_CONNECTION=mysql \
    -e DB_HOST=database \
    -e DB_DATABASE=koel \
    -e DB_USERNAME=koel \
    -e DB_PASSWORD=<koel_password> \
    --network=koel-net \
    -v music:/music \
    -v covers:/var/www/html/public/img/covers \
    -v search_index:/var/www/html/storage/search-indexes \
    phanan/koel
```

The same applies for the first run. See the [First run section](#first-run).

### How to bind-mount the `.env` file

To be sure to preserve `APP_KEY` you can choose to bind-mount the `.env` file to your host:

```bash
# On your host, create an `.env` file
touch .env

# Then, you can bind-mount it directly in the container
docker run -d --name koel \
    -p 80:80 \
    --mount type=bind,source="$(pwd)"/.env,target=/var/www/html/.env \
    phanan/koel
    
docker exec --user www-data -it koel bash

# In the container, run koel:init command with --no-assets flag
$ php artisan koel:init --no-assets
```

### Pass environment variables

Once you have generated an `APP_KEY` you can provide it as environment variables to your container to preserve it.

```bash
# Run a container just to generate the key
docker run -it --rm phanan/koel sh
# In the container, generate APP_KEY
$ php artisan key:generate --force
# Show the modified .env file
$ cat .env
# Copy the APP_KEY variable, and exit the container
$ exit
```

You can then provide the variables to your real container:

```bash
docker run -d --name koel \
    -p 80:80 \
    -e APP_KEY=<your_app_key> \
    phanan/koel
# Even better, write an env-file in your host and pass it to the container
docker run -d --name koel \
    -p 80:80 \
    --env-file .koel.env \
    phanan/koel
```

### Scan media folders

Koel's init script installs a [scheduler](https://docs.koel.dev/cli-commands#command-scheduling) that scans the `/music` folder daily for new music.
You can also trigger a manual scan at any time by running the following command:

```bash
docker exec --user www-data <container_name_for_koel> php artisan koel:sync
```

### Populate the search indexes

If you were running a version of Koel prior to v5.0.2, the search mechanism has changed and needs a step to index songs, albums and artists. Run the following command:

```bash
docker exec --user www-data <container_name_for_koel> php artisan koel:search:import
```

For all new songs, the search index will be automatically populated by `php artisan koel:scan`. No need to run the `php artisan koel:search:import` again 🙂.

## Useful environment variables

> [!IMPORTANT]
> This list is not exhaustive and may not be up-to-date. See [`.env.example`][koel-env-example] for a complete reference.
- `SKIP_INIT` : set a value to prevent the container from automatically running the init script on startup
- `DB_CONNECTION`: `mysql` OR `pgsql` OR `sqlsrv` OR `sqlite-persistent`. Corresponds to the type of database being used with Koel.
- `DB_HOST`: `database`. The name of the Docker container hosting the database. Koel needs to be on the same Docker network to find the database by its name.
- `DB_USERNAME`: `koel`. If you change it, also change it in the database container.
- `DB_PASSWORD`: The password credential matching `DB_USERNAME`. If you change it, also change it in the database container.
- `DB_DATABASE`: `koel`. The database name for Koel. If you change it, also change it in the database container.
- `APP_KEY`: A base64-encoded string, generated by `php artisan koel:init` or by `php artisan key:generate`.
- `FORCE_HTTPS`: If set to `true`, all URLs redirects done by koel will use `https`. If you have set up a reverse-proxy in front of this container that supports `https`, set it to `true`.
- `MEMORY_LIMIT`: The amount of memory in MB for the scanning process. Increase this value if `php artisan koel:scan` runs out of memory.
- `LASTFM_API_KEY` and `LASTFM_API_SECRET`: Enables Last.fm integration. See https://docs.koel.dev/3rd-party.html#last-fm
- `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`: Enables Spotify integration. See https://docs.koel.dev/3rd-party.html#spotify
- `OPTIMIZE_CONFIG` Preload and optimize the config. This disables your ability to do config edits while the container is running. If you enable this every config change will require a container restart to apply.

## Volumes

### /music

`/music` will contain the music library.

### /var/www/html/storage/search-indexes

`/var/www/html/storage/search-indexes` will contain the search indexes. Searching songs, albums and artists leverages this to provide results.

## Ports

### 80

Only HTTP is provided. Consider setting up a reverse-proxy to provide HTTPS support.

## Workdir

### /var/www/html

Apache's root directory. All koel files will be here. If you `exec` into the container, this will be your current directory.

## Help & Support

If you run into any issues, check the [Koel documentation][koel-doc] first. 
If you encounter a bug in Koel itself, open an issue in the [Koel repository][koel-repo].
This repo’s issues are reserved for Docker-related questions and problems.

[koel-env-example]: https://github.com/koel/koel/blob/master/.env.example
[koel-requirements]: https://docs.koel.dev/guide/getting-started#requirements
[koel]: https://koel.dev/
[koel-doc]: https://docs.koel.dev/
[koel-repo]: https://github.com/koel/koel
[mariadb]: https://hub.docker.com/r/mariadb/server
[docker-compose]: https://docs.docker.com/compose/

[docker-pulls-badge]: <https://img.shields.io/docker/pulls/phanan/koel>
[docker-hub]: https://hub.docker.com/r/phanan/koel
