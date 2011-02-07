//
//  iNotify.m
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import "iNotify.h"


NSString * const iNotifyIgnoredNotificationsKey = @"iNotifyIgnoredNotifications";
NSString * const iNotifyLastCheckedVersionKey = @"iNotifyLastCheckedVersion";
NSString * const iNotifyLastRemindedVersionKey = @"iNotifyLastRemindedVersion";

NSString * const iNotifyTitleKey = @"Title";
NSString * const iNotifyMessageKey = @"Message";
NSString * const iNotifyActionURLKey = @"ActionURL";
NSString * const iNotifyActionButtonKey = @"ActionButton";


static iNotify *sharedInstance = nil;


#define SECONDS_IN_A_DAY 86400.0


@interface iNotify()

@property (nonatomic, retain) NSDictionary *notificationsData;

@end


@implementation iNotify

@synthesize notificationsData;
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


- (void)setnotificationsData:(NSDictionary *)notifications
{
	if (notifications != notificationsData)
	{
		[notificationsData release];
		
		//filter out ignored notifications
		NSArray *ignored = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey];
		NSMutableDictionary *filteredNotifications = [[notifications mutableCopy] autorelease];
		[filteredNotifications removeObjectsForKeys:ignored];
		
		//if no un-ignored messages...
		if (debug && [filteredNotifications count] == 0 && [notifications count])
		{
			//reset ignore list
			[[NSUserDefaults standardUserDefaults] setObject:nil forKey:iNotifyIgnoredNotificationsKey];
			filteredNotifications = [[notifications mutableCopy] autorelease];
		}
		
		//set data
		notificationsData = [filteredNotifications retain];
	}
}

- (void)ignorePromotion:(NSString *)key
{
	NSArray *ignored = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey];
	if (ignored == nil)
	{
		ignored = [NSArray array];
	}
	[[NSUserDefaults standardUserDefaults] setObject:[ignored arrayByAddingObject:key] forKey:iNotifyIgnoredNotificationsKey];
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

- (void)downloadednotificationsData
{
	
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
	
	//only show when main window is available
	if (![[NSApplication sharedApplication] mainWindow])
	{
		[self performSelector:@selector(downloadednotificationsData) withObject:nil afterDelay:0.5];
		return;
	}
	
#endif
	
	//get next notification
	NSString *notificationKey = [self nextNotificationInDict:notificationsData];
	if (notificationKey)
	{
		//get notification data
		NSDictionary *notificationData = [notificationsData objectForKey:notificationKey];
		NSString *title = [notificationData objectForKey:iNotifyTitleKey];
		NSString *message = [notificationData objectForKey:iNotifyMessageKey];
		NSString *actionURL = [notificationData objectForKey:iNotifyActionURLKey];
		NSString *actionButtonLabel = [notificationData objectForKey:iNotifyActionButtonKey];
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

- (void)updateLastCheckedDate
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:iNotifyLastCheckedVersionKey];
}

- (BOOL)shouldCheckForNotifications
{
	if (disabled)
	{
		return NO;
	}
	if (debug)
	{
		return YES;
	}
	if (!showOnFirstLaunch && [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey] == nil)
	{
		[[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:iNotifyIgnoredNotificationsKey];
		return NO;
	}
	NSDate *lastReminded = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastRemindedVersionKey];
	if (lastReminded != nil)
	{
		//reminder takes priority over check period
		return ([[NSDate date] timeIntervalSinceDate:lastReminded] >= remindPeriod * SECONDS_IN_A_DAY);
	}
	NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastCheckedVersionKey];
	if (lastChecked == nil || [[NSDate date] timeIntervalSinceDate:lastChecked] >= checkPeriod * SECONDS_IN_A_DAY)
	{
		return YES;
	}
	return NO;
}

- (void)checkForNotifications
{
	@synchronized (self)
	{
		if (notificationsPlistURL)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSDictionary *notifications = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:notificationsPlistURL]];
			[self performSelectorOnMainThread:@selector(setnotificationsData:) withObject:notifications waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(updateLastCheckedDate) withObject:nil waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(downloadednotificationsData) withObject:nil waitUntilDone:YES];
			[pool drain];
		}
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[notificationsData release];
	[notificationsPlistURL release];
	[okButtonLabel release];
	[ignoreButtonLabel release];
	[remindButtonLabel release];
	[defaultActionButtonLabel release];
	[super dealloc];
}

#pragma mark -
#pragma mark UIAlertViewDelegate methods

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == alertView.cancelButtonIndex)
	{
		//ignore this version
		[self ignorePromotion:[self nextNotificationInDict:notificationsData]];
		[[NSUserDefaults standardUserDefaults] setObject:nil forKey:iNotifyLastRemindedVersionKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	else if (buttonIndex == 1)
	{
		//remind later
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:iNotifyLastRemindedVersionKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	else
	{
		//ignore and clear reminder
		[self ignorePromotion:[self nextNotificationInDict:notificationsData]];
		[[NSUserDefaults standardUserDefaults] setObject:nil forKey:iNotifyLastRemindedVersionKey];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		//go to download page
		NSDictionary *data = [notificationsData objectForKey:[self nextNotificationInDict:notificationsData]];
		NSString *actionURL = [data objectForKey:iNotifyActionURLKey];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:actionURL]];
	}
}

#else

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	switch (returnCode)
	{
		case NSAlertAlternateReturn:
		{
			//ignore this version
			[self ignorePromotion:[self nextNotificationInDict:notificationsData]];
			[[NSUserDefaults standardUserDefaults] setObject:nil forKey:iNotifyLastRemindedVersionKey];
			[[NSUserDefaults standardUserDefaults] synchronize];
			break;
		}
		case NSAlertDefaultReturn:
		{
			//ignore and clear reminder
			[self ignorePromotion:[self nextNotificationInDict:notificationsData]];
			[[NSUserDefaults standardUserDefaults] setObject:nil forKey:iNotifyLastRemindedVersionKey];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			//go to download page
			NSDictionary *data = [notificationsData objectForKey:[self nextNotificationInDict:notificationsData]];
			NSString *actionURL = [data objectForKey:iNotifyActionURLKey];
			if (actionURL)
			{
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionURL]];
			}
			break;
		}
		default:
		{
			//remind later
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:iNotifyLastRemindedVersionKey];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
}

#endif

- (void)applicationLaunched:(NSNotification *)notification
{
	if ([self shouldCheckForNotifications])
	{
		[self performSelectorInBackground:@selector(checkForNotifications) withObject:nil];
	}
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
	if ([self shouldCheckForNotifications])
	{
		[self performSelectorInBackground:@selector(checkForNotifications) withObject:nil];
	}
}

@end