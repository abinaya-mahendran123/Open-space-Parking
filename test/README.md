# Test Suite

Run all tests:

```bash
flutter test
```

Run by category:

```bash
flutter test test/unit
flutter test test/repository
flutter test test/provider
flutter test test/widget
flutter test test/authentication
```

## Structure

| Directory | Coverage |
|-----------|----------|
| `test/unit/` | Domain entities, validators, templates, session service |
| `test/repository/` | Auth, notification, WhatsApp repositories/services |
| `test/provider/` | Riverpod auth, notification, WhatsApp providers |
| `test/widget/` | PrimaryButton, AppErrorWidget, AppStatCard, LoginPage |
| `test/authentication/` | Auth flow integration (login, register, logout, session restore) |
| `test/helpers/` | Mocks (mocktail), fixtures, pump utilities |

## Dependencies

- `flutter_test` — Flutter testing framework
- `mocktail` — Mockito-style mocks without code generation
