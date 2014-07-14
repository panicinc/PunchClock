//
//  PCCloudKitBackend.m
//  PunchClock
//
//  Created by Buckley on 7/12/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#ifdef __IPHONE_8_0

#import "PCCloudKitBackend.h"
#import <CloudKit/CloudKit.h>

NSString *const kPhotoRecordField = @"photo";

NSString *const kStatusRecordType = @"Status";
NSString *const kNameRecordField = @"name";
NSString *const kStatusRecordField = @"status";

NSString *const kWatchRecordType = @"Watch";
NSString *const kWatcherRecordField = @"watcher";
NSString *const kWatchedRecordField = @"watched";

NSString *const kMessageRecordType = @"Message";
NSString *const kFromRecordField = @"from";
NSString *const kMessageRecordField = @"message";

@interface PCCloudKitBackend ()

@property (nonatomic, readwrite, strong) CKContainer *container;
@property (nonatomic, readwrite, strong) CKDatabase *publicDatabase;

@property (nonatomic, readwrite, strong) NSMutableDictionary *statusSubscriptionIDsByName;
@property (nonatomic, readwrite, strong) NSString *messageSubscriptionID;

@end

@implementation PCCloudKitBackend

- (id)init
{
	self = [super init];

	if (self) {
		_container = [CKContainer defaultContainer];
		_publicDatabase = [_container publicCloudDatabase];

		_statusSubscriptionIDsByName = [NSMutableDictionary new];
	}

	return self;
}

- (void)addOrUpdateRecords:(NSArray *)recordsToSave
			 deleteRecords:(NSArray *)recordsToDelete
			responseObject:(id)responseObject
				   success:(void (^)(id responseObject))success
				   failure:(void (^)(NSError *error))failure
{
	CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:recordsToSave
																				recordIDsToDelete:recordsToDelete];
	operation.savePolicy = CKRecordSaveChangedKeys;
	operation.modifyRecordsCompletionBlock = ^(NSArray *savedRecords, NSArray *deletedRecordIDs, NSError *error) {
		if (error != nil) {
			failure(error);
		} else {
			success(responseObject);
		}
	};

	[self.publicDatabase addOperation:operation];
}

- (void)updateWithStatus:(NSString *)status
					name:(NSString *)username
				 push_id:(NSString *)push_id
			beacon_minor:(NSNumber *)beacon_minor
				 success:(void (^)(id responseObject))success
				 failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];

	__block CKRecord *record = nil;

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"@% = @%", kNameRecordField, username];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kStatusRecordType predicate:predicate];
	query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kNameRecordField, kStatusRecordField];

	NSMutableArray *results = [[NSMutableArray alloc] init];

	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		[results addObject:fetchedRecord];
	}];

	__weak typeof(self) weakSelf = self;
	void (^subscribeToMessages)(id responseObject) = ^(id responseObject) {
		typeof(self) strongSelf = weakSelf;

		if (strongSelf.messageSubscriptionID == nil) {
			NSPredicate *truePredicate = [NSPredicate predicateWithValue:YES];
			CKSubscriptionOptions options = CKSubscriptionOptionsFiresOnRecordCreation;
			CKSubscription *messageSubscription = [[CKSubscription alloc] initWithRecordType:kMessageRecordType
																				   predicate:truePredicate
																					options:options];


			CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
			notification.alertLocalizationKey = @"MessageNotification";
			notification.alertLocalizationArgs = @[kFromRecordField, kMessageRecordField];
			notification.soundName = @"message";
			messageSubscription.notificationInfo = notification;

			[strongSelf.publicDatabase saveSubscription:messageSubscription
									  completionHandler:^(CKSubscription *subscription, NSError *error) {
										  if (error) {
											  failure(error);
										  } else {
											  strongSelf.messageSubscriptionID = subscription.subscriptionID;
											  success(responseObject);
										  }
									  }];
		}
	};

	void (^unsubscribeFromMessage)(id responseObject) = ^(id responseObject) {
		typeof(self) strongSelf = weakSelf;

		if (strongSelf.messageSubscriptionID != nil) {
			[strongSelf.publicDatabase deleteSubscriptionWithID:strongSelf.messageSubscriptionID
											  completionHandler:^(NSString *subscriptionID, NSError *error) {
												  if (error) {
													  failure(error);
												  } else {
													  strongSelf.messageSubscriptionID = nil;
													  success(responseObject);
												  }
											  }];
	}
	};

	queryOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			BOOL statusChanged = NO;
			BOOL shouldSubscribeToMessages = [status isEqualToString:@"In"];

			if ([results count] > 0) {
				record = results[0];
			} else {
				record = [[CKRecord alloc] initWithRecordType:kStatusRecordType];

				statusChanged = [status isEqualToString:record[kStatusRecordField]];

				record[kNameRecordField] = username;
			}

			record[kStatusRecordField] = status;

			[self addOrUpdateRecords:@[record]
					   deleteRecords:nil
					  responseObject:@{@"status_changed" : @(statusChanged)}
							 success:^(id responseObject) {
								 if (shouldSubscribeToMessages) {
									 subscribeToMessages(responseObject);
								 } else {
									 unsubscribeFromMessage(responseObject);
								 }
							 }
							 failure:failure];
		}
	};

	[self.publicDatabase addOperation:queryOperation];
}

- (void)sendMessage:(NSString *)message
	   fromUsername:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];

	CKRecord *record = [[CKRecord alloc] initWithRecordType:kMessageRecordType];
	record[kFromRecordField] = username;
	record[kMessageRecordField] = username;

	[self addOrUpdateRecords:@[record]
			   deleteRecords:nil
			  responseObject:@"Operation Successful"
					 success:success
					 failure:failure];
}

