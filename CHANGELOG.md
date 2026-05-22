# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Since this docker image only has one tag which is `latest`, there are no versions. However we'll write changes with the date at which they occured.

## 2026-05-22
### Fixed
- ⚠ Image storage path moved to follow koel/koel#2479. If you're upgrading from a previous release, update your `docker-compose.yml` so the `image_storage` volume binds to `/var/www/html/storage/app/public/images` instead of `/var/www/html/public/img/storage`. Existing data in your `image_storage` volume / host bind transfers over automatically when you switch the mount point — files inside the volume don't move, only the mount path inside the container does.
- Apache now follows symlinks under the document root, fixing the `Symbolic link not allowed or link target not accessible: /var/www/html/public/storage` error introduced when the new image path was symlinked.

## 2022-04-15
### Changed
- ⚠ BREAKING CHANGE: Image name has changed, it is now [`phanan/koel`](https://hub.docker.com/r/phanan/koel) instead of `hyzual/koel`.
- Koel: 5.1.13 -> 5.1.14

## 2022-03-10
### Changed
- Bump PHP version to 7.4.28

## 2022-01-18
### Changed
- Koel: 5.1.12 -> 5.1.13

## 2021-12-30
### Changed
- Koel: 5.1.8 -> 5.1.12
- Bump PHP version to 7.4.27

## 2021-11-08
### Changed
- Koel: 5.1.5 -> 5.1.8
- Bump PHP version to 7.4.25
- Bump ffmpeg version to 4.1.8

## 2021-09-27
### Changed
- Bump PHP version to 7.4.24

## 2021-09-07
### Changed
- Bump PHP version to 7.4.23

## 2021-08-29
### Changed
- Bump PHP version to 7.4.22

### Fixed
- Fixed a bug that prevented transcoding songs whose path had non-ascii characters in them. Thanks to [glynnt](https://github.com/glynnt) !

## 2021-07-27
### Changed
- Bump PHP version to 7.4.21
- Bump to Koel v5.1.5

## 2021-06-07
### Changed
- Bump PHP version to 7.4.20

## 2021-05-22
### Added
- Support of PostgreSQL

### Changed
- Bump to Koel v5.1.4
