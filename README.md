Purpose
--------------

iNotify is a simple library that allows you to "push" notifications to users of your iPhone or Mac apps that pop up when they open the app. Unlike Apple's built-in push notifications API, these do not appear when the app isn't running (technically, they are pulled by the app rather than pushed), but they require very little in terms of server-side infrastructure or configuration - you simply place a file on public-facing URL somewhere and update it when needed.

The notifications consist of a title, message and optionally a button that sends the user to a URL that can be specified on a per-message basis. 

These notifications are ideal for cross-promoting your apps, or telling users about features that they may have missed.

The notifications can also be used to notify users about new releases, but for this you would be better off using our iVersion library, which was specifically designed for the purpose and provides a more automated approach. iVersion and iNotify can be used in the same project without interference.

Note that the documentation in this file focusses predominantly on iPhone, but the iNotify library should work equally well on Mac Cocoa apps.


Supported iOS & SDK Versions
-----------------------------

* Supported build target - iOS 5.1 / Mac OS 10.7 (Xcode 4.3.1, Apple LLVM compiler 3.0)
* Earliest supported deployment target - iOS 4.3 / Mac OS 10.6
* Earliest compatible deployment target - iOS 3.0

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

iNotify makes use of the ARC Helper library to automatically work with both ARC and non-ARC projects through conditional compilation. There is no need to exclude iNotify files from the ARC validation process, or to convert iNotify using the ARC conversion tool.


Thread Safety
--------------

iNotify uses threading internally to avoid blocking the UI, but none of the iNotify external interfaces are thread safe and you should not call any methods or set any properties on iNotify except from the main thread.


Installation
--------------

To install iNotify into your app, drag the iNotify.h, .m and .bundle files into your project. You can omit the .bundle if you are not interested in localised copy.

To enable iNotify in your application you need to instantiate and configure iNotify *before* the app has finished launching. The easiest way to do this is to add the iNotify configuration code in your AppDelegate's initialize method, like this:

    + (void)initialize
    {
        //configure iNotify
        [iNotify sharedInstance].notificationsPlistURL = @"http://example.com/notifications.plist";
    }

The above code represents the minimum configuration needed to make iNotify work, although there are other configuration options you may wish to add (documented below).

You will need to place a plist containing your notification on a public-facing web server somewhere. The format of the plist is as follows:

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>2011/02/01</key>
        <dict>
            <key>Title</key>
            <string>Some notification title</string>
            <key>Message</key>
            <string>Some notification message</string>
        </dict>
        <key>2011/01/22</key>
        <dict>
            <key>Title</key>
            <string>Some other notification title</string>
            <key>Message</key>
            <string>Some other notification message</string>
            <key>ActionButton</key>
            <string>Find Out More...</string>
            <key>ActionURL</key>
            <string>http://example.com/somepage.html</string>
        </dict>
        ...
    </dict>
    </plist>

The root node of the plist is a dictionary containing one or more key/dict pairs. Each dictionary represents a particular notification message.

The key for each value can be any string, but best practice is to use a date in the form YYYY/MM/DD. The reason for this is that the messages will be displayed in reverse-alphanumeric sorting order by key, so by using dates like this, your messages will be shown in reverse chronological order each time the app is launched, starting with the newest (you can configure iNotify to show them oldest-first instead if you prefer).

If you are likely to send more than one message per day, you may wish to adjust the naming scheme by adding the time or an extra digit to the end of the date, or adopt a different scheme such as keying each message with an ascending digit or letter sequence.

Once messages get old or irrelevant, you should remove them from the plist to reduce download time for users. Don't adopt the practice of leaving all your messages in the file indefinitely. Also, DO NOT re-use message keys after you delete the old notification messages, as users who have already viewed the message for that key will never see any new message that uses the same key.

Each value should be a dictionary containing the following keys:

* Title

The title of the promotional message

* Message

The content of the notification message

The dictionary may also include the following optional keys:

* ActionURL

