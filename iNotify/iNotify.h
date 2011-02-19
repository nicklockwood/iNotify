//
//  iNotify.h
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>


extern NSString * const iNotifyTitleKey;
extern NSString * const iNotifyMessageKey;
extern NSString * const iNotifyActionURLKey;
extern NSString * const iNotifyActionButtonKey;


@protocol iNotifyDelegate

@optional
- (BOOL)iNotifyShouldCheckForNotifications;
- (void)iNotifyDidNotDetectNotifications;
- (void)iNotifyNotificationsCheckFailed:(NSError *)error;
- (void)iNotifyDetectedNotifications:(NSDictionary *)notifications;
- (BOOL)iNotifyShouldDisplayNotificationWithKey:(NSString *)key details:(NSDictionary *)details;

@end


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
@interface iNotify : NSObject<UIAlertViewDelegate>
#else
@interface iNotify : NSObject
#endif

+ (iNotify *)sharedInstance;

//notifications url - always set this
@property (nonatomic, copy) NSString *notificationsPlistURL;

//frequency settings - these have sensible defaults
@property (nonatomic, assign) BOOL showOldestFirst;
@property (nonatomic, assign) BOOL showOnFirstLaunch;
@property (nonatomic, assign) float checkPeriod;
@property (nonatomic, assign) float remindPeriod;

//message text, you may wish to customise these, e.g. for localisation
@property (nonatomic, copy) NSString *okButtonLabel;
@property (nonatomic, copy) NSString *ignoreButtonLabel;
@property (nonatomic, copy) NSString *remindButtonLabel;
@property (nonatomic, copy) NSString *defaultActionButtonLabel;

//debugging and disabling
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, assign) BOOL debug;

//advanced properties for implementing custom behaviour
@property (nonatomic, copy) NSArray *ignoredNotifications;
@property (nonatomic, copy) NSArray *viewedNotifications;
@property (nonatomic, retain) NSDate *lastChecked;
@property (nonatomic, retain) NSDate *lastReminded;
@property (nonatomic, assign) id<iNotifyDelegate> delegate;

//manually control behaviour
- (NSString *)nextNotificationInDict:(NSDictionary *)dict;
- (void)setNotificationIgnored:(NSString *)key;
- (void)setNotificationViewed:(NSString *)key;
- (void)checkForNotifications;

@end
