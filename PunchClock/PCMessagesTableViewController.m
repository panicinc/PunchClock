//
//  PCMessagesViewController.m
//  PunchClock
//
//  Created by Jurre Stender on 22/07/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCMessagesTableViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/UIImageView+AFNetworking.h>
#import "PCMessageTableViewCell.h"

@interface PCMessagesTableViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *messages;

@end

@implementation PCMessagesTableViewController

static NSString *cellIdentifier = @"MessageTableCell";

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.tableView.dataSource = self;
	self.tableView.delegate = self;

	[self refreshData:self];
}

- (void)refreshData:(id)sender
{
	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"GET"
																	  URLString:[NSString stringWithFormat:@"%@/messages", PCbaseURL]
																	 parameters:@{}
																		  error:nil];


    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {

        self.messages = (NSArray *)responseObject;
		[self.tableView reloadData];
		self.toolbarTitle.text = @"Messages";
		[self.refreshControl endRefreshing];

    } failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		DDLogError(@"Fetching Messages failed: %@", error.localizedDescription);
		[self.refreshControl endRefreshing];
		self.toolbarTitle.text = @"Messages";
    }];

    [operation start];
}

#pragma mark - UITableView Delegate/Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (!self.messages) {
		return 0;
	}
	
	return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	PCMessageTableViewCell *cell = (PCMessageTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];

	NSDictionary *message = self.messages[indexPath.row];

	NSString *username = message[@"person"][@"name"];
	NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
	NSString *imageURL = [NSString stringWithFormat:@"%@/image/%@", PCbaseURL, encodedUsername];
	
	AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
	[serializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];
	NSMutableURLRequest *URLRequest = [serializer requestWithMethod:@"GET" URLString:imageURL parameters:nil error:nil];
	

	[cell.avatarImageView.layer setCornerRadius:cell.avatarImageView.frame.size.width / 2];
	[cell.avatarImageView setClipsToBounds:YES];
	[cell.avatarImageView setImageWithURLRequest:URLRequest
					 placeholderImage:[UIImage imageNamed:@"unknown"]
							  success:nil
							  failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								  DDLogError(@"image fetch failed: %@\n%@", response, error);
								  
							  }];

	cell.nameLabel.text = [username capitalizedString];
	cell.messageTextView.text = message[@"message"];
	cell.dateLabel.text = [self formattedStringFromISO8601String:message[@"date"]];

	return cell;
}

#pragma mark - Private

- (NSString *)formattedStringFromISO8601String:(NSString *)iso8601String
{
	NSDate *date = [[self ISO8601DateFormatter] dateFromString:iso8601String];

	return [[self displayDateFormatter] stringFromDate:date];
}

- (NSDateFormatter *)displayDateFormatter
{
	static NSDateFormatter *_dateFormatter;

	if (!_dateFormatter) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		[_dateFormatter setLocale:[NSLocale currentLocale]];
	}

	return _dateFormatter;
}

- (NSDateFormatter *)ISO8601DateFormatter
{
	static NSDateFormatter *_dateFormatter;

	if (!_dateFormatter) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
	}

	return _dateFormatter;
}

- (NSDate *)dateFromISO8601String:(NSString *)dateString
{
    return [[self ISO8601DateFormatter] dateFromString:dateString];
}

@end
