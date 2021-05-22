koel/docker
===========

[![docker-pulls-badge]][docker-hub] ![Continuous testing and deployment](https://github.com/koel/docker/workflows/Continuous%20testing%20and%20deployment/badge.svg)

A docker image with only the bare essentials needed to run [koel]. It includes
apache and a php runtime with required extensions.

See the [Changelog](<./CHANGELOG.md>) to keep track of changes to the image.

## Usage

⚠ This container does not include a database. It **requires** another container to handle the database.

Since [Koel supports many databases][koel-requirements] you are free to choose any Docker image that hosts one of those databases.

`koel/docker` (this image) has been tested with MySQL and PostgreSQL.

### Run with docker-compose and MySQL

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

### First run

On the first run, you will need to:

1. Generate `APP_KEY`
2. Create an admin user
3. Initialize the database

All these steps are achieved by running `koel:init` once:

Replace `<container_name_for_koel>` in the command by the actual container name.

```bash
docker exec -it <container_name_for_koel> bash
# Once inside the container, you can run commands:
$ php artisan koel:init --no-assets
```

`--no-assets` option tells the init command to skip the build of front-end assets. They are already built by a Github Action in koel's repository, so this step is not necessary.

### Default admin account

⚠ From v5.1.0, Koel will no longer ask for a username, email and password for the admin account. Instead, it creates one automatically with the following credentials:

```
email: admin@koel.dev
password: KoelIsCool
```

**Make sure to change this unsecure password** with the user interface (click on your profile picture) or by running the following command:

```bash
docker exec -it <container_name_for_koel> php artisan koel:admin:change-password
```

### Run manually with MySQL

Create a docker network. It will be shared by Koel and its database.

```bash
docker network create --attachable koel-net
```

Create a database container. Here we will use [mysql].

```bash
docker run -d --name database \
    -e MYSQL_ROOT_PASSWORD=<root_password> \
    -e MYSQL_DATABASE=koel \
    -e MYSQL_USER=koel \
    -e MYSQL_PASSWORD=<koel_password> \
    --network=koel-net \
    -v koel_db:/var/lib/mysql \
    mysql/mysql-server:5.7
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
    hyzual/koel
```

The same applies for the first run. See the [First run section](#first-run).

### How to bind-mount the `.env` file

To be sure to preserve `APP_KEY` you can choose to bind-mount the `.env` file to your host:

```bash
# On your host, create an `.env` file:
touch .env
# Then, you can bind-mount it directly in the container.
docker run -d --name koel \
    -p 80:80 \
    --mount type=bind,source="$(pwd)"/.env,target=/var/www/html/.env \
    hyzual/koel
docker exec -it koel bash
# In the container, init
$ php artisan koel:init --no-assets
```

### Pass environment variables

Once you have generated an `APP_KEY` you can provide it as environment variables to your container to preserve it.

```bash
# Run a container just to generate the key
docker run -it --rm hyzual/koel bash
# In the container, generate APP_KEY
$ php artisan key:generate --force
# Show the modified .env file
$ cat .env
# Copy the APP_KEY variable
$ exit
```

You can then provide the variables to your real container:

```bash
docker run -d --name koel \
    -p 80:80 \
    -e APP_KEY=<your_app_key> \
    hyzual/koel
# Even better, write an env-file in your host and pass it to the container
docker run -d --name koel \
    -p 80:80 \
    --env-file .koel.env \
    hyzual/koel
```

### Scan media folders

Whenever the music in `/music` changes, you will need to manually scan it before koel is able to play it. Run the following command:

```bash
docker exec <container_name_for_koel> php artisan koel:sync
```

### Populate the search indexes

If you were running a version of Koel prior to v5.0.2, the search mechanism has changed and needs a step to index songs, albums and artists. Run the following command:

```bash
docker exec <container_name_for_koel> php artisan koel:search:import
```

For all new songs, the search index will be automatically populated by `php artisan koel:sync`. No need to run the `php artisan koel:search:import` again 🙂.

## Useful environment variables

See [`.env.example`][koel-env-example] for reference.

- `DB_CONNECTION`: `mysql` OR `pgsql` OR `sqlsrv` OR `sqlite-persistent`. Corresponds to the type of database being used with Koel.
- `DB_HOST`: `database`. The name of the Docker container hosting the database. Koel needs to be on the same Docker network to find the database by its name.
- `DB_USERNAME`: `koel`. If you change it, also change it in the database container.
- `DB_PASSWORD`: The password credential matching `DB_USERNAME`. If you change it, also change it in the database.
- `DB_DATABASE`: `koel`. The database name for Koel. If you change it, also change it in the database.
- `APP_KEY`: a base64 string. It is generated by `php artisan koel:init` or by `php artisan key:generate`. Once you have scanned music, DO NOT CHANGE `APP_KEY`. Songs are identified by a combination of `APP_KEY` and their path, so if `APP_KEY` changes, the next `php artisan koel:scan` will report all songs as changed.
- `FORCE_HTTPS`: if set to `true`, all URLs redirects done by koel will use `https`. If you have setup a reverse-proxy in front of this container that supports `https`, set it to `true`.
- `MEMORY_LIMIT`: amount of memory in MB for the scanning process. Set this if `php artisan koel:scan` runs out of memory.
- `LASTFM_API_KEY` and `LASTFM_API_SECRET`: Enable scrobbling to Last.fm. See https://docs.koel.dev/3rd-party.html#last-fm

## Volumes

### /music

`/music` will contain the music library. Keep in mind that koel needs to scan music before it's able to play it.

### /var/www/html/storage/search-indexes

`/var/www/html/storage/search-indexes` will contain the search indexes. Searching songs, albums and artists leverages this to provide results.

## Ports

### 80

Only HTTP is provided. Consider setting up a reverse-proxy to provide HTTPS support.

## Workdir

### /var/www/html

Apache's root directory. All koel files will be here. If you `exec` into the container, this will be your current directory.

[koel-env-example]: https://github.com/koel/koel/blob/v5.1.3/.env.example
[koel-requirements]: https://docs.koel.dev/#/?id=requirements
[koel]: https://koel.dev/
[mysql]: https://hub.docker.com/r/mysql/mysql-server
[docker-compose]: https://docs.docker.com/compose/

[docker-pulls-badge]: <https://img.shields.io/docker/pulls/hyzual/koel>
[docker-hub]: https://hub.docker.com/r/hyzual/koel
