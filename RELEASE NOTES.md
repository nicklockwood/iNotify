Version 1.5.3

- Fixed a bug where advanced properties set in the delegate methods might be subsequently overridden by iNotify
- Added disableAlertViewResizing option (see README for details)
- Added explicit 60-second timeout for notification update checks
- iNotify will now no longer spawn multiple download threads if closed and re-opened whilst performing an update check

Version 1.5.2

- Improved UIAlertView resizing logic
- Alert is no longer displayed if ActionURL cannot be opened on the device

Version 1.5.1

- Added logic to prevent UIAlertView collapsing in landscape mode

Version 1.5

- Included localisation for French, German, Italian, Spanish and Japanese
- Added workaround for change in UIApplicationWillEnterForegroundNotification implementation in iOS5
- iNotify delegate now defaults to App Delegate unless otherwise specified
- iNotify now uses the CFBundleShortVersionString to compare agains the MaxVersion and MinVersion (if available) instead of the CFBundleVersion
- applicationVersion property is now exposed as a property of iNotify in case you want to override it

Version 1.4.1

- Added automatic support for ARC compile targets
- Now requires Apple LLVM 3.0 compiler target

Version 1.4

- Notification messages can now be restricted to specific application versions
- Added additional delegate methods
- Renamed disabled property to checkAtLaunch for clarity

Version 1.3.2

- Fixed bug whereby ignored or viewed notifications would continue to appear.

Version 1.3.1

- Fixed crash on iOS versions before 4.0 when downloading notifications.

Version 1.3

- Added delegate and additional accessor properties for custom behaviour
- Added advanced example project to demonstrate use of the delegate protocol
- Added explicit ivars to support i386 (32bit x86) targets

Version 1.2

- Now compatible with iOS 3.x

Version 1.1

- Configuration no longer involves modifying iNotify.h file
- Now detects application launch and app switching events automatically
- Fixed bug in Mac code path
- Mac and iPhone demos now included
- Simpler to localise

Version 1.0

- Initial release.