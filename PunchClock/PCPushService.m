//
//  PCPushService.m
//  PunchClock
//
//  Created by Buckley on 7/11/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCPushService.h"

@implementation PCPushService

+ (id<PCPushService>)sharedPushService
{
	static dispatch_once_t onceToken;
	static NSObject<PCPushService> *sharedPushService = nil;
	dispatch_once(&onceToken, ^{
		Class cls = NSClassFromString(pushServiceClass);
		NSAssert(cls != nil, @"No such push service class found: %@", pushServiceClass);

		if (cls != nil) {
			sharedPushService = [[cls alloc] init];
			NSAssert([sharedPushService conformsToProtocol: @protocol(PCPushService)],
					 @"Push service class %@ does not conform to PCPushService protocol", pushServiceClass);
		}
	});

	return sharedPushService;
}

@end
