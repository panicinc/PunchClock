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

NSString *const kStatusRecordType = @"Status";
NSString *const kNameRecordField = @"name";
NSString *const kStatusRecordField = @"status";

NSString *const kWatchRecordType = @"Watch";
NSString *const kWatcherRecordField = @"watcher";
NSString *const kWatchedRecordField = @"watched";

NSString *const kMessageRecordType = @"Message";
NSString *const kFromRecordField = @"from";
NSString *const kMessageRecordField = @"message";

NSString *const kPhotoRecordType = @"Photo";
NSString *const kUsernameRecordField = @"username";
NSString *const kPhotoRecordField = @"photo";

@interface PCCloudKitBackend ()

@property (nonatomic, readwrite, strong) CKContainer *container;
@property (nonatomic, readwrite, strong) CKDatabase *publicDatabase;

@property (nonatomic, readwrite, copy)   NSMutableSet *pendingStatusSubscriptionNames;
@property (nonatomic, readwrite, copy)   NSMutableDictionary *statusSubscriptionIDsByName;
@property (nonatomic, readwrite, copy)   NSString *messageSubscriptionID;

@end

@implementation PCCloudKitBackend

- (id)init
{
	self = [super init];

	if (self) {
		_container = [CKContainer defaultContainer];
		_publicDatabase = [_container publicCloudDatabase];

		_statusSubscriptionIDsByName = [NSMutableDictionary new];

		[self fetchSubscriptions];
	}

	return self;
}

- (void)fetchSubscriptions
{
	CKFetchSubscriptionsOperation *operation = [CKFetchSubscriptionsOperation fetchAllSubscriptionsOperation];

	__weak typeof(self) weakSelf = self;

	operation.fetchSubscriptionCompletionBlock = ^(NSDictionary *subscriptionsByID, NSError *operationError) {
		typeof(self) strongSelf = weakSelf;

		for (NSString *subscriptionID in subscriptionsByID) {
			CKSubscription *subscription = subscriptionsByID[subscriptionID];

			if ([subscription.recordType isEqualToString: kMessageRecordType]) {
				strongSelf.messageSubscriptionID = subscriptionID;
			} else if ([subscription.recordType isEqualToString: kStatusRecordType]) {
				NSString *predicateFormat = [[subscription predicate] predicateFormat];

				NSRegularExpression *regex =
					[NSRegularExpression regularExpressionWithPattern:@"\"([^\"]+)\""
															  options:NSRegularExpressionCaseInsensitive
																error:NULL];

				NSArray *matches = [regex matchesInString:predicateFormat
												  options:0
													range:NSMakeRange(0, [predicateFormat length])];

				for (NSTextCheckingResult *match in matches) {
					if (match.numberOfRanges == 2) {
						NSString *name = [predicateFormat substringWithRange:[match rangeAtIndex:1]];
						strongSelf.statusSubscriptionIDsByName[name] = subscription;
					}
				}
			}
		}
	};

	[self.publicDatabase addOperation:operation];
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
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				success(responseObject);
			});
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

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", kNameRecordField, username];

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
			NSPredicate *messagePredicate = [NSPredicate predicateWithFormat: @"%K != %@", kFromRecordField, username];
			CKSubscriptionOptions options = CKSubscriptionOptionsFiresOnRecordCreation;
			CKSubscription *messageSubscription = [[CKSubscription alloc] initWithRecordType:kMessageRecordType
																				   predicate:messagePredicate
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
	record[kMessageRecordField] = message;

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

	if ([self.pendingStatusSubscriptionNames containsObject:name]) {
		return;
	}

	[self.pendingStatusSubscriptionNames addObject:name];

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

						 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", kNameRecordField, name];

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
														   [strongSelf.pendingStatusSubscriptionNames
															removeObject:name];
														   failure(error);
													   } else {
														   [strongSelf.pendingStatusSubscriptionNames
															removeObject:name];
														   strongSelf.statusSubscriptionIDsByName[name] =
															subscription.subscriptionID;
														   success(@"Operation successful");
													   }
												   }];
	}
					 failure:^(NSError *error) {
						 typeof(self) strongSelf = weakSelf;
						 [strongSelf.pendingStatusSubscriptionNames removeObject:name];
						 failure(error);
					 }];


}

