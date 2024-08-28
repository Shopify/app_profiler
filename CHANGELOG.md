# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.2.3] - 2024-08-28

- Profile sampler probability fix (#130)

## [0.2.2] - 2024-08-26

- Add profile sampler (#128)

## [0.2.1] - 2024-08-01

- Centralize Ruby Version to .ruby-version (#115)
- Forward profile metadata to GCS (#126)

## [0.2.0] - 2024-06-17

- Make profiler backend modular, add support for vernier profiler (#101)

## [0.1.10] - 2023-12-13

- Redirect to remote speedscope request profiles automatically (#108)

## [0.1.9] - 2023-12-07

- Bug fix: use HTML5 sanitizer when available so Speedscope remote viewer doesn't bail on big payloads (#102)
- Bug fix: view profiles in test mode by default (#105)

## [0.1.8] - 2023-11-07

- add callbacks for async profile processing(#103)

## [0.1.7] - 2023-10-19

- Clean up files after uploading to GCS (#99)

## [0.1.6] - 2023-10-18

- Allow passing custom block to determine profile file name prefix (#94)
- Change `'X-Profile-Async: true` to `'X-Profile-Async: "true"` (#95)

## [0.1.5] - 2023-09-25

- Fix `AppProfiler::Server` to no longer be immortal. This avoid leaking servers when respawning the server after fork (#93)

## [0.1.4] - 2023-09-19

- Allow passing custom parameters instance to Middleware#call, to programatically trigger profiling (#87)
- Allow async uploads of profiles in a background thread (#80)

## [0.1.3] - 2022-09-22

- Take logger as an arg in `AppProfiler::Server` start method (#64)
- Railtie is an optional dependency (#63)

## [0.1.2] - 2022-08-12

- Bug fix: Update profile server to respond with a conflict if already profiling (#57)
- Profiler Server imports necessary Active Support core extensions (#59,#61)
- Bug fix: Ensure default profile_url_formatter default url formatter is set during initialization (#54)

## [0.1.1] - 2022-06-15

- Support for "profile server" to support on-demand profiling via HTTP (#48)
- Log info with link to speedscope during file upload (#47)

## [0.1.0] - 2022-04-18

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
