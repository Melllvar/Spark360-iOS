/*
 * Spark 360 for iOS
 * https://github.com/pokebyte/Spark360-iOS
 *
 * Copyright (C) 2011-2014 Akop Karapetyan
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307  USA.
 *
 */

#import <UIKit/UIKit.h>

#import "GenericController.h"
#import "AccountListController.h"

@interface ProfileOverviewController : GenericController<UITableViewDataSource, AccountSelectionDelegate, UISplitViewControllerDelegate>

-(id)initWithAccount:(XboxLiveAccount*)account;

@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, assign) IBOutlet UITableViewCell *optionsCell;

@property (nonatomic, retain) NSMutableDictionary *profile;
@property (nonatomic, retain) NSMutableArray *beacons;
@property (nonatomic, assign) NSInteger messagesUnread;
@property (nonatomic, assign) NSInteger friendsOnline;

@property (nonatomic, retain) UIPopoverController *popover;

- (IBAction)viewGames:(id)sender;
- (IBAction)viewMessages:(id)sender;
- (IBAction)viewFriends:(id)sender;

-(IBAction)refresh:(id)sender;
-(IBAction)viewLiveStatus:(id)sender;
-(IBAction)about:(id)sender;

@end
