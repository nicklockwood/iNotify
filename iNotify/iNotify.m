//
//  iNotify.m
//
//  Version 1.5
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

#import "iNotify.h"


static NSString *const iNotifyIgnoredNotificationsKey = @"iNotifyIgnoredNotifications";
static NSString *const iNotifyViewedNotificationsKey = @"iNotifyViewedNotifications";
static NSString *const iNotifyLastCheckedKey = @"iNotifyLastChecked";
static NSString *const iNotifyLastRemindedKey = @"iNotifyLastReminded";


static iNotify *sharedInstance = nil;


#define SECONDS_IN_A_DAY 86400.0


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
@interface iNotify() <UIAlertViewDelegate>
#else
@interface iNotify()
#endif

@property (nonatomic, copy) NSDictionary *notificationsDict;
@property (nonatomic, strong) NSError *downloadError;

@end


@implementation iNotify

@synthesize applicationVersion;
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
@synthesize checkAtLaunch;
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

- (NSString *)localizedStringForKey:(NSString *)key
{
    static NSBundle *bundle = nil;
    if (bundle == nil)
    {
        //get localisation bundle
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"iNotify" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:bundlePath] ?: [NSBundle mainBundle];

        //get correct lproj folder as this doesn't always happen automatically
        for (NSString *language in [NSLocale preferredLanguages])
        {
            if ([[bundle localizations] containsObject:language])
            {
                bundlePath = [bundle pathForResource:language ofType:@"lproj"];
                bundle = [NSBundle bundleWithPath:bundlePath];
                break;
            }
        }

        //retain bundle
        bundle = AH_RETAIN(bundle);
    }

    //return localised string
    return [bundle localizedStringForKey:key value:nil table:nil];
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
        checkAtLaunch = YES;
        showOldestFirst = NO;
        showOnFirstLaunch = NO;
        checkPeriod = 0.5;
        remindPeriod = 1;
        
        //application version (use short version preferentially)
        self.applicationVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ([applicationVersion length] == 0)
        {
            self.applicationVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        }
        
        //default button text, don't edit these here; if you want to provide your
        //own defaults then configure them using the setters/getters
        self.okButtonLabel = [self localizedStringForKey:@"OK"];
        self.ignoreButtonLabel = [self localizedStringForKey:@"Ignore"];
        self.remindButtonLabel = [self localizedStringForKey:@"Remind Me Later"];
        self.defaultActionButtonLabel = [self localizedStringForKey:@"More Info"];
    }
    return self;
}

- (id<iNotifyDelegate>)delegate
{
    if (delegate == nil)
    {
        
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
        
        delegate = (id<iNotifyDelegate>)[[UIApplication sharedApplication] delegate];
#else
        delegate = (id<iNotifyDelegate>)[[NSApplication sharedApplication] delegate];
#endif
        
    }
    return delegate;
}

- (NSDate *)lastChecked
{
    return  [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyLastCheckedKey];
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
    
    AH_RELEASE(applicationVersion);
    AH_RELEASE(notificationsDict);
    AH_RELEASE(downloadError);
    AH_RELEASE(notificationsPlistURL);
    AH_RELEASE(okButtonLabel);
    AH_RELEASE(ignoreButtonLabel);
    AH_RELEASE(remindButtonLabel);
    AH_RELEASE(defaultActionButtonLabel);
    AH_SUPER_DEALLOC;
}

#pragma mark -
#pragma mark Private methods

