//
//  iNotify.m
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import "iNotify.h"


NSString * const iNotifyTitleKey = @"Title";
NSString * const iNotifyMessageKey = @"Message";
NSString * const iNotifyActionURLKey = @"ActionURL";
NSString * const iNotifyActionButtonKey = @"ActionButton";


static NSString * const iNotifyIgnoredNotificationsKey = @"iNotifyIgnoredNotifications";
static NSString * const iNotifyViewedNotificationsKey = @"iNotifyViewedNotifications";
static NSString * const iNotifyLastCheckedKey = @"iNotifyLastChecked";
static NSString * const iNotifyLastRemindedKey = @"iNotifyLastReminded";


static iNotify *sharedInstance = nil;


#define SECONDS_IN_A_DAY 86400.0


@interface iNotify()

@property (nonatomic, copy) NSDictionary *notificationsDict;
@property (nonatomic, retain) NSError *downloadError;

@end


@implementation iNotify

@synthesize notificationsDict;
@synthesize downloadError;
@synthesize notificationsPlistURL;
@synthesize showOldestFirst;
@synthesize showOnFirstLaunch;
@synthesize checkPeriod;
@synthesize remindPeriod;
@synthesize okButtonLabel;
@synthesize ignoreButtonLabel;
@synthesize remindButtonLabel;
@synthesize defaultActionButtonLabel;
@synthesize disabled;
@synthesize debug;
@synthesize delegate;


+ (iNotify *)sharedInstance
{
	if (sharedInstance == nil)
	{
		sharedInstance = [[iNotify alloc] init];
	}
	return sharedInstance;
}

- (iNotify *)init
{
	if ((self = [super init]))
	{
		
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
		
		//register for iphone application events
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationLaunched:)
													 name:UIApplicationDidFinishLaunchingNotification
												   object:nil];
		
		if (&UIApplicationWillEnterForegroundNotification)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(applicationWillEnterForeground:)
														 name:UIApplicationWillEnterForegroundNotification
													   object:nil];
		}
#else
		//register for mac application events
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationLaunched:)
													 name:NSApplicationDidFinishLaunchingNotification
												   object:nil];
#endif
		//default settings
		showOldestFirst = NO;
		showOnFirstLaunch = NO;
		checkPeriod = 0.5;
		remindPeriod = 1;
		
		//default button text, don't edit these here; if you want to provide your
		//own defaults then configure them using the setters/getters
		self.okButtonLabel = @"OK";
		self.ignoreButtonLabel = @"Ignore";
		self.remindButtonLabel = @"Remind Me Later";
		self.defaultActionButtonLabel = @"More...";
	}
	return self;
}

