//
//  PCStatusTableDataSource.m
//  PunchClock
//
//  Created by James Moore on 12/10/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCBackend.h"
#import "PCStatusTableDataSource.h"
#import "PCStatusLabel.h"

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

	id<PCBackend> backend = [PCBackend sharedBackend];
	[backend fetchPeopleForUsername:username
							success:^(id responseObject) {
								self.fetchedPeople = (NSArray *)responseObject;

								[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"StatusesUpdated" object:self.numberOfPeopleIn]];
								self.fetchingPeople = NO;
							} failure:^(NSError *error) {
								DDLogError(@"Fetching Statuses failed: %@", error.localizedDescription);
								self.fetchingPeople = NO;
								
							}];
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

		UIImageView *imageView = (UIImageView *)[cell viewWithTag:3];

		id<PCBackend> backend = [PCBackend sharedBackend];
		[backend setImage:imageView
			  forUsername:username
		 placeholderImage:[UIImage imageNamed:@"unknown"]
				  failure:^(NSString *errorMessage) {
					  DDLogError(@"image fetch failed: %@", errorMessage);
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
