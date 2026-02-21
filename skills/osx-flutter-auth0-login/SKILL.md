---
name: osx-flutter-auth0-login
description: Use when adding login/authentication to a Flutter macOS app (desktop) using Auth0. Includes Auth0 tenant setup, macOS callback configuration, Flutter login UI and AuthService, secure token storage, logout, and a backend JWT verification example.
---

# Flutter macOS Login with Auth0

## Scope and Goals

Implement production-ready login for a Flutter app running on macOS using Auth0 Universal Login with Authorization Code Flow + PKCE.

Deliverables:
- Auth0 configuration steps (Native app)
- Flutter macOS login UI screen
- Auth service for login, logout, token caching and refresh
- Secure token storage using Keychain via flutter_secure_storage
- Backend example that validates access tokens using JWKS
- Clear separation of dev vs prod settings (domain, clientId, audience, redirect URIs)

Use the Auth0 Flutter SDK patterns and recommended flows.

## When to Use

- User asks for "login", "sign in", "Auth0", "OAuth", "SSO", "Google login", "Apple login"
- App is Flutter and targets macOS desktop
- There is an API backend that needs authenticated requests

## Non Goals

- Do not implement username/password collection inside the app UI.
- Do not embed client secrets in the client app.
- Do not implement ROPC.

Use system browser and PKCE.

## Architecture Summary

- Flutter app uses Auth0 Universal Login in system browser (ASWebAuthenticationSession on Apple platforms).
- App receives callback via custom URL scheme (and optionally Universal Links on newer macOS versions).
- App stores tokens in Keychain.
- App calls backend with Authorization: Bearer <access_token>.
- Backend validates JWT using JWKS and checks issuer, audience, and exp.

Auth0 docs emphasize Authorization Code with PKCE for native apps.

## Auth0 Dashboard Setup (Native Application)

1. Create an Auth0 Application of type "Native".
2. Note:
   - Domain (example: your-tenant.us.auth0.com)
   - Client ID
3. Configure Callback URLs and Logout URLs:
   - Custom scheme callback (recommended baseline):
     - com.example.myapp://callback
     - com.example.myapp://logout
   - If you opt into Universal Links on macOS 14.4+ you can add those too, but keep custom scheme for fallback.