- (void)setNotificationsDict:(NSDictionary *)notifications
{
    if (notifications != notificationsDict)
    {
        AH_RELEASE(notificationsDict);
        
        //filter out ignored and viewed notifications
        NSMutableDictionary *filteredNotifications = AH_AUTORELEASE([notifications mutableCopy]);
        [filteredNotifications removeObjectsForKeys:self.ignoredNotifications];
        [filteredNotifications removeObjectsForKeys:self.viewedNotifications];
        
        //if no un-ignored messages...
        if (debug && [notifications count] && ![filteredNotifications count])
        {
            //reset ignored and viewed lists
            self.ignoredNotifications = nil;
            self.viewedNotifications = nil;
            filteredNotifications = AH_AUTORELEASE([notifications mutableCopy]);
        }
        
        //remove notifications exluded for this version
        for (NSString *key in [filteredNotifications allKeys])
        {
            //get details
            NSDictionary *notification = [filteredNotifications objectForKey:key];
            NSString *minVersion = [notification objectForKey:iNotifyMessageMinVersionKey];
            NSString *maxVersion = [notification objectForKey:iNotifyMessageMaxVersionKey];
            
            //check version
            if ((minVersion && [applicationVersion compare:minVersion options:NSNumericSearch] == NSOrderedAscending) ||
                (maxVersion && [applicationVersion compare:maxVersion options:NSNumericSearch] == NSOrderedDescending))
            {
                [filteredNotifications removeObjectForKey:key];
            }
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
        if ([self.delegate respondsToSelector:@selector(iNotifyNotificationsCheckDidFailWithError:)])
        {
            [delegate iNotifyNotificationsCheckDidFailWithError:downloadError];
        }
        
        //deprecated code path
        else if ([delegate respondsToSelector:@selector(iNotifyNotificationsCheckFailed:)])
        {
            NSLog(@"iNotifyNotificationsCheckFailed: delegate method is deprecated, use iNotifyNotificationsCheckDidFailWithError: instead");
            [delegate performSelector:@selector(iNotifyNotificationsCheckFailed:) withObject:downloadError];
        }
        
        return;
    }
    
    //inform delegate about notifications
    if ([self.delegate respondsToSelector:@selector(iNotifyDidDetectNotifications:)])
    {
        [delegate iNotifyDidDetectNotifications:notificationsDict];
    }
    
    //deprecated code path
    else if ([delegate respondsToSelector:@selector(iNotifyDetectedNotifications:)])
    {
        NSLog(@"iNotifyDetectedNotifications: delegate method is deprecated, use iNotifyDidDetectNotifications: instead");
        [delegate performSelector:@selector(iNotifyDetectedNotifications:) withObject:notificationsDict];
    }   
    
    //get next notification
    NSString *notificationKey = [self nextNotificationInDict:notificationsDict];
    if (notificationKey)
    {
        //get notification data
        NSDictionary *notification = [notificationsDict objectForKey:notificationKey];
        
        //get notification details
        NSString *title = [notification objectForKey:iNotifyTitleKey];
        NSString *message = [notification objectForKey:iNotifyMessageKey];
        NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
        NSString *actionButtonLabel = [notification objectForKey:iNotifyActionButtonKey] ?: defaultActionButtonLabel;
        
        //check delegate
        if ([self.delegate respondsToSelector:@selector(iNotifyShouldDisplayNotificationWithKey:details:)])
        {
            if (![delegate iNotifyShouldDisplayNotificationWithKey:notificationKey details:notification])
            {
                return;
            }
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
        AH_RELEASE(alert);
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
    if (!debug)
    {
        if (!showOnFirstLaunch && [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey] == nil)
        {
            self.ignoredNotifications = [NSArray array];
            return NO;
        }
        else if (self.lastReminded != nil)
        {
            //reminder takes priority over check period
            if ([[NSDate date] timeIntervalSinceDate:self.lastReminded] < remindPeriod * SECONDS_IN_A_DAY)
            {
                return NO;
            }
        }
        else if (self.lastChecked != nil && [[NSDate date] timeIntervalSinceDate:self.lastChecked] < checkPeriod * SECONDS_IN_A_DAY)
        {
            return NO;
        }
    }
    if ([self.delegate respondsToSelector:@selector(iNotifyShouldCheckForNotifications)])
    {
        return [delegate iNotifyShouldCheckForNotifications];
    }
    return YES;
}

- (void)checkForNotificationsInBackground
{
    @synchronized (self)
    {
        if (notificationsPlistURL)
        {
            @autoreleasepool
            {
                NSError *error = nil;
                NSDictionary *notifications = nil;
                NSURL *URL = [NSURL URLWithString:notificationsPlistURL];
                NSData *data = [NSData dataWithContentsOfURL:URL options:NSDataReadingUncached error:&error];
                if (data)
                {
                    NSPropertyListFormat format;
                    if ([NSPropertyListSerialization respondsToSelector:@selector(propertyListWithData:options:format:error:)])
                    {
                        notifications = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:&error];
                    }
                    else
                    {
                        notifications = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:0 format:&format errorDescription:NULL];
                    }
                }
                [self performSelectorOnMainThread:@selector(setDownloadError:) withObject:error waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(setNotificationsDict:) withObject:notifications waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(setLastChecked:) withObject:[NSDate date] waitUntilDone:YES];
                [self performSelectorOnMainThread:@selector(downloadedNotificationsData) withObject:nil waitUntilDone:YES];
            }
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
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidIgnoreNotificationWithKey:details:)])
            {
                [delegate iNotifyUserDidIgnoreNotificationWithKey:key details:notification];
            }
            
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
        //log event
        if ([self.delegate respondsToSelector:@selector(iNotifyUserDidRequestReminderForNotificationWithKey:details:)])
        {
            [delegate iNotifyUserDidRequestReminderForNotificationWithKey:key details:notification];
        }
        
        //remind later
        self.lastReminded = [NSDate date];
    }
    else
    {
        //set viewed and clear reminder
        [self setNotificationViewed:key];
        self.lastReminded = nil;
        
        //log event
        if ([self.delegate respondsToSelector:@selector(iNotifyUserDidViewActionURLForNotificationWithKey:details:)])
        {
            [delegate iNotifyUserDidViewActionURLForNotificationWithKey:key details:notification];
        }
        
        //open URL
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
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidIgnoreNotificationWithKey:details:)])
            {
                [delegate iNotifyUserDidIgnoreNotificationWithKey:key details:notification];
            }
            
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
            
            if (actionURL)
            {
                //log event
                if ([self.delegate respondsToSelector:@selector(iNotifyUserDidViewActionURLForNotificationWithKey:details:)])
                {
                    [delegate iNotifyUserDidViewActionURLForNotificationWithKey:key details:notification];
                }
                
                //open URL
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionURL]];
            }
            break;
        }
        default:
        {
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidRequestReminderForNotificationWithKey:details:)])
            {
                [delegate iNotifyUserDidRequestReminderForNotificationWithKey:key details:notification];
            }
            
            //remind later
            self.lastReminded = [NSDate date];
        }
    }
}

#endif

- (void)applicationLaunched:(NSNotification *)notification
{
    if (checkAtLaunch && [self shouldCheckForNotifications])
    {
        [self checkForNotifications];
    }
}

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        if (checkAtLaunch && [self shouldCheckForNotifications])
        {
            [self checkForNotifications];
        }
    }
}

#endif

@end