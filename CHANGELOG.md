# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

[Unreleased]: https://github.com/Shopify/app_profiler

## [0.10.0] - 2022-04-18

- Support stackprof's ignore_gc option (#42)

## [0.0.9] - 2022-03-02

- Add speedscope remote viewer (#33)
- Properly cast X-Profile-Data to String (#40)
- Allow a trailing slash in the URL (#39)

## [0.0.8] - 2021-06-09

- Add File Safe Regex to Profile Filename (#30)
- Bump various dependencies

## [0.0.7] - 2021-02-19

- Add default logger for non-rails contexts (#21).
- Fix redundant `yarn add`s when viewing profiles (#20).
- Add `AppProfiler.start` and `AppProfiler.stop` (#19).

## [0.0.6] - 2020-07-08

- Fix development Speedscope view when using Yarn workspaces (#16).

## [0.0.5] - 2020-06-17

- Support for customizing the profile url (#12).

## [0.0.4] - 2020-05-25

- Fix keyword argument warnings on Ruby 2.7 (#11).

## [0.0.3] - 2020-05-20

### Changed

- The default object sampling rate is decreased from 10,000 to 2000 (#5).
- The acceptable minimum interval for object profiling is decreased from 10,000 to 400 (#5).
