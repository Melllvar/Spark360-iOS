//
//  RootViewController.h
//  ListTest
//
//  Created by Akop Karapetyan on 7/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CoreData/CoreData.h>

#import "XboxAccount.h"

@interface GameListController : UITableViewController <NSFetchedResultsControllerDelegate>
{
    XboxAccount *account;
}

@property (nonatomic, assign) IBOutlet UITableViewCell *tvCell;

@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSNumberFormatter *numberFormatter;

@property (nonatomic, retain) XboxAccount *account;

@end