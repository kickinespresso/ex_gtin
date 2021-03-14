# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2021-03-14

Summary: Merged new function `normalize/1` and other refactoring thanks to the fork [fork](https://github.com/hellonarrativ/ex_gtin)
 and @michaeljguarino

Details:

- Merged [7a1a0fc3f(https://github.com/hellonarrativ/ex_gtin/commit/7a1a0fc3f42f9eacd5de61f24cac0b9f3e52d1a7) from [fork](https://github.com/hellonarrativ/ex_gtin) - @cdesch
- Adding `normalize/1` and tests to convert a GTIN or ISBN to GTIN-14 format - Big Thanks to @michaeljguarino!
- Update `gtin_check_digit`, `generate_gtin_code` to use capture operators `&` - Big Thanks to @michaeljguarino!
- Add `()` to `generate_check_digit` functions - Big Thanks to @michaeljguarino!
- Fix Formatting of `multiply_and_sum_array`, `subtract_from_nearest_multiple_of_ten`, `mult_by_index_code` and `find_gs1_prefix_country` - Big Thanks to @michaeljguarino!
- Added tests for GTIN-8, GTIN-12, GTIN 14 - @cdesch

## [1.0.1] - 2021-03-14

- Bumping version from `1.0.0` to `1.0.1` - @cdesch
- Update dependenciens `credo`, `excoveralls` and `ex_doc` to the latest versions - @cdesch
- Add installation instructions to readme.md - @cdesch
- Testing with elixir 1.11.3 - @cdesch
- Remove deperated functions `check_gtin` and `generate_gtin` - *Please use `validate/1` and `generate/1` instead* - @cdesch
- Remove tests associated with `check_gtin` and `generate_gtin` - *Please use `validate/1` and `generate/1` instead* - @cdesch
- Convert `@since` to `@doc since:` for `ex_doc` - @cdesch
- Add proper `@doc since: "1.0.0"` to `validation.ex` - @cdesch
- Add `preferred_cli_env` as `:test` for `pull_request_checkout.task` task - @cdesch

## [1.0.0] - 2019-08-06

### Contains breaking changes*

- *BREAKING CHANGE* `generate/1` - Formerly would return the result. It now returns the result in an atom e.g. `{:ok, "6291041500213"}`  - @cdesch
- Added `generate!/1` - Raises `ArgumentError` if invalid  - @cdesch
- Added `validate!/1`- Raises `ArgumentError` if invalid  - @cdesch
- Deprecated `generate_gtin` for `generate`. `generate_gtin` will be removed in version `1.0.1` - @cdesch
- Deprecated `check_gtin` for `validate`. `check_gtin` will be removed in version `1.0.1` - @cdesch
- Updated README with changes
- Fixed README markdown issues for code indentation

## [0.4.0] - 2019-07-26

- Deprecated `generate_gtin` for `generate`. `generate_gtin` will be removed in version `1.0.0` - @cdesch
- Deprecated `check_gtin` for `validated`. `check_gtin` will be removed in version `1.0.0` - @cdesch
- Validated Functionality with Elixir 1.9.1 and Elixir 1.7.4 - @cdesch
- README Updates with additional information - @cdesch
- Credo Fixes - @cdesch
- Updating Credo from `0.10.0` to `1.1.2` - @cdesch
- Updating Coveralls from `0.9.2` to `0.11.1` - @cdesch
- Updating ExDocs from `0.19.1` to `0.21.1` - @cdesch

TODO: Make functions private in the validation module

## [0.3.4] - 2018-08-15 (Not Published)

- Adding `describe` groupings to tests - @cdesch

## [0.3.3] - 2018-08-15

- Reformatted CHANGELOG.md - @cdesch
- Testing with Elixir 1.7.2 - @cdesch
- Added UPC acronym definition to README.md - @cdesch
- Updating Credo from `0.9.2` to `0.10.0` - @cdesch
- Updating Coveralls from `0.8.2` to `0.9.2` - @cdesch
- Updating ExDocs from `0.18.3` to `0.19.1` - @cdesch

## [0.3.2] - 2018-05-21

- Adding UPC to description in README.md - @cdesch
- Adding Module Docs - @cdesch
- Fixing Readme Link for MIT license badge - @cdesch

## [0.3.1] - 2018-05-21

- Updated dependencies and fixed Credo Errors - @cdesch

## [0.3.0] - 2018-01-16

- Added GS1 Prefix Look up `gs1_prefix_country`for country code - @cdesch

## [0.2.7] - 2018-01-16

- Bumping version to 0.2.7 due to issue with `mix hex.publish` - @cdesch

## [0.2.6] - 2018-01-16

- Bumping versions of credo, ex_doc and coveralls - @cdesch

## [0.2.5] - 2017-07-30

- Added additional Doc Tests - @cdesch

## [0.2.4] - 2017-07-28

- Changed package name from ExGtin to ex_gtin - @cdesch

## [0.2.3] - 2017-07-28

- Fixing [README.md](README.md) formatting - @cdesch
- Refactored `string` type spec to `String.t()` - @cdesch
- Added composite mix task for validating the library - @cdesch
- Changed [CONTRIBUTING.md](CONTRIBUTING.md) pull request process to test the library - @cdesch

### Added

- Added .editorconfig file - @cdesch
- Added more test for each type of GTIN - @cdesch

## [0.2.2] - 2017-07-06

- Added Generate GTIN function - @cdesch
- Added CHANGELOG.md with history - @cdesch
- Updated Readme with usage and minor fixes - @cdesch

## [0.2.1] - 2017-07-04

- Added GTIN Length Validation and error handling - @cdesch

## [0.2.0] - 2017-07-03

- Added [CONTRIBUTING.md](CONTRIBUTING.md) file - @cdesch
- Added [LICENSE.md](LICENSE.md) file - @cdesch
- Reorganizing code in modules - @cdesch

## [0.1.0] - 2017-07-03

- Initial Release - @cdesch
