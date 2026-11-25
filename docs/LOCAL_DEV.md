# Running Pulse locally (emulator + local backend)

## Gradle memory
`android/gradle.properties` defaults to a 2 GB Gradle heap and a 1 GB Kotlin daemon, which fits an 8 GB PC. CI runs on 7 GB runners but sets 3 GB / 1.5 GB itself (a step in `.github/workflows/ci.yml` writes `~/.gradle/gradle.properties`). To change it on your own machine without touching the repo, put your values in `~/.gradle/gradle.properties` (on Windows `C:\Users\<you>\.gradle\gradle.properties`); it overrides the project file:

```
org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G
kotlin.daemon.jvmargs=-Xmx1536m
org.gradle.workers.max=2
```

## Backend with dev sign-in
In the `pulse` backend repo (branch `dev-auth`, README "Dev sign-in"), set in `.env`:

```
APP_ENV=development
ALLOW_DEV_AUTH=true
SUPABASE_JWT_SECRET=any-long-random-string
```

then `make dev`. This exposes `POST /v1/dev/token`, which returns a JWT for a fixed local user. The backend refuses to start with `ALLOW_DEV_AUTH=true` unless `APP_ENV=development`.

## App
```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=DEV_AUTH=true
```
(`10.0.2.2` is the host PC as seen from the Android emulator.) With `DEV_AUTH=true` the app fetches a token from `/v1/dev/token` and sends it as the bearer, so Splits and live Wealth prices work with the mock sign-in. It only works in non-release builds with `API_BASE_URL` set; in a release build the flag is ignored. If the backend does not offer the endpoint the app carries on unauthenticated as before.
