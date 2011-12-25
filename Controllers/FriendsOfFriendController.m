//
//  FriendsOfFriendController.m
//  BachZero
//
//  Created by Akop Karapetyan on 12/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "FriendsOfFriendController.h"

#import "TaskController.h"
#import "ImageCache.h"
#import "PlayerCell.h"

#import "ProfileController.h"

@implementation FriendsOfFriendController

@synthesize screenName = _screenName;
@synthesize friendsOfFriend = _friendsOfFriend;
@synthesize lastUpdated = _lastUpdated;

-(id)initWithScreenName:(NSString*)screenName
                account:(XboxLiveAccount*)account;
{
    if (self = [super initWithAccount:account
                              nibName:@"FriendsOfFriendController"])
    {
        self.lastUpdated = nil;
        self.screenName = screenName;
        
        _friendsOfFriend = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void)dealloc
{
    self.friendsOfFriend = nil;
    self.screenName = nil;
    self.lastUpdated = nil;
    
    [super dealloc];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dataLoaded:)
                                                 name:BACHFriendsOfFriendLoaded
                                               object:nil];
    
    self.title = NSLocalizedString(@"FriendsOfFriend", nil);
    
	[_refreshHeaderView refreshLastUpdatedDate];
    
    [self refreshUsingRefreshHeaderTableView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BACHFriendsOfFriendLoaded
                                                  object:nil];
}

#pragma mark - EGORefreshTableHeaderDelegate Methods

-(void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
    [[TaskController sharedInstance] loadFriendsOfFriendForScreenName:self.screenName
                                                              account:self.account];
}

-(BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
	return [[TaskController sharedInstance] isLoadingRecentPlayersForAccount:self.account];
}

-(NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view
{
	return self.lastUpdated;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView 
 numberOfRowsInSection:(NSInteger)section 
{
    return [self.friendsOfFriend count];
}

- (UITableViewCell *)tableView:(UITableView *)tv 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    PlayerCell *cell = (PlayerCell*)[self.tableView dequeueReusableCellWithIdentifier:@"playerCell"];
    
    if (indexPath.row < [self.friendsOfFriend count])
    {
        if (!cell)
        {
            UINib *cellNib = [UINib nibWithNibName:@"PlayerCell" 
                                            bundle:nil];
            
            NSArray *topLevelObjects = [cellNib instantiateWithOwner:nil options:nil];
            
            for (id object in topLevelObjects)
            {
                if ([object isKindOfClass:[UITableViewCell class]])
                {
                    cell = (PlayerCell *)object;
                    break;
                }
            }
        }
        
        NSDictionary *player = [self.friendsOfFriend objectAtIndex:indexPath.row];
        
        cell.screenName.text = [player objectForKey:@"screenName"];
        cell.activity.text = [player objectForKey:@"activityText"];
        cell.gamerScore.text = [NSString localizedStringWithFormat:[self.numberFormatter stringFromNumber:[player objectForKey:@"gamerScore"]]];
        
        UIImage *gamerpic = [[ImageCache sharedInstance] getCachedFile:[player objectForKey:@"iconUrl"]
                                                          notifyObject:self
                                                        notifySelector:@selector(imageLoaded:)];
        
        UIImage *boxArt = [[ImageCache sharedInstance] getCachedFile:[player objectForKey:@"activityTitleIconUrl"]
                                                            cropRect:CGRectMake(0,16,85,85)
                                                        notifyObject:self
                                                      notifySelector:@selector(imageLoaded:)];
        
        cell.gamerpic.image = gamerpic;
        cell.titleIcon.image = boxArt;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *friendOfFriend = [self.friendsOfFriend objectAtIndex:indexPath.row];
    
    [ProfileController showProfileWithScreenName:[friendOfFriend objectForKey:@"screenName"]
                                         account:self.account
                            managedObjectContext:managedObjectContext
                            navigationController:self.navigationController];
}

#pragma mark - Notifications

- (void)imageLoaded:(NSString*)url
{
    // TODO: this causes a full data reload; not a good idea
    [self.tableView reloadData];
}

-(void)dataLoaded:(NSNotification *)notification
{
    NSLog(@"Got data loaded notification");
    
    XboxLiveAccount *account = [notification.userInfo objectForKey:BACHNotificationAccount];
    NSString *screenName = [notification.userInfo objectForKey:BACHNotificationScreenName];
    
    if ([self.account isEqualToAccount:account] && [self.screenName isEqualToString:screenName])
    {
        [self hideRefreshHeaderTableView];
        
        NSArray *players = [notification.userInfo objectForKey:BACHNotificationData];
        
        [self.friendsOfFriend removeAllObjects];
        [self.friendsOfFriend addObjectsFromArray:players];
        
        self.lastUpdated = [NSDate date];
        [self.tableView reloadData];
        
        [_refreshHeaderView refreshLastUpdatedDate];
    }
}

@end