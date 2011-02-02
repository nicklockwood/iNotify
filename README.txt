Purpose
--------------

iNotify is a simple library that allows you to "push" notifications to users of your iPhone or Mac App Store apps that pop up when they open the app. Unlike Apple's built-in push notifications API, these do not appear when the app isn't running, but they require very little in terms of server-side infrastructure or configuration - you simply place a file on some hosted web space somewhere and update it when needed.

The notifications consist of a title, message and optionally a button that sends the user to a URL that can be specified on a per-message basis. 

These notifications are ideal for cross-promoting your apps, or telling users about features that they may have missed.

The notifications can also be used to notify users about new releases, but for this  you would be better off using our iVersion library, which was specifically designed for the purpose and provides a more automated approach. iVersion and iNotify can be used in the same project without interference.

Note that the documentation in this file focusses predominantly on iPhone, but the iNotify library should work equally well on Mac Cocoa apps.


Installation
--------------

To install iNotify into your app, drag the iNotify.h and .m files into your project.

To enable iNotify in your application, add a call to [iNotify appLaunched] to your app delegate's applicationDidFinishLaunching method, and (on the iPhone only) add a call to [iNotify appEnteredForeground] to the applicationWillEnterForeground method. The resultant code will look something like this:

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
    // Override point for customization after application launch.

    // Add the view controller's view to the window and display.
    [self.window addSubview:viewController.view];
    [self.window makeKeyAndVisible];
	
	//iNotify init
	[iNotify appLaunched];

    return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	//iNotify init
	[iNotify appEnteredForeground];
}

You will need to place a plist containing your notification on a web-facing server somewhere. If your app is popular this will get quite a bit of traffic so make sure the server is ready to support that. The format of the plist is as follows:

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

The key for each value can be anything, but best practice is probably to use a date in the form YYYY/MM/DD. The reason for this is that the messages will be displayed in reverse-alphanumeric sorting order by key, so by using dates like this, your messages will be shown in reverse chronological order each time the app is launched, starting with the newest.

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

To configure iNotify, there are a number of constants in the iNotify.h file
that can alter the behaviour and appearance. These should be mostly self-
explanatory, but key ones are documented below:

INOTIFY_NOTIFICATIONS_URL - This is the URL that iNotify will check for new notification messages. For testing purposes, you may wish to create a separate copy of the file at a different address and use a build constant to switch which version the app points at.

INOTIFY_CHECK_PERIOD - Sets how frequently the app will check for new notification messages. This is measured in days but can be set to a fractional value, e.g. 0.5. Set this to a higher value to avoid excessive traffic to your server. A value of zero means the app will check every time it's launched.

INOTIFY_REMIND_PERIOD - How long the app should wait before reminding a user of a notification after they select the "remind me later" option. A value of zero means the app will remind the user every launch. Note that this value supersedes the check period, so once a reminder is set, the app won't check for notifications during the reminder period, even if additional notifications are added in the meantime.

INOTIFY_OK_BUTTON - The dismissal button label for messages that do not include an action URL.

INOTIFY_IGNORE_BUTTON - The button label for the button the user presses if they wish to dismiss a notification without visiting the associated action URL.

INOTIFY_REMIND_BUTTON - The button label for the button the user presses if they don't want to view a notification URL immediately, but do want to be reminded about it in future. Set this to nil if you don't want to display the remind me button - e.g. if you don't have space on screen.

INOTIFY_DEFAULT_ACTION_BUTTON - The default text to use for the action button label if it is not specified in the notifications plist.

INOTIFY_DEBUG - If set to YES, iNotify will always download and display the next unread message in the notifications plist when the app launches, irrespective of the INOTIFY_CHECK_PERIOD and INOTIFY_REMIND_PERIOD settings. If a message has been read or ignored then it will not display even with the INOTIFY_DEBUG setting on. To show the message again you will have to delete the app and re-install, or change the message key in the notifications.plist to a new date.


Example Project
---------------

When you build and run the example project for the first time, it will show an alert with a promotional message about iNotify. This is because it has downloaded the remote notifications.plist file and this was the newest message it found.

Close the message and quit the app. If you relaunch, you will see nothing unless you set the INOTIFY_DEBUG to true, or set the INOTIFY_CHECK_PERIOD to 0. If you do this, you will see a new message each time the app launches until all messages in the plist have been viewed.

Once the messages have been exhausted, to show the alerts again, delete the app from the simulator or set INOTIFY_DEBUG to true.