A URL relating to the notification. If the ActionURL is omitted, the message will not feature an action button but will simply have an OK button to dismiss the message.

Note that the ActionURL can be used to launch other apps, or to trigger behaviour within your app by specifying a custom URL schema handler. If the action URL cannot be opened (because the app is not installed), the alert will not be shown.

* ActionButton

The label of the button that opens the action URL. If the ActionURL is omitted, the ActionButton value is not used. If the ActionURL is included, but ActionButton is omitted, the action button's text will default to whatever is specified in the iNotify configuration constants ("More Info..." by default).

* MinVersion

The minimum application version that the notification should be displayed on. This is useful for notifications that refer to features in specific application versions. For example, you could use this to notify users about a new feature in the latest release if you forgot to mention it anywhere in the app.

* MaxVersion

The maximum application version that the notification should be displayed on. This is useful for notifications that refer to features in specific application versions. For example, you could use this to notify users of older releases of the app that a new version is available (note that if this is the only reason you're using iRate you'd be better off using our iVersion library, which was specifically designed for the purpose).


Configuration
--------------

To configure iNotify, there are a number of properties of the iNotify class that can alter the behaviour and appearance. These should be mostly self-
explanatory, but key ones are documented below:

    @property (nonatomic, copy) NSString *notificationsPlistURL;

This is the URL that iNotify will check for new notification messages. For testing purposes, you may wish to create a separate copy of the file at a different address and use a build constant to switch which version the app points at. 

    @property (nonatomic, copy) NSString *applicationVersion;
    
The current version number of the app. This is used for comparison against the MinVersion and MaxVersion in the plist to determine if a given notification should be shown. This is set automatically from the  CFBundleShortVersionString (if available) or CFBundleVersion string in the info.plist and it's probably not a good idea to change it unless you know what you are doing.

    @property (nonatomic, assign) BOOL showOldestFirst;

This boolean can be used to toggle whether notifications are shown newest-first (the default) or oldest-first.

    @property (nonatomic, assign) BOOL showOnFirstLaunch;

When a user first installs your app, you may not want to bombard them with popup alerts. Use this option to disable notifications from showing the first time the app launches (set to NO by default).

    @property (nonatomic, assign) float checkPeriod;

Sets how frequently the app will check for new notification messages. This is measured in days but can be set to a fractional value. Set this to a higher value to avoid excessive traffic to your server. A value of zero means the app will check every time it's launched. Default is 0.5 days.
    
    @property (nonatomic, assign) float remindPeriod;

How long the app should wait before reminding a user of a notification after they select the "remind me later" option. A value of zero means the app will remind the user every launch. Note that this value supersedes the check period, so once a reminder is set, the app won't check for notifications during the reminder period, even if additional notifications are added in the meantime. Default is 1 day.

    @property (nonatomic, copy) NSString *okButtonLabel;

The dismissal button label for messages that do not include an action URL.

    @property (nonatomic, copy) NSString *ignoreButtonLabel;

The button label for the button the user presses if they wish to dismiss a notification without visiting the associated action URL.

    @property (nonatomic, copy) NSString *remindButtonLabel;

The button label for the button the user presses if they don't want to view a notification URL immediately, but do want to be reminded about it in future. Set this to nil if you don't want to display the remind me button - e.g. if you don't have space on screen.

    @property (nonatomic, copy) NSString *defaultActionButtonLabel;

The default text to use for the action button label if it is not specified in the notifications plist.

    @property (nonatomic, assign) BOOL disableAlertViewResizing;

On iPhone, iNotify includes some logic to resize the alert view to ensure that your message doesn't become truncated in landscape mode. The code to do this is a rather nasty hack, so if your alert text is very short and/or your app only needs to function in portrait mode on iPhone, you may wish to set this property to YES, which may help make your app more robust against future iOS updates.

    @property (nonatomic, assign) BOOL onlyPromptIfMainWindowIsAvailable;

