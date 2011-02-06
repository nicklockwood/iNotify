//
//  iNotifyMacAppDelegate.m
//  iNotifyMac
//
//  Created by Nick Lockwood on 05/02/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import "iNotifyMacAppDelegate.h"
#import "iNotify.h"


@implementation iNotifyMacAppDelegate

@synthesize window;

+ (void)initialize
{
	//configure iNotify
	[iNotify sharedInstance].notificationsPlistURL = @"http://charcoaldesign.co.uk/iNotify/notifications.plist";
	[iNotify sharedInstance].debug = YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//not used
}

@end
