Purpose
--------------

iNotify is a simple library that allows you to "push" notifications to users of your iPhone or Mac App Store apps that pop up when they open the app. Unlike Apple's built-in push notifications API, these do not appear when the app isn't running (technically, they are pulled by the app rather than pushed), but they require very little in terms of server-side infrastructure or configuration - you simply place a file on some hosted web space somewhere and update it when needed.

The notifications consist of a title, message and optionally a button that sends the user to a URL that can be specified on a per-message basis. 

These notifications are ideal for cross-promoting your apps, or telling users about features that they may have missed.

The notifications can also be used to notify users about new releases, but for this  you would be better off using our iVersion library, which was specifically designed for the purpose and provides a more automated approach. iVersion and iNotify can be used in the same project without interference.

Note that the documentation in this file focusses predominantly on iPhone, but the iNotify library should work equally well on Mac Cocoa apps.


Installation
--------------

To install iNotify into your app, drag the iNotify.h and .m files into your project.

To enable iNotify in your application you need to instantiate and configure iNotify *before* the app has finished launching. The easiest way to do this is to add the iNotify configuration code in your AppDelegate's initialize method, like this:

+ (void)initialize
{
	//configure iNotify
	[iNotify sharedInstance].notificationsPlistURL = @"http://example.com/notifications.plist";
}

The above code represents the minimum configuration needed to make iNotify work, although there are other configuration options you may wish to add (documented below).

You will need to place a plist containing your notification on a web-facing server somewhere. The format of the plist is as follows:

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

The root node of the plist is a dictionary containing one or more key/item pairs. Each item represents a particular notification message.

The key for each value can be anything, but best practice is to use a date in the form YYYY/MM/DD. The reason for this is that the messages will be displayed in reverse-alphanumeric sorting order by key, so by using dates like this, your messages will be shown in reverse chronological order each time the app is launched, starting with the newest (you can configure iNotify to show them oldest-first instead if you prefer).

If you are likely to send more than one message per day, you may wish to adjust the naming scheme by adding the time or an extra digit to the end of the date, or adopt a different scheme such as keying each message with an ascending digit or letter sequence.

Once messages get old or irrelevant, you should remove them from the plist to reduce download time for users. Don't adopt the practice of leaving all your messages in the file indefinitely. Also, DO NOT re-use message keys after you delete the old notification messages, as users who have already viewed the message for that key will never see any message that uses the same key.

Each value should be a dictionary containing the following items:

Title - the title of the promotional message
Message - the notification message
ActionURL (optional) - a URL relating to the notification
ActionButton (optional) - the label of the button that opens the URL

If the ActionURL is omitted, the message will not feature an action button but will simply have an OK button to dismiss the message. If the ActionURL is included, but ActionButton is omitted, the action button's text will default to whatever is specified in the iNotify configuration constants.

Note that the ActionURL can be used to launch other apps, or to trigger behaviour within your app by specifying a custom URL schema handler.


Configuration
--------------

To configure iNotify, there are a number of properties of the iNotify class that can alter the behaviour and appearance. These should be mostly self-
explanatory, but key ones are documented below:

notificationsPlistURL - This is the URL that iNotify will check for new notification messages. For testing purposes, you may wish to create a separate copy of the file at a different address and use a build constant to switch which version the app points at.

showOldestFirst - this boolean can be used to toggle whether notifications are shown newest-first (the default) or oldest-first.

showOnFirstLaunch - when a user first installs your app, you may not want to bombard them with popup alerts. Use this option to disable notifications from showing the first time the app launches (set to NO by default).

checkPeriod - Sets how frequently the app will check for new notification messages. This is measured in days but can be set to a fractional value. Set this to a higher value to avoid excessive traffic to your server. A value of zero means the app will check every time it's launched. Default is 0.5 days.

remindPeriod - How long the app should wait before reminding a user of a notification after they select the "remind me later" option. A value of zero means the app will remind the user every launch. Note that this value supersedes the check period, so once a reminder is set, the app won't check for notifications during the reminder period, even if additional notifications are added in the meantime. Default is 1 day.

okButtonLabel - The dismissal button label for messages that do not include an action URL.

ignoreButtonLabel - The button label for the button the user presses if they wish to dismiss a notification without visiting the associated action URL.

