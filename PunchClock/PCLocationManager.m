//
//  PCLocationManager.m
//  PunchClock
//
//  Created by James Moore on 12/2/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCLocationManager.h"
@import CoreLocation;
@import MapKit;
#import <AFNetworking/AFNetworking.h>

@interface PCLocationManager () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLBeaconRegion *beaconRegion;
@property (nonatomic, strong) CLCircularRegion *officeRegion;
@property (nonatomic, strong) CLLocation *officeLocation;
@property (nonatomic, strong) NSDate *lastExitDate;
@property (nonatomic, strong) NSDate *lastEntryDate;
@property (nonatomic, strong) NSDate *lastNotificationDate;
@property (nonatomic, strong) NSString *beaconDistance;
@property (nonatomic, strong) NSString *officeDistance;
@property (nonatomic, strong) CLBeacon *closestBeacon;
@property (nonatomic, strong) CLLocation *location;

@property BOOL inRange;
@property BOOL nearOffice;

@property (nonatomic) CLLocationDistance officeDistanceValue;

@property (nonatomic, strong, readonly) NSString *locationStatus;

@property BOOL isRanging;
@property (readonly) BOOL canTrackLocation;
@property BOOL trackLocationNotified;
@property BOOL setupCompleted;
@property BOOL geoFenceEnabled;
@property BOOL bluetoothEnabled;

@property (nonatomic, strong) NSTimer *updateTimer;

@end

@implementation PCLocationManager

@synthesize nearOffice = _nearOffice;
@synthesize inRange = _inRange;

+ (PCLocationManager *)sharedLocationManager
{
	static dispatch_once_t onceToken;
	static PCLocationManager *sharedLocationManager = nil;
	dispatch_once(&onceToken, ^{
		sharedLocationManager = [[super alloc] initUniqueInstance];
	});

	return sharedLocationManager;

}

- (PCLocationManager *)initUniqueInstance
{
	self = [super init];

	if (self) {

		self.nearOffice = NO;
		self.inRange =  NO;
		self.trackLocationNotified = NO;
		self.setupCompleted = NO;
		self.beaconDistance = @"?";
		self.officeDistance = @"?";
		self.officeDistanceValue = 1000;
		self.geoFenceEnabled = NO;
		self.closestBeacon = [[CLBeacon alloc] init];

		self.officeLocation = [[CLLocation alloc] initWithLatitude:geoFenceLat longitude:geoFenceLong];

		[self setupManager];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		[defaults addObserver:self forKeyPath:@"username" options:NSKeyValueObservingOptionNew context:NULL];

		self.dispatchGroup = dispatch_group_create();

		[self updateLocationStatusOnTimer];

	}

	return self;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"username"];
}

- (BOOL)canTrackLocation
{

#if TARGET_IPHONE_SIMULATOR
//	return YES;
#endif

	NSString *errorMsg;

	if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
		DDLogError(@"Beacon Tracking Unavailable");
	}

	if (![CLLocationManager locationServicesEnabled]) {
		errorMsg = @"Location Services Unavailable";

	} else {

		if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
			errorMsg = @"GeoFence Monitoring Unavailable";

		} else {

			if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied ||
					[CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
				
				errorMsg = @"Location Tracking Unavailable";
			} else {
				
				// We have the services we need to get started
				
				return YES;
			}
		}
	}

	if (!self.trackLocationNotified) {
		UILocalNotification *notification = [[UILocalNotification alloc] init];
		notification.alertBody = errorMsg;
		[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
		self.trackLocationNotified = YES;
	}

	DDLogError(@"%@", errorMsg);
	self.nearOffice = NO;

	return NO;
}

- (void)setupManager
{

	if (!self.canTrackLocation || self.setupCompleted) {
		return;
	}

	self.lastExitDate = [NSDate dateWithTimeIntervalSince1970:0];
	self.lastEntryDate = [NSDate dateWithTimeIntervalSince1970:0];
	self.lastNotificationDate = [NSDate dateWithTimeIntervalSince1970:0];
	_bluetoothEnabled = YES;

	_locationManager = [CLLocationManager new];
	_locationManager.delegate = self;
	_locationManager.distanceFilter = kCLLocationAccuracyBest;
	_locationManager.activityType = CLActivityTypeAutomotiveNavigation;

	_beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:beaconUUID]
													   identifier:officeBeaconIdentifier];
	_beaconRegion.notifyEntryStateOnDisplay = YES;
	_beaconRegion.notifyOnEntry = YES;
	_beaconRegion.notifyOnExit = YES;

	[_locationManager stopMonitoringForRegion:_beaconRegion];
	[_locationManager startMonitoringForRegion:_beaconRegion];
	[_locationManager requestStateForRegion:_beaconRegion];

	self.officeRegion = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(geoFenceLat, geoFenceLong)
														  radius:geoFenceRadius
													  identifier:officeIdentifier];


	[_locationManager startUpdatingLocation];

	self.setupCompleted = YES;

	[self startRanging];
	[self enableGeoFence];

}

#pragma mark - KVO