This setting is applicable to Mac OS only. By default, on Mac OS the iNotify alert is displayed as sheet on the main window. Some applications do not have a main window, so this approach doesn't work. For such applications, set this property to NO to allow the iNotify alert to be displayed as a regular modal window.

    @property (nonatomic, assign) BOOL checkAtLaunch;

Set this to NO to disable automatic checking for notifications when the application launches or returns from background. Note that if automatic checks are disabled, you can still trigger a check manually by calling the `checkForNotifications` method.

    @property (nonatomic, assign) BOOL debug;

If set to YES, iNotify will always download and display the next unread message in the notifications plist when the app launches, irrespective of the checkPeriod and remindPeriod settings. With debug enabled, the ignore list will also be cleared out after all message have been read, so that they will continue to display from the beginning on subsequent launches.


Advanced properties
---------------

If the default iNotify behaviour doesn't meet your requirements, you can implement your own by using the advanced properties, methods and delegate. The properties below let you access internal state and override it:

    @property (nonatomic, copy) NSArray *ignoredNotifications;

An array of keys for notifications that the user has already seen and chosen to ignore.

    @property (nonatomic, copy) NSArray *viewedNotifications;

An array of keys for notifications that the user has already viewed.

    @property (nonatomic, retain) NSDate *lastChecked;

The last date on which iNotify checked for notifications. You can use this in combination with the checkPeriod to determine if the app should check again.

    @property (nonatomic, retain) NSDate *lastReminded;

The last date on which the user was reminded of a notification. You can use this in combination with the remindPeriod to determine if the app should check again. Set this to nil to clear the reminder delay.

    @property (nonatomic, assign) id<iNotifyDelegate> delegate;

An object you have supplied that implements the iNotifyDelegate protocol, documented below. Use this to detect and/or override iNotify's default behaviour. This defaults to the App Delegate, so if you are using your App Delegate as your iNotify delegate, you don't need to set this property.


Advanced methods
---------------

These can be used in combination with the advanced properties and delegate to precisely control iNotify's behaviour.

    - (NSString *)nextNotificationInDict:(NSDictionary *)dict;

This returns the key for the most recent (or oldest, depending on the showOldestFirst setting) notification in the passed dictionary. You can use this with the notifications parameter of the iNotifyDetectedNotifications delegate method to extract a single notification for display.

    - (void)setNotificationIgnored:(NSString *)key;

This is a convenience method for marking a notification as ignored, so that it won't appear in future checks for notifications.

    - (void)setNotificationViewed:(NSString *)key;

This is a convenience method for marking a notification as viewed, so that it won't appear in future checks for notifications.

    - (BOOL)shouldCheckForNotifications;

This performs the normal checks to test if notifications should be displayed, including calling the 'iNotifyShouldCheckForNotifications' delegate method if available. This is useful if you have disabled checkAtLaunch and wish to trigger a check manually whilst still taking into account the checkPeriod, remindPeriod, etc. 

    - (void)checkForNotifications;

This method will trigger a new check for new notifications, ignoring the checkPeriod and remindPeriod properties.


Delegate methods
---------------

The iNotifyDelegate protocol provides the following methods that can be used intercept iNotify events and override the default behaviour. All methods are optional.

    - (BOOL)iNotifyShouldCheckForNotifications;

This is called if the checking criteria have all been met and iNotify is about to check for notifications. If you return NO, the check will not be performed. This method is not called if you trigger the check manually with the checkForNotifications method.

    - (void)iNotifyDidNotDetectNotifications;

This is called if the notifications check did not detect any new notifications (that is, notifications that have not already been viewed or ignored).

    - (void)iNotifyNotificationsCheckDidFailWithError:(NSError *)error;

This is called if the notifications check failed due to network issues or because the notifications plist file was missing or corrupt.

    - (void)iNotifyDidDetectNotifications:(NSDictionary *)notifications;

This is called if new notifications are detected that have not already been viewed or ignored. The notifications parameter is a dictionary of dictionaries, with each entry representing a single notification (structurally this is the same as the content in the notifications plist).

