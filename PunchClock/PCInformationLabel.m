//
//  PCInformationLabel.m
//  PunchClock
//
//  Created by Buckley on 7/29/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCInformationLabel.h"

@implementation PCInformationLabel

- (NSString *)accessibilityLabel
{
	if ([self.text isEqualToString: @"?"]) {
		return NSLocalizedString(@"Unknown", nil);
	}

	return self.text;
}

@end