remindButtonLabel - The button label for the button the user presses if they don't want to view a notification URL immediately, but do want to be reminded about it in future. Set this to nil if you don't want to display the remind me button - e.g. if you don't have space on screen.

defaultActionButtonLabel - The default text to use for the action button label if it is not specified in the notifications plist.

disabled - Set this to YES to disable checking for notifications. This is equivalent to setting the notificationsPlistURL to nil, but may be more convenient.

debug - If set to YES, iNotify will always download and display the next unread message in the notifications plist when the app launches, irrespective of the checkPeriod and remindPeriod settings. With debug enabled, the ignore list will also be cleared out after all message have been read, so that they will continue to display from the beginning on subsequent launches.


Advanced properties
---------------

If the default iNotify behaviour doesn't meet your requirements, you can implement your own by using the advanced properties, methods and delegate. The properties below let you access internal state and override it:

ignoredNotifications - An array of keys for notifications that the user has already seen and chosen to ignore.

viewedNotifications - An array of keys for notifications that the user has already viewed.

lastChecked - The last date on which iNotify checked for notifications. You can use this in combination with the checkPeriod to determine if the app should check again.

lastReminded - The last date on which the user was reminded of a notification. You can use this in combination with the remindPeriod to determine if the app should check again. Set this to nil to clear the reminder delay.

delegate - An object you have supplied that implements the iNotifyDelegate protocol, documented below. Use this to detect and/or override iNotify's default behaviour. 


Advanced methods
---------------

These can be used in combination with the advanced properties and delegate to precisely control iNotify's behaviour.

- (NSString *)nextNotificationInDict:(NSDictionary *)dict;

This returns the key for the most recent (or oldest, depending on the showOldestFirst setting) notification in the passed dictionary. You can use this with the notifications parameter of the iNotifyDetectedNotifications delegate method to extract a single notification for display.

- (void)setNotificationIgnored:(NSString *)key;

This is a convenience method for marking a notification as ignored, so that it won't appear in future checks for notifications.

- (void)setNotificationViewed:(NSString *)key;

This is a convenience method for marking a notification as viewed, so that it won't appear in future checks for notifications.

- (void)checkForNotifications;

This method will trigger a new check for new notifications, ignoring the checkPeriod and remindPeriod properties.


Delegate methods
---------------

The iNotifyDelegate protocol provides the following methods that can be used intercept iNotify events and override the default behaviour. All methods are optional.

- (BOOL)iNotifyShouldCheckForNotifications;

This is called if the checking criteria have all been met and iNotify is about to check for notifications. If you return NO, the check will not be performed. This method is not called if you trigger the check manually with the checkForNotifications method.

- (void)iNotifyDidNotDetectNotifications;

This is called if the notifications check did not detect any new notifications (that is, notifications that have not already been viewed or ignored).

- (void)iNotifyNotificationsCheckFailed:(NSError *)error;

This is called if the notifications check failed due to network issues or because the notifications plist file was missing or corrupt.

- (void)iNotifyDetectedNotifications:(NSDictionary *)notifications;

This is called if new notifications are detected that have not already been viewed or ignored. The notifications parameter is a dictionary of dictionaries, with each entry representing a single notification (structurally this is the same as the content in the notifications plist).

If you only wish to display a single notification, use the nextNotificationInDict method to filter out the most recent (or oldest, depending on the showOldestFirst setting) notification in dictionary.

To get extract the individual fields for a notification, use the key constants defined at the top of the iNotify.h file.

- (BOOL)iNotifyShouldDisplayNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

This is called immediately before the notification alert is displayed. Return NO to prevent the alert from being displayed. Note that if you do return NO, and intend to implement the alert yourself, you will need to update the lastChecked, lastReminded, ignoredNotifications and viewedNotifications properties manually, depending on the user response.


Example Project
---------------

When you build and run the example project for the first time, it will show an alert with a promotional message about iNotify. This is because it has downloaded the remote notifications.plist file and this was the newest message it found.

Close the message and quit the app. If you relaunch, you will see nothing unless you set the debug option to YES, or set the checkPeriod to 0. If you do this, you will see a new message each time the app launches until all messages in the plist have been viewed.

Once the messages have been exhausted, to show the alerts again, delete the app from the simulator or set debug to YES.