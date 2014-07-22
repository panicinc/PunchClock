//
//  PCTableViewController.h
//  PunchClock
//
//  Created by Jurre Stender on 22/07/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PCTableViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) IBOutlet UIView *topToolbar;
@property (strong, nonatomic) IBOutlet UILabel *toolbarTitle;

@end
