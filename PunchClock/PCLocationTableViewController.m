//
//  PCViewController.m
//  PunchClock
//
//  Created by James Moore on 11/25/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCLocationTableViewController.h"
#import "PCLocationManager.h"
#import "PCStatusLabel.h"

@interface PCLocationTableViewController ()

@property (strong, nonatomic) IBOutlet UILabel *inOfficeLabel;
@property (strong, nonatomic) IBOutlet UILabel *inRangeLabel;
@property (strong, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *isRangingLabel;
@property (strong, nonatomic) IBOutlet UILabel *lastUpdateLabel;
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *distanceLabel;
@property (strong, nonatomic) IBOutlet PCStatusLabel *locationStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *versionLabel;
@property (strong, nonatomic) PCLocationManager *locationManager;
@property (strong, nonatomic) IBOutlet UILabel *officeDistanceLabel;
@property (strong, nonatomic) IBOutlet UILabel *closestBeaconLabel;
@property (strong, nonatomic) IBOutlet UILabel *beaconSignalStrengthLabel;
@property (strong) CLBeacon *closestBeacon;

@end

@implementation PCLocationTableViewController

- (IBAction)refreshLocation:(id)sender
{

	[self.locationManager updateLocationStatus];
	[[self tableView] reloadData];
	[self.refreshControl endRefreshing];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{

	if (object == self.locationManager) {

	  if ([keyPath isEqualToString:@"nearOffice"]) {

			BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
			self.inOfficeLabel.text = newValue ? @"Yes" : @"No";

		} else if ([keyPath isEqualToString:@"inRange"]) {

			BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
			self.inRangeLabel.text = newValue ? @"Yes" : @"No";

		} else if ([keyPath isEqualToString:@"isRanging"]) {
			
			BOOL newValue = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
			self.isRangingLabel.text = newValue ? @"Yes" : @"No";
			
		} else if ([keyPath isEqualToString:@"lastNotificationDate"]) {
			
			NSDate *newValue = (NSDate *)[change objectForKey:NSKeyValueChangeNewKey];
			NSString *localDate = [NSDateFormatter localizedStringFromDate:newValue dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
			
			self.lastUpdateLabel.text = localDate;
			
		} else if ([keyPath isEqualToString:@"beaconDistance"]) {
			NSString *newValue = (NSString *)[change objectForKey:NSKeyValueChangeNewKey];
			self.distanceLabel.text = newValue;

		} else if ([keyPath isEqualToString:@"officeDistance"]) {
			NSString *newValue = (NSString *)[change objectForKey:NSKeyValueChangeNewKey];
			self.officeDistanceLabel.text = newValue;

		} else if ([keyPath isEqualToString:@"locationStatus"]) {
			NSString *newValue = (NSString *)[change objectForKey:NSKeyValueChangeNewKey];
			self.locationStatusLabel.text = newValue;

		} else if ([keyPath isEqualToString:@"closestBeacon"]) {
			CLBeacon *newValue = (CLBeacon *)[change objectForKey:NSKeyValueChangeNewKey];

			if (![newValue isEqual:[NSNull null]]) {
				self.closestBeaconLabel.text = [NSString stringWithFormat:@"%@", newValue.minor];
				self.beaconSignalStrengthLabel.text = [NSString stringWithFormat:@"%li", (long)newValue.rssi];
			} else {
				self.closestBeaconLabel.text = @"?";
				self.beaconSignalStrengthLabel.text = @"?";
			}
		} else if ([keyPath isEqualToString:@"location"]) {
			CLLocation *newLocation = (CLLocation *)[change objectForKey:NSKeyValueChangeNewKey];
			self.latitudeLabel.text = [NSString stringWithFormat:@"%f", newLocation.coordinate.latitude];
			self.longitudeLabel.text = [NSString stringWithFormat:@"%f", newLocation.coordinate.longitude];
		}

	} else if (object == [NSUserDefaults standardUserDefaults]) {

		if ([keyPath isEqualToString:@"username"]) {
			NSString *newValue = (NSString *)[change objectForKey:NSKeyValueChangeNewKey];

			self.nameLabel.text = newValue;
		}

	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	_locationManager = [PCLocationManager sharedLocationManager];

	[self.locationManager addObserver:self forKeyPath:@"nearOffice" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial )  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"inRange" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial )  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"location" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial )  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"isRanging" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial )  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"lastNotificationDate" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"beaconDistance" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)  context:NULL];
	[self.locationManager addObserver:self forKeyPath:@"officeDistance" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)  context:NULL];

	[self.locationManager addObserver:self forKeyPath:@"locationStatus" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)  context:NULL];

	[self.locationManager addObserver:self forKeyPath:@"closestBeacon" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)  context:NULL];

	self.versionLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[defaults addObserver:self forKeyPath:@"username" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial ) context:NULL];

}

- (void)dealloc
{
	[self.locationManager removeObserver:self forKeyPath:@"nearOffice"];
	[self.locationManager removeObserver:self forKeyPath:@"inRange"];
	[self.locationManager removeObserver:self forKeyPath:@"isRanging"];
	[self.locationManager removeObserver:self forKeyPath:@"lastNotificationDate"];
	[self.locationManager removeObserver:self forKeyPath:@"beaconDistance"];
	[self.locationManager removeObserver:self forKeyPath:@"officeDistance"];
	[self.locationManager removeObserver:self forKeyPath:@"locationStatus"];
	[self.locationManager removeObserver:self forKeyPath:@"closestBeacon"];
	[self.locationManager removeObserver:self forKeyPath:@"location"];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"username"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
