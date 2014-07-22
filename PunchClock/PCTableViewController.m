//
//  PCTableViewController.m
//  PunchClock
//
//  Created by Jurre Stender on 22/07/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCTableViewController.h"
#import "UIView+Borders.h"

@interface PCTableViewController ()

@end

@implementation PCTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	UITableViewController *tableViewController = [[UITableViewController alloc] init];
    tableViewController.tableView = self.tableView;

    self.refreshControl = [[UIRefreshControl alloc] init];
	self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self action:@selector(refreshData:) forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;

	[self.topToolbar addBottomBorderWithHeight:0.3f andColor:[UIColor colorWithRed:0.325f green:0.255f blue:0.318f alpha:1.000]];
}

- (void)refreshData:(id)sender
{
	[[NSException exceptionWithName:@"Method not implemented" reason:@"-refreshData: should be implemented in subclass" userInfo:nil] raise];
}

@end
