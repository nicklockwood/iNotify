//
//  iNotify.m
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

#import "iNotify.h"


static NSString *const iNotifyIgnoredNotificationsKey = @"iNotifyIgnoredNotifications";
static NSString *const iNotifyViewedNotificationsKey = @"iNotifyViewedNotifications";
static NSString *const iNotifyLastCheckedKey = @"iNotifyLastChecked";
static NSString *const iNotifyLastRemindedKey = @"iNotifyLastReminded";


static iNotify *sharedInstance = nil;


#define SECONDS_IN_A_DAY 86400.0
#define REQUEST_TIMEOUT 60.0


#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
@interface iNotify() <UIAlertViewDelegate>
#else
@interface iNotify()
#endif

@property (nonatomic, copy) NSDictionary *notificationsDict;
@property (nonatomic, strong) NSError *downloadError;
@property (nonatomic, strong) id visibleAlert;
@property (nonatomic, assign) BOOL currentlyChecking;

- (BOOL)canOpenURL:(NSURL *)URL;

@end


@implementation iNotify

@synthesize applicationVersion = _applicationVersion;
@synthesize notificationsDict = _notificationsDict;
@synthesize downloadError = _downloadError;
@synthesize notificationsPlistURL = _notificationsPlistURL;
@synthesize showOldestFirst = _showOldestFirst;
@synthesize showOnFirstLaunch = _showOnFirstLaunch;
@synthesize checkPeriod = _checkPeriod;
@synthesize remindPeriod = _remindPeriod;
@synthesize okButtonLabel = _okButtonLabel;
@synthesize ignoreButtonLabel = _ignoreButtonLabel;
@synthesize remindButtonLabel = _remindButtonLabel;
@synthesize defaultActionButtonLabel = _defaultActionButtonLabel;
@synthesize disableAlertViewResizing = _disableAlertViewResizing;
@synthesize onlyPromptIfMainWindowIsAvailable = _onlyPromptIfMainWindowIsAvailable;
@synthesize checkAtLaunch = _checkAtLaunch;
@synthesize debug = _debug;
@synthesize delegate = _delegate;
@synthesize visibleAlert = _visibleAlert;
@synthesize currentlyChecking = _currentlyChecking;

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
        [bundle ah_retain];
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didRotate)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
#else
        //register for mac application events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationLaunched:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
#endif
        //default settings
        self.onlyPromptIfMainWindowIsAvailable = YES;
        self.checkAtLaunch = YES;
        self.showOldestFirst = NO;
        self.showOnFirstLaunch = NO;
        self.checkPeriod = 0.5;
        self.remindPeriod = 1;
        
        //application version (use short version preferentially)
        self.applicationVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ([self.applicationVersion length] == 0)
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
    if (_delegate == nil)
    {
        
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
        
        _delegate = (id<iNotifyDelegate>)[[UIApplication sharedApplication] delegate];
#else
        _delegate = (id<iNotifyDelegate>)[[NSApplication sharedApplication] delegate];
#endif
        
    }
    return _delegate;
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
    if (self.showOldestFirst)
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
    
    [_applicationVersion release];
    [_notificationsDict release];
    [_downloadError release];
    [_notificationsPlistURL release];
    [_okButtonLabel release];
    [_ignoreButtonLabel release];
    [_remindButtonLabel release];
    [_defaultActionButtonLabel release];
    [_visibleAlert release];
    [super ah_dealloc];
}

#pragma mark -
#pragma mark Private methods

- (void)setNotificationsDict:(NSDictionary *)notifications
{
    if (notifications != _notificationsDict)
    {
        [_notificationsDict release];
        
        //filter out ignored and viewed notifications
        NSMutableDictionary *filteredNotifications = [[notifications mutableCopy] autorelease];
        [filteredNotifications removeObjectsForKeys:self.ignoredNotifications];
        [filteredNotifications removeObjectsForKeys:self.viewedNotifications];
        
        //if no un-ignored messages...
        if (self.debug && [notifications count] && ![filteredNotifications count])
        {
            //reset ignored and viewed lists
            self.ignoredNotifications = nil;
            self.viewedNotifications = nil;
            filteredNotifications = [[notifications mutableCopy] autorelease];
        }
        
        //remove notifications exluded for this version
        for (NSString *key in [filteredNotifications allKeys])
        {
            //get details
            NSDictionary *notification = [filteredNotifications objectForKey:key];
            NSString *minVersion = [notification objectForKey:iNotifyMessageMinVersionKey];
            NSString *maxVersion = [notification objectForKey:iNotifyMessageMaxVersionKey];
            
            //check version
            if ((minVersion && [self.applicationVersion compare:minVersion options:NSNumericSearch] == NSOrderedAscending) ||
                (maxVersion && [self.applicationVersion compare:maxVersion options:NSNumericSearch] == NSOrderedDescending))
            {
                [filteredNotifications removeObjectForKey:key];
            }
        }
        
        //set dict
        _notificationsDict = [filteredNotifications copy];
    }
}

