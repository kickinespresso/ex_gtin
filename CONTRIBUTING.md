# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change.

Please note we have a code of conduct, please follow it in all your interactions with the project.

## Pull Request Process

1. Update the [CHANGELOG.md](CHANGELOG.md) with details of your changes to the
   public API or behavior.
2. Bump the version number in [mix.exs](mix.exs) and any examples in the
   [README.md](README.md) to the version this Pull Request would represent. The
   versioning scheme we use is [SemVer](http://semver.org/).
3. Run the tests (`ExUnit`), code coverage (`coveralls`), static analysis tools (`credo`), and code formatting as follows:

```shell
mix test
MIX_ENV=test mix coveralls
mix credo --strict
mix format --check-formatted
```

or

```shell
mix pull_request_checkout.task
```

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By
participating, you are expected to uphold it. Please report unacceptable
behavior to [contact@kickinespresso.com](mailto:contact@kickinespresso.com).
