# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-09-26

- Added GS1-128 / Application Identifier (AI) element-string parsing (F10):
  `ExGtin.parse_gs1/1`, `ExGtin.parse_gs1/2`, and the raising
  `ExGtin.parse_gs1!/1`, backed by `ExGtin.GS1.ElementString` and the
  data-driven `ExGtin.GS1.AITable` dictionary
  - A single entry point accepts **both** serializations of the same logical
    payload: the parenthesized human-readable form (`(01)06291041500213(10)ABC123`,
    recognized because it starts with `(`) and the raw FNC1 scanner form (fixed-length
    AIs concatenated without a separator, variable-length AIs terminated by the
    FNC1/GS separator, ASCII 29). Both forms of the same payload produce an equal
    `%{ai => value}` map
  - Initially supported AI set: `01` (GTIN), `10` (Batch/Lot), `11` (Production
    Date), `13` (Packaging Date), `15` (Best Before Date), `17` (Expiration
    Date), `21` (Serial Number), and the 3xx variable-measure weight AIs —
    `3100`–`3105` (net weight, kg), `3200`–`3205` (net weight, lb), `3300`–`3305`
    (gross weight, kg), `3400`–`3405` (gross weight, lb), and `3560`–`3565`
    (net weight, troy ounce)
  - The embedded GTIN (AI `01`) is check-digit validated via `ExGtin.CheckDigit`;
    an invalid embedded GTIN is reported as an error
  - Date-format AIs (`11`/`13`/`15`/`17`) are surfaced as their raw `YYMMDD`
    string by default; opt in to Elixir `Date` structs with `parse_gs1/2` and
    `dates: :parsed`
  - An AI outside the supported set produces an
    `{:error, {:unknown_ai, code, position}}` when it appears at the very start
    (nothing parsed yet); other structured errors cover a wrong fixed-length
    value, unbalanced parentheses, and an invalid embedded GTIN
  - Partial parses are non-lossy: when a leading portion parses but the remainder
    cannot be interpreted after at least one AI+value pair, the unparsed
    remainder is reported as a 3-tuple `{:ok, map, unparsed}` rather than dropped
  - `parse_gs1!/1` returns the parsed map on a full parse, returns a
    `{map, unparsed}` tuple on a partial parse (a partial parse does **not**
    raise), and raises `ArgumentError` only on a hard `{:error, _}`
- Added variable-measure / price-embedded restricted-circulation-number (RCN)
  parsing (F11), backed by `ExGtin.RCN` and the data-driven
  `ExGtin.RCN.Schemes`
  - RCN recognition via `ExGtin.RCN.recognize/1` and `ExGtin.RCN.rcn_prefix?/1`,
    matching the `02` (`020`–`029`) and `20`–`29` (`200`–`299`) prefixes flagged
    by the existing GS1 prefix table; non-RCN input returns an `{:error, _}`
    tuple
  - Scheme-driven decoding via `ExGtin.RCN.decode/2` against either a shipped
    scheme's named atom or an explicit scheme map, returning
    `{:ok, %{item: item, embedded: %{price: _} | %{weight: _}}}` with the item
    reference and embedded amount as raw digit substrings (leading zeros
    preserved, no implied-decimal scaling applied)
  - Internal price/weight check-digit validation when a scheme declares one
    (`check: {:price_check, position}`): the digit at that position is checked
    against a GS1 mod-10 check digit computed over the embedded field via the
    shared `ExGtin.CheckDigit.mod10/1` engine, an **illustrative convention** for
    the shipped schemes; a mismatch returns
    `{:error, "Invalid internal price check digit"}`, and a scheme with
    `check: nil` skips the check
  - A code whose leading prefix is not listed in the scheme returns
    `{:error, "Code prefix does not match scheme"}`; an unknown scheme atom and a
    non-13-digit or non-digit code each return an `{:error, _}` tuple
  - RCN layouts are region/retailer defined, so a scheme is always supplied
    explicitly; two illustrative schemes ship on the `"2"` prefix —
    `:gs1_germany_price` (item positions 2..6, embedded price 8..12, with an
    internal price check digit at position 7) and `:gs1_embedded_weight` (item
    positions 2..7, embedded weight 8..12, no internal check digit)

## [1.4.0] - 2026-09-26