+ (NSSet *)keyPathsForValuesAffectingLocationStatus
{
	return [NSSet setWithObjects:@"inRange", @"nearOffice", @"officeDistanceValue", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"username"]) {
		[self updateLocationStatusOnTimer];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

}

#pragma mark - properties

- (NSString *)locationStatus
{
	if (self.inRange) {
		return  @"In";
	} else if (self.nearOffice) {
		if (self.officeDistanceValue <= 30) {
			return @"In";
		} else {
			return @"Near";
		}
	} else {
		return @"Out";
	}
}

- (void)updateLocationStatusOnTimer
{
	if (self.updateTimer.isValid) {
		// The timer is already running.
		[self.updateTimer invalidate];
		DDLogVerbose(@"status update timer reset");
	}
	self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
														target:self
													  selector:@selector(updateLocationStatus)
													  userInfo:nil
													   repeats:NO];
}

- (BOOL)updateLocationStatusIfNeeded
{
	NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.lastNotificationDate];

	if (interval > 60) {
		dispatch_queue_t queue = dispatch_queue_create("com.panic.punchclock.updateLocation", NULL);
		dispatch_async(queue, ^{
			[self updateLocationStatus];
		});

		return YES;
	} else {

		return NO;
	}
}

- (void)updateLocationStatus
{
	[self updateWithStatus:self.locationStatus withBeacon:self.closestBeacon];
}

- (void)updateWithStatus:(NSString *)status withBeacon:(CLBeacon *)beacon
{
	dispatch_group_enter(self.dispatchGroup);

	BOOL isInBackground = NO;
	isInBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];
	NSString *push_id = [defaults stringForKey:@"push_id"];

	if ([username isEqualToString:@""]) {
		DDLogError(@"missing username, doing nothing");
		return;
	}

	DDLogInfo(@"Sending update for %@:%@ in background:%i.", username, status, isInBackground);

	AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:PCbaseURL]];
	[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:backendUsername password:backendPassword];

	NSNumber *beacon_minor = beacon.minor;

	if (!beacon_minor) {
		beacon_minor = @0;
	}

	NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"POST"
																	  URLString:[NSString stringWithFormat:@"%@/status/update", PCbaseURL]
																	 parameters:@{@"status": status,
																				  @"name": username,
																				  @"push_id": push_id,
																				  @"beacon_minor": beacon_minor}
																		  error:nil];
	request.timeoutInterval = 5;

    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *requestOperation, id responseObject) {

		DDLogDebug(@"Response: %@", responseObject);
		NSNumber *status_changed = responseObject[@"status_changed"];

		if (!isInBackground && status_changed.boolValue) {
			NSNotification *n = [NSNotification notificationWithName:@"StatusUpdated" object:nil];
			[[NSNotificationCenter defaultCenter] postNotification:n];
		}
		self.lastNotificationDate = [NSDate date];

		dispatch_group_leave(self.dispatchGroup);

    } failure:^(AFHTTPRequestOperation *requestOperation, NSError *error) {
		DDLogError(@"Status update failed: %@", error.localizedDescription);
		dispatch_group_leave(self.dispatchGroup);

    }];

	[operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:^{
		// Handle iOS shutting you down (possibly make a note of where you
		// stopped so you can resume later)
	}];

    [operation start];
	
}

#pragma mark - App State

- (void)enterBackground
{
	DDLogDebug(@"Entering Background");
	[self stopRanging];
	[self.locationManager stopUpdatingLocation];
	[self.locationManager startMonitoringSignificantLocationChanges];
}

- (void)enterForeground
{

	if (!self.setupCompleted) {
		return;
	}

	DDLogDebug(@"Entering Foreground");

	[self.locationManager startUpdatingLocation];
	[self.locationManager stopMonitoringSignificantLocationChanges];

	[self startRanging];
	[self.locationManager requestStateForRegion:self.officeRegion];
	[self.locationManager requestStateForRegion:self.beaconRegion];
	[self updateLocationStatusOnTimer];

}

#pragma mark - GeoFencing

- (void)enableGeoFence
{
	if (!self.geoFenceEnabled && self.canTrackLocation && self.setupCompleted) {

		DDLogInfo(@"Enabling GeoFence");
		[self.locationManager startMonitoringForRegion:self.officeRegion];
		[self.locationManager requestStateForRegion:self.officeRegion];
		self.geoFenceEnabled = YES;
	}
}

- (void)disableGeoFence
{
	DDLogInfo(@"Disabling GeoFence");
	[self.locationManager stopMonitoringForRegion:self.officeRegion];
	self.geoFenceEnabled = NO;
}

- (void)setNearOffice:(BOOL)near
{

	if (_nearOffice == near) {
		return;
	}

	[self willChangeValueForKey:@"nearOffice"];

	if (near) {
		DDLogInfo(@"Near Office");

		if (!_nearOffice) {
			self.lastEntryDate = [NSDate date];
			[self startRanging];
		}

	} else {
		DDLogInfo(@"Not Near Office");

	}

	_nearOffice = near;

	[self updateLocationStatusOnTimer];

	[self didChangeValueForKey:@"nearOffice"];
}

