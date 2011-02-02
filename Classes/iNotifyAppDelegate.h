//
//  iNotifyAppDelegate.h
//  iNotify
//
//  Created by Nick Lockwood on 26/01/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iNotifyViewController;

@interface iNotifyAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    iNotifyViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet iNotifyViewController *viewController;

@end

