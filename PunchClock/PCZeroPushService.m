//
//  PCZeroPushService.m
//  PunchClock
//
//  Created by Buckley on 7/11/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCZeroPushService.h"

@implementation PCZeroPushService

- (NSString *)registerDeviceToken:(NSData *)tokenData
{
	[[ZeroPush shared] registerDeviceToken:tokenData];

	return [ZeroPush deviceTokenFromData:tokenData];
}

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types
{
#ifdef CONFIGURATION_Debug
	[ZeroPush engageWithAPIKey:zeroPushDevKey delegate:self];
#else
	[ZeroPush engageWithAPIKey:zeroPushProdKey delegate:self];
#endif

	[[ZeroPush shared] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert |
														   UIRemoteNotificationTypeBadge |
														   UIRemoteNotificationTypeSound)];
}

@end
