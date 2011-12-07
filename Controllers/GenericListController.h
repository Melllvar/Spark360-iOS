//
//  RootViewController.h
//  ListTest
//
//  Created by Akop Karapetyan on 7/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "EGORefreshTableHeaderView.h"

#import "XboxLiveAccount.h"

@interface GenericListController : UITableViewController <EGORefreshTableHeaderDelegate>
{
    EGORefreshTableHeaderView *_refreshHeaderView;
    NSManagedObjectContext *managedObjectContext;
};

@property (nonatomic, retain) NSNumberFormatter *numberFormatter;
@property (nonatomic, retain) XboxLiveAccount *account;

-(void)refreshUsingRefreshHeaderTableView;
-(void)hideRefreshHeaderTableView;

@end