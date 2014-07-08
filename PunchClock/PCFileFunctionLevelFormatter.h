//
//  PCFileFunctionLevelFormatter.h
//  PunchClock
//
//  Created by Julien Grimault on 23/1/12.
//  Copyright (c) 2012 Julien Grimault. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PCFileFunctionLevelFormatter : NSObject <DDLogFormatter>
{
    int loggerCount;
    NSDateFormatter *threadUnsafeDateFormatter;
}
@end
