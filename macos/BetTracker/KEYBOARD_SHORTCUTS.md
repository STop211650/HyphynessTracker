# BetTracker Keyboard Shortcuts

## Current Keyboard Shortcuts

The following keyboard shortcuts are now implemented and working:

- **⌘⇧S** - Take Bet Screenshot
- **⌘⇧N** - Manual Bet Entry  
- **⌘⇧O** - Load Bet Screenshot
- **⌘,** - Settings (standard macOS shortcut)
- **⌘Q** - Quit (standard macOS shortcut)

## How Shortcuts Work

1. **Menu Commands**: Shortcuts are registered in the app's command menu system
2. **Notification System**: Uses NotificationCenter to communicate between menu and app
3. **Local Event Monitor**: Captures keyboard events when the app is active
4. **Help Tooltips**: Shows shortcut hints when hovering over menu items

## Avoiding System Conflicts

### Common macOS System Shortcuts to Avoid:
- **⌘Space** - Spotlight Search
- **⌘Tab** - App Switcher
- **⌘⇧3/4/5** - Screenshot tools
- **⌘⇧A** - Often used by apps for "Select All in Sidebar"
- **⌘Option[Key]** - Often reserved for system functions

### Best Practices:
1. Use **⌘⇧[Letter]** for app-specific actions (as we've done)
2. Follow macOS conventions (⌘, for Settings, ⌘Q for Quit)
3. Test shortcuts with Accessibility settings enabled
4. Avoid function keys (F1-F12) unless necessary

## Customizing Shortcuts

To change a shortcut, modify the `.keyboardShortcut()` modifier in the CommandMenu:

```swift
Button("Take Screenshot") {
    NotificationCenter.default.post(name: .takeScreenshot, object: nil)
}
.keyboardShortcut("s", modifiers: [.command, .shift])
```

And update the corresponding case in `setupKeyboardShortcuts()`:

```swift
case "s":
    self?.handleTakeScreenshot()
    return nil
```

## Testing Shortcuts

1. Build and run the app
2. Click on the menu bar icon (🎲)
3. Test each shortcut:
   - Focus should be on any app window
   - Press the keyboard combination
   - The corresponding action should trigger

## Troubleshooting

If shortcuts don't work:
1. Check if another app is using the same shortcut
2. Ensure the app has accessibility permissions if needed
3. Make sure no modal dialogs are open
4. Verify the app is the active application