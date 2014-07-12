//
//  PCPushService.h
//  PunchClock
//
//  Created by Buckley on 7/11/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PCPushService <NSObject>

@required
- (NSString *)registerDeviceToken:(NSData *)tokenData;
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;

@end

@interface PCPushService : NSObject

+ (id<PCPushService>)sharedPushService;

@end