- (NSDate *)lastChecked
{
	return 	[[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastCheckedKey];
}

- (void)setLastChecked:(NSDate *)date
{
	[[NSUserDefaults standardUserDefaults] setObject:date forKey:iNotifyLastCheckedKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastReminded
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastRemindedKey];
}

- (void)setLastReminded:(NSDate *)date
{
	[[NSUserDefaults standardUserDefaults] setObject:date forKey:iNotifyLastRemindedKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)ignoredNotifications
{
	NSArray *ignored = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey];
	return ignored ?: [NSArray array];
}

- (void)setIgnoredNotifications:(NSArray *)keys
{
	//prevent ignored list being set to nil as this is
	//used to determine if this is the first launch
	keys = keys ?: [NSArray array];
	[[NSUserDefaults standardUserDefaults] setObject:keys forKey:iNotifyIgnoredNotificationsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setNotificationIgnored:(NSString *)key
{
	self.ignoredNotifications = [self.ignoredNotifications arrayByAddingObject:key];
}

- (NSArray *)viewedNotifications
{
	NSArray *viewed = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyViewedNotificationsKey];
	return viewed ?: [NSArray array];
}

- (void)setViewedNotifications:(NSArray *)keys
{
	[[NSUserDefaults standardUserDefaults] setObject:keys forKey:iNotifyViewedNotificationsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setNotificationViewed:(NSString *)key
{
	self.viewedNotifications = [self.viewedNotifications arrayByAddingObject:key];
}

- (NSString *)nextNotificationInDict:(NSDictionary *)dict
{
	NSArray *keys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	if (showOldestFirst)
	{
		//return oldest notification in the dictionary, assuming notifications are keyed by date
		return [keys count]? [keys objectAtIndex:0]: nil;
	}
	else
	{
		//return newest notification in the dictionary, assuming notifications are keyed by date
		return [keys lastObject];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[notificationsDict release];
	[downloadError release];
	[notificationsPlistURL release];
	[okButtonLabel release];
	[ignoreButtonLabel release];
	[remindButtonLabel release];
	[defaultActionButtonLabel release];
	[super dealloc];
}

#pragma mark -
#pragma mark Methods

- (void)setnotificationsDict:(NSDictionary *)notifications
{
	if (notifications != notificationsDict)
	{
		[notificationsDict release];
		
		//filter out ignored and viewed notifications
		NSMutableDictionary *filteredNotifications = [[notifications mutableCopy] autorelease];
		[filteredNotifications removeObjectsForKeys:self.ignoredNotifications];
		[filteredNotifications removeObjectsForKeys:self.viewedNotifications];
		
		//if no un-ignored messages...
		if (debug && [notifications count] && ![filteredNotifications count])
		{
			//reset ignored and viewed lists
			self.ignoredNotifications = nil;
			self.viewedNotifications = nil;
			filteredNotifications = [[notifications mutableCopy] autorelease];
		}
		
		//set dict
		notificationsDict = [filteredNotifications copy];
	}
}

- (void)downloadedNotificationsData
{
	
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
	
	//only show when main window is available
	if (![[NSApplication sharedApplication] mainWindow])
	{
		[self performSelector:@selector(downloadedNotificationsData) withObject:nil afterDelay:0.5];
		return;
	}
	
#endif
	
	//check if data downloaded
	if (!notificationsDict)
	{
		if ([(NSObject *)delegate respondsToSelector:@selector(iNotifyNotificationsCheckFailed:)])
		{
			[delegate iNotifyNotificationsCheckFailed:downloadError];
		}
		return;
	}

	//inform delegate about notifications
	if ([(NSObject *)delegate respondsToSelector:@selector(iNotifyDetectedNotifications:)])
	{
		[delegate iNotifyDetectedNotifications:notificationsDict];
	}		
	
	//get next notification
	NSString *notificationKey = [self nextNotificationInDict:notificationsDict];
	if (notificationKey)
	{
		//get notification data
		NSDictionary *notification = [notificationsDict objectForKey:notificationKey];
		if ([(NSObject *)delegate respondsToSelector:@selector(iNotifyShouldDisplayNotificationWithKey:details:)])
		{
			if (![delegate iNotifyShouldDisplayNotificationWithKey:notificationKey details:notification])
			{
				return;
			}
		}
		
		//get notification details
		NSString *title = [notification objectForKey:iNotifyTitleKey];
		NSString *message = [notification objectForKey:iNotifyMessageKey];
		NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
		NSString *actionButtonLabel = [notification objectForKey:iNotifyActionButtonKey];
		if (!actionButtonLabel)
		{
			actionButtonLabel = defaultActionButtonLabel;
		}

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
														message:message
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:nil];
		if (actionURL)
		{
			[alert addButtonWithTitle:actionButtonLabel];
			[alert addButtonWithTitle:remindButtonLabel];
			[alert addButtonWithTitle:ignoreButtonLabel];
			alert.cancelButtonIndex = 2;
		}
		else
		{
			[alert addButtonWithTitle:okButtonLabel];
			alert.cancelButtonIndex = 0;
		}
		
		[alert show];
		[alert release];
#else
		NSAlert *alert = nil;
		
		if (actionURL)
		{
			alert = [NSAlert alertWithMessageText:title
									defaultButton:actionButtonLabel
								  alternateButton:ignoreButtonLabel
									  otherButton:remindButtonLabel
						informativeTextWithFormat:message];
		}
		else
		{
			alert = [NSAlert alertWithMessageText:title
									defaultButton:okButtonLabel
								  alternateButton:nil
									  otherButton:nil
						informativeTextWithFormat:message];
		}
		
		[alert beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow]
						  modalDelegate:self
						 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
#endif
	}
}

- (BOOL)shouldCheckForNotifications
{
	//check if disabled
	if (disabled)
	{
		return NO;
	}
	
	//debug mode?
	else if (debug)
	{
		//continue
	}
	
	//check if first launch
	else if (!showOnFirstLaunch && [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey] == nil)
	{
		self.ignoredNotifications = [NSArray array];
		return NO;
	}
	
	//check if within the reminder period
	else if (self.lastReminded != nil)
	{
		//reminder takes priority over check period
		if ([[NSDate date] timeIntervalSinceDate:self.lastReminded] < remindPeriod * SECONDS_IN_A_DAY)
		{
			return NO;
		}
	}
	
	//check if within the check period
	else if (self.lastChecked != nil && [[NSDate date] timeIntervalSinceDate:self.lastChecked] < checkPeriod * SECONDS_IN_A_DAY)
	{
		return NO;
	}
	
	//confirm with delegate
	if ([(NSObject *)delegate respondsToSelector:@selector(iNotifyShouldCheckForNotifications)])
	{
		return [delegate iNotifyShouldCheckForNotifications];
	}
	
	//perform the check
	return YES;
}

- (void)checkForNotificationsInBackground
{
	@synchronized (self)
	{
		if (notificationsPlistURL)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSError *error = nil;
			NSDictionary *notifications = nil;
			NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:notificationsPlistURL] options:NSDataReadingUncached error:&error];
			if (data)
			{
				NSPropertyListFormat format;
				notifications = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:&error];
			}
			[self performSelectorOnMainThread:@selector(setDownloadError:) withObject:error waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(setNotificationsDict:) withObject:notifications waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(setLastChecked:) withObject:[NSDate date] waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(downloadedNotificationsData) withObject:nil waitUntilDone:YES];
			[pool drain];
		}
	}
}

