# Performance Logging Integration Guide

## Overview

This guide shows how to instrument cisum's codebase with performance logging to pinpoint bottlenecks and optimize performance. The system is designed to be minimal, zero-overhead in release builds, and provide exact file/function/line context for debugging.

## Core Logger: `PerfLog` (Modules/Shared/Utilities)

Located at `/Modules/Shared/Utilities/Sources/Utilities/PerformanceLogger.swift`

### Basic Usage

```swift
import Utilities

// Simple logging with automatic context capture
PerfLog.trace("Starting search operation")
PerfLog.info("User logged in successfully")
PerfLog.warning("Cache is getting full")
PerfLog.error("Failed to fetch data")

// Automatic timing measurement
let results = await PerfLog.measure("spotify-search") {
    await spotifySDK.search(term: "hello")
}

// Manual timing for complex operations
let timer = PerfLog.start("playlist-import")
// ... do work ...
PerfLog.end(timer)

// Mark significant events
PerfLog.mark("cache-hit")
PerfLog.mark("fallback-triggered")
```

### Output Format

```
🔍 [SearchViewModel.swift:142] performSearch() → Starting search for 'hello'
⏱️ [SpotifySDK.swift:89] search(term:) → ⏱️ spotify-search took 245.32ms
💾 [CacheManager.swift:56] fetch(key:) → 💾 cache HIT: playlist:abc123
```

## SDK Logger: `SDKPerfLog` (Packages/StreamingKit)

Located at `/Packages/StreamingKit/SDKPerformanceLogger.swift`

Standalone version for SDK packages that don't depend on Utilities module.

### Usage in SDKs

```swift
// In SpotifySDK/Sources/SpotifySDK/SpotifyPathfinderClient.swift
public func performQuery(
    operation: SpotifyPathfinderOperation,
    variables: [String: Any]
) async throws -> Data {
    return try await SDKPerfLog.measure("spotify", operation.operationName) {
        let tokens = try await auth.currentSessionTokens()
        SDKPerfLog.trace("spotify", "Fetching tokens for \(operation.operationName)")
        return try await performQuery(tokens: tokens, operation: operation, variables: variables)
    }
}

// In LyricsKit/Sources/LyricsKit/LRCLIBClient.swift
public func getLyrics(trackName: String, artistName: String) async throws -> LRCLIBSearchResult? {
    SDKPerfLog.trace("lyrics", "Searching for '\(trackName)' by '\(artistName)'")
    
    return try await SDKPerfLog.measure("lyrics", "search") {
        // Check cache first
        if let cached = cache[cacheKey] {
            SDKPerfLog.cacheHit("lyrics", cacheKey)
            return cached
        }
        
        SDKPerfLog.cacheMiss("lyrics", cacheKey)
        // Make API call
        return try await client.search(trackName: trackName, artistName: artistName)
    }
}

// Authentication events
SDKPerfLog.authEvent("spotify", "token-refreshed")
SDKPerfLog.authEvent("youtube", "login-success")

// Errors
catch {
    SDKPerfLog.error("spotify", "Failed to fetch playlist", error: error)
    throw error
}
```

## Instrumentation Strategy by Component

### 1. Packages/StreamingKit SDKs

**Copy `SDKPerformanceLogger.swift` to each SDK's Sources directory.**

#### Critical Points to Instrument:

- **Initialization**: Log when SDK is initialized
- **Network Requests**: Measure all HTTP calls
- **Authentication**: Track token refresh, login, logout
- **Cache Operations**: Log hits/misses
- **Parsing**: Measure JSON decode time
- **Search Operations**: Track query performance

#### Example: Spotify SDK

