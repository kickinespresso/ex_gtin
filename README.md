# ExGtin

![CI Status](https://github.com/kickinespresso/ex_gtin/actions/workflows/elixir.yml/badge.svg)
[![Static Badge](https://img.shields.io/badge/HexDocs-ex_gtin-blue)](https://hexdocs.pm/ex_gtin/ExGtin.html)
[![Hex.pm Version](https://img.shields.io/hexpm/v/ex_gtin)](https://hex.pm/packages/ex_gtin)
[![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)](LICENSE.md)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/kickinespresso/ex_gtin/issues)

A [GTIN](https://www.gtin.info/) (Global Trade Item Number) & UPC (Universal Price Code) Generation and Validation Library in Elixir under the GS1 specification.

- GTIN-8 (EAN/UCC-8): this is an 8-digit number used predominately outside of North America
- GTIN-12 (UPC-A): this is a 12-digit number used primarily in North America
- GTIN-13 (EAN/UCC-13): this is a 13-digit number used predominately outside of North America - Global Location Number (GLN)
- GTIN-14 (EAN/UCC-14 or ITF-14): this is a 14-digit number used to identify trade items at various packaging levels

## Features

- Supports GTIN-8, GTIN-12 (UPC-12), GTIN-13 (GLN), GTIN-14
- Generate GTIN
- Check GTIN validity
- Lookup GS1 country prefix
- Convert (normalize) GTIN-13 to GTIN-14
- Parse GS1-128 / Application Identifier (AI) element strings (both the
  parenthesized `(01)...` form and the raw FNC1 scanner form)
- Recognize and decode variable-measure restricted-circulation numbers (RCNs)
  against an explicit region/retailer scheme

Features to Come:

- Global Shipment Identification Number (GSIN)
- Serial Shipping Container Code (SSCC)

## Installation

_WARNING `1.0.1` contains breaking changes from `1.0.0`_ (I know this is a patch release but the breaking changes related to the deprecation of `check_gtin` and `generate_gtin` were noted in the changelog and docs over a year ago)
_WARNING `1.0.0` contains breaking changes from `0.4.0`_

Add `:ex_gtin` as a dependency to your project's `mix.exs`:

```elixir
def deps do
  [{:ex_gtin, "~> 1.5.0"}]
end
```

and run `mix deps.get` to install the `:ex_gtin` dependency

```shell
mix deps.get
```

## Usage

- Check GTIN codes

```elixir
iex> ExGtin.validate("6291041500213")
{:ok, "GTIN-13"}

iex> ExGtin.validate("6291041500214")
{:error, "Invalid Code"}

iex> ExGtin.validate!("6291041500213")
"GTIN-13"
```

Pass GTIN numbers in as a String, Number or an Array

```elixir
iex> number = [6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3]
iex> ExGtin.validate(number)
{:ok, "GTIN-13"}

iex> number = 6_291_041_500_213
iex> ExGtin.validate(number)
{:ok, "GTIN-13"}
```

- Generate GTIN codes

```elixir
iex> ExGtin.generate("629104150021")
{:ok, "6291041500213"}

iex> ExGtin.generate!("629104150021")
"6291041500213"
```

- Lookup GS1 Prefix

```elixir
iex> ExGtin.Validation.find_gs1_prefix_country("53523235")
{:ok, "GS1 Malta"}
```

- Convert GTIN-13 to GTIN 14

```elixir
iex> ExGtin.normalize("6291041500213")
{:ok, "16291041500210"}
```

- Parse GS1-128 / Application Identifier (AI) element strings

`ExGtin.parse_gs1/1` accepts both the parenthesized human-readable form and the
raw FNC1 scanner form of the same payload and returns an `%{ai => value}` map.

```elixir
# Parenthesized form (starts with `(`)
iex> ExGtin.parse_gs1("(01)06291041500213(17)261231(10)ABC123")
{:ok, %{"01" => "06291041500213", "17" => "261231", "10" => "ABC123"}}

# Raw FNC1 form of the same payload (variable-length AIs are terminated by the
# FNC1/GS separator, ASCII 29)
iex> ExGtin.parse_gs1("010629104150021310ABC123" <> <<29>> <> "21XYZ789")
{:ok, %{"01" => "06291041500213", "10" => "ABC123", "21" => "XYZ789"}}
```

The embedded GTIN (AI `01`) is check-digit validated, and date-format AIs are
returned as their raw `YYMMDD` string by default. Pass `dates: :parsed` to
interpret them into Elixir `Date` structs:

```elixir
iex> ExGtin.parse_gs1("(01)06291041500213(17)261231", dates: :parsed)
{:ok, %{"01" => "06291041500213", "17" => ~D[2026-12-31]}}
```

The initially supported AI set is:

- `01` — GTIN
- `10` — Batch/Lot Number
- `11` — Production Date
- `13` — Packaging Date
- `15` — Best Before Date
- `17` — Expiration Date
- `21` — Serial Number
- the 3xx variable-measure weight AIs: `3100`–`3105` (net weight, kg),
  `3200`–`3205` (net weight, lb), `3300`–`3305` (gross weight, kg),
  `3400`–`3405` (gross weight, lb), and `3560`–`3565` (net weight, troy ounce)

An AI outside this set is **unsupported and produces an error**. When it appears
at the very start (nothing parsed yet), `parse_gs1/1` returns
`{:error, {:unknown_ai, code, position}}`:

```elixir
iex> ExGtin.parse_gs1("(99)ABC")
{:error, {:unknown_ai, "99", 0}}
```

When an unsupported AI (or otherwise uninterpretable input) follows one or more
successfully parsed AIs, the unparsed remainder is reported alongside the parsed
map as a 3-tuple rather than dropped:

```elixir
iex> ExGtin.parse_gs1("(01)06291041500213(99)ABC")
{:ok, %{"01" => "06291041500213"}, "(99)ABC"}
```

`ExGtin.parse_gs1!/1` is the raising variant: it returns the parsed map on a
full parse, returns a `{map, unparsed}` tuple on a partial parse, and raises
`ArgumentError` only on a hard error.

- Parse variable-measure restricted-circulation numbers (RCNs)

Restricted-circulation numbers are GTINs whose leading digits fall in the GS1
restricted-circulation ranges — the `02` prefix (`020`–`029`) and the `20`–`29`
prefixes (`200`–`299`). These codes are issued for in-store or in-company use
(for example a variable-measure retail item priced by weight) and are not
globally unique, so `ExGtin.RCN.recognize/1` lets you tell an RCN apart from a
normal GTIN.

```elixir
iex> ExGtin.RCN.recognize("2001234500009")
{:ok, "2001234500009"}

iex> ExGtin.RCN.recognize("6291041500213")
{:error, "Not a restricted-circulation number"}
```

An RCN's embedded price or weight has **no single, universal layout**: the exact
digit positions of the item reference, the embedded amount, and any internal
check digit are **defined by the region or retailer** that issues the code. For
that reason decoding never assumes one global layout — you always pass an
explicit scheme, either a shipped scheme's named atom or your own scheme map.
`ExGtin.parse_rcn/2` is the public entry point (backed by `ExGtin.RCN.decode/2`,
which is available today) and returns the raw item reference plus an `embedded`
map carrying the raw `:price` or `:weight` digit substring:

```elixir
iex> ExGtin.RCN.decode("2123451789012", :gs1_germany_price)
{:ok, %{item: "12345", embedded: %{price: "78901"}}}

# Supply your own layout as a scheme map
iex> scheme = %{prefix: ["2"], item: 2..6, embedded: {:price, 8..12}, check: nil}
iex> ExGtin.RCN.decode("2123456789012", scheme)
{:ok, %{item: "12345", embedded: %{price: "78901"}}}
```

The schemes shipped in `ExGtin.RCN.Schemes` are documented, illustrative
defaults on the `"2"` prefix; treat them as sensible starting points and
override with your own scheme map as your market requires:

- `:gs1_germany_price` — a GS1 Germany / EU-style price-embedded layout with an
  **internal price check digit** (a mod-10 check digit over the embedded price
  field)
- `:gs1_embedded_weight` — a weight-embedded layout with **no internal check
  digit**

### Using Strings, Arrays or Numbers

- String

```elixir
iex> ExGtin.validate("6291041500213")
{:ok, "GTIN-13"}
```

- Array of Integers

```elixir
iex> ExGtin.validate([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
{:ok, "GTIN-13"}
```

- Integer

```elixir
iex> ExGtin.validate(6291041500213)
{:ok, "GTIN-13"}
```

Integers with leading zeros may not process properly

## Reference

- [GTIN](https://www.gs1.org)
- [How to calculate GTIN](https://www.gs1.org/how-calculate-check-digit-manually)

Documentation can be found at [https://hexdocs.pm/ex_gtin](https://hexdocs.pm/ex_gtin) on [HexDocs](https://hexdocs.pm).

## Tests

Run tests with

```shell
mix test
```

Run test coverage

```shell
MIX_ENV=test mix coveralls
```

Produce Coverage report in HTML to `cover/excoveralls.html`

```shell
MIX_ENV=test mix coveralls.html
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

When making pull requests, please be sure to update the [CHANGELOG.md](CHANGELOG.md) with the corresponding changes. Please make sure that all tests pass, add tests for new functionality and that the static analysis checker `credo` is run. Use `mix pull_request_checkout.task` to ensure that everything checks out.

Run static code analysis

```shell
mix credo
```

Generate Documentation

```shell
mix docs
```

Run the gambit of tests, static analysis and coverage

```shell
mix pull_request_checkout.task
```

## Sponsors

This project is sponsored by [KickinEspresso](https://kickinespresso.com/?utm_source=github&utm_medium=sponsor&utm_campaign=opensource)

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/kickinespresso/ex_gtin/tags).

## Code of Conduct

Please refer to the [Code of Conduct](CODE_OF_CONDUCT.md) for details

## Security

Please refer to the [Security](SECURITY.md) for details

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Publish & Releasing

```shell
mix hex.publish
```
