//
//  PCHerokuBackend.m
//  PunchClock
//
//  Created by Buckley on 7/10/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCHerokuBackend.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>

@implementation PCHerokuBackend

- (void)updateWithStatus:(NSString *)status
					name:(NSString *)username
				 push_id:(NSString *)push_id
			beacon_minor:(NSNumber *)beacon_minor
				success:(void (^)(id responseObject))success
				failure:(void (^)(NSError *error))failure
{
	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"POST"
																	  URLString:[NSString stringWithFormat:@"%@/status/update", PCbaseURL]
																	 parameters:@{@"status": status,
																				  @"name": username,
																				  @"push_id": push_id,
																				  @"beacon_minor": beacon_minor}
																		  error:nil];
	request.timeoutInterval = 5;

	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];

	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {
		success(responseObject);
	} failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		failure(error);
	}];

	[operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:^{
		// Handle iOS shutting you down (possibly make a note of where you
		// stopped so you can resume later)
	}];

	[operation start];
}

- (void)sendMessage:(NSString *)message
	   fromUsername:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"POST"
																	  URLString:[NSString stringWithFormat:@"%@/message/in", PCbaseURL]
																	 parameters:@{@"message": message,
																				  @"name": username}
																		  error:nil];

	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];

	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {
		success(responseObject);
	} failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		failure(error);
	}];

	[operation start];
}

- (void)performAction:(NSString *)action
			   onUser:(NSString *)name
			 username:(NSString *)username
			  success:(void (^)(id responseObject))success
			  failure:(void (^)(NSError *error))failure
{
	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSString *urlString = [[NSString stringWithFormat:@"%@/%@/%@", PCbaseURL, action, name] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"POST"
																	  URLString:urlString
																	 parameters:@{@"name": username}
																		  error:nil];


	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];

	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {
		success(responseObject);
	} failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		failure(error);
	}];

	[operation start];
}

- (void)watchUser:(NSString *)name
		 username:(NSString *)username
		  success:(void (^)(id responseObject))success
		  failure:(void (^)(NSError *error))failure
{
	[self performAction:@"watch"
				 onUser:name
			   username:username
				success:success
				failure:failure];
}

- (void)unwatchUser:(NSString *)name
		   username:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	[self performAction:@"watch"
				 onUser:name
			   username:username
				success:success
				failure:failure];
}

- (void)fetchPeopleForUsername:(NSString *)username
					   success:(void (^)(id responseObject))success
					   failure:(void (^)(NSError *error))failure
{
	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"GET"
																	  URLString:[NSString stringWithFormat:@"%@/status/list", PCbaseURL]
																	 parameters:@{@"name": username}
																		  error:nil];


	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];

	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {
		success(responseObject);
	} failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		failure(error);
	}];

	[operation start];
}

- (void)setImage:(UIImageView *)imageView
	 forUsername:(NSString *)username
placeholderImage:(UIImage *)placeholderImage
		 failure:(void (^)(NSString *errorMessage))failure
{
	NSString *imageURL = [[NSString stringWithFormat:@"%@/image/%@", PCbaseURL, username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
	[serializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];
	NSMutableURLRequest *URLRequest = [serializer requestWithMethod:@"GET" URLString:imageURL parameters:nil error:nil];


	[imageView.layer setCornerRadius:imageView.frame.size.width / 2];
	[imageView setClipsToBounds:YES];
	[imageView setImageWithURLRequest:URLRequest
					 placeholderImage:[UIImage imageNamed:@"unknown"]
							  success:nil
							  failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								  NSString *errorMessage = [NSString stringWithFormat:@"%@\n%@", response, error];
								  failure(errorMessage);
							  }];
}

@end
