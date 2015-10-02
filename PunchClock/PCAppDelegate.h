//
//  PCAppDelegate.h
//  PunchClock
//
//  Created by James Moore on 11/25/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

@import UIKit;
#import "PCLocationManager.h"
#import <ZeroPush/ZeroPush.h>

@interface PCAppDelegate : UIResponder <UIApplicationDelegate, ZeroPushDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) PCLocationManager *locationManager;

@end
