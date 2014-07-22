//
//  PCMessageTableViewCell.h
//  PunchClock
//
//  Created by Jurre Stender on 22/07/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PCMessageTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UITextView *messageTextView;
@property (nonatomic, strong) IBOutlet UIImageView *avatarImageView;
@property (nonatomic, strong) IBOutlet UILabel *dateLabel;

@end
