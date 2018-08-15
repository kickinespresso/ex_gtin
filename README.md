[![Build Status](https://semaphoreci.com/api/v1/kickinespresso/ex_gtin/branches/master/badge.svg)](https://semaphoreci.com/kickinespresso/ex_gtin)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/dwyl/esta/issues)
[![Hex.pm](https://img.shields.io/hexpm/v/plug.svg)](https://www.hex.pm/packages/ex_gtin)
[![Packagist](https://img.shields.io/packagist/l/doctrine/orm.svg)](LICENSE.md)

# ExGtin

A GTIN (Global Trade Item Number) & UPC (Universal Price Code) Generation and  Validation Library in Elixir under the GS1 specification.

## Features

- Supports GTIN-8, GTIN-12 (UPC-12), GTIN-13 (GLN), GTIN-14, GSIN, SSCC codes
- Generate GTIN
- Check GTIN validity 
- Lookup GS1 country prefix

## Installation

```elixir
def deps do
  [{:ex_gtin, "~> 0.3.0"}]
end
```

## Usage

- Check GTIN codes

      iex> ExGtin.check_gtin("6291041500213")
      {:ok, "GTIN-13"}

      iex> ExGtin.check_gtin("6291041500214")
      {:error, "Invalid Code"}

- Generate GTIN codes

      iex> ExGtin.generate_gtin("629104150021")
      "6291041500213"

- Lookup GS1 Prefix 

      iex> ExGtin.Validation.find_gs1_prefix_country("53523235")
      {:ok, "GS1 Malta"}

### Using Strings, Arrays or Numbers

- String

      iex> ExGtin.check_gtin("6291041500213")
      {:ok, "GTIN-13"}

- Array of Integers    

      iex> ExGtin.check_gtin([6, 2, 9, 1, 0, 4, 1, 5, 0, 0, 2, 1, 3])
      {:ok, "GTIN-13"}

- Integer

      iex> ExGtin.check_gtin(6291041500213)
      {:ok, "GTIN-13"}

    *Integers with leading zeros may not process properly*

## Reference

- [GTIN](https://www.gs1.org)
- [How to calculate GTIN](https://www.gs1.org/how-calculate-check-digit-manually)

Documentation can be found at [https://hexdocs.pm/ex_gtin](https://hexdocs.pm/ex_gtin) on [HexDocs](https://hexdocs.pm).

## Tests

Run tests with

    mix test

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

When making pull requests, please be sure to update the [CHANGELOG.md](CHANGELOG.md) with the corresponding changes.

## Sponsors

This project is sponsored by [KickinEspresso](https://kickinespresso.com/?utm_source=github&utm_medium=sponsor&utm_campaign=opensource)

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/kickinespresso/ex_gtin/tags).

## Code of Conduct

Please refer to the [Code of Conduct](CODE_OF_CONDUCT.md) for details

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Publish

    mix hex.publish