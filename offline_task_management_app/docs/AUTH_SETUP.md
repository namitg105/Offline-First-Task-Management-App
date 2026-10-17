# Auth feature — setup & flow

## 1. Why this app has auth at all

The brief asks the app to "synchronize changes with a **remote database**" and lists
"**multi-device support for the same account**" as a bonus. A remote database with no
identity means one shared pile of tasks for every install on earth. Auth gives every
row an owner, which is what makes sync, de-duplication and conflict resolution
meaningful.

**Rule we follow:** auth must never block offline use. Sign-*in* needs internet once.
After that the session lives on the device and the app opens straight into the task
list with no signal.

## 2. Backend

| Piece | What it is |
|---|---|
| Postgres (Supabase) | The DBMS. `public.profiles` + later `public.tasks`. |
| GoTrue (Supabase Auth) | Issues JWTs. Handles email/password and Google. |
| Row Level Security | Postgres reads `auth.uid()` from the JWT and filters rows. |

## 3. Setup steps

### 3.1 Supabase project
1. Create a project at https://supabase.com.
2. SQL Editor → paste and run `supabase/01_auth_schema.sql`.
3. Project Settings → API → copy **Project URL** and **anon public** key.
4. `cp lib/core/secrets/app_secrets.example.dart lib/core/secrets/app_secrets.dart`
   and paste them in. The real file is gitignored.

### 3.2 Google Cloud (for Google sign-in)
You need **two** OAuth client IDs in the same Google Cloud project:

| Client type | What it is for |
|---|---|
| **Web** | Goes in `googleWebClientId` AND into Supabase. This is the `aud` of the ID token. |
| **Android** | Just needs to exist, with your package name + SHA-1. Not pasted anywhere in code. |

Get your debug SHA-1 (Windows PowerShell / CMD):

```bat
keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android
```

Then: Supabase Dashboard → Authentication → Providers → Google → enable, and paste the
**Web** client ID + secret. Add the Web client ID to "Authorized Client IDs" too.

> Release builds are signed with a different key, so repeat with your release keystore
> before submitting the APK, or Google sign-in works in debug and fails in release.

### 3.3 Run

```bash
flutter pub get
flutter analyze
flutter run
```

## 4. What actually travels over the wire

### Email + password sign-up
`POST https://<ref>.supabase.co/auth/v1/signup`

Request headers: `apikey: <anon key>`, `Content-Type: application/json`
Request body:
```json
{ "email": "namit@example.com", "password": "secret123", "data": { "name": "Namit" } }
```
Response body:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "v1MtJ8s...",
  "user": {
    "id": "8f14e45f-ceea-467a-9c2b-...",
    "email": "namit@example.com",
    "user_metadata": { "name": "Namit" }
  }
}
```

The `data` field lands in `auth.users.raw_user_meta_data`; our trigger copies it into
`public.profiles`.

### The access token (JWT), decoded
```json
{
  "iss": "https://<ref>.supabase.co/auth/v1",
  "sub": "8f14e45f-ceea-467a-9c2b-...",   // <-- this IS auth.uid()
  "aud": "authenticated",
  "role": "authenticated",
  "email": "namit@example.com",
  "exp": 1760000000
}
```

### Every later database call
`GET /rest/v1/profiles?select=id,name&id=eq.8f14e45f...&limit=1`
```
apikey:        <anon key>
Authorization: Bearer <access_token>
```
Postgres reads `sub` out of that token and rewrites your query as
`... WHERE id = auth.uid()`. That is the whole security model.

### Google sign-in
1. `google_sign_in` opens the native account picker and returns an **ID token signed by
   Google** (`iss: accounts.google.com`, `aud: <your Web client ID>`).
2. `POST /auth/v1/token?grant_type=id_token` with
   `{ "provider": "google", "id_token": "<google token>" }`
3. Supabase verifies Google's signature, creates/finds the user, and returns the **same
   session shape as above** — so everything downstream is identical.

### Token refresh
`access_token` expires in 1 hour. The SDK silently calls
`POST /auth/v1/token?grant_type=refresh_token` and replaces both tokens. Offline, it
cannot — so it keeps using the stored session, which is exactly what we want.

## 5. Layer map

```
presentation   LoginPage / SignUpPage  ->  AuthBloc  ->  (events/states only)
                                              |
domain                                   5 UseCases  ->  AuthRepository (abstract)
                                              |
data                              AuthRepositoryImpl  ->  AuthRemoteDataSource
                                                              |-> SupabaseClient
                                                              |-> GoogleAuthService
```
Dependencies point inward only. Swapping Supabase for Firebase touches `data/` and
nothing else.
