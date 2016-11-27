//
//  iNotifyMacAppDelegate.h
//  iNotifyAdvanced
//
//  Created by Nick Lockwood on 06/02/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "iNotify.h"


@interface iNotifyMacAppDelegate : NSObject <NSApplicationDelegate, iNotifyDelegate>

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong) IBOutlet NSTextView *textView;

- (IBAction)checkForNotifications:(id)sender;

@end