4. Configure Allowed Web Origins if needed for any embedded web contexts (generally not needed for system browser flows on macOS).
5. If the backend is an API:
   - Create an Auth0 API (audience identifier like https://api.example.com)
   - Define scopes (read:stuff, write:stuff)
   - The Flutter app will request audience + scopes to obtain an access token intended for your API.

## Flutter Dependencies

Prefer the official Auth0 Flutter SDK.

Add:
- auth0_flutter
- flutter_secure_storage

Example:

```yaml
dependencies:
  auth0_flutter: ^1.7.0
  flutter_secure_storage: ^9.0.0
```

Auth0 provides a Flutter quickstart and the pub.dev package documents macOS support and callback behavior.

## macOS App Configuration (Callback Handling)

Set a custom URL scheme for the macOS runner so the app can receive:

- com.example.myapp://callback

In macOS Runner Info.plist, include CFBundleURLTypes. The Auth0 examples describe registering the bundle identifier or scheme so callbacks reach the app.

Example Info.plist snippet:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.example.myapp</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.myapp</string>
    </array>
  </dict>
</array>
```

Redirect URI becomes:

- com.example.myapp://callback

Logout return URI becomes:

- com.example.myapp://logout

## macOS Entitlements (Keychain Access)

For flutter_secure_storage to work in sandboxed macOS apps, configure Keychain entitlements.

In `macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`:

```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.example.myapp</string>
</array>
```

If the app is sandboxed (required for App Store), also ensure:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

## App Configuration Model

Create a single source of truth for auth config:

- Auth0 domain
- clientId
- audience
- redirectUri
- logoutUri

Support env switching:

- dev, staging, prod

Example:

```dart
class AuthConfig {
  final String domain;
  final String clientId;
  final String audience;
  final String redirectUri;
  final String logoutUri;

  const AuthConfig({
    required this.domain,
    required this.clientId,
    required this.audience,
    required this.redirectUri,
    required this.logoutUri,
  });
}
```

## Token Storage (Keychain)

Store:

- accessToken
- idToken
- refreshToken (only if enabled)
- expiresAt

Use flutter_secure_storage which maps to Keychain on macOS.

Keys:

- auth.accessToken
- auth.idToken
- auth.refreshToken
- auth.expiresAt

## AuthService Implementation (Dart)

AuthService responsibilities:

- login() using Auth0WebAuth (system browser) with PKCE
- logout()
- getValidAccessToken() with refresh if needed
- user profile extraction from idToken
- error mapping

Skeleton:

```dart
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Auth0 auth0;
  final FlutterSecureStorage storage;

  AuthService({
    required String domain,
    required String clientId,
    FlutterSecureStorage? storage,
  })  : auth0 = Auth0(domain, clientId),
        storage = storage ?? const FlutterSecureStorage();

  Future<Credentials?> login({
    required String redirectUri,
    required String audience,
    required Set<String> scopes,
    String? connection,
  }) async {
    final params = <String, String>{};
    if (connection != null && connection.isNotEmpty) {
      params['connection'] = connection;
    }

    final credentials = await auth0.webAuthentication(
      scheme: Uri.parse(redirectUri).scheme,
    ).login(
      redirectUrl: redirectUri,
      audience: audience,
      scopes: scopes.toList(),
      parameters: params.isEmpty ? null : params,
    );

    await _persist(credentials);
    return credentials;
  }

  Future<void> logout({
    required String logoutUri,
  }) async {
    await auth0.webAuthentication(
      scheme: Uri.parse(logoutUri).scheme,
    ).logout(
      returnToUrl: logoutUri,
    );

    await _clear();
  }

  Future<String?> getAccessToken() async {
    return storage.read(key: 'auth.accessToken');
  }

  /// Returns a valid access token, refreshing if needed.
  /// Returns null if no valid token and refresh fails (re-login required).
  Future<String?> getValidAccessToken() async {
    final expiresAtStr = await storage.read(key: 'auth.expiresAt');
    if (expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      // Return cached token if still valid with 5-minute buffer
      if (expiresAt != null && expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        return storage.read(key: 'auth.accessToken');
      }
    }
    // Token expired or expiring soon - attempt refresh
    final refreshToken = await storage.read(key: 'auth.refreshToken');
    if (refreshToken != null) {
      try {
        final credentials = await auth0.api.renewCredentials(refreshToken: refreshToken);
        await _persist(credentials);
        return credentials.accessToken;
      } catch (_) {
        // Refresh failed, clear tokens
        await _clear();
        return null;
      }
    }
    return null;
  }

  /// Check if user has a valid session (for app startup routing).
  Future<bool> isLoggedIn() async {
    final token = await getValidAccessToken();
    return token != null;
  }

  Future<void> _persist(Credentials c) async {
    if (c.accessToken != null) {
      await storage.write(key: 'auth.accessToken', value: c.accessToken);
    }
    if (c.idToken != null) {
      await storage.write(key: 'auth.idToken', value: c.idToken);
    }
    if (c.refreshToken != null) {
      await storage.write(key: 'auth.refreshToken', value: c.refreshToken);
    }
    if (c.expiresAt != null) {
      await storage.write(key: 'auth.expiresAt', value: c.expiresAt!.toIso8601String());
    }
  }

  Future<void> _clear() async {
    await storage.delete(key: 'auth.accessToken');
    await storage.delete(key: 'auth.idToken');
    await storage.delete(key: 'auth.refreshToken');
    await storage.delete(key: 'auth.expiresAt');
  }
}
```

Note: Adjust API calls to match the exact auth0_flutter API version in the repo.

### Alternative: Using Built-in CredentialsManager

The auth0_flutter SDK includes a `CredentialsManager` that handles secure storage and refresh automatically. This is simpler but offers less control:

```dart
import 'package:auth0_flutter/auth0_flutter.dart';

class AuthServiceSimple {
  final Auth0 auth0;
  final CredentialsManager credentialsManager;

  AuthServiceSimple({required String domain, required String clientId})
      : auth0 = Auth0(domain, clientId),
        credentialsManager = CredentialsManager(Auth0(domain, clientId));

  Future<Credentials> login({required String redirectUri, required String audience}) async {
    final credentials = await auth0.webAuthentication(scheme: Uri.parse(redirectUri).scheme)
        .login(redirectUrl: redirectUri, audience: audience, scopes: ['openid', 'profile', 'email', 'offline_access']);
    await credentialsManager.storeCredentials(credentials);
    return credentials;
  }

  Future<bool> isLoggedIn() => credentialsManager.hasValidCredentials();

  Future<Credentials> getCredentials() => credentialsManager.credentials();