- Added batch validation helpers `ExGtin.validate_all/1` and
  `ExGtin.partition/1` (F9), backed by `ExGtin.Batch`
  - `validate_all(codes)` maps each input to a `{code, ExGtin.validate(code)}`
    tuple, preserving input order
  - `partition(codes)` returns `%{valid: [...], invalid: [...]}`, preserving
    order within each bucket
  - Individual items never raise: a bad code (wrong length, non-digit, or a
    tampered check digit) is captured as an `{:error, _}` result rather than
    aborting the batch. `ExGtin.validate/1` raises on a correct-length,
    non-digit input, so `ExGtin.Batch` catches that and reports
    `{:error, "Invalid Code"}` to preserve the batch contract
  - An empty list returns `[]` (`validate_all/1`) or empty buckets
    (`partition/1`)
- Added a generic fixed-length GS1 key path in `ExGtin.Keys`: a `@key_lengths`
  table drives `ExGtin.Keys.validate_key/2` and `ExGtin.Keys.generate_key/2`,
  covering `:gln`, `:sscc`, `:gsin`, `:gsrn`, `:gcn`, and `:gdti` (base form)
  with the shared length + mod-10 logic
  - `validate_key(code, key)` returns `{:ok, key}` for a code of the correct
    length with a valid mod-10 check digit, `{:error, "Invalid Code"}` for a
    right-length code with a wrong check digit, and an `{:error, _}` tuple for
    wrong-length or non-digit input
  - `generate_key(body, key)` takes a body one digit shorter than the key,
    appends the mod-10 check digit, and returns `{:ok, code}`
  - The key type is explicit, so same-length keys never collide (e.g. `:sscc`
    and `:gsrn` are both 18 — the caller states which)
  - Added format validation for the variable-component keys, which are **not**
    pure length + mod-10 checks: `:grai` (GRAI, a 14-digit `0`-led numeric core
    with a mod-10 check plus an optional serial of up to 16 GS1
    Character-Set-82 characters), `:giai` (GIAI, a numeric-prefixed alphanumeric
    reference of up to 30 Character-Set-82 characters, no check digit), and
    `:gdti` (GDTI, a 13-digit numeric core plus an optional serial of up to 17
    numeric digits). A malformed structure returns `{:error, "Invalid GRAI"}` /
    `"Invalid GIAI"` / `"Invalid GDTI"`, and a bad numeric-core check digit
    returns `{:error, "Invalid Code"}`
  - `generate_key/2` supports only the fixed-length keys; the
    variable-component keys `:grai` and `:giai` return
    `{:error, "Unsupported key"}` (a free-form serial has no single canonical
    value to generate), and `generate_key(_, :gdti)` produces only the base
    13-digit form
  - The explicit key type prevents same-length collisions: an 18-digit value
    validates as `:sscc` or `:gsrn` per the caller, and a 13-digit value as
    `:gln`, `:gcn`, or `:gdti` — the caller states which
  - Exposed publicly as `ExGtin.validate_key/2` and `ExGtin.generate_key/2`,
    thin delegates to `ExGtin.Keys`
  - `validate_sscc/1`, `generate_sscc/1`, `validate_gsin/1`, and
    `generate_gsin/1` now delegate to this table-driven path and keep their
    existing `"SSCC"` / `"GSIN"` string labels and behavior
- Completed Bookland support: ISBN-10 ⇄ ISBN-13 conversion and ISBN
  validation via `ExGtin.isbn10_to_isbn13/1`, `ExGtin.isbn13_to_isbn10/1`, and
  `ExGtin.valid_isbn?/1`, backed by `ExGtin.Convert.Bookland`
  - `isbn10_to_isbn13/1` validates the ISBN-10 (mod-11, trailing `X` allowed)
    and returns `{:ok, isbn13}` equal to `978` followed by the first 9 ISBN-10
    digits and a recomputed GS1 mod-10 check digit, so the result validates as
    `GTIN-13` via `ExGtin.validate/1`; an invalid ISBN-10 returns
    `{:error, "Invalid ISBN-10"}`
  - `isbn13_to_isbn10/1` reverses a `978`-prefixed ISBN-13 to
    `{:ok, isbn10}` with a recomputed ISBN-10 mod-11 check digit, which may be
    `X`; a `979`-prefixed ISBN-13 has no ISBN-10 equivalent and returns
    `{:error, "ISBN-13 with 979 prefix has no ISBN-10 equivalent"}`, and any
    other invalid input returns `{:error, "Invalid ISBN-13"}`
  - `valid_isbn?/1` dispatches on length: a 10-character input is checked with
    the ISBN-10 mod-11 rule (reusing `ExGtin.Validation.valid_isbn10?/1`) and a
    13-digit input as an ISBN-13 (`978`/`979` prefix with a valid mod-10 check)
  - The `X` check digit is handled in both conversion directions, and an
    ISBN-10 with a bad mod-11 check or an ISBN-13 with a bad mod-10 check is
    rejected
  - Accepts String, integer, and digit-list inputs (note the leading-zero
    caveat for integer input)
