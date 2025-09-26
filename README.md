# Flutter TV Media3

[![pub package](https://img.shields.io/pub/v/flutter_tv_media3.svg)](https://pub.dev/packages/flutter_tv_media3)

A Flutter plugin for playing video on Android TV using the native Media3 player, which runs in its own `Activity`. 
**Note: This plugin is for Android  only.**
Android (minSdk = 21).
The main difference of this plugin is that the player is launched in a separate native Android window, not as a widget in the Flutter hierarchy. This approach allows for the use of native features like **Auto Frame Rate (AFR) switching** and potential support for **HDR/Dolby Vision**, which may not be available in standard widget-based player implementations.

## Table of Contents

*   [Architecture and Limitations](#architecture-and-limitations)
*   [Key Features](#key-features)
*   [Getting Started](#getting-started)
    *   [Installation](#1-installation)
    *   [Android Configuration](#2-android-configuration)
*   [Basic Usage](#basic-usage)
    *   [Plugin and Controller Initialization](#1-plugin-and-controller-initialization)
    *   [Creating a Playlist](#2-creating-a-playlist)
    *   [Launching the Player](#3-launching-the-player)
*   [Advanced Usage](#advanced-usage)
    *   [Dynamic Link Resolution (`getDirectLink`)](#dynamic-link-resolution-getdirectlink)
    *   [Full Configuration and Callbacks](#full-configuration-and-callbacks)
    *   [External Control (IP Control)](#external-control-ip-control)
*   [API Reference](#api-reference)
    *   [`FtvMedia3PlayerController`](#ftvmedia3playercontroller)
    *   [`PlaylistMediaItem`](#playlistmediaitem)
    *   [`PlayerSettings`](#playersettings)
*   [Optional Native Libraries (Decoders)](#optional-native-libraries-decoders)
*   [External Subtitle Search Architecture](#external-subtitle-search-architecture)
*   [Auto Frame Rate (AFR)](#auto-frame-rate-afr)
*   [License](#license)


## Architecture and Limitations

Understanding the architecture is key to using this plugin correctly:

*   **Native Window:** The player runs in a separate Android `Activity`. This ensures the best possible performance and access to low-level system features.
*   **Separate UI Engine:** The user interface (UI) for the player is written in Flutter and runs in a separate, isolated `FlutterEngine`.
*   **Programmatic Control:** Interaction with the player from your main application is done exclusively programmatically via the `FtvMedia3PlayerController` singleton.
*   **D-pad and Touch Control:** The player UI is designed for D-pad (remote control's directional pad) navigation and also supports touch input(mouse). 
### Important Limitations

*  **UI is Not Customizable:** The player's UI is an internal part of the plugin. You cannot change its appearance or add your own widgets without modifying the plugin's source code.

## Key Features

*   **AFR Support:** [Automatic frame rate switching](https://developer.android.com/media/optimize/performance/frame-rate) for smooth playback (experimental functionality has been tested on only one device).
*   **Programmatic Control:** Full control over playback (play/pause, seek, track selection) from your application's code. This is primarily intended for implementing IP control.
*   **Playlist Management:** Create and manage playlists using `PlaylistMediaItem` objects.
*   **State Tracking:** Monitor the player's state, metadata, and playback progress through streams. This is primarily intended for implementing IP control.
*   **Dynamic Links:** Support for media that requires dynamically resolving a direct playback URL via an asynchronous callback.
*   **EPG (Electronic Program Guide):** Ability to pass and display a program guide for TV channels. The EPG is activated in the player by pressing the left/right D-pad buttons or on touch panel. To activate this, the `List<EpgProgram>? programs` field must not be `null`.
*   **Settings Persistence:** Callbacks to save player settings (quality, language) and subtitle styles that the user changes in the UI.
<p align="center">
    <a href="screenshots/screen0.png"><img src="screenshots/screen0.png" width="400"/></a>
    <a href="screenshots/screen1.png"><img src="screenshots/screen1.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen2.png"><img src="screenshots/screen2.png" width="400"/></a>
    <a href="screenshots/screen3.png"><img src="screenshots/screen3.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen4.png"><img src="screenshots/screen4.png" width="400"/></a>
    <a href="screenshots/screen5.png"><img src="screenshots/screen5.png" width="400"/></a>
</p>
<p align="center">
    <a href="screenshots/screen6.png"><img src="screenshots/screen6.png" width="400"/></a>
</p>
## Getting Started

### 1. Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_tv_media3: ^0.0.1 # Replace with the latest version
```
or 
```yaml
dependencies:
  flutter_tv_media3:
   git: https://github.com/Farg0k/flutter_tv_media3
```

### 2. Android Configuration

If you're playing content from the internet, your app must include the following permission in `AndroidManifest.xml` (inside the `<application>` tag):
```
<uses-permission android:name="android.permission.INTERNET" />
```
To play videos from `http` links (not `https`):
```
<application
    ...
    android:usesCleartextTraffic="true">
    ...
</application>
```

## Basic Usage

### 1. Controller Lifecycle: `init()` and `close()`

Properly managing the lifecycle of the `FtvMedia3PlayerController` is crucial for the stability of your application.

*   **`init()`**: This method must be called **once** before any other interaction with the controller. It configures all the necessary callbacks, initial settings, and localization strings. A good place to call it is in the `initState` of your main widget. The configuration cannot be changed after initialization.
*   **`close()`**: This method should be called when the controller is no longer needed, typically in the `dispose` method of your widget. It closes all internal streams and releases resources, preventing memory leaks.

```dart
@override
void initState() {
  super.initState();
  controller.init(...);
}

@override
void dispose() {
  controller.close();
  super.dispose();
}
```

### 2. Plugin and Controller Initialization

First, get the singleton instance of the `FtvMedia3PlayerController`. It's best to do this in a `StatefulWidget`.

The controller must be configured **once** before launching the player for the first time. This is done exclusively through the `init()` method, typically in your widget's `initState`. All configuration properties are private and cannot be changed after initialization.

The `init()` method accepts a variety of parameters to customize the player's behavior and set up callbacks. Below is a complete list of available parameters.

**General Configuration and Callbacks:**

These parameters are detailed in the [Full Configuration and Callbacks](#full-configuration-and-callbacks) section.

*   `localeStrings`: A map to provide localized strings for the player UI. For a complete list of available keys, see the `lib/src/localization/default_locale_strings.dart` file.
*   `subtitleStyle`: The initial `SubtitleStyle` to be applied.
*   `playerSettings`: The initial `PlayerSettings` (e.g., video quality, preferred languages).
*   `clockSettings`: The initial `ClockSettings` (e.g., position, format).
*   `saveSubtitleStyle`: A callback that is triggered when the user changes subtitle settings in the UI.
*   `savePlayerSettings`: A callback that is triggered when the user changes player settings.
*   `saveClockSettings`: A callback that is triggered when the user changes clock settings.
*   `saveWatchTime`: A callback to save the playback progress for a media item.
*   `sleepTimerExec`: A callback that is executed when the sleep timer is triggered from the player UI.

**External Subtitle Search:**

These parameters enable and configure the external subtitle search feature, which is described in detail in the [External Subtitle Search Architecture](#external-subtitle-search-architecture) section.

*   `searchExternalSubtitle`: The main handler function that performs the subtitle search.
*   `findSubtitlesLabel`: The text for the search button in the UI.
*   `findSubtitlesStateInfoLabel`: Optional text displayed below the search button (e.g., API usage).
*   `labelSearchExternalSubtitle`: An optional callback to dynamically update the `findSubtitlesStateInfoLabel` after a search.

**Example:**

```dart
// In your widget's state
final controller = FtvMedia3PlayerController();

@override
void initState() {
  super.initState();
  
  // A comprehensive initialization example
  controller.init(
    // General settings
    localeStrings: {'loading': 'Loading...'},
    clockSettings: ClockSettings(clockPosition: ClockPosition.topLeft),
    saveWatchTime: _mySaveWatchTimeFunction,
    
    // Subtitle search settings
    searchExternalSubtitle: _mySubtitleSearchFunction,
    findSubtitlesLabel: 'Search on OpenSubtitles',
  );
}

// Define your callback functions elsewhere
Future<void> _mySaveWatchTimeFunction({required String id, required int duration, required int position, required int playIndex}) async {
  // ... logic to save watch time
}

Future<List<MediaItemSubtitle>?> _mySubtitleSearchFunction({required String id}) async {
  // ... logic to search for subtitles
  return null;
}
```

### 3. Creating a Playlist

A playlist is a list of `PlaylistMediaItem` objects. Each object describes a single media item in detail.

```dart
final mediaItems = [
  // Simple item with a direct URL
  PlaylistMediaItem(
    id: 'sintel_trailer',
    url: 'https://.../playlist.m3u8',
    title: 'Sintel',
    description: 'Third open movie by Blender Foundation',
    subTitle: 'Blender Foundation',
    coverImg: 'https://.../image.jpg',
    startPosition: 60, // Start playback at 60 seconds
    duration: 888,
    headers: {'Referer': 'https://example.com/player'},
  ),
  // Item that requires dynamic link resolution
  PlaylistMediaItem(
    id: 'dynamic_video_1',
    url: 'myapp://resolving/video1', // Initial identifier
    title: 'Dynamic Video',
    getDirectLink: ({ required item, onProgress, required requestId }) async {
      onProgress?.call(requestId: requestId, state: 'Querying API...', progress: 0.5);
      await Future.delayed(const Duration(seconds: 2));
      final resolvedUrl = 'https://.../direct_link.mp4';
      return item.copyWith(url: resolvedUrl);
    },
  ),
];
```

### 4. Launching the Player

There are three ways to launch the player, depending on your needs.

#### Method 1: Launching with the Built-in Loading Screen (Recommended)

This approach provides visual feedback to the user while the native player initializes. It can be done in two ways:

**A) Using the `openPlayer` helper method:**

This is the most convenient way. The `FtvMedia3PlayerController` handles the navigation for you.

```dart
controller.openPlayer(
  context: context,
  playlist: mediaItems,
  initialIndex: 0, // Start with the first item
);
```

**B) Using Flutter's Navigator directly:**

You can also push the `Media3PlayerScreen` widget onto the navigation stack yourself. This gives you more control over the navigation, for example, if you want to use a different page route transition. This is the method used in the example application.

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => Media3PlayerScreen(
      playlist: mediaItems,
      initialIndex: 0,
    ),
  ),
);
```

#### Method 2: `openNativePlayer` (Advanced)

This method directly launches the native Android `Activity` for the player, bypassing the Flutter loading screen. This is useful if you want to implement your own custom loading logic or splash screen.

**Note:** This method does not use Flutter's `Navigator`. It's a direct call to the native side.

```dart
controller.openNativePlayer(
  playlist: mediaItems,
  initialIndex: 0,
);
```

## Advanced Usage

### Dynamic Link Resolution (`getDirectLink`)

If the playback URL is not known in advance (e.g., it needs to be fetched from your server), use the `getDirectLink` callback. The plugin will call this function before starting playback.

```
PlaylistMediaItem(
  id: 'secure_stream',
  url: 'secure_api://stream/123',
  title: 'Secure Video',
  getDirectLink: ({ required item, onProgress, required requestId }) async {
    // Show progress to the user
    onProgress?.call(requestId: requestId, state: 'Authorizing...', progress: 0.3);
    
    // Your asynchronous API request
    final String token = await getAuthToken();
    final String directUrl = await fetchSecureUrl(item.id, token);

    onProgress?.call(requestId: requestId, state: 'Loading...', progress: 0.8);

    // Return a copy of the item with the direct link and headers
    return item.copyWith(
      url: directUrl,
      headers: {'Authorization': 'Bearer $token'},
    );
  },
)
```

### Full Configuration and Callbacks

You can configure the player and handle events from its UI by passing all configurations to the `controller.init()` method.

Here is a full example of configuration:

```dart
// In your widget's state
final controller = FtvMedia3PlayerController();

// It's good practice to define callback functions separately
Future<void> _saveSubtitleStyle({required SubtitleStyle subtitleStyle}) async { /* ... */ }
Future<void> _savePlayerSettings({required PlayerSettings playerSettings}) async { /* ... */ }
Future<void> _saveClockSettings({required ClockSettings clockSettings}) async { /* ... */ }
Future<void> _saveWatchTime({required String id, required int duration, required int position, required int playIndex}) async { /* ... */ }
void _sleepTimerExec() { /* ... */ }

@override
void initState() {
  super.initState();
  
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;


  // Call setConfig() with all desired configurations
  controller.setConfig(
    // 1. Localize strings
    localeStrings: const { 'loading': 'Loading...', 'error_title': 'Error' },

    // 2. Initial subtitle style
    subtitleStyle: SubtitleStyle( foregroundColor: BasicColors.yellow, /* ... */ ),

    // 3. Initial player settings
    playerSettings: PlayerSettings( videoQuality: VideoQuality.high, /* ... */ ),

    // 4. Initial clock settings
    clockSettings: ClockSettings(clockPosition: ClockPosition.topLeft),
    
    // 5. Assign callbacks
    saveWatchTime: _saveWatchTime,
    savePlayerSettings: _savePlayerSettings,
    saveSubtitleStyle: _saveSubtitleStyle,
    saveClockSettings: _saveClockSettings,
    sleepTimerExec: _sleepTimerExec,
  );
}
```

### External Control (IP Control)

The `FtvMedia3PlayerController` is not just for launching the player. Its methods and streams are ideal for implementing **external control**. For example, you could create a remote control in a mobile app that sends commands to the player over the network (IP Control).

This is a two-way communication:
1.  **Sending Commands:** Use controller methods like `playPause()`, `seekTo()`, etc., to control playback.
2.  **Listening to State:** Use controller streams like `playerStateStream` to monitor the player's state and update your external UI accordingly.

**Listening to State Example:**

The controller provides several streams to track the player's state.

*   `playerStateStream`: Emits a complete `PlayerState` object whenever a significant change occurs (track change, pause, error). This is the main stream for tracking the overall state.
*   `playbackStateStream`: Emits a `PlaybackState` object (position, duration) several times per second during playback.
*   `mediaMetadataStream`: Emits the metadata of the current track (`MediaMetadata`) when it changes.

```dart
@override
void initState() {
  super.initState();
  // ... initialization

  controller.playerStateStream.listen((state) {
    // Update the UI, e.g., by highlighting the active track.
    if (mounted) {
      setState(() {
        lastPlayedIndex = state.playIndex;
      });
    }

    // Check for errors
    if (state.lastError != null) {
      print('An error occurred: ${state.lastError}');
      controller.resetError(); // Reset the error after handling it
    }
  });

  controller.playbackStateStream.listen((playback) {
    // print('Position: ${playback.position}, Duration: ${playback.duration}');
  });
}
```

### Error Handling

The plugin provides a mechanism for tracking and handling errors that may occur during playback. This is crucial for building a reliable and user-friendly application.

The primary way to receive error notifications is by listening to the `playerStateStream`. The `PlayerState` object emitted from this stream contains a `lastError` field.

**How It Works:**

1.  **Error Detection:** When an error occurs (e.g., unable to load a video, a network issue, or a decoding problem), information about it is written to the `lastError` field in the `PlayerState` object, and the new state is emitted to the `playerStateStream`.
2.  **Handling the Error:** Your code, subscribed to `playerStateStream`, receives the updated state. You can check if `state.lastError` is not `null`. If an error exists, you can display an appropriate message to the user, attempt to restart playback, or perform other necessary actions.
3.  **Resetting the Error:** After you have handled the error, it is important to "reset" it to prevent it from being processed again on subsequent state updates. This is done using the `controller.resetError()` method. It sets `lastError` back to `null`. If you don't do this, you might handle the same error multiple times.

**Code Example:**

```dart
@override
void initState() {
  super.initState();
  // ... other initialization

  controller.playerStateStream.listen((state) {
    // Check for an unhandled error
    if (state.lastError != null) {
      // Show a notification to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${state.lastError}'),
          backgroundColor: Colors.red,
        ),
      );

      // After handling, reset the error to avoid reacting to it again
      controller.resetError();
    }
  });
}
```

This approach allows for centralized error management and ensures the stable operation of the player in your application.

## API Reference

### `FtvMedia3PlayerController`

A singleton for controlling the player.

**Key Methods:**

*   **`setConfig()`**: **(Lifecycle)** Configures the controller. This method can be called multiple times to set or update configurations incrementally. Each call only modifies the parameters you provide, leaving previously set values intact. For all settings to be applied correctly on the initial launch, ensure this method is called **before launching the player**. Once the native player window is open, any subsequent configuration changes will only take effect the next time the player is launched.
*   `openPlayer()`: **(Core)** Opens the player with a playlist using a built-in loading screen (`Media3PlayerScreen`). This method handles Flutter navigation and is the recommended way to launch the player for most use cases.
*   `openNativePlayer()`: **(Core)** A lower-level alternative to `openPlayer`. It directly triggers the native player activity, bypassing the Flutter loading screen. This is useful if you want to implement a custom loading UI. This method does not manage Flutter navigation.
*   `close()`: **(Lifecycle)** Releases the controller's resources. Must be called in your widget's `dispose` method to prevent memory leaks.

All subsequent methods and streams are **optional** and are primarily intended for advanced scenarios, such as implementing IP control:

**Playback Control:**
*   `playPause()`: Toggles between play and pause.
*   `play()` / `pause()`: Starts or pauses playback.
*   `stop()`: Stops playback and releases player resources.
*   `seekTo(Duration)`: Seeks to the specified position.
*   `playNext()` / `playPrevious()`: Switches to the next/previous item in the playlist.
*   `playSelectedIndex({required int index})`: Plays a specific item from the playlist by its index.
*   `setSpeed({required double speed})`: Sets the playback speed.
*   `setRepeatMode({required RepeatMode repeatMode})`: Sets the repeat mode (off, one, all).
*   `setShuffleMode(bool enabled)`: Enables or disables shuffle mode.

**Track and Subtitle Management:**
*   `selectAudioTrack(AudioTrack)` / `selectSubtitleTrack(SubtitleTrack)` / `selectVideoTrack(VideoTrack)`: Selects a specific track.
*   `setExternalSubtitles({required List<MediaItemSubtitle> subtitleTracks})`: Programmatically adds a list of external subtitle tracks to the current media item.
*   `setExternalAudio({required List<MediaItemAudioTrack> audioTracks})`: Programmatically adds a list of external audio tracks.

**UI and Display Control:**
*   `setZoom({required PlayerZoom zoom})`: Sets the video zoom/resize mode (e.g., fit, fill).
*   `setScale({required double scaleX, required double scaleY})`: Applies a custom scale to the v allowing for fine-grained zoom control.
*   `sendCustomInfoToOverlay(String text)`: Displays a custom string in the player's timeline panel. Useful for showing dynamic information like network speed or connection status.

**Information Retrieval:**
*   `getMetaData()`: Fetches the latest metadata for the currently playing media item.
*   `getCurrentTracks()`: Returns a list of all available tracks (video, audio, subtitle).
*   `getRefreshRateInfo()`: Gets information about the display's supported and active refresh rates.

**Key Streams (Optional):**
*   `playerStateStateStream`: A stream that emits `PlayerState` objects on any significant state change (e.g., play/pause, track change, error).
*   `playbackStateStream`: A stream that emits `PlaybackState` objects (position, duration) several times per second during playback.
*   `mediaMetadataStream`: A stream that emits `MediaMetadata` objects when the current media item changes.

### `PlaylistMediaItem`

A class to describe a single item in a playlist. Objects of this class are immutable; use the `copyWith` method to create a modified copy.

**Core Properties:**

*   `id` (String): **Required.** A unique identifier for the media item.
*   `url` (String): **Required.** The URL of the media resource.

**UI Metadata:**

*   `title` (String?): The main title of the media (e.g., the name of a movie or series).
*   `subTitle` (String?): A subtitle that can be used as an episode title.
*   `description` (String?): A full description of the media item.
*   `label` (String?): A text label displayed for this item in the playlist UI.
*   `coverImg` (String?): The URL for the cover art image.
*   `placeholderImg` (String?): The URL for a placeholder image shown while the media is loading.
*   `mediaItemType` (`MediaItemType`): The type of the media item (`video`, `audio`, `tvStream`). This property has two functions: it is used to display a corresponding icon in the playlist UI, and **it can be used to force a specific player interface.** If set to `MediaItemType.audio`, the player will display the audio-only interface. Otherwise, the player will attempt to determine the interface automatically based on the media's tracks.

**Audio Metadata:**

*   `artistName` (String?): The name of the performer or artist.
*   `trackName` (String?): The name of the track.
*   `albumName` (String?): The name of the album.
*   `albumYear` (String?): The release year of the album.

**Playback Parameters:**

*   `startPosition` (int?): The initial playback position in seconds.
*   `duration` (int?): The total duration of the media in seconds.
*   `headers` (Map<String, String>?): HTTP headers to be used when requesting the `url`.
*   `userAgent` (String?): A custom User-Agent for HTTP requests.
*   `resolutions` (Map<String, String>?): A map of available video resolutions (e.g., `"720p": "url..."`).
*   `subtitles` (List<`MediaItemSubtitle`>?): A list of external subtitle tracks.
*   `audioTracks` (List<`MediaItemAudioTrack`>?): A list of external audio tracks.

**Advanced Features:**

*   `getDirectLink` (`GetDirectLinkCallback`?): An asynchronous callback to get a direct playback link.
*   `saveWatchTime` (bool): A flag indicating whether to save the watch time for this item. Defaults to `true`.
*   `programs` (List<`EpgProgram`>?): A list of programs for the EPG. If this field is not `null`, the EPG functionality is enabled for this media item.

### `PlayerSettings`

A class for player configuration.

**Properties:**
*   `videoQuality` (`VideoQuality`): The desired video quality (`low`, `medium`, `high`, `ultraHigh`).
*   `preferredAudioLanguages` (List<String>): A list of language codes for audio tracks (e.g., `['en', 'de']`).
*   `preferredTextLanguages` (List<String>): A list of language codes for subtitles.

## Optional Native Libraries (Decoders)

This plugin uses the native Media3 player from Google. By default, Media3 supports a standard set of audio and video formats. To extend its capabilities and support additional formats like AV1, IAMF, MPEGH, as well as containers and codecs provided by the FFmpeg library (e.g., AC3, EAC3, DTS, TrueHD), you need to add the corresponding decoder libraries to your application.

In the example (`/example/android/app/libs`), you can find the following pre-built libraries:
* `decoder_av1-release.aar`
* `decoder_ffmpeg-release.aar`
* `decoder_iamf-release.aar`
* `decoder_mpegh-release.aar`

### Why aren't these libraries included in the plugin?

1.  **Application Size:** Including all decoders would significantly increase the final application size, even if you don't need support for these formats.
2.  **Licensing:** The FFmpeg library is distributed under the LGPL/GPL license. Including it directly in the plugin could create legal complexities for developers. Providing these libraries as an optional component shifts the responsibility for license compliance to the end developer.
3.  **Flexibility:** You can choose exactly which decoders you need for your project.
4.  **Technical Build Limitations:** The Android build system (Gradle) does not allow a plugin to reliably transmit local libraries (`.aar`) to the final application. Explicitly including these files in the application's own `build.gradle` is a Gradle requirement that ensures they are available to the Media3 player at runtime.

### How to add the libraries to your application

1.  **Create a directory:** In your Flutter project, create a directory at `android/app/libs`.

2.  **Copy the files:** Copy the required `.aar` files from this plugin's `example/android/app/libs` directory into your newly created `android/app/libs` folder.

3.  **Add dependencies:** Open the `android/app/build.gradle.kts` file (or `android/app/build.gradle` if you're not using Kotlin Script) and add the dependencies for each library inside the `dependencies` block:

    ```kotlin
    // android/app/build.gradle.kts

    dependencies {
        // ... other dependencies
        implementation(files("libs/decoder_av1-release.aar"))
        implementation(files("libs/decoder_ffmpeg-release.aar"))
        implementation(files("libs/decoder_iamf-release.aar"))
        implementation(files("libs/decoder_mpegh-release.aar"))
    }
    ```

### Where to get the libraries?

*   **From the example:** The easiest way is to copy them from the `example/android/app/libs` folder of this project.
*   **Build them yourself:** You can build the latest versions of the libraries from the official [Google Media3](https://github.com/androidx/media) repository.
*   **FFmpeg:** For formats requiring FFmpeg, you can either:
    *   Use the local `decoder_ffmpeg-release.aar` library found in `example/android/app/libs`.
    *   Alternatively, add a dependency on the [Jellyfin](https://github.com/jellyfin/jellyfin-android) project. This allows you to receive library updates automatically via Gradle. To do this:
        1.  Ensure that `mavenCentral()` is added to the repositories in your `android/settings.gradle.kts` file (or `settings.gradle`):
            ```
            // android/settings.gradle.kts
            pluginManagement {
                repositories {
                    ...
                    mavenCentral() // This line must be present
                    ...
                }
            }
            ```
        2.  Replace the local dependency with the Jellyfin dependency in your `android/app/build.gradle.kts` file:
            ```
            // implementation(files("libs/decoder_ffmpeg-release.aar")) // Comment out or remove this line
            implementation 'org.jellyfin.media3:media3-ffmpeg-decoder:1.6.1+1' // Uncomment or add this line
            ```

## External Subtitle Search Architecture

This document describes the mechanism for searching and integrating external subtitles into the player. The architecture divides responsibilities between the main application, the native player, and the UI overlay.

### Overview

Thture allows a user to initiate a search for subtitles for the current media file. The search is performed by an external service (implemented in the main application), and the results are dynamically added to the list of available subtitle tracks in the player.

### Key Components

1.  **Main App:**
    *   Responsible for implementing the subtitle search logic (e.g., via a third-party service API).
    *   Provides the `FtvMedia3PlayerController` with a `searchExternalSubtitle` handler function.
    *   Passes initial settings (like the search button label) when launching the player.

2.  **Native Player (`PlayerActivity.kt`):**
    *   Acts as a bridge between the UI overlay and the main application.
    *   **Does not implement search logic.**
    *   Receives the `findSubtitles` command from the UI and forwards the `onFindSubtitlesRequested` request to the main app.
    *   Receives search status updates (`onSubtitleSearchStateChanged`) from the main app and broadcasts them to the UI overlay.
    *   Receives the found subtitle tracks (`setExternalSubtitles`) and adds them to the player's media source.

3.  **UI Overlay:**
    *   Contains the user controls (e.g., "Find Subtitles" button).
    *   Initiates the search process by calling `findSubtitles` on the `Media3UiController`.
    *   Reactively updates its state (e.g., shows a loading indicator, errors, or success notifications) based on data from `findSubtitlesStateNotifier`.

### Configuration in the Main Application

To activate the subtitle search functionality, you must pass the following parameters during the initialization of `FtvMedia3PlayerController`:

*   **`searchExternalSubtitle`**:
    *   **Type:** `Future<List<MediaItemSubtitle>?> Function({required String id})`
    *   **Description:** This is the core handler function that implements the subtitle search logic. It accepts the `id` of the current media item and must return a `Future` that resolves to a list of found subtitles (`List<MediaItemSubtitle>`) or `null` if nothing is found or an error occurs. This is where you place the code to interact with your subtitle search API.

*   **`findSubtitlesLabel`**:
    *   **Type:** `String?`
    *   **Description:** The initial static text for the subtitle search button in the player's UI. For example: "Find on OpenSubtitles".

*   **`findSubtitlesStateInfoLabel`**:
    *   **Type:** `String?`
    *   **Description:** Optional. The initial text to display under the button with additional info (e.g., API usage limits like "10/10"). This text can be dynamically updated after each search using the `labelSearchExternalSubtitle` callback.

*   **`labelSearchExternalSubtitle`**:
    *   **Type:** `Future<String> Function()`
    *   **Description:** An optional function that is called *after* every successful or failed search to dynamically update the `findSubtitlesStateInfoLabel` text. This allows displaying up-to-date information, such as API usage limits (e.g., "9/10 searches left") or other service statuses. The function must return a `Future<String>`, the result of which will become the new text for the info label.

### Data Flow

1.  **Initialization:**
    *   The main app, when configuring `FtvMedia3PlayerController`, passes the `searchExternalSubtitle` function and, optionally, `findSubtitlesLabel`, `findSubtitlesStateInfoLabel`, and `labelSearchExternalSubtitle`.
    *   This data is serialized to JSON and passed to `PlayerActivity` as `subtitle_search` on launch.
    *   `PlayerActivity` forwards this data to the UI overlay, where `Media3UiController` initializes `findSubtitlesStateNotifier`.

2.  **Initiating the Search:**
    *   The user presses the "Find Subtitles" button in the UI overlay.
    *   `SubtitleWidget` calls the `controller.findSubtitles()` method.
    *   `Media3UiController` immediately updates `findSubtitlesStateNotifier.value` to the `loading` state and calls the `findSubtitles` method on the `_activityChannel`.
    *   `PlayerActivity` receives the call, sees the `findSubtitles` method, and forwards the request by calling `onFindSubtitlesRequested` on the `methodChannel` leading to the main app, passing the `mediaId` as an argument.

3.  **Processing in the Main App:**
    *   `FtvMedia3PlayerController` receives the `onFindSubtitlesRequested` request.
    *   It calls the user-provided `_searchExternalSubtitle` function, passing it the `mediaId`.
    *   Throughout the process, `FtvMedia3PlayerController` can send intermediate states (e.g., "error", "not found") back to `PlayerActivity` via the `_updateFindSubtitlesState` method.

4.  **State and Result Updates:**
    *   `PlayerActivity` receives these updates via the `onSubtitleSearchStateChanged` method and broadcasts them to the UI overlay.
    *   `Media3UiController` in the overlay receives these states and updates `findSubtitlesStateNotifier`. The `SubtitleWidget` listens to this `ValueNotifier` and rebuilds, showing a loading indicator, error message, etc.
    *   After the search is complete (successful or not), `FtvMedia3PlayerController` calls the `_labelSearchExternalSubtitle` function (if provided) to update the info label's text (`findSubtitlesStateInfoLabel`).
    *   If the search is successful, `FtvMedia3PlayerController` calls `setExternalSubtitles`, passing the list of found `MediaItemSubtitle`.
    *   `PlayerActivity` receives this list, adds it to `currentSubtitleTracks`, and rebuilds the player's `MediaSource` to make the new subtitles available for selection.

5.  **Displaying Results:**
    *   After the `MediaSource` is rebuilt, the player sends an updated list of tracks (`onTracksChanged`).
    *   The UI overlay receives this list, and `SubtitleWidget` displays the new subtitle tracks. The widget also shows a notification that subtitles were successfully added.

### Data Objects

*   **`FindSubtitlesState`**: A class that encapsulates the complete UI state for the search feature. It contains the following fields:
    *   `isVisible`: Whether to show the search button.
    *   `label`: The text on the button.
    *   `stateInfoLabel`: The text to display under the button with additional info.
    *   `errorMessage`: The error message to display.
    *   `status`: The current status (`idle`, `loading`, `error`, `success`).
*   **`MediaItemSubtitle`**: A class representing an external subtitle track, containing the URL, title, and language.


## Auto Frame Rate (AFR)

### Important Notice

This feature has been tested on **only one device**. The implementation may be unstable or may not work on your hardware. Please consider it experimental. Use it at your own risk. We would appreciate your feedback and bug reports to improve this functionality.

### Overview

The Auto Frame Rate (AFR) feature is designed to provide the smoothest possible video playback. It works by synchronizing the display's refresh rate with the original frame rate of the video file (e.g., 23.976, 24, 25, 50, 60 fps). This eliminates judder, which can occur when playing content with a frame rate that is not a multiple of the screen's refresh rate.

This capability is realized because the player runs in a separate native Android window, which provides direct access to control the display modes.

### How It Works

The AFR logic is split between the native side (Kotlin) and the Flutter side (Dart).

#### Native Implementation (Android/Kotlin)

The core logic resides in the `FrameRateManager.kt` class.

1.  **Frame Rate Detection:** When video playback starts, `FrameRateManager` analyzes the video track in `ExoPlayer` and determines its original frame rate (fps).
2.  **Finding a Compatible Mode:** The class retrieves a list of all display modes supported by the device and searches for the best option that is compatible with the video's frame rate. Compatibility is determined by multiplicity or minimal difference between the rates (taking into account standard TV frequencies).
3.  **Switching the Refresh Rate:**
    *   **On Android 11 (API 30) and above:** It uses `Surface.setFrameRate()` to precisely set the refresh rate for the surface on which the video is being rendered. This is the modern and recommended approach.
    *   **On older Android versions (API 23-29):** It chIt changes the overall display mode (`preferredDisplayModeId`), which results in a brief black screen during the switch.
4.  **Resetting:** When playback stops or the AFR feature is disabled, `FrameRateManager` reverts the display's refresh rate to the default value.

The `PlayerActivity.kt` class manages the lifecycle of `FrameRateManager` and enables/disables it according to the settings received from Flutter.

#### Flutter Implementation (Dart)

On the Flutter side, the feature is managed through the UI and controllers.

1.  **Settings:**
    *   In `lib/src/entity/player_settings.dart`, the `PlayerSettings` class contains a boolean field `isAfrEnabled`, which is responsible for enabling or disabling AFR.
    *   The `lib/src/overlay/screens/components/setup_panel/settings_screen/player_settings_widget.dart` widget provides the user with a switch in the UI to control this setting.
2.  **Control:**
    *   When `isAfrEnabled` is `true`, `FrameRateManager` on the native side operates in automatic mode.
    *   When `isAfrEnabled` is `false`, automatic switching is disabled, and the user gets the option to **manually** select the screen's refresh rate.
3.  **Developer API:**
    *   The `FtvMedia3PlayerController` and `Media3UiController` controllers provide two methods for interacting with AFR:
        *   `Future<RefreshRateInfo> getRefreshRateInfo()`: Asynchronously returns a `RefreshRateInfo` object containing a list of supported refresh rates (`supportedRates`) and the currently active rate (`activeRate`).
        *   `Future<void> setManualFrameRate(double rate)`: Allows you to manually set the refresh rate. **This method will only work if AFR is disabled.**

### Usage

1.  **Automatic Mode:**
    *   Navigate to the player settings.
    *   Enable the "Auto Frame Rate (AFR)" switch.
    *   The player will automatically try to match the refresh rate to the content.

2.  **Manual Mode:**
    *   Ensure the "Auto Frame Rate (AFR)" switch is **disabled**.
    *   An active option for manual rate selection will appear in the settings menu.
    *   Call `getRefreshRateInfo()` to get a list of available rates and provide the user with a choice.
    *   Call `setManualFrameRate(rate)` to set the selected rate.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.ails.le rates and provide the user with a choice.
    *   Call `setManualFrameRate(rate)` to set the selected rate.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.