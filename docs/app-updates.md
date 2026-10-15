# Optional Google Play update offer

Android release only. The app checks once per cold launch, after which dismissal
lasts for that process. Resume/returning from Play does not repeat the offer.
Version comparison uses installed build number (`versionCode`), not version name.
Login is not required, and network errors never block startup or log a user out.
The offer waits for the startup intro, existing modals, foreground state and a
safe Home/stores/catalog route; it never interrupts checkout or address forms.

## Backend configuration

```dotenv
ANDROID_UPDATE_ENABLED=False
ANDROID_LATEST_BUILD_NUMBER=0
ANDROID_LATEST_VERSION=
```

Public `GET /api/user/app-release/android/` returns:

```json
{
  "enabled": false,
  "latest_build_number": 0,
  "latest_version": "",
  "store_url": "https://play.google.com/store/apps/details?id=uz.beshkashtan.customer"
}
```

To announce a release, set the build number/name to the actual published AAB's
values, enable the flag, and restart **all API workers**. Enabled configuration
requires a positive integer build number and a non-empty version. No migration
or admin panel changes are required. The response is not cached by the client/CDN.
To stop an offer, disable the flag and restart workers; a dismissed offer is
never persisted on disk. The market-app link falls back to the fixed HTTPS link;
if neither opens, the dialog provides retry and Later.

## Rollout

1. Deploy the backend with the offer disabled.
2. Publish the first app release containing this check, with a higher build code
   than any already published release. Existing APKs without this code cannot
   acquire an update dialog from the backend alone.
3. Publish subsequent releases to Play. Do not enable the global offer during
   staged rollout or while a release is pending review. Verify availability for
   the entire intended audience before enabling the corresponding build number.
4. Use the same application ID and compatible signing identity for upgrades.
   Store listing publication and Play Console uploads are separate operator work.

Checks: backend `manage.py test api.user.app_release`; Flutter
`flutter test --no-pub test/features/app_update`; full analyzer/tests and release
packaging under the existing signing/map-provider gate. Test real-device Later,
Android back, Play open/browser fallback and cold re-launch before rollout.
