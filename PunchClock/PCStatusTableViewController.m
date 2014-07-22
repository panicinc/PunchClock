//
//  PCStatusTableViewController.m
//  PunchClock
//
//  Created by James Moore on 12/11/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCStatusTableViewController.h"
#import "PCStatusTableDataSource.h"
#import <AFNetworking/AFNetworking.h>
#import <MZFormSheetController/MZFormSheetController.h>
#import <MZFormSheetController/MZFormSheetSegue.h>
#import "PCMessageFormViewController.h"
#import "UIView+Borders.h"

@interface PCStatusTableViewController () <MZFormSheetBackgroundWindowDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) IBOutlet UIButton *messageButton;
@property (strong, nonatomic) IBOutlet UIView *topToolbar;
@property (strong, nonatomic) IBOutlet UILabel *toolbarTitle;

@end

@implementation PCStatusTableViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"messageFormSegue"]) {
        MZFormSheetSegue *formSheetSegue = (MZFormSheetSegue *)segue;
        MZFormSheetController *formSheet = formSheetSegue.formSheetController;
        formSheet.transitionStyle = MZFormSheetTransitionStyleBounce;
        formSheet.cornerRadius = 8.0;
		formSheet.presentedFormSheetSize = CGSizeMake(284.0, 200.0);
		
        formSheet.didTapOnBackgroundViewCompletionHandler = ^(CGPoint location) {
			// Just dismiss it
        };

        formSheet.shouldDismissOnBackgroundViewTap = YES;

        formSheet.didPresentCompletionHandler = ^(UIViewController *presentedFSViewController) {

        };
    }
}

- (void)refreshData:(id)sender
{
	DDLogDebug(@"Refreshing");
	[(PCStatusTableDataSource *) [self.tableView dataSource] refreshData];
}

- (void)refreshCompleted:(NSNotification *)notification
{
	DDLogDebug(@"Refresh completed");

	NSNumber *count = (NSNumber *)notification.object;

	[self.refreshControl endRefreshing];
	[self.tableView reloadData];
//	self.tabBarItem.badgeValue = [count stringValue];

	self.toolbarTitle.text = [NSString stringWithFormat:@"%@ People", count];

	self.messageButton.enabled = ([count compare:@0] == NSOrderedDescending);

	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

}

- (IBAction)watchButtonTapped:(UIButton *)sender
{
	// Get the name from the label in the same row
	CGPoint hitPoint = [sender convertPoint:CGPointZero toView:self.tableView];
	NSIndexPath *hitIndex = [self.tableView indexPathForRowAtPoint:hitPoint];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:hitIndex];
	UILabel *nameLabel = (UILabel *)[cell viewWithTag:1];
	NSString *name = nameLabel.text;

	// Send the command
	NSString *action = sender.selected ? @"unwatch" : @"watch";

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

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

        NSDictionary *response = (NSDictionary *)responseObject;
		DDLogDebug(@"Watch update response: %@", response);

		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"StatusUpdated" object:nil]];

    } failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		DDLogError(@"Watch update failed: %@", error.localizedDescription);
		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"StatusUpdated" object:nil]];

    }];

    [operation start];


}

- (void)viewDidLoad
{
  [super viewDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshData:)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshData:)
												 name:@"StatusUpdated"
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(refreshCompleted:)
												 name:@"StatusesUpdated"
											   object:nil];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

	if ([username isEqualToString:@""]) {
		[self performSegueWithIdentifier:@"missingNameStatus" sender:self];
	}

	UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;

    self.refreshControl = [[UIRefreshControl alloc] init];
	self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(refreshData:) forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;

	[[MZFormSheetBackgroundWindow appearance] setBackgroundBlurEffect:YES];
    [[MZFormSheetBackgroundWindow appearance] setBlurRadius:5.0];
    [[MZFormSheetBackgroundWindow appearance] setBackgroundColor:[UIColor clearColor]];


	[self.topToolbar addBottomBorderWithHeight:0.3f andColor:[UIColor colorWithRed:0.325f green:0.255f blue:0.318f alpha:1.000]];

}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