- (BOOL)nearOffice
{
	return _nearOffice;
}

+ (BOOL)automaticallyNotifiesObserversOfNearOffice
{
	return NO;
}

#pragma mark - Beacons

- (void)startRanging
{
	if (!self.bluetoothEnabled) {
		return;
	}

	DDLogInfo(@"Start Ranging");
	
	[self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
	self.isRanging = YES;
}

- (void)stopRanging
{
	DDLogInfo(@"Stop Ranging");
	[self.locationManager stopRangingBeaconsInRegion:self.beaconRegion];
	self.isRanging = NO;
	self.closestBeacon = nil;
}

- (void)setInRange:(BOOL)inRange
{
	if (_inRange == inRange) {
		return;
	}

	[self willChangeValueForKey:@"inRange"];

	if (inRange) {

		DDLogInfo(@"Found Beacon");

	} else {
		DDLogInfo(@"Lost Beacon");
		self.closestBeacon = nil;
		[self.locationManager requestStateForRegion:self.officeRegion];

		self.lastExitDate = [NSDate date];

	}

	_inRange = inRange;

	[self updateLocationStatusOnTimer];

	[self didChangeValueForKey:@"inRange"];
}

- (BOOL)inRange
{
	return _inRange;
}

+ (BOOL)automaticallyNotifiesObserversOfInRange
{
	return NO;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{

	self.location = [locations lastObject];
	NSDate *eventDate = self.location.timestamp;
	NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];

	if (howRecent < 15.0) {

		self.officeDistanceValue = [self.officeLocation distanceFromLocation:self.location];

		MKDistanceFormatter *formatter = [[MKDistanceFormatter alloc] init];
		formatter.units = MKDistanceFormatterUnitsImperial;
		self.officeDistance = [formatter stringFromDistance:self.officeDistanceValue];

		DDLogVerbose(@"Distance from office %f", self.officeDistanceValue);

		if ([self.officeRegion containsCoordinate:self.location.coordinate]) {
			self.nearOffice = YES;
		} else {
			self.nearOffice = NO;
		}

	}
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{

	self.bluetoothEnabled = YES;

	if (beacons.count == 0) {
		self.inRange = NO;
		return;
	}

	DDLogVerbose(@"%ld Beacons found", (long) beacons.count);

	NSInteger strongestSignal = -100;

	for (CLBeacon *beacon in beacons) {

		if (beacon.rssi > strongestSignal && beacon.rssi != 0) {
			self.closestBeacon = beacon;
		}
		DDLogVerbose(@"Ranging Beacon #%@ Region: %@ Distance: %@ Signal: %ld", beacon.minor, region.identifier, self.beaconDistance, (long) beacon.rssi);

	}

	if (self.closestBeacon.proximity == CLProximityUnknown) {
		self.beaconDistance = @"?";
	} else if (self.closestBeacon.proximity == CLProximityImmediate) {
		self.beaconDistance = @"Immediate";
	} else if (self.closestBeacon.proximity == CLProximityNear) {
		self.beaconDistance = @"Near";
	} else if (self.closestBeacon.proximity == CLProximityFar) {
		self.beaconDistance = @"Far";
	}

	DDLogVerbose(@"Closest Beacon #%@ Distance: %@ Signal: %ld", self.closestBeacon.minor, self.beaconDistance, (long) self.closestBeacon.rssi);
	self.inRange = YES;

}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
	DDLogError(@"Monitoring Failed for Region: %@. Reason: %@", region.identifier, error.localizedDescription);

}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
	self.bluetoothEnabled = NO;
	DDLogError(@"Monitoring Beacon Failed for Region: %@. Reason: %@", region.identifier, error.localizedDescription);
	[self.locationManager stopRangingBeaconsInRegion:self.beaconRegion];
	self.inRange = NO;
	[self stopRanging];

}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
	DDLogVerbose(@"<---- %@", region.identifier);

	if ([region.identifier isEqualToString:officeIdentifier]) {
		self.nearOffice = YES;
	} else {
		self.bluetoothEnabled = YES;

		self.inRange = YES;
	}
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
	DDLogVerbose(@"<---- %@", region.identifier);

	if ([region.identifier isEqualToString:officeIdentifier]) {
		self.nearOffice = NO;
	} else {
		self.inRange = NO;
	}
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
	DDLogVerbose(@"<---- %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	self.trackLocationNotified = NO;
	[self setupManager];
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
	// A user can transition in or out of a region while the application is not running.
	// When this happens CoreLocation will launch the application momentarily and call this delegate method

	DDLogVerbose(@"<---- %@", region.identifier);

	if ([region.identifier isEqualToString:officeBeaconIdentifier]) {

		if (state == CLRegionStateInside) {
			self.inRange = YES;
		} else if (state == CLRegionStateOutside) {
			self.inRange = NO;
		}

	} else if ([region.identifier isEqualToString:officeIdentifier]) {

		if (state == CLRegionStateInside) {
			self.nearOffice = YES;
		} else if (state == CLRegionStateOutside) {
			self.nearOffice = NO;
		}
	}

}

@end
