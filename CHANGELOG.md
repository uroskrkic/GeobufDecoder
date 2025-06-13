# Release Notes / Changelog

## Version 1.1.3

- Fix "Index out of range" for closed paths, when data is malformed.
- Changelog added

## Version 1.1.2

- Silent JSON properties value parsing, as fallback to `String`. Printable with verbose flag.

## Version 1.1.1

- Fix when a string returned in `jsonValue` field and cannot be parsed as `JSONObject`, falling back to `String`. Try `Decimal`, `Bool` types to parse when fallback, otherwise claim as `String`.
- Optionally trim quotes of properties values.

## Version 1.1.0

- Support for root level properties (custom properties), like `name`, `crs`, ...

## Version 1.0.0

- Initial implementation.