  Future<void> logout({required String logoutUri}) async {
    await auth0.webAuthentication(scheme: Uri.parse(logoutUri).scheme).logout(returnToUrl: logoutUri);
    await credentialsManager.clearCredentials();
  }
}
```

Choose the manual approach (above) for full control over storage keys and error handling, or `CredentialsManager` for simplicity.

## Flutter macOS Login Screen (UI)

Requirements:

- Show buttons: Continue with Apple, Continue with Google, Continue with Email
- Buttons call AuthService.login() with connection hint when desired
- Show loading state and errors
- On success, route to app shell and start API calls with token

Example screen:

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  final AuthConfig config;

  const LoginScreen({super.key, required this.auth, required this.config});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _doLogin({String? connection}) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.auth.login(
        redirectUri: widget.config.redirectUri,
        audience: widget.config.audience,
        scopes: {'openid', 'profile', 'email', 'offline_access'},
        connection: connection,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Login failed. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue with', style: theme.textTheme.titleLarge),
                const SizedBox(height: 20),

                _LoginButton(
                  label: 'Apple',
                  onPressed: _busy ? null : () => _doLogin(connection: 'apple'),
                ),
                const SizedBox(height: 12),

                _LoginButton(
                  label: 'Google',
                  onPressed: _busy ? null : () => _doLogin(connection: 'google-oauth2'),
                ),
                const SizedBox(height: 12),

                _LoginButton(
                  label: 'Email',
                  onPressed: _busy ? null : () => _doLogin(),
                ),

                const SizedBox(height: 16),
                if (_busy) const CircularProgressIndicator(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _LoginButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
```

Connection names must match what is enabled in Auth0 connections:

- Apple connection name often "apple"
- Google often "google-oauth2"

Validate in Auth0 Dashboard > Authentication > Social.

## Backend: Verify Auth0 JWT (Example with FastAPI)

Backend must:

- Fetch JWKS from https://YOUR_DOMAIN/.well-known/jwks.json
- Validate JWT signature
- Validate issuer: https://YOUR_DOMAIN/
- Validate audience: your API audience
- Validate exp, nbf

This follows standard Auth0 guidance for calling APIs with access tokens.

### FastAPI Implementation

```python
from fastapi import Depends, HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt import PyJWKClient
from functools import lru_cache

# Configuration - use environment variables in production
AUTH0_DOMAIN = "your-tenant.us.auth0.com"
API_AUDIENCE = "https://api.example.com"

security = HTTPBearer()

@lru_cache()
def get_jwks_client():
    return PyJWKClient(f"https://{AUTH0_DOMAIN}/.well-known/jwks.json")

async def verify_token(
    credentials: HTTPAuthorizationCredentials = Security(security)
) -> dict:
    """Validate Auth0 access token and return claims."""
    token = credentials.credentials
    try:
        jwks_client = get_jwks_client()
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=API_AUDIENCE,
            issuer=f"https://{AUTH0_DOMAIN}/"
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidAudienceError:
        raise HTTPException(status_code=401, detail="Invalid audience")
    except jwt.InvalidIssuerError:
        raise HTTPException(status_code=401, detail="Invalid issuer")
    except jwt.exceptions.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

def require_scope(required_scope: str):
    """Dependency to enforce a specific scope."""
    async def check_scope(claims: dict = Depends(verify_token)):
        scopes = claims.get("scope", "").split()
        if required_scope not in scopes:
            raise HTTPException(status_code=403, detail=f"Missing scope: {required_scope}")
        return claims
    return check_scope

# Usage in routes:
# @app.get("/protected")
# async def protected_route(claims: dict = Depends(verify_token)):
#     return {"user": claims["sub"]}
#
# @app.post("/admin")
# async def admin_route(claims: dict = Depends(require_scope("admin:write"))):
#     return {"admin": True}
```

Requirements:

```
PyJWT>=2.8.0
cryptography>=41.0.0
```

Also ensure:

- Do not accept idToken as API auth token
- Only accept accessToken issued for your API audience

## Hardening Checklist (Required)

- Use Authorization Code + PKCE, never client secret in app.
- Store tokens in Keychain via flutter_secure_storage.
- Implement logout that clears local tokens.
- Implement API client that retries after refresh, and handles 401 by re-auth.
- Never log tokens.
- Use Universal Links only if you fully configure associated domains, but keep custom scheme fallback on macOS.

## Output Format When Running This Skill

When implementing in a repo, produce:

1. A short checklist of what was added/changed (files and purpose)
2. Auth0 dashboard values needed (placeholders only)
3. Flutter code: AuthConfig, AuthService, LoginScreen
4. macOS Info.plist edits
5. Backend JWT verification snippet or middleware outline
6. A smoke test plan:
   - login
   - logout
   - token persisted across restart
   - API call returns 200 with token
   - API call returns 401 when token missing

## Related Skills

- **osx-review**: deep release-oriented code review
- **osx-compliance**: macOS DMG + desktop release infrastructure
- **osx-ios**: iOS/iPad distribution preparation
