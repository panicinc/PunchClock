//
//  PCStatusTableDataSource.m
//  PunchClock
//
//  Created by James Moore on 12/10/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCStatusTableDataSource.h"
#import "PCStatusLabel.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>

@interface PCStatusTableDataSource()

@property (nonatomic, strong, readonly) NSArray *allPeople;
@property (atomic, strong) NSArray *fetchedPeople;

@property BOOL fetchingPeople;

@end

@implementation PCStatusTableDataSource

static NSString *cellIdentifier = @"StatusTableCell";

- (NSArray *)allPeople
{
	if (self.fetchedPeople == nil) {
		[self fetchPeople];

		return @[];
	} else {
		return [self.fetchedPeople copy];
	}
}

- (void)refreshData
{
	[self fetchPeople];
}

- (void)fetchPeople
{
	if (self.fetchingPeople) {
		return;
	}

	DDLogDebug(@"Polling for statuses");

	self.fetchingPeople = YES;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"GET"
																	  URLString:[NSString stringWithFormat:@"%@/status/list", PCbaseURL]
																	 parameters:@{@"name": username}
																		  error:nil];


    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {

        self.fetchedPeople = (NSArray *)responseObject;

		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"StatusesUpdated" object:self.numberOfPeopleIn]];
		self.fetchingPeople = NO;

    } failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		DDLogError(@"Fetching Statuses failed: %@", error.localizedDescription);
		self.fetchingPeople = NO;

    }];

    [operation start];

}

- (NSNumber *)numberOfPeopleIn
{
	NSPredicate *predicateString = [NSPredicate predicateWithFormat:@"%K == %@", @"status", @"In"];
	NSNumber *c = @([[self.fetchedPeople filteredArrayUsingPredicate:predicateString] count]);

	return c;
}

#pragma mark - UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (!self.allPeople) {
		return 0;
	}

	return self.allPeople.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
	}

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *push_id = [defaults stringForKey:@"push_id"];

	if (self.allPeople.count > 0) {
		NSDictionary *person = self.allPeople[indexPath.row];

		// Image
		NSString *username = [person objectForKey:@"name"];
        NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
		NSString *imageURL = [NSString stringWithFormat:@"%@/image/%@", PCbaseURL, encodedUsername];

		AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
		[serializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];
		NSMutableURLRequest *URLRequest = [serializer requestWithMethod:@"GET" URLString:imageURL parameters:nil error:nil];


		UIImageView *imageView = (UIImageView *)[cell viewWithTag:3];
		[imageView setImageWithURLRequest:URLRequest
						 placeholderImage:[UIImage imageNamed:@"unknown"]
								  success:nil
								  failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
									  DDLogError(@"image fetch failed: %@\n%@", response, error);

								  }];

		// Name label
		NSString *personLabel = [username capitalizedString];
		[(UILabel *)[cell viewWithTag:1] setText:personLabel];

		// Status
		PCStatusLabel *statusLabel = (PCStatusLabel *)[cell viewWithTag:2];
		statusLabel.text = [person objectForKey:@"status"];

		// Notification Bell
		UIButton *bell = (UIButton *)[cell viewWithTag:4];
		NSNumber *watched_by_value = (NSNumber *)[person objectForKey:@"watched_by_requestor"];
		bell.selected = [watched_by_value boolValue];

		if ([push_id isEqualToString:@""]) {
			bell.hidden = YES;
		}

		UIButton *eye = (UIButton *)[cell viewWithTag:5];
		NSNumber *watches_value = (NSNumber *)[person objectForKey:@"watches_requestor"];
		eye.hidden = ![watches_value boolValue];


	}

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

@end
