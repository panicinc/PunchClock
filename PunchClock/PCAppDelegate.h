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

@interface PCAppDelegate : UIResponder <UIApplicationDelegate, BITHockeyManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) PCLocationManager *locationManager;

@end
