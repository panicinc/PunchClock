//
//  PCZeroPushService.h
//  PunchClock
//
//  Created by Buckley on 7/11/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCPushService.h"
#import <ZeroPush/ZeroPush.h>

@interface PCZeroPushService : NSObject <PCPushService, ZeroPushDelegate>

@end
