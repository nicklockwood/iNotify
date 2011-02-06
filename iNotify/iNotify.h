//
//  iNotify.h
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
@interface iNotify : NSObject<UIAlertViewDelegate>
#else
@interface iNotify : NSObject
#endif

+ (iNotify *)sharedInstance;

//notifications url - always set this
@property (nonatomic, retain) NSString *notificationsPlistURL;

//frequency settings - these have sensible defaults
@property (nonatomic, assign) BOOL showOldestFirst;
@property (nonatomic, assign) BOOL showOnFirstLaunch;
@property (nonatomic, assign) float checkPeriod;
@property (nonatomic, assign) float remindPeriod;

//message text, you may wish to customise these, e.g. for localisation
@property (nonatomic, retain) NSString *okButtonLabel;
@property (nonatomic, retain) NSString *ignoreButtonLabel;
@property (nonatomic, retain) NSString *remindButtonLabel;
@property (nonatomic, retain) NSString *defaultActionButtonLabel;

//debugging and disabling
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, assign) BOOL debug;

@end
