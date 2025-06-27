# Keyboard Shortcuts - Recommendations

## Current Issues

1. **Conflicts**: ⌘⇧S, ⌘⇧N, and ⌘⇧O conflict with common macOS app shortcuts
2. **Complexity**: Dual implementation (CommandMenu + event monitor) is overly complex
3. **Limited Scope**: Shortcuts only work when app is active, limiting usefulness for a menu bar app

## Recommended Approach

### Option 1: Global Hotkeys (Best for Power Users)
Use a library like [HotKey](https://github.com/soffes/HotKey) for system-wide shortcuts:
- **⌃⌥S** - Take Screenshot (Control+Option+S)
- **⌃⌥N** - New Manual Entry
- **⌃⌥L** - Load Screenshot (avoid O which might conflict)

### Option 2: Simpler Local Shortcuts (Current Users)
Keep local shortcuts but use less common combinations:
- **⌘⌃S** - Take Screenshot (Command+Control+S)
- **⌘⌃N** - New Manual Entry
- **⌘⌃O** - Load Screenshot

### Option 3: Minimal Approach (Recommended)
- Remove keyboard shortcuts entirely except for standard ones (⌘Q, ⌘,)
- Menu bar apps are click-driven by nature
- Reduces complexity and avoids all conflicts
- Users can use macOS's built-in keyboard shortcut preferences to add their own

### Option 4: User-Configurable Shortcuts
Add a preference pane where users can:
1. Enable/disable shortcuts
2. Set their own key combinations
3. See conflicts with existing shortcuts

## Implementation Simplification

Instead of the current dual approach, choose ONE:

1. **For local shortcuts**: Use only `.keyboardShortcut()` modifiers, remove event monitor
2. **For global shortcuts**: Remove CommandMenu, use only global hotkey library
3. **For no shortcuts**: Remove all keyboard code, keep UI simple

## Conflict-Free Combinations

If keeping shortcuts, these are rarely used:
- **⌃⌘[Letter]** - Control+Command combinations
- **⌃⌥[Letter]** - Control+Option combinations  
- **⌘\`[Letter]** - Command+Backtick combinations
- **Function Keys**: F13-F19 with modifiers (if available)

## Testing for Conflicts

Before finalizing, test with common apps:
- Safari/Chrome (web browsing)
- Xcode (development)
- Finder (file management)
- Mail/Calendar (productivity)
- Popular third-party apps in your target audience