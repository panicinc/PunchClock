//
//  PCFileFunctionLevelFormatter.m
//  PunchClock
//
//  Created by Julien Grimault on 23/1/12.
//  Copyright (c) 2012 Julien Grimault. All rights reserved.
//

#import "PCFileFunctionLevelFormatter.h"

@implementation PCFileFunctionLevelFormatter

- (id)init
{
    if((self = [super init]))
    {
        threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
        [threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [threadUnsafeDateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
    }
    return self;
}

- (NSString*)formatLogMessage:(DDLogMessage *)logMessage
{
	NSString* logLevel = nil;
	switch (logMessage->logFlag) {
		case LOG_FLAG_ERROR : logLevel = @"E"; break;
		case LOG_FLAG_WARN  : logLevel = @"W"; break;
		case LOG_FLAG_INFO  : logLevel = @"I"; break;
		case LOG_FLAG_DEBUG : logLevel = @"D"; break;
		default             : logLevel = @"V"; break;
	}

	NSString *dateAndTime = [threadUnsafeDateFormatter stringFromDate:(logMessage->timestamp)];

	return [NSString stringWithFormat:@"[%@] %@ [%@ %@:%d] => %@",
			logLevel,
			dateAndTime,
			logMessage.fileName,
			logMessage.methodName,
			logMessage->lineNumber,
			logMessage->logMsg];
}

- (void)didAddToLogger:(id <DDLogger>)logger
{
    loggerCount++;
    NSAssert(loggerCount <= 1, @"This logger isn't thread-safe");
}
- (void)willRemoveFromLogger:(id <DDLogger>)logger
{
    loggerCount--;
}

@end