- Added GSIN (Global Shipment Identification Number) validation and generation:
  `ExGtin.validate_gsin/1` and `ExGtin.generate_gsin/1` (plus raising `!`
  variants), backed by `ExGtin.Keys`
  - `validate_gsin/1` returns `{:ok, "GSIN"}` for a 17-digit code with a valid
    mod-10 check digit and `{:error, "Invalid Code"}` for a 17-digit code with
    a wrong check digit
  - `generate_gsin/1` takes a 16-digit body and returns `{:ok, gsin}` with the
    check digit appended
  - Any wrong-length or non-digit input returns an `{:error, _}` tuple
  - Key detection is explicit: a 17-digit GSIN is never classified as an SSCC,
    a GTIN, or any other key of a nearby length, and an 18-digit SSCC is never
    classified as a GSIN
  - Round-trip guarantee: `validate_gsin(generate_gsin(body)) == {:ok, "GSIN"}`
  - Accepts String, integer, and digit-list inputs (note the leading-zero
    caveat for integer input)
- Added SSCC (Serial Shipping Container Code) validation and generation:
  `ExGtin.validate_sscc/1` and `ExGtin.generate_sscc/1` (plus raising `!`
  variants), backed by `ExGtin.Keys`
  - `validate_sscc/1` returns `{:ok, "SSCC"}` for an 18-digit code with a valid
    mod-10 check digit and `{:error, "Invalid Code"}` for an 18-digit code with
    a wrong check digit
  - `generate_sscc/1` takes a 17-digit body and returns `{:ok, sscc}` with the
    check digit appended
  - Any wrong-length or non-digit input returns an `{:error, _}` tuple
  - Key detection is explicit: an 18-digit SSCC is never classified as a GTIN,
    and a 14-digit GTIN is never classified as an SSCC
  - Round-trip guarantee: `validate_sscc(generate_sscc(body)) == {:ok, "SSCC"}`
  - Accepts String, integer, and digit-list inputs (note the leading-zero
    caveat for integer input)
- Added structured component extraction: `ExGtin.parse/1`, backed by
  `ExGtin.Parse`
  - Returns `{:ok, parsed}` for a valid GTIN-8/12/13/14, where `parsed` exposes
    `type`, `digits`, `indicator`, `gs1_prefix`, `gs1_prefix_region`,
    `check_digit`, and `valid?`
  - `indicator` is the leading packaging digit for a GTIN-14 and `nil` for every
    other type
  - A tampered check digit yields `valid?: false` rather than an error; an
    `{:error, _}` tuple is returned only for genuinely invalid input (wrong
    length or non-digit characters)
  - An unknown GS1 prefix maps `gs1_prefix_region` to `nil`
  - No company/item split is performed, since the company-prefix length is not
    derivable from the number offline
  - Accepts String, integer, and digit-list inputs
- Added GTIN-14 down-conversion: `ExGtin.to_gtin13/1` and `ExGtin.to_gtin12/1`
  (plus raising `!` variants), backed by `ExGtin.Convert.GTIN14`
  - A GTIN-14 with indicator `0` reduces to its base GTIN-13 by stripping the
    leading zero; the mod-10 check digit is unchanged, so the result validates
    as `GTIN-13` via `ExGtin.validate/1`
  - `to_gtin12/1` additionally strips the next leading zero and re-validates the
    result as `GTIN-12`
  - A GTIN-14 whose indicator is in `1..9` returns
    `{:error, "GTIN-14 indicator is not 0; no base GTIN-13"}`; a GTIN-14 with
    indicator `0` but a non-zero next digit returns
    `{:error, "GTIN-14 has no base GTIN-12"}`
  - Round-trip guarantee: `to_gtin13(normalize(x, 0)) == {:ok, x}`
  - Accepts String, integer, and digit-list inputs
- Added a configurable GTIN-14 indicator digit via `ExGtin.normalize/2`
  - The optional `indicator` (`0..9`, default `1`) becomes the leading digit of
    the emitted GTIN-14, with the check digit recomputed over the full body so
    the result validates as `GTIN-14` via `ExGtin.validate/1`
  - `normalize/1` (no indicator) is unchanged and still uses the per-type default
    leading digit (`1` for GTIN-8/12/13, `0` for ISBN-10)
  - An indicator outside `0..9` returns
    `{:error, "Invalid indicator digit; must be in 0..9"}`