- (void)watchUser:(NSString *)name
		 username:(NSString *)username
		  success:(void (^)(id responseObject))success
		  failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];
	name = [name capitalizedString];

	CKRecord *record = [[CKRecord alloc] initWithRecordType:kWatchRecordType];
	record[kWatcherRecordField] = username;
	record[kWatchedRecordField] = name;

	__weak typeof(self) weakSelf = self;
	[self addOrUpdateRecords:@[record]
			   deleteRecords:nil
			  responseObject:@{@"Status" : @1}
					 success:^(id responseObject) {
						 typeof(self) strongSelf = weakSelf;

						 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ = @%", kNameRecordField, name];

						 CKSubscriptionOptions options = CKSubscriptionOptionsFiresOnRecordCreation |
							CKSubscriptionOptionsFiresOnRecordUpdate;
						 CKSubscription *watchSubscription =
							[[CKSubscription alloc] initWithRecordType:kStatusRecordType
															 predicate:predicate
															   options:options];


						 CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
						 notification.alertLocalizationKey = @"StatusChangeNotification";
						 notification.alertLocalizationArgs = @[kNameRecordField, kStatusRecordField];
						 notification.soundName = @"status";
						 watchSubscription.notificationInfo = notification;

						 [strongSelf.publicDatabase saveSubscription:watchSubscription
												   completionHandler:^(CKSubscription *subscription, NSError *error) {
													   if (error) {
														   failure(error);
													   } else {
														   strongSelf.statusSubscriptionIDsByName[name] =
															subscription.subscriptionID;
														   success(@"Operation successful");
													   }
												   }];
	}
					 failure:failure];


}

- (void)unwatchUser:(NSString *)name
		   username:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];
	name = [name capitalizedString];

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ = @% AND @% = @%",
							  kWatcherRecordField,
							  username,
							  kWatchedRecordField,
							  name];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kWatchRecordType predicate:predicate];
	query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kWatcherRecordField, kWatchedRecordField];

	NSMutableArray *results = [[NSMutableArray alloc] init];

	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		[results addObject:fetchedRecord];
	}];

	__weak typeof(self) weakSelf = self;
	void (^deleteSubscription)(id responseObject) = ^(id responseObject)
	{
		typeof(self) strongSelf = weakSelf;
		[strongSelf.publicDatabase deleteSubscriptionWithID:strongSelf.statusSubscriptionIDsByName[name]
										  completionHandler:^(NSString *subscriptionID,
															  NSError *deleteError) {
											  if (deleteError) {
												  failure(deleteError);
											  } else {
												  [strongSelf.statusSubscriptionIDsByName removeObjectForKey:
												   subscriptionID];
												  success(@"Operation successful");
											  }
										  }];
	};

	queryOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			[self addOrUpdateRecords:nil
					   deleteRecords:results
					  responseObject:@"Operation Successful"
							 success:deleteSubscription
							 failure:failure];
		}
	};
}

- (void)fetchWatchStatusesForUsername:(NSString *)username
				  andMergeWithResults:(NSDictionary *)results
							  success:(void (^)(id responseObject))success
							  failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"@% = @% OR @% = @%",
							  kWatcherRecordField,
							  username,
							  kWatchedRecordField,
							  username];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kStatusRecordType predicate:predicate];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kWatcherRecordField, kWatchedRecordField];

	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		NSMutableDictionary *result = nil;

		if ((result = results[fetchedRecord[kWatcherRecordField]])) {
			result[@"watches_requestor"] = @YES;
		}

		if ((result = results[fetchedRecord[kWatchedRecordField]])) {
			result[@"watched_by_requestor"] = @YES;
		}
	}];

	queryOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			success(results);
		}
	};
}

- (void)fetchPeopleForUsername:(NSString *)username
					   success:(void (^)(id responseObject))success
					   failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];

	NSPredicate *truePredicate = [NSPredicate predicateWithValue:YES];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kStatusRecordType predicate:truePredicate];
	query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kNameRecordField, kStatusRecordField];

	NSMutableDictionary *results = [[NSMutableDictionary alloc] init];

	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:
										  @{kNameRecordField: fetchedRecord[kNameRecordField],
											kStatusRecordField: fetchedRecord[kStatusRecordField]}];

		results[fetchedRecord[kNameRecordField]] = dictionary;
	}];

	queryOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			[self fetchWatchStatusesForUsername:username
							andMergeWithResults:results
										success:success
										failure:failure];
		}
	};

	[self.publicDatabase addOperation:queryOperation];
}

- (void)setImage:(UIImageView *)imageView
	 forUsername:(NSString *)username
placeholderImage:(UIImage *)placeholderImage
		 failure:(void (^)(NSString *errorMessage))failure
{
	username = [username capitalizedString];

	CKRecordID *current = [[CKRecordID alloc] initWithRecordName:username];
	[self.publicDatabase fetchRecordWithID:current completionHandler:^(CKRecord *record, NSError *error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^(void){
				[imageView setImage:placeholderImage];
			});

			failure([error localizedDescription]);
		} else {
			CKAsset *photoAsset = record[kPhotoRecordField];

			UIImage *image = [UIImage imageWithContentsOfFile:photoAsset.fileURL.path];

			if (image == nil) {
				image = placeholderImage;
			}

			dispatch_async(dispatch_get_main_queue(), ^(void){
				[imageView setImage:image];
			});
		}
	}];
}

@end

#endif
