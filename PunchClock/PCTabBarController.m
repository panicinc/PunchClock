//
//  PCTabBarControllerDelegate.m
//  PunchClock
//
//  Created by James Moore on 3/17/14.
//  Copyright (c) 2014 Panic Inc. All rights reserved.
//

#import "PCTabBarController.h"

@implementation PCTabBarController

- (void)viewDidLoad
{
    [super viewDidLoad];

    for (UIViewController *vc in self.viewControllers) {

        if (vc == [self.viewControllers objectAtIndex:0]) {
            vc.tabBarItem.selectedImage = [UIImage imageNamed:@"team-on"];
            vc.tabBarItem.image = [[UIImage imageNamed:@"team"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        } else if (vc == [self.viewControllers objectAtIndex:1]) {
            vc.tabBarItem.selectedImage = [UIImage imageNamed:@"options-on"];
            vc.tabBarItem.image = [[UIImage imageNamed:@"options"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }

    [[UITabBar appearance] setBarTintColor:[UIColor colorWithRed:0.207f green:0.137f blue:0.202f alpha:1.000]];
    self.tabBar.translucent = NO;

    // Selected
    [[UITabBarItem appearance] setTitleTextAttributes:@{ NSForegroundColorAttributeName : [UIColor colorWithRed:0.561f green:0.467f blue:0.549f alpha:1.000] } forState:UIControlStateSelected];


    // Unselected
    [[UITabBarItem appearance] setTitleTextAttributes:@{ NSForegroundColorAttributeName : [UIColor colorWithRed:0.561f green:0.467f blue:0.549f alpha:1.000] } forState:UIControlStateNormal];


    [[UITabBar appearance] setTintColor:[UIColor colorWithRed:0.715f green:0.325f blue:0.691f alpha:1.000] ];

//    [[UITabBar appearance] setSelectedImageTintColor:[UIColor colorWithRed:0.715 green:0.325 blue:0.691 alpha:1.000]]; // for selected items that are green

}

@end
