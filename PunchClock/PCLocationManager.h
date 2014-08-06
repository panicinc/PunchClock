//
//  PCLocationManager.h
//  PunchClock
//
//  Created by James Moore on 12/2/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

@import Foundation;
@import CoreLocation;

@protocol PCLocationManagerDelegate <NSObject>

- (void)updateWithStatus:(NSString *)status withBeacon:(CLBeacon *)beacon;

@end

@interface PCLocationManager : NSObject

+ (PCLocationManager *)sharedLocationManager;
// clue for improper use (produces compile time error)
+ (instancetype)alloc __attribute__((unavailable("alloc not available, call sharedLocationManager instead")));
- (instancetype)init __attribute__((unavailable("init not available, call sharedLocationManager instead")));
+ (instancetype)new __attribute__((unavailable("new not available, call sharedLocationManager instead")));

- (void)stopRanging;
- (void)startRanging;
- (void)enterForeground;
- (void)enterBackground;

- (void)updateLocationStatus;
- (BOOL)updateLocationStatusIfNeeded;


@property dispatch_group_t dispatchGroup;

@property (nonatomic, weak) id <PCLocationManagerDelegate> delegate;

@end