- (void)downloadedNotificationsData
{
    
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
    
    //only show when main window is available
    if (self.onlyPromptIfMainWindowIsAvailable && ![[NSApplication sharedApplication] mainWindow])
    {
        [self performSelector:@selector(downloadedNotificationsData) withObject:nil afterDelay:0.5];
        return;
    }
    
#endif
    
    //no longer checking
    self.currentlyChecking = NO;
    
    //check if data downloaded
    if (!self.notificationsDict)
    {
        if ([self.delegate respondsToSelector:@selector(iNotifyNotificationsCheckDidFailWithError:)])
        {
            [self.delegate iNotifyNotificationsCheckDidFailWithError:self.downloadError];
        }
        
        //deprecated code path
        else if ([self.delegate respondsToSelector:@selector(iNotifyNotificationsCheckFailed:)])
        {
            NSLog(@"iNotifyNotificationsCheckFailed: delegate method is deprecated, use iNotifyNotificationsCheckDidFailWithError: instead");
            [self.delegate performSelector:@selector(iNotifyNotificationsCheckFailed:) withObject:self.downloadError];
        }
        
        return;
    }
    
    //inform delegate about notifications
    if ([self.delegate respondsToSelector:@selector(iNotifyDidDetectNotifications:)])
    {
        [self.delegate iNotifyDidDetectNotifications:self.notificationsDict];
    }  
    
    //get next notification
    NSString *notificationKey = [self nextNotificationInDict:self.notificationsDict];
    if (notificationKey)
    {
        //get notification data
        NSDictionary *notification = [self.notificationsDict objectForKey:notificationKey];
        
        //get notification details
        NSString *title = [notification objectForKey:iNotifyTitleKey];
        NSString *message = [notification objectForKey:iNotifyMessageKey];
        NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
        NSString *actionButtonLabel = [notification objectForKey:iNotifyActionButtonKey] ?: self.defaultActionButtonLabel;
        
        //check action url can be opened
        if (actionURL && ![self canOpenURL:[NSURL URLWithString:actionURL]])
        {
            return;
        }
        
        //check delegate
        if ([self.delegate respondsToSelector:@selector(iNotifyShouldDisplayNotificationWithKey:details:)])
        {
            if (![self.delegate iNotifyShouldDisplayNotificationWithKey:notificationKey details:notification])
            {
                return;
            }
        }
        
        if (!self.visibleAlert)
        {
            
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
        
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
            if (actionURL)
            {
                [alert addButtonWithTitle:actionButtonLabel];
                [alert addButtonWithTitle:self.remindButtonLabel];
                [alert addButtonWithTitle:self.ignoreButtonLabel];
                alert.cancelButtonIndex = 2;
            }
            else
            {
                [alert addButtonWithTitle:self.okButtonLabel];
                alert.cancelButtonIndex = 0;
            }
            
            self.visibleAlert = alert;
            [self.visibleAlert show];
            [alert release];
            
#else
            
            if (actionURL)
            {
                self.visibleAlert = [NSAlert alertWithMessageText:title
                                                    defaultButton:actionButtonLabel
                                                  alternateButton:self.ignoreButtonLabel
                                                      otherButton:self.remindButtonLabel
                                        informativeTextWithFormat:@"%@", message];
            }
            else
            {
                self.visibleAlert = [NSAlert alertWithMessageText:title
                                                    defaultButton:self.okButtonLabel
                                                  alternateButton:nil
                                                      otherButton:nil
                                        informativeTextWithFormat:@"%@", message];
            }
            
            [self.visibleAlert beginSheetModalForWindow:[[NSApplication sharedApplication] mainWindow]
                                          modalDelegate:self
                                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                                            contextInfo:nil];
#endif
        }
    }
}

- (BOOL)shouldCheckForNotifications
{
    if (!self.debug)
    {
        if (!self.showOnFirstLaunch && [[NSUserDefaults standardUserDefaults] objectForKey:iNotifyIgnoredNotificationsKey] == nil)
        {
            self.ignoredNotifications = [NSArray array];
            return NO;
        }
        else if (self.lastReminded != nil)
        {
            //reminder takes priority over check period
            if ([[NSDate date] timeIntervalSinceDate:self.lastReminded] < self.remindPeriod * SECONDS_IN_A_DAY)
            {
                return NO;
            }
        }
        else if (self.lastChecked != nil && [[NSDate date] timeIntervalSinceDate:self.lastChecked] < self.checkPeriod * SECONDS_IN_A_DAY)
        {
            return NO;
        }
    }
    if ([self.delegate respondsToSelector:@selector(iNotifyShouldCheckForNotifications)])
    {
        return [self.delegate iNotifyShouldCheckForNotifications];
    }
    return YES;
}

