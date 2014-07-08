//
//  PCStatusTableDataSource.h
//  PunchClock
//
//  Created by James Moore on 12/10/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

@import Foundation;

@interface PCStatusTableDataSource : NSObject <UITableViewDataSource>

- (void)refreshData;
@property (nonatomic, strong, readonly) NSNumber *numberOfPeopleIn;
@end
