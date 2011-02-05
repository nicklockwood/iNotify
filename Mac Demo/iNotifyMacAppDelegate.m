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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//initialise iNotify
	[iNotify appLaunched];
}

@end
