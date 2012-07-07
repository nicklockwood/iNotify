//
//  iNotify.h
//
//  Version 1.5.4
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#inotify
//  https://github.com/nicklockwood/iNotify
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

//
//  ARC Helper
//
//  Version 2.1
//
//  Created by Nick Lockwood on 05/01/2012.
//  Copyright 2012 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://gist.github.com/1563325
//

#ifndef ah_retain
#if __has_feature(objc_arc)
#define ah_retain self
#define ah_dealloc self
#define release self
#define autorelease self
#else
#define ah_retain retain
#define ah_dealloc dealloc
#define __bridge
#endif
#endif

//  Weak delegate support

#ifndef ah_weak
#import <Availability.h>
#if (__has_feature(objc_arc)) && \
((defined __IPHONE_OS_VERSION_MIN_REQUIRED && \
__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_5_0) || \
(defined __MAC_OS_X_VERSION_MIN_REQUIRED && \
__MAC_OS_X_VERSION_MIN_REQUIRED > __MAC_10_7))
#define ah_weak weak
#define __ah_weak __weak
#else
#define ah_weak unsafe_unretained
#define __ah_weak __unsafe_unretained
#endif
#endif

//  ARC Helper ends


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


static NSString *const iNotifyTitleKey = @"Title";
static NSString *const iNotifyMessageKey = @"Message";
static NSString *const iNotifyActionURLKey = @"ActionURL";
static NSString *const iNotifyActionButtonKey = @"ActionButton";
static NSString *const iNotifyMessageMinVersionKey = @"MinVersion";
static NSString *const iNotifyMessageMaxVersionKey = @"MaxVersion";


@protocol iNotifyDelegate <NSObject>
@optional

- (BOOL)iNotifyShouldCheckForNotifications;
- (void)iNotifyDidNotDetectNotifications;
- (void)iNotifyNotificationsCheckDidFailWithError:(NSError *)error;
- (void)iNotifyDidDetectNotifications:(NSDictionary *)notifications;
- (BOOL)iNotifyShouldDisplayNotificationWithKey:(NSString *)key details:(NSDictionary *)details;
- (void)iNotifyUserDidViewActionURLForNotificationWithKey:(NSString *)key details:(NSDictionary *)details;
- (void)iNotifyUserDidRequestReminderForNotificationWithKey:(NSString *)key details:(NSDictionary *)details;
- (void)iNotifyUserDidIgnoreNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

@end


@interface iNotify : NSObject

//required for 32-bit Macs
#ifdef __i386__
{
    @private
    
    NSDictionary *_notificationsDict;
    NSError *_downloadError;
    NSString *_notificationsPlistURL;
    NSString *_applicationVersion;
    BOOL _showOldestFirst;
    BOOL _showOnFirstLaunch;
    float _checkPeriod;
    float _remindPeriod;
    NSString *_okButtonLabel;
    NSString *_ignoreButtonLabel;
    NSString *_remindButtonLabel;
    NSString *_defaultActionButtonLabel;
    BOOL _disableAlertViewResizing;
    BOOL _onlyPromptIfMainWindowIsAvailable;
    BOOL _checkAtLaunch;
    BOOL _debug;
    id<iNotifyDelegate> __ah_weak _delegate;
    id _visibleAlert;
    BOOL _currentlyChecking;
}
#endif

+ (iNotify *)sharedInstance;

//notifications url - always set this
@property (nonatomic, copy) NSString *notificationsPlistURL;

//application version, used to filter notifications - this is set automatically
@property (nonatomic, copy) NSString *applicationVersion;

//frquency and sort order settings - these have sensible defaults
@property (nonatomic, assign) BOOL showOldestFirst;
@property (nonatomic, assign) BOOL showOnFirstLaunch;
@property (nonatomic, assign) float checkPeriod;
@property (nonatomic, assign) float remindPeriod;

//message text, you may wish to customise these, e.g. for localisation
@property (nonatomic, copy) NSString *okButtonLabel;
@property (nonatomic, copy) NSString *ignoreButtonLabel;
@property (nonatomic, copy) NSString *remindButtonLabel;
@property (nonatomic, copy) NSString *defaultActionButtonLabel;

//debugging and notification overrides
@property (nonatomic, assign) BOOL disableAlertViewResizing;
@property (nonatomic, assign) BOOL onlyPromptIfMainWindowIsAvailable;
@property (nonatomic, assign) BOOL checkAtLaunch;
@property (nonatomic, assign) BOOL debug;

//advanced properties for implementing custom behaviour
@property (nonatomic, copy) NSArray *ignoredNotifications;
@property (nonatomic, copy) NSArray *viewedNotifications;
@property (nonatomic, strong) NSDate *lastChecked;
@property (nonatomic, strong) NSDate *lastReminded;
@property (nonatomic, ah_weak) id<iNotifyDelegate> delegate;

//manually control behaviour
- (NSString *)nextNotificationInDict:(NSDictionary *)dict;
- (void)setNotificationIgnored:(NSString *)key;
- (void)setNotificationViewed:(NSString *)key;
- (BOOL)shouldCheckForNotifications;
- (void)checkForNotifications;

@end
