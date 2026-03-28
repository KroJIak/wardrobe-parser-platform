# wardrobe-parser-platform
Aggregates clothing data from multiple online stores via a parser service and exposes it through a backend API with a frontend card‑based catalog.

## Integration Testing

Run full stack and integration tests locally:

```bash
docker compose up -d --build
docker compose --profile test run --rm integration-tests
```

Stop stack after test run:

```bash
docker compose down -v
```