If you only wish to display a single notification, use the nextNotificationInDict method to filter out the most recent (or oldest, depending on the showOldestFirst setting) notification in dictionary.

To get extract the individual fields for a notification, use the key constants defined at the top of the iNotify.h file.

    - (BOOL)iNotifyShouldDisplayNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

This is called immediately before the notification alert is displayed. Return NO to prevent the alert from being displayed. Note that if you do return NO, and intend to implement the alert yourself, you will need to update the lastChecked, lastReminded, ignoredNotifications and viewedNotifications properties manually, depending on the user response.

    - (void)iNotifyUserDidViewActionURLForNotificationWithKey:(NSString *)key details:(NSDictionary *)details;
    
This is called when the user views the action URL for a notification. This is useful if you want to log user interaction with iNotify. This method is only called if you are using the standard iNotify alert view and will not be called automatically if you provide a custom alert implementation.
    
    - (void)iNotifyUserDidRequestReminderForNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

This is called when the user asks to be reminded about a notification. This is useful if you want to log user interaction with iNotify. This method is only called if you are using the standard iNotify alert view and will not be called automatically if you provide a custom alert implementation.

    - (void)iNotifyUserDidIgnoreNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

This is called when the user ignores a notification. This is useful if you want to log user interaction with iNotify. This method is only called if you are using the standard iNotify alert view and will not be called automatically if you provide a custom alert implementation.


Localisation
---------------

The defaults strings for iNotify are already localised for English, French, German, Italian, Spanish and Japanese, however there is no automatic way for iNotify to localise the content in your notifications Plist file.

To localise the notifications themselves, the simplest approach is is provide separate notification Plist files for each language, each with a unique URL. The easiest way to do this is to include the notificationsPlistURL in your Localizable.strings file, like this:

    + (void)initialize
    {
        [iNotify sharedInstance].notificationsPlistURL = NSLocalizedString(@"http://example.com/notifications_en.plist", @"iNotify plist URL");
    }
    
It is not recommended that you modify the strings files in the iNotify.bundle, as it will complicate updating to newer versions of iNotify. If you do want to edit the files, or open them so you can copy the keys into your own strings file, you should note that the iNotify strings files have actually been compiled as binary plists, so you'll need to open them in Xcode and use the Open As > Property List option, or they will appear as gibberish.

If you want to add an additional language, or replace all the built-in strings, the simplest option is to remove the iNotify.bundle from your project and then add the iNotify keys directly to your own Localizable.strings file.

If you want to override some of the localised strings but leave the others intact, you can provide localised values for any or all of the message strings by setting the keys directly in code using NSLocalizedString(...), e.g.

    + (void)initialize
    {
        [iNotify sharedInstance].okButtonLabel = NSLocalizedString(@"OK", @"iNotify OK button");
        [iNotify sharedInstance].ignoreButtonLabel = NSLocalizedString(@"Ignore", @"iNotify ignore button");
        [iNotify sharedInstance].remindButtonLabel = NSLocalizedString(@"Remind Me Later", @"iNotify remind button");
        [iNotify sharedInstance].defaultActionButtonLabel = NSLocalizedString(@"More...", @"iNotify action button");
    }


Example Project
---------------

When you build and run the example project for the first time, it will show an alert with a promotional message about iNotify. This is because it has downloaded the remote notifications.plist file and this was the newest message it found.

Close the message and quit the app. If you relaunch, you will see a new message each time the app launches until all messages in the plist have been viewed, then they will cycle around again.

Normally, messages would be shown less often, but because the debug option is set to YES in the example, the usual notification throttling is ignored. If you set debugging to NO, you will not see an alert each time the app launches, and each unique alert will be shown only once.


Advanced Example
---------------

The advanced example demonstrates how you might implement a completely bespoke iNotify interface using the iNotifyDelegate methods. Automatic checking is disabled and instead the user can opt to download notifications by pressing the "Check for notifcations" button.

When pressed, the app display a progress wheel and then prints the notifications in a console underneath the button.

The example is for Mac OS, but the same thing can be applied on iOS.