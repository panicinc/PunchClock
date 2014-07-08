//
//  PCMessageFormViewController.m
//  PunchClock
//
//  Created by James Moore on 3/25/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCMessageFormViewController.h"
#import <AFNetworking/AFNetworking.h>

@interface PCMessageFormViewController() <UITextFieldDelegate>
@property (strong, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (strong, nonatomic) IBOutlet UITextField *messageTextField;

@end

@implementation PCMessageFormViewController

- (IBAction)sendButtonTapped:(id)sender {
	[self textFieldShouldReturn:self.messageTextField];
}

- (IBAction)cancelButtonTapped:(id)sender {
	[self mz_dismissFormSheetControllerAnimated:YES completionHandler:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{

	NSString *message = textField.text;

	DDLogInfo(@"Sending '%@' to all who are In", message);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"POST"
																	  URLString:[NSString stringWithFormat:@"%@/message/in", PCbaseURL]
																	 parameters:@{@"message": message,
																				  @"name": username}
																		  error:nil];

    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {

		DDLogDebug(@"Response: %@", responseObject);
		[self.messageTextField resignFirstResponder];
		[self mz_dismissFormSheetControllerAnimated:YES completionHandler:nil];

    } failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		DDLogError(@"Status update failed: %@", error.localizedDescription);

		UIAlertView *theAlert = [[UIAlertView alloc] initWithTitle:@"Message send failed. 😭"
														   message:nil
														  delegate:self
												 cancelButtonTitle:@"OK"
												 otherButtonTitles:nil];
		[theAlert show];



    }];

    [operation start];

	return YES;
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self.messageTextField becomeFirstResponder];
}
@end
