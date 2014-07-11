//
//  PCBackend.h
//  PunchClock
//
//  Created by Buckley on 7/10/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PCBackend : NSObject

+ (PCBackend *)sharedBackend;

- (void)updateWithStatus:(NSString *)status
					name:(NSString *)username
				 push_id:(NSString *)push_id
			beacon_minor:(NSNumber *)beacon_minor
				success:(void (^)(id responseObject))success
				failure:(void (^)(NSError *error))failure;

- (void)sendMessage:(NSString *)message
	   fromUsername:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure;

- (void)watchUser:(NSString *)name
		 username:(NSString *)username
		  success:(void (^)(id responseObject))success
		  failure:(void (^)(NSError *error))failure;

- (void)unwatchUser:(NSString *)name
		   username:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure;

- (void)fetchPeopleForUsername:(NSString *)username
					   success:(void (^)(id responseObject))success
					   failure:(void (^)(NSError *error))failure;

- (void)setImage:(UIImageView *)imageView
	 forUsername:(NSString *)username
placeholderImage:(UIImage *)placeholderImage
		 failure:(void (^)(NSString *errorMessage))failure;

@end
