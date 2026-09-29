# Roadmap

Planned and outstanding work for `ex_gtin`. Items here are not yet scheduled to
a specific release unless noted.

## Planned

- [ ] **True GS1-8 (`960..969`) prefix semantics for GTIN-8 country lookups.**
  `ExGtin.Validation.find_gs1_prefix_country/1` (and the public
  `ExGtin.gs1_prefix_country/1` facade) currently resolve GTIN-8 inputs with a
  GTIN-13 prefix-table lookup, which can return a misleading GS1 Member
  Organisation. This path is already marked deprecated. Implement real GS1-8
  prefix handling for the `960..969` "Global Office GTIN-8" range and either
  return the correct result or an explicit error for GTIN-8 inputs. This is a
  behavior change and should land in a minor/major release with updated tests.
