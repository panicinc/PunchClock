//
//  PCAppDelegate.h
//  PunchClock
//
//  Created by James Moore on 11/25/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

@import UIKit;
#import "PCLocationManager.h"
#import <HockeySDK/HockeySDK.h>
#import <ZeroPush/ZeroPush.h>

@interface PCAppDelegate : UIResponder <UIApplicationDelegate, BITHockeyManagerDelegate, ZeroPushDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) PCLocationManager *locationManager;

@end