- (void)checkForNotifications
{
	[self performSelectorInBackground:@selector(checkForNotificationsInBackground) withObject:nil];
}

#pragma mark -
#pragma mark UIAlertViewDelegate methods

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	NSString *key = [self nextNotificationInDict:notificationsDict];
	NSDictionary *notification = [notificationsDict objectForKey:key];
	NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
	
	if (buttonIndex == alertView.cancelButtonIndex)
	{
		if (actionURL)
		{
			//set ignored
			[self setNotificationIgnored:key];
		}
		else
		{
			//no action url to view so treat dismissal as a view
			[self setNotificationViewed:key];
		}
		
		//clear reminder
		self.lastReminded = nil;
	}
	else if (buttonIndex == 1)
	{
		//remind later
		self.lastReminded = [NSDate date];
	}
	else
	{
		//set viewed and clear reminder
		[self setNotificationViewed:key];
		self.lastReminded = nil;
		
		//go to download page
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:actionURL]];
	}
}

#else

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSString *key = [self nextNotificationInDict:notificationsDict];
	NSDictionary *notification = [notificationsDict objectForKey:key];
	NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
	
	switch (returnCode)
	{
		case NSAlertAlternateReturn:
		{
			//set ignored and clear reminder
			[self setNotificationIgnored:key];
			self.lastReminded = nil;
			break;
		}
		case NSAlertDefaultReturn:
		{
			//set viewed and clear reminder
			[self setNotificationViewed:key];
			self.lastReminded = nil;
			
			//go to download page
			if (actionURL)
			{
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionURL]];
			}
			break;
		}
		default:
		{
			//remind later
			self.lastReminded = [NSDate date];
		}
	}
}

#endif

- (void)applicationLaunched:(NSNotification *)notification
{
	if ([self shouldCheckForNotifications])
	{
		[self checkForNotifications];
	}
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
	if ([self shouldCheckForNotifications])
	{
		[self checkForNotifications];
	}
}

@end