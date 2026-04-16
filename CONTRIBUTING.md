# Contributing

Thanks for your interest in improving `hardware_backed_dpop`.

## Before Opening a PR

- open an issue for substantial API changes
- keep changes focused and documented
- add or update tests when behavior changes
- preserve the narrow package focus: hardware-backed binding and signing primitives

## Development

```bash
flutter test
```

## Style

- favor small, composable APIs
- keep security guarantees explicit
- avoid turning the package into a full auth framework