- (void)checkForNotificationsInBackground
{
    @synchronized (self)
    {
        if (self.notificationsPlistURL)
        {
            @autoreleasepool
            {
                NSError *error = nil;
                NSDictionary *notifications = nil;
                NSURLResponse *response = nil;
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.notificationsPlistURL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:REQUEST_TIMEOUT];
                NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
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
    if (!self.currentlyChecking)
    {
        self.currentlyChecking = YES;
        [self performSelectorInBackground:@selector(checkForNotificationsInBackground) withObject:nil];
    }
}

#pragma mark -
#pragma mark UIAlertView methods

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
            
- (BOOL)canOpenURL:(NSURL *)URL
{
    return [[UIApplication sharedApplication] canOpenURL:URL];
}

- (void)resizeAlertView:(UIAlertView *)alertView
{
    if (!self.disableAlertViewResizing && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
    {
        CGFloat max = alertView.window.bounds.size.height - alertView.frame.size.height - 10.0f;
        CGFloat offset = 0.0f;
        for (UIView *view in alertView.subviews)
        {
            CGRect frame = view.frame;
            if ([view isKindOfClass:[UILabel class]])
            {
                UILabel *label = (UILabel *)view;
                if ([label.text isEqualToString:alertView.message])
                {
                    label.alpha = 1.0f;
                    label.lineBreakMode = UILineBreakModeWordWrap;
                    label.numberOfLines = 0;
                    [label sizeToFit];
                    offset = label.frame.size.height - frame.size.height;
                    frame.size.height = label.frame.size.height;
                    if (offset > max)
                    {
                        frame.size.height -= (offset - max);
                        offset = max;
                    }
                    if (offset > max - 10.0f)
                    {
                        frame.size.height -= (offset - max - 10);
                        frame.origin.y += (offset - max - 10) / 2.0f;
                    }
                }
            }
            else if ([view isKindOfClass:[UITextView class]])
            {
                view.alpha = 0.0f;
            }
            else if ([view isKindOfClass:[UIControl class]])
            {
                frame.origin.y += offset;
            }
            view.frame = frame;
        }
        CGRect frame = alertView.frame;
        frame.origin.y -= roundf(offset/2.0f);
        frame.size.height += offset;
        alertView.frame = frame;
    }
}

- (void)didRotate
{
    [self performSelectorOnMainThread:@selector(resizeAlertView:) withObject:self.visibleAlert waitUntilDone:NO];
}

- (void)willPresentAlertView:(UIAlertView *)alertView
{
    [self resizeAlertView:alertView];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    NSString *key = [self nextNotificationInDict:self.notificationsDict];
    NSDictionary *notification = [self.notificationsDict objectForKey:key];
    NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
    
    if (buttonIndex == alertView.cancelButtonIndex)
    {
        //clear reminder
        self.lastReminded = nil;
        
        if (actionURL)
        {            
            //set ignored
            [self setNotificationIgnored:key];
            
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidIgnoreNotificationWithKey:details:)])
            {
                [self.delegate iNotifyUserDidIgnoreNotificationWithKey:key details:notification];
            }
        }
        else
        {
            //no action url to view so treat dismissal as a view
            [self setNotificationViewed:key];
        }
    }
    else if (buttonIndex == 1)
    {
        //remind later
        self.lastReminded = [NSDate date];
        
        //log event
        if ([self.delegate respondsToSelector:@selector(iNotifyUserDidRequestReminderForNotificationWithKey:details:)])
        {
            [self.delegate iNotifyUserDidRequestReminderForNotificationWithKey:key details:notification];
        }
    }
    else
    {
        //set viewed and clear reminder
        [self setNotificationViewed:key];
        self.lastReminded = nil;
        
        //log event
        if ([self.delegate respondsToSelector:@selector(iNotifyUserDidViewActionURLForNotificationWithKey:details:)])
        {
            [self.delegate iNotifyUserDidViewActionURLForNotificationWithKey:key details:notification];
        }
        
        //open URL
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:actionURL]];
    }
    
    //release alert
    self.visibleAlert = nil;
}

#else
            
- (BOOL)canOpenURL:(NSURL *)URL
{
    return [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:URL] != nil;
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    NSString *key = [self nextNotificationInDict:self.notificationsDict];
    NSDictionary *notification = [self.notificationsDict objectForKey:key];
    NSString *actionURL = [notification objectForKey:iNotifyActionURLKey];
    
    switch (returnCode)
    {
        case NSAlertAlternateReturn:
        {            
            //set ignored and clear reminder
            [self setNotificationIgnored:key];
            self.lastReminded = nil;
            
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidIgnoreNotificationWithKey:details:)])
            {
                [self.delegate iNotifyUserDidIgnoreNotificationWithKey:key details:notification];
            }

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
                    [self.delegate iNotifyUserDidViewActionURLForNotificationWithKey:key details:notification];
                }
                
                //open URL
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:actionURL]];
            }
            
            break;
        }
        default:
        {
            //remind later
            self.lastReminded = [NSDate date];
            
            //log event
            if ([self.delegate respondsToSelector:@selector(iNotifyUserDidRequestReminderForNotificationWithKey:details:)])
            {
                [self.delegate iNotifyUserDidRequestReminderForNotificationWithKey:key details:notification];
            }
        }
    }
}

#endif

- (void)applicationLaunched:(NSNotification *)notification
{
    if (self.checkAtLaunch && [self shouldCheckForNotifications])
    {
        [self checkForNotifications];
    }
}

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
    {
        if (self.checkAtLaunch && [self shouldCheckForNotifications])
        {
            [self checkForNotifications];
        }
    }
}

#endif

@end