```swift
// SpotifySDK.swift
public init(session: SpotifyOAuthSession, ...) {
    SDKPerfLog.info("spotify", "Initializing SDK in \(session.mode) mode")
    // ... existing code
}

// SpotifySearchClient.swift
public func search(term: String) async throws -> Results {
    return try await SDKPerfLog.measure("spotify", "search") {
        let query = try await pathfinder.performQuery(
            operation: .search,
            variables: ["searchTerm": term]
        )
        return try parseResults(query)
    }
}

// SpotifyAuthService.swift
func refreshToken() async throws {
    SDKPerfLog.authEvent("spotify", "refreshing-token")
    let newToken = try await performRefresh()
    SDKPerfLog.authEvent("spotify", "token-refreshed")
    return newToken
}
```

#### Apply to all SDKs:
- SpotifySDK
- YouTubeSDK (extensive - focus on InnerTubeAPI, VideoPreloadCache, auth)
- iTunesKit
- LyricsKit
- SaavnKit
- RadioKit
- AirbudsKit
- MonochromeSDK
- DistributeSDK
- ProviderSDK

### 2. Modules/Core

**Use `PerfLog` from Utilities**

#### Critical Points:

```swift
// AppBootstrap.swift
func bootstrap() async {
    PerfLog.info("Starting app bootstrap")
    let timer = PerfLog.start("bootstrap")
    
    await PerfLog.measure("init-services") {
        await initializeServices()
    }
    
    await PerfLog.measure("load-state") {
        await loadPersistedState()
    }
    
    PerfLog.end(timer)
}

// RootView.swift
struct RootView: View {
    init() {
        PerfLog.trace("RootView initialized")
    }
    
    var body: some View {
        // ...
    }
}

// ServicesContainer.swift
func resolveService<T>(_ type: T.Type) -> T {
    PerfLog.trace("Resolving service: \(T.self)")
    return // ...
}
```

### 3. Modules/Shared

#### Networking
```swift
// NetworkClient.swift
func request<T>(_ endpoint: Endpoint) async throws -> T {
    return try await PerfLog.measure("network-\(endpoint.path)") {
        let response = try await performRequest(endpoint)
        return try decode(response)
    }
}
```

#### Caching
```swift
// CacheManager.swift
func fetch<T>(_ key: String) async -> T? {
    if let value = storage[key] {
        PerfLog.mark("cache-hit:\(key)")
        return value
    }
    PerfLog.mark("cache-miss:\(key)")
    return nil
}
```

#### Models
```swift
// Model deserialization
extension SongModel {
    init(from decoder: Decoder) throws {
        PerfLog.trace("Decoding SongModel")
        // ... existing code
    }
}
```

### 4. Modules/Features

Every feature module should log:
- View lifecycle
- Data fetching
- User interactions that trigger work
- Background operations

#### Player
```swift
// PlayerViewModel.swift
func play(_ track: Track) async {
    let timer = PerfLog.start("play-track")
    defer { PerfLog.end(timer) }
    
    PerfLog.info("Playing: \(track.title)")
    
    let stream = await PerfLog.measure("resolve-stream") {
        await streamResolver.resolve(track)
    }
    
    await PerfLog.measure("start-playback") {
        await audioEngine.play(stream)
    }
}
```

#### Search
```swift
// SearchViewModel.swift
func performSearch(_ query: String) async {
    PerfLog.info("Searching for: '\(query)'")
    
    results = await PerfLog.measure("search-\(query)") {
        await searchService.search(query)
    }
    
    PerfLog.info("Found \(results.count) results")
}
```

#### Library
```swift
// LibraryViewModel.swift
func loadPlaylists() async {
    let timer = PerfLog.start("load-playlists")
    defer { PerfLog.end(timer) }
    
    let cached = await PerfLog.measure("cache-check") {
        await cache.getPlaylists()
    }
    
    if cached.isEmpty {
        playlists = await PerfLog.measure("fetch-playlists") {
            await api.fetchPlaylists()
        }
    }
}
```

Apply this pattern to:
- Authentication
- Discover
- Home
- Albums
- Artists
- Profile
- Tracks
- Radio
- Playlists
- Rechords
- Plugins
- Onboarding

### 5. iOS & macOS Entry Points

