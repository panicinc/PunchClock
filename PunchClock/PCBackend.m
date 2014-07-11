//
//  PCBackend.m
//  PunchClock
//
//  Created by Buckley on 7/10/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCBackend.h"

@implementation PCBackend

+ (PCBackend *)sharedBackend
{
	static dispatch_once_t onceToken;
	static PCBackend *sharedBackend = nil;
	dispatch_once(&onceToken, ^{
		Class cls = NSClassFromString(backendClass);

		if (cls == nil) {
			cls = self;
		}

		sharedBackend = [[cls alloc] init];
	});

	return sharedBackend;
}

- (NSError *)notImplementedError
{
	return [NSError errorWithDomain:@"com.panic.PunchClock"
							   code:0
						   userInfo:@{NSLocalizedDescriptionKey : @"Attempted to use PCBackend base class"}];
}

- (void)updateWithStatus:(NSString *)status
					name:(NSString *)username
				 push_id:(NSString *)push_id
			beacon_minor:(NSNumber *)beacon_minor
				 success:(void (^)(id responseObject))success
				 failure:(void (^)(NSError *error))failure
{
	failure([self notImplementedError]);
}

- (void)sendMessage:(NSString *)message
	   fromUsername:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	failure([self notImplementedError]);
}

- (void)watchUser:(NSString *)name
		 username:(NSString *)username
		  success:(void (^)(id responseObject))success
		  failure:(void (^)(NSError *error))failure
{
	failure([self notImplementedError]);
}

- (void)unwatchUser:(NSString *)name
		   username:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	failure([self notImplementedError]);
}

- (void)fetchPeopleForUsername:(NSString *)username
					   success:(void (^)(id responseObject))success
					   failure:(void (^)(NSError *error))failure
{
	failure([self notImplementedError]);
}

- (void)setImage:(UIImageView *)imageView
	 forUsername:(NSString *)username
placeholderImage:(UIImage *)placeholderImage
		 failure:(void (^)(NSString *errorMessage))failure
{
	failure([[self notImplementedError] localizedDescription]);
}

@end
