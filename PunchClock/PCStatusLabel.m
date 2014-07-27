//
//  PCStatusLabel.m
//  PunchClock
//
//  Created by James Moore on 1/3/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCStatusLabel.h"
@import QuartzCore;

@implementation PCStatusLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
    }

    return self;
}

- (void)setText:(NSString *)text
{
	if ([text isEqualToString:@"In"]) {
		[super setText:NSLocalizedString(@"In", @"Label used to indicate that a person is in the office")];
		self.backgroundColor = [UIColor colorWithRed:(39.0f / 255.0f) green:(193.0f / 255.0f) blue:(31.0f / 255.0f) alpha:1.0];

	} else if ([text isEqualToString:@"Out"]) {
		[super setText:NSLocalizedString(@"Out", @"Label used to indicate that a person is out of the office")];
		self.backgroundColor = [UIColor colorWithRed:252.0f / 255.0f green:67.0f / 255.0f blue:73.0f / 255.0f alpha:1.0];

	} else if ([text isEqualToString:@"Near"]) {
		[super setText:NSLocalizedString(@"Near", @"Label used to indicate that a person is near the office")];
		self.backgroundColor = [UIColor colorWithRed:242.0f / 255.0f green:126.0f / 255.0f blue:24.0f / 255.0f alpha:1.0];

	} else {
		[super setText:text];
		self.backgroundColor = [UIColor whiteColor];
	}
	self.layer.cornerRadius = 2.0;

}

@end
