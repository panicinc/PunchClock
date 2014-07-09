//
//  PCNameViewController.m
//  PunchClock
//
//  Created by James Moore on 3/13/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCNameViewController.h"
@import QuartzCore;

@interface PCNameViewController()
@property (strong, nonatomic) IBOutlet UITextField *nameField;

@end

@implementation PCNameViewController

- (void)viewDidAppear:(BOOL)animated
{
    self.nameField.layer.cornerRadius = 3.0;
    
    self.nameField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    [self.nameField becomeFirstResponder];
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if ([textField.text isEqualToString:@""]) {
        return NO;
    } else {
        return YES;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (![textField.text isEqualToString:@""]) {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [self mz_dismissFormSheetControllerAnimated:YES completionHandler:nil];
    }
}

@end
