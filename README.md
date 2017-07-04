[![Build Status](https://semaphoreci.com/api/v1/kickinespresso/ex_gtin/branches/master/badge.svg)](https://semaphoreci.com/kickinespresso/ex_gtin)

# ExGtin

A GTIN Validation Library in elixir.

## Features

- Supports GTIN-8, GTIN-12, GTIN-13, GTIN-14, GSIN, SSCC codes

## Usage

    ExGtin.check_gtin("6291041500213")

## Reference

- [GTIN](https://www.gs1.org)
- [How to calculate GTIN](https://www.gs1.org/how-calculate-check-digit-manually)

## Installation

```elixir
def deps do
  [{:ex_gtin, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_gtin](https://hexdocs.pm/ex_gtin).


## Tests

Run tests with

    mix text

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Sponsors

This project is sponsored by [KickinEspresso](www.kickinespresso.com)

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/kickinespresso/ex_gtin/tags).


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
