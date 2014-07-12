//
//  PCBackend.m
//  PunchClock
//
//  Created by Buckley on 7/10/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCBackend.h"

@implementation PCBackend

+ (id<PCBackend>)sharedBackend
{
	static dispatch_once_t onceToken;
	static id<PCBackend> sharedBackend = nil;
	dispatch_once(&onceToken, ^{
		Class cls = NSClassFromString(backendClass);
		NSAssert(cls != nil, @"No such backend class found: %@", backendClass);

		sharedBackend = [[cls alloc] init];
		NSAssert([sharedBackend conformsToProtocol: @protocol(PCBackend)],
				 @"Push backend %@ does not conform to PCBackend protocol", backendClass);
	});

	return sharedBackend;
}

@end
