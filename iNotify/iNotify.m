//
//  iNotify.m
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import "iNotify.h"


NSString * const iNotifyIgnoredNotificationsKey = @"iNotifyIgnoredNotificationsKey";
NSString * const iNotifyLastCheckedVersionKey = @"iNotifyLastCheckedVersionKey";
NSString * const iNotifyLastRemindedVersionKey = @"iNotifyLastRemindedVersionKey";

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

+ (iNotify *)sharedInstance
{
	if (sharedInstance == nil)
	{
		sharedInstance = [[iNotify alloc] init];
	}
	return sharedInstance;
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
		if (INOTIFY_DEBUG && [filteredNotifications count] == 0 && [notifications count])
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
	//return oldest notification in the dictionary, assuming notifications are keyed by date
	NSArray *keys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	return [keys lastObject];
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
		NSString *actionButton = [notificationData objectForKey:iNotifyActionButtonKey];
		if (!actionButton)
		{
			actionButton = INOTIFY_DEFAULT_ACTION_BUTTON;
		}
		
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
														message:message
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:nil];
		if (actionURL)
		{
			[alert addButtonWithTitle:actionButton];
			[alert addButtonWithTitle:INOTIFY_REMIND_BUTTON];
			[alert addButtonWithTitle:INOTIFY_IGNORE_BUTTON];
			alert.cancelButtonIndex = 2;
		}
		else
		{
			[alert addButtonWithTitle:INOTIFY_OK_BUTTON];
			alert.cancelButtonIndex = 0;
		}
		
		[alert show];
		[alert release];
#else
		NSAlert *alert = nil;
		
		if (actionURL)
		{
			alert = [NSAlert alertWithMessageText:title
									defaultButton:actionButton
								  alternateButton:INOTIFY_IGNORE_BUTTON
									  otherButton:INOTIFY_REMIND_BUTTON
						informativeTextWithFormat:message];
		}
		else
		{
			alert = [NSAlert alertWithMessageText:title
									defaultButton:INOTIFY_OK_BUTTON
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
	if (INOTIFY_DEBUG)
	{
		return YES;
	}
	NSDate *lastReminded = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastRemindedVersionKey];
	if (lastReminded != nil)
	{
		//reminder takes priority over check period
		return ([[NSDate date] timeIntervalSinceDate:lastReminded] >= (float)INOTIFY_REMIND_PERIOD * SECONDS_IN_A_DAY);
	}
	NSDate *lastChecked = [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastCheckedVersionKey];
	if (lastChecked == nil || [[NSDate date] timeIntervalSinceDate:lastChecked] >= (float)INOTIFY_CHECK_PERIOD * SECONDS_IN_A_DAY)
	{
		return YES;
	}
	return NO;
}

- (void)checkForNotifications
{
	@synchronized (self)
	{
		if (INOTIFY_NOTIFICATIONS_URL)
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSDictionary *notifications = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:INOTIFY_NOTIFICATIONS_URL]];
			[self performSelectorOnMainThread:@selector(setnotificationsData:) withObject:notifications waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(updateLastCheckedDate) withObject:nil waitUntilDone:YES];
			[self performSelectorOnMainThread:@selector(downloadednotificationsData) withObject:nil waitUntilDone:YES];
			[pool drain];
		}
	}
}

- (void)dealloc
{
	[notificationsData release];
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
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionURL]];
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

#pragma mark -
#pragma mark Public methods

+ (void)appLaunched
{
	if ([[self sharedInstance] shouldCheckForNotifications])
	{
		[[self sharedInstance] performSelectorInBackground:@selector(checkForNotifications) withObject:nil];
	}
}

+ (void)appEnteredForeground
{
	if ([[self sharedInstance] shouldCheckForNotifications])
	{
		[[self sharedInstance] performSelectorInBackground:@selector(checkForNotifications) withObject:nil];
	}
}

@end