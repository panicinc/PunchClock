//
//  PCMessageFormViewController.m
//  PunchClock
//
//  Created by James Moore on 3/25/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCBackend.h"
#import "PCMessageFormViewController.h"

@interface PCMessageFormViewController() <UITextFieldDelegate>
@property (strong, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (strong, nonatomic) IBOutlet UITextField *messageTextField;

@end

@implementation PCMessageFormViewController

- (IBAction)sendButtonTapped:(id)sender
{
	[self textFieldShouldReturn:self.messageTextField];
}

- (IBAction)cancelButtonTapped:(id)sender
{
	[self mz_dismissFormSheetControllerAnimated:YES completionHandler:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self setSendButtonEnabled:NO];
	NSString *message = textField.text;

	DDLogInfo(@"Sending '%@' to all who are In", message);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

	id<PCBackend> backend = [PCBackend sharedBackend];
	[backend sendMessage:message
			fromUsername:username
				 success:^(id responseObject) {
					 DDLogDebug(@"Response: %@", responseObject);
					 [self.messageTextField resignFirstResponder];
					 [self mz_dismissFormSheetControllerAnimated:YES completionHandler:nil];
				 }
				 failure:^(NSError *error) {
					 DDLogError(@"Status update failed: %@", error.localizedDescription);

					 UIAlertView *theAlert = [[UIAlertView alloc] initWithTitle:@"Message send failed. 😭"
																		message:nil
																	   delegate:self
															  cancelButtonTitle:@"OK"
															  otherButtonTitles:nil];
					 [theAlert show];
				 }];

	return YES;

}

- (void)setSendButtonEnabled:(BOOL)enabled
{
	self.sendButton.enabled = enabled;
	self.sendButton.title = enabled ? @"Send" : @"Sending..";
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self.messageTextField becomeFirstResponder];
}

@end
