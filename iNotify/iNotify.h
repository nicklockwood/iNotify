//
//  iNotify.h
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>


#define INOTIFY_NOTIFICATIONS_URL @"http://charcoaldesign.co.uk/iNotify/notifications.plist"

#define INOTIFY_CHECK_PERIOD 0.5 //measured in days
#define INOTIFY_REMIND_PERIOD 1 //measured in days

#define INOTIFY_OK_BUTTON @"OK"
#define INOTIFY_IGNORE_BUTTON @"Ignore"
#define INOTIFY_REMIND_BUTTON @"Remind Me Later"
#define INOTIFY_DEFAULT_ACTION_BUTTON @"More..."

#define INOTIFY_DEBUG YES //always shows notification alert


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
@interface iNotify : NSObject<UIAlertViewDelegate>
#else
@interface iNotify : NSObject
#endif

+ (void)appLaunched;
+ (void)appEnteredForeground;

@end
