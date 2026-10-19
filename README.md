# Shinji for iOS

Shinji is a native SwiftUI starter for a personal media app covering movies, TV shows, and live TV, with URL-installed declarative add-ons.

## Included in this starter
- SwiftUI tabs for Movies, Shows, Live TV, Add-ons, and Settings
- HTTPS JSON add-on manifest validation
- AVPlayer playback for a direct stream URL
- Mute control and best-effort mixing with other audio
- GitHub Actions workflow to build an unsigned iOS IPA artifact on a macOS runner

## Build from an iPhone
1. Open the **Actions** tab and enable workflows if prompted.
2. Select **Build unsigned IPA** and choose **Run workflow**, or push a commit to `main`.
3. Open the completed workflow run and download the `Shinji-unsigned-ipa` artifact.
4. Import the artifact into a compatible signing service. An unsigned IPA is not installable until signed with a certificate/profile supported by the service and device.

## Add-on manifest
A manifest URL must use HTTPS and return JSON similar to:

```json
{
  "schemaVersion": 1,
  "id": "example.catalog",
  "name": "Example Catalog",
  "version": "1.0.0",
  "publisher": "Example Publisher",
  "capabilities": ["movie.catalog", "tv.catalog", "live.channels", "playback.resolve"],
  "endpoints": {
    "catalog": "https://example.org/catalog.json"
  }
}
```

The app validates manifest metadata and endpoint schemes. Downloaded code is never executed. Catalog fetching and rendering are not yet implemented.

## Current limitations
This is a starter template, not a complete streaming service. It does not yet include a real catalog aggregator, XMLTV guide, profiles, parental controls, offline downloads, episode calendar, source fallback, or full subtitle/audio-track controls. Playback depends on the URL format, provider access, and any DRM requirements. Only use content and sources you are authorized to access.
