# BetTracker macOS App - Code Summary

## Overview
BetTracker is a macOS menubar application designed to capture screenshots of betting information. The app uses a modern architecture with a workspace + Swift Package Manager (SPM) structure for clean separation between the app shell and feature code.

## Current Implementation

### Architecture
The project follows a **two-tier architecture**:

1. **App Shell** (`BetTracker/BetTrackerApp.swift`): Minimal app entry point
2. **Feature Package** (`BetTrackerPackage/`): Intended for business logic (currently minimal)

### Key Components

#### 1. Main App Entry Point (`BetTrackerApp.swift`)
- **Purpose**: Defines the app structure and screenshot capture functionality
- **Key Features**:
  - MenuBar app using `MenuBarExtra` with dice emoji (🎲) 
  - Uses `ScreenCaptureKit` framework for modern screenshot capture
  - Implements `SCContentSharingPicker` for user-controlled screen capture
  - Saves screenshots to Documents directory with timestamps

#### 2. Screenshot Capture System
- **Technology**: Uses `SCContentSharingPicker` (modern macOS approach)
- **Flow**: 
  1. User clicks "📸 Capture Screenshot" button
  2. System presents native content picker UI
  3. User selects what to capture
  4. App captures and saves as PNG with timestamp
- **Permissions**: Requires Screen Recording permission

#### 3. App Configuration
- **MenuBar App**: Configured as `LSUIElement = YES` (no dock icon)
- **Sandbox**: App is sandboxed with basic file access permissions
- **Deployment Target**: macOS 15.0+
- **Bundle ID**: `com.hyphyness.BetTracker`

## Project Structure

```
BetTracker/
├── BetTracker.xcworkspace/          # Main workspace (open this in Xcode)
├── BetTracker.xcodeproj/            # App shell project
├── BetTracker/                      # App target
│   ├── BetTrackerApp.swift          # Main app code with screenshot logic
│   └── Assets.xcassets/             # App icons and assets
├── BetTrackerPackage/               # Swift Package for feature code
│   ├── Package.swift               # Package configuration
│   └── Sources/BetTrackerFeature/   # Feature code (minimal)
├── Config/                          # Build configuration
│   ├── BetTracker.entitlements      # App sandbox permissions
│   └── Shared.xcconfig              # Build settings
└── BetTrackerUITests/               # UI automation tests
```

## Current State Analysis

### What Works
- Basic menubar app structure is set up correctly
- Uses modern `ScreenCaptureKit` framework
- Proper workspace + SPM architecture
- Correct menubar app configuration (`LSUIElement = YES`)

### The Problem
The app has a **permission handling bug**:

1. **Issue**: App attempts screenshot capture before checking/requesting permissions
2. **Result**: Error dialog appears, then permission request dialog
3. **User Experience**: Confusing double-dialog flow

### Missing Components
1. **Permission Pre-Check**: App should use `CGPreflightScreenCaptureAccess()` before attempting capture
2. **Graceful Permission Handling**: Should guide user to grant permissions before attempting capture
3. **Feature Package Utilization**: Most code is in app shell instead of feature package
4. **Entitlements**: Missing screen capture entitlements for proper permission handling

## Technical Details

### Current Screenshot Flow
```swift
// Current problematic flow:
1. User clicks button
2. App immediately activates SCContentSharingPicker
3. System shows error (no permission)
4. System then shows permission request
```

### Recommended Screenshot Flow
```swift
// Better flow:
1. User clicks button
2. App checks CGPreflightScreenCaptureAccess()
3. If no permission: Show helpful message, request permission
4. If permission granted: Proceed with SCContentSharingPicker
```

### Key Files and Their Purpose

| File | Purpose | Current State |
|------|---------|---------------|
| `BetTrackerApp.swift` | Main app logic, screenshot capture | Contains all functionality |
| `ContentView.swift` (Package) | Feature UI components | Minimal "Hello World" |
| `BetTracker.entitlements` | App permissions | Basic sandbox only |
| `Shared.xcconfig` | Build configuration | Properly configured |

## Next Steps for Fixes

1. **Fix Permission Flow**: Add proper permission checking before capture attempts
2. **Add Screen Capture Entitlements**: Update entitlements file for proper permission handling
3. **Improve User Experience**: Better error messages and permission guidance
4. **Code Organization**: Move business logic to feature package as intended by architecture

## Integration Context

This macOS app appears to be part of a larger system that includes:
- Supabase backend for bet tracking
- Web dashboard for administration
- Screenshot analysis capabilities (Vision API integration)

The app's role is to capture screenshots of bets which are then processed and stored in the backend system.