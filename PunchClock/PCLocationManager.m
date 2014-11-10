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
@property (nonatomic, copy) NSString *beaconDistance;
@property (nonatomic, copy) NSString *officeDistance;
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

		_nearOffice = NO;
		_inRange =  NO;
		_trackLocationNotified = NO;
		_setupCompleted = NO;
		_beaconDistance = @"?";
		_officeDistance = @"?";
		_officeDistanceValue = 1000;
		_geoFenceEnabled = NO;
		_closestBeacon = [[CLBeacon alloc] init];

		_officeLocation = [[CLLocation alloc] initWithLatitude:geoFenceLat longitude:geoFenceLong];

		[self setupManager];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		[defaults addObserver:self forKeyPath:@"username" options:NSKeyValueObservingOptionNew context:NULL];

		_dispatchGroup = dispatch_group_create();

		[self updateLocationStatusOnTimer];

	}

	return self;
}

- (void)dealloc
{
	self.locationManager.delegate = nil;
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
		errorMsg = NSLocalizedString(@"Location Services Unavailable", nil);

	} else {

		if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
			errorMsg = NSLocalizedString(@"GeoFence Monitoring Unavailable", nil);

		} else {

			if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied ||
					[CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
				
				errorMsg = NSLocalizedString(@"Location Tracking Unavailable", nil);
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
	if ([self.updateTimer isValid]) {
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
	self.lastNotificationDate = [NSDate date];

	[self.delegate updateWithStatus:self.locationStatus withBeacon:self.closestBeacon];
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
   	
   	if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
	 	[self requestAlwaysAuthorization];
    	}
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
		formatter.units = MKDistanceFormatterUnitsDefault;
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

	if ([beacons count] == 0) {
		self.inRange = NO;
		return;
	}

	DDLogVerbose(@"%ld Beacons found", (long) beacons.count);

	CLLocationAccuracy closestSignal = 100;
	CLBeacon *closestBeacon;

	for (CLBeacon *beacon in beacons) {

		DDLogVerbose(@"Beacon #%@/%@ Distance: %li Signal: %ld: Accuracy: %f", beacon.major, beacon.minor, (long)self.closestBeacon.proximity, (long) beacon.rssi, beacon.accuracy);

		if (beacon.accuracy < closestSignal && beacon.accuracy > 0) {
			closestSignal = beacon.accuracy;
			self.closestBeacon = beacon;
		}

	}

	self.closestBeacon = closestBeacon;

	if (self.closestBeacon.proximity == CLProximityUnknown) {
		self.beaconDistance = @"?";
	} else if (self.closestBeacon.proximity == CLProximityImmediate) {
		self.beaconDistance = NSLocalizedString(@"Immediate", nil);
	} else if (self.closestBeacon.proximity == CLProximityNear) {
		self.beaconDistance = NSLocalizedString(@"Near", nil);
	} else if (self.closestBeacon.proximity == CLProximityFar) {
		self.beaconDistance = NSLocalizedString(@"Far", nil);
	}

	DDLogVerbose(@"Closest Beacon #%@/%@ Distance: %@ Signal: %ld", self.closestBeacon.major, self.closestBeacon.minor, self.beaconDistance, (long) self.closestBeacon.rssi);
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

		switch (state) {
			case CLRegionStateInside:
				self.inRange = YES;

				break;
			case CLRegionStateOutside:
			case CLRegionStateUnknown:
			default:
				self.inRange = NO;
		}


	} else if ([region.identifier isEqualToString:officeIdentifier]) {

		switch (state) {
			case CLRegionStateInside:
				self.nearOffice = YES;

				break;
			case CLRegionStateOutside:
			case CLRegionStateUnknown:
			default:
				self.nearOffice = NO;
		}

	}

}



- (void)requestAlwaysAuthorization
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    // If the status is denied or only granted for when in use, display an alert
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusDenied) {
        NSString *title;
        title = (status == kCLAuthorizationStatusDenied) ? @"Location services are off" : @"Background location is not enabled";
        NSString *message = @"To use background location you must turn on 'Always' in the Location Services Settings";
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                                  otherButtonTitles:@"Settings", nil];
        [alertView show];
    }
    // The user has not enabled any location services. Request background authorization.
    else if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestAlwaysAuthorization];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        // Send the user to the Settings for this app
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:settingsURL];
    }
}


@end
