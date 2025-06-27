# BetTracker Code Improvements TODO

This document tracks remaining code improvements identified during the code review. These issues are lower priority than the critical fixes that have already been implemented.

## 🟠 High Priority Issues

### 1. Redundant Keyboard Shortcuts Implementation
**Problem**: The app has triple implementation of keyboard shortcuts:
- CommandMenu (standard SwiftUI way)
- Local event monitor (`addLocalMonitorForEvents`)
- Global event monitor

**Impact**: Makes code complex and hard to maintain.

**Solution**:
- Remove the local event monitor (`eventMonitor`) entirely
- Keep CommandMenu for app-active shortcuts
- Keep global monitor only for system-wide shortcuts
- Remove `setupKeyboardShortcuts()` function and its references

**Files affected**:
- `BetTrackerApp.swift` (lines 127, 156-160, 258-311)

## 🟡 Medium Priority Issues

### 2. Brittle Keyboard Shortcut Matching
**Problem**: Current implementation uses `event.charactersIgnoringModifiers` which depends on keyboard layout.

**Impact**: Shortcuts may fail with non-US keyboard layouts.

**Solution**:
- Add `keyCode` property to `AppShortcut` struct
- Use keyCode-based matching instead of character matching
- Update global event monitor to use keyCodes

**Example**:
```swift
struct AppShortcut {
    let key: String
    let keyCode: UInt16 // Add this
    // ... other properties
}
```

**Files affected**:
- `BetTrackerApp.swift` (AppShortcut struct and global event monitor)

## 🟢 Low Priority Improvements

### 3. Type Safety for Bet Types
**Problem**: Using string literals for bet types is prone to typos.

**Impact**: Potential runtime errors from typos.

**Solution**:
```swift
enum BetType: String, CaseIterable, Identifiable {
    case straight, parlay, teaser, round_robin, futures
    var id: String { self.rawValue }
    var displayName: String { 
        self.rawValue.replacingOccurrences(of: "_", with: " ").capitalized 
    }
}
```

**Files affected**:
- `ManualBetEntryView.swift` (line 20, 44-47)

## 📋 Implementation Notes

- These improvements focus on code maintainability and reliability
- None are critical for app functionality
- Can be implemented incrementally as time permits
- Consider user feedback before implementing keyboard shortcut changes

## 🔧 Testing Checklist

After implementing any of these improvements:
- [ ] Test all keyboard shortcuts on different keyboard layouts
- [ ] Verify no regression in window management
- [ ] Test bet entry with all bet types
- [ ] Ensure backwards compatibility with existing data