- (void)unwatchUser:(NSString *)name
		   username:(NSString *)username
			success:(void (^)(id responseObject))success
			failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];
	name = [name capitalizedString];

	NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
							  @[[NSPredicate predicateWithFormat:@"%K = %@", kWatcherRecordField, username],
								[NSPredicate predicateWithFormat:@"%K = %@", kWatchedRecordField, name]]];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kWatchRecordType predicate:predicate];
	query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kWatcherRecordField, kWatchedRecordField];

	NSMutableArray *results = [[NSMutableArray alloc] init];

	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		[results addObject:fetchedRecord.recordID];
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

	[self.publicDatabase addOperation:queryOperation];
}

- (void)fetchWatchStatusesForUsername:(NSString *)username
				  andMergeWithResults:(NSDictionary *)results
							  success:(void (^)(id responseObject))success
							  failure:(void (^)(NSError *error))failure
{
	username = [username capitalizedString];

	if ([username length] == 0) {
		return;
	}

	// CloudKit doesn't seem to yet support OR compound predicates,
	// so we have to chain two queries to get both the users you're watching
	// and the users watching you.
	NSPredicate *watcherPredicate = [NSPredicate predicateWithFormat:@"%K = %@", kWatcherRecordField, username];
	NSPredicate *watchedPredicate = [NSPredicate predicateWithFormat:@"%K = %@", kWatchedRecordField, username];

	CKQuery *watcherQuery = [[CKQuery alloc] initWithRecordType:kWatchRecordType predicate:watcherPredicate];
	CKQuery *watchedQuery = [[CKQuery alloc] initWithRecordType:kWatchRecordType predicate:watchedPredicate];

	CKQueryOperation *watcherOperation = [[CKQueryOperation alloc] initWithQuery:watcherQuery];
	CKQueryOperation *watchedOperation = [[CKQueryOperation alloc] initWithQuery:watchedQuery];

	watcherOperation.desiredKeys = @[kWatcherRecordField];
	watchedOperation.desiredKeys = @[kWatchedRecordField];

	[watcherOperation setRecordFetchedBlock:^(CKRecord *watcherRecord) {
		NSMutableDictionary *result = nil;

		if ((result = results[watcherRecord[kWatcherRecordField]])) {
			result[@"watches_requestor"] = @YES;
		}
	}];

	[watchedOperation setRecordFetchedBlock:^(CKRecord *watchedRecord) {
		NSMutableDictionary *result = nil;

		if ((result = results[watchedRecord[kWatchedRecordField]])) {
			result[@"watched_by_requestor"] = @YES;
		}
	}];

	watcherOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			[self.publicDatabase addOperation:watchedOperation];
		}
	};

	watchedOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			failure(error);
		} else {
			success([results allValues]);
		}
	};

	[self.publicDatabase addOperation:watcherOperation];
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

// CloudKit currently doesn't properly download assets uploaded via the
// CloudKit dashboard, so custom images currently do not work.
- (void)setImage:(UIImageView *)imageView
	 forUsername:(NSString *)username
placeholderImage:(UIImage *)placeholderImage
		 failure:(void (^)(NSString *errorMessage))failure
{
	username = [username capitalizedString];

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", kUsernameRecordField, username];

	CKQuery *query = [[CKQuery alloc] initWithRecordType:kPhotoRecordType predicate:predicate];
	query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];

	CKQueryOperation *queryOperation = [[CKQueryOperation alloc] initWithQuery:query];

	queryOperation.desiredKeys = @[kPhotoRecordField];

	__block CKAsset *photoAsset = nil;
	[queryOperation setRecordFetchedBlock:^(CKRecord *fetchedRecord) {
		photoAsset = fetchedRecord[kPhotoRecordField];
	}];

	queryOperation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[imageView setImage:placeholderImage];
			});

			failure([error localizedDescription]);
		} else if (photoAsset != nil) {
			UIImage *image = [UIImage imageWithContentsOfFile:photoAsset.fileURL.path];

			if (image == nil) {
				image = placeholderImage;
			}

			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[imageView setImage:image];
			});
		}
	};

	[self.publicDatabase addOperation:queryOperation];
}

@end

#endif