```swift
// iOS/cisum/iOSApp.swift
@main
struct iOSApp: App {
    init() {
        PerfLog.info("🚀 cisum iOS app starting")
        let timer = PerfLog.start("app-init")
        // ... setup
        PerfLog.end(timer)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    PerfLog.mark("root-view-appeared")
                }
        }
    }
}

// macOS/cisum/macOSApp.swift
@main
struct macOSApp: App {
    init() {
        PerfLog.info("🚀 cisum macOS app starting")
        let timer = PerfLog.start("app-init")
        // ... setup
        PerfLog.end(timer)
    }
}
```

## Best Practices

### 1. Log Strategically, Not Everywhere
Focus on:
- Entry points (API calls, user actions)
- Expensive operations (network, disk I/O, parsing)
- Cache boundaries
- Background work
- Error paths

Avoid:
- Logging inside tight loops
- Trivial property getters
- SwiftUI body computations (unless debugging layout)

### 2. Use the Right Log Level

- **`trace`**: Detailed flow tracking, disabled in release
- **`debug`**: Performance measurements, timing
- **`info`**: Significant events (user actions, lifecycle)
- **`warning`**: Recoverable issues, fallbacks
- **`error`**: Failures, exceptions

### 3. Measure What Matters

```swift
// ✅ GOOD: Measure meaningful work
let tracks = await PerfLog.measure("fetch-playlist-tracks") {
    await api.getTracks(playlistId)
}

// ❌ BAD: Measuring trivial operations
let count = PerfLog.measure("get-count") {
    array.count
}
```

### 4. Preserve Context in Logs

```swift
// ✅ GOOD: Include relevant identifiers
PerfLog.info("Loading playlist: \(playlistId)")
PerfLog.error("Failed to decode track: \(trackId)")

// ❌ BAD: Generic messages
PerfLog.info("Loading playlist")
PerfLog.error("Decode failed")
```

### 5. Use Marks for State Transitions

```swift
PerfLog.mark("auth-started")
// ... authenticate ...
PerfLog.mark("auth-completed")

PerfLog.mark("player-buffering")
// ... buffer ...
PerfLog.mark("player-playing")
```

## Performance Impact

- **Debug builds**: Full logging enabled, ~0.1-0.5ms overhead per log
- **Release builds**: Minimal overhead, most logging compiled out
- **No external dependencies**: Pure Swift, uses Foundation only
- **Thread-safe**: Can log from any actor/thread

## Reading Logs

### Xcode Console
Logs appear immediately with file:line:function context.

### Console.app
Use subsystem filter: `aaravgupta.cisum`
Categories: Lifecycle, Playback, StreamResolver, MetadataCache, etc.

### Instruments
Enable Points of Interest to see signpost intervals.
Use Time Profiler with OSLog integration.

## Debugging Performance Issues

### Finding Slow Operations
```bash
# Filter for timing logs
grep "⏱️" console.log | sort -k5 -n
```

### Identifying Bottlenecks
1. Look for operations > 100ms
2. Check for repeated operations (missing cache)
3. Find nested expensive calls
4. Identify unnecessary work on main thread

### Example Investigation
```
⏱️ [SpotifySDK.swift:89] search(term:) → ⏱️ spotify-search took 1245.32ms
  ⏱️ [NetworkClient.swift:45] request() → ⏱️ network-/search took 890.12ms
  ⏱️ [JSONDecoder.swift:12] decode() → ⏱️ json-decode took 355.20ms
```

**Analysis**: 
- Total: 1245ms
- Network: 890ms (acceptable)
- Decoding: 355ms (HIGH - optimize model)

## Next Steps

1. Copy `SDKPerformanceLogger.swift` to each SDK package
2. Instrument SDK initialization and main API methods
3. Add logging to Core/AppBootstrap and RootView
4. Instrument feature ViewModels (Player, Search, Library)
5. Test and verify logs appear in Xcode console
6. Optimize operations identified as slow

## Maintenance

- Keep logs minimal and focused
- Remove debug logs after fixing issues
- Use consistent naming for operations
- Update this guide when adding new patterns