- Added UPC-E ⇄ UPC-A conversion: `ExGtin.upce_to_upca/1` and `ExGtin.upca_to_upce/1`
  (plus raising `!` variants), backed by `ExGtin.Convert.UPC`
  - Expansion is a table-driven zero-suppression transform keyed on the 6th UPC-E
    body digit; only number systems `0` and `1` are eligible
  - The UPC-A check digit is always recomputed, so expanded output validates as
    `GTIN-12` via `ExGtin.validate/1`
  - `upca_to_upce/1` returns `{:error, "UPC-A is not compressible to UPC-E"}` when
    no zero-run pattern matches
  - Accepts String, integer, and digit-list inputs
- Added a shared mod-10 check-digit engine `ExGtin.CheckDigit`
  (`mod10/1`, `valid?/1`, `append/1`); `ExGtin.Validation` now delegates to it

## [1.3.0] - 2026-09-25

- Fixed `normalize/1` crashing on a valid ISBN-10 whose check digit is `X`
- `normalize/1` now validates the ISBN-10 check digit before treating a 10-character
  input as an ISBN-10; a 10-digit string with a bad checksum now returns
  `{:error, "Invalid Code"}` instead of silently normalizing garbage
- Fixed `normalize/1` crashing on list input, which its `@spec` already advertised
- Numeric guards narrowed to `is_integer/1`; float input now returns
  `{:error, "Invalid numeric input"}` instead of raising `FunctionClauseError`
- Corrected typespecs to include `integer` input and fixed `generate/1`'s return spec
- Added `ExGtin.Validation.valid_isbn10?/1`
- Documented that `find_gs1_prefix_country/1` does a generic prefix-table lookup and
  does not implement true GS1-8 prefix semantics for GTIN-8 barcodes
- Tooling: replaced deprecated `import Mix.Config` with `import Config` and folded the
  mistyped `coverallspreferred_cli_env` key into `preferred_cli_env`

## [1.2.1] - 2025-12-08

Remove duplicate reference to Malta

## [1.2.0] - 2025-04-18

- Updated min Elixir version to 1.15. Tested successfully with 1.18.3, 1.16, and 1.15.
- Fixed incorrect GS1 Code handling as noted in issue `#2`
- Fixed normalize/1 function to add correct GTIN-14 indicator digit prefix as a default of `1`
  - Updated corresponding DocTests and tests
- Added tests and corrected bad tests that were validating bad checks
- Added tests for edge cases and checks for error handling
- Fixed incorrect `@spec` for `validate!`
- Update README.md with better formatting and refreshed notes
- Added `.formatter.exs`
-

## [1.1.0] - 2022-01-11

- Adding test coverage
- Fixing conflicting GS1 Codes 99 to 990 for "GS1 coupon identification"
- Bump minumum version of Elixir to `1.12`
- Update dependencies
- Replace deprecated `use Mix.Config` to `import Mix.Config`
- Add Pull Request template - @cdesch
- Updating security Policy - (Not sure that we need this but whatever) - @cdesch
- Fixing "contributions welcome" badge link - @cdesch
- Replacing CI badges on README.md - @cdesch
- Adding github ci for automated testing and removing semaphoreci - @cdesch

## [1.0.2] - 2021-03-14

Summary: Merged new function `normalize/1` and other refactoring thanks to the fork [fork](https://github.com/hellonarrativ/ex_gtin)
and @michaeljguarino

Details:

- Merged [7a1a0fc3f](https://github.com/hellonarrativ/ex_gtin/commit/7a1a0fc3f42f9eacd5de61f24cac0b9f3e52d1a7) from [fork](https://github.com/hellonarrativ/ex_gtin) - @cdesch
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
- Remove deprecated functions `check_gtin` and `generate_gtin` - _Please use `validate/1` and `generate/1` instead_ - @cdesch
- Remove tests associated with `check_gtin` and `generate_gtin` - _Please use `validate/1` and `generate/1` instead_ - @cdesch
- Convert `@since` to `@doc since:` for `ex_doc` - @cdesch
- Add proper `@doc since: "1.0.0"` to `validation.ex` - @cdesch
- Add `preferred_cli_env` as `:test` for `pull_request_checkout.task` task - @cdesch

## [1.0.0] - 2019-08-06

### Contains breaking changes\*

- _BREAKING CHANGE_ `generate/1` - Formerly would return the result. It now returns the result in an atom e.g. `{:ok, "6291041500213"}` - @cdesch
- Added `generate!/1` - Raises `ArgumentError` if invalid - @cdesch
- Added `validate!/1`- Raises `ArgumentError` if invalid - @cdesch
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
