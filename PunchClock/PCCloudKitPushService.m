//
//  PCCloudKitPushService.m
//  PunchClock
//
//  Created by Buckley on 7/12/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#ifdef __IPHONE_8_0

#import "PCCloudKitPushService.h"
#import <CloudKit/CloudKit.h>

@implementation PCCloudKitPushService

- (NSString *)registerDeviceToken:(NSData *)tokenData
{
	return @"CloudKit";
}

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types
{
	[[UIApplication sharedApplication] registerUserNotificationSettings:
	 [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType) types categories:nil]];

	[[UIApplication sharedApplication] registerForRemoteNotifications];
}

@end

#endif
