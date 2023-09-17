# Changelog for pre-release v0

## v0.4.0

Fix bug when joining tenant'd to non-tenant'd schema. Non-breaking, but bumping minor.

## v0.2.0

Support for `as/1` dynamic bindings. This is a backwards compatible change.

## v0.1.0

Support for `coalesce/2` to be used in queries. For now, we simply ignore the coalesce statement, because there's a chance for unsafe queries with it.

## v0.0.1

Initial release.
