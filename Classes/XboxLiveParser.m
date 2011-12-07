//
//  XboxLiveParser.m
//  ListTest
//
//  Created by Akop Karapetyan on 8/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XboxLiveParser.h"

#import "GTMNSString+HTML.h"
#import "GTMNSString+URLArguments.h"

#import "SBJson.h"

#define TIMEOUT_SECONDS 30

#define XBLPGet  (@"GET")
#define XBLPPost (@"POST")

NSString* const BACHAchievementsSynced = @"BachAchievementsSynced";
NSString* const BACHError = @"BachError";

NSString* const BACHNotificationGameTitleId = @"BachGameTitleId";
NSString* const BACHNotificationAccount = @"BachAccount";
NSString* const BACHNotificationNSError = @"BachNSError";

NSString* const BachErrorDomain = @"com.akop.bach";

@interface XboxLiveParser (PrivateMethods)

- (NSString*)loadWithMethod:(NSString*)method
                        url:(NSString*)url 
                     fields:(NSDictionary*)fields
                 addHeaders:(NSDictionary*)headers
                     useXhr:(BOOL)useXhr
                      error:(NSError**)error;
- (NSString*)loadWithGET:(NSString*)url 
                  fields:(NSDictionary*)fields
                  useXhr:(BOOL)useXhr
                   error:(NSError**)error;
- (NSString*)loadWithPOST:(NSString*)url 
                   fields:(NSDictionary*)fields
                   useXhr:(BOOL)useXhr
                    error:(NSError**)error;

+(NSString*)getActionUrl:(NSString*)text;
+(NSMutableDictionary*)getInputs:(NSString*)response
                     namePattern:(NSRegularExpression*)namePattern;
+(NSDictionary*)jsonObjectFromLive:(NSString*)script
                             error:(NSError**)error;
+(NSDictionary*)jsonDataObjectFromPage:(NSString*)json
                                 error:(NSError**)error;
+(NSDictionary*)jsonObjectFromPage:(NSString*)json
                             error:(NSError**)error;
+(NSNumber*)getStarRatingFromPage:(NSString*)html;

-(void)saveSessionForAccount:(XboxLiveAccount*)account;
-(void)saveSessionForEmailAddress:(NSString*)emailAddress;
-(BOOL)restoreSessionForAccount:(XboxLiveAccount*)account;
-(BOOL)restoreSessionForEmailAddress:(NSString*)emailAddress;
-(void)clearAllSessions;

-(BOOL)parseSynchronizeProfile:(NSMutableDictionary*)profile
                  emailAddress:(NSString*)emailAddress
                      password:(NSString*)password
                         error:(NSError**)error;
-(BOOL)parseSynchronizeGames:(NSMutableDictionary*)games
                  forAccount:(XboxLiveAccount*)account
                       error:(NSError**)error;
-(BOOL)parseSynchronizeAchievements:(NSMutableDictionary*)achievements
                         forAccount:(XboxLiveAccount*)account
                            titleId:(NSString*)titleId
                              error:(NSError**)error;

+(NSError*)errorWithCode:(NSInteger)code
                 message:(NSString*)message;
+(NSError*)errorWithCode:(NSInteger)code
         localizationKey:(NSString*)key;

-(NSString*)parseObtainNewToken;
+(NSDate*)getTicksFromJSONString:(NSString*)jsonTicks;

-(NSManagedObject*)profileForAccount:(XboxLiveAccount*)account;
-(NSManagedObject*)getGameWithTitleId:(NSString*)titleId
                              account:(XboxLiveAccount*)account;

-(NSDictionary*)retrieveAchievementsWithAccount:(XboxLiveAccount*)account
                                        titleId:(NSString*)titleId
                                          error:(NSError**)error;

-(void)writeAchievementData:(NSDictionary*)data;

-(void)postNotificationOnMainThread:(NSString*)postNotificationName
                           userInfo:(NSDictionary*)userInfo;
-(void)postNotificationSelector:(NSDictionary*)args;

@end

@implementation XboxLiveParser

@synthesize context = _context;
@synthesize lastError;

#define LOCALE (NSLocalizedString(@"Locale", nil))

NSString* const ErrorDomainAuthentication = @"Authentication";

NSString* const URL_LOGIN = @"http://login.live.com/login.srf?wa=wsignin1.0&wreply=%@";
NSString* const URL_LOGIN_MSN = @"https://msnia.login.live.com/ppsecure/post.srf?wa=wsignin1.0&wreply=%@";
NSString* const URL_VTOKEN = @"http://live.xbox.com/%@/Home";

NSString* const URL_GAMERCARD = @"http://gamercard.xbox.com/%@/%@.card";

NSString* const URL_JSON_PROFILE = @"http://live.xbox.com/Handlers/ShellData.ashx?culture=%@&XBXMChg=%i&XBXNChg=%i&XBXSPChg=%i&XBXChg=%i&leetcallback=jsonp1287728723001";
NSString* const URL_JSON_GAME_LIST = @"http://live.xbox.com/%@/Activity/Summary";
NSString* const REFERER_JSON_PROFILE = @"http://live.xbox.com/%@/MyXbox";

NSString* const URL_ACHIEVEMENTS = @"http://live.xbox.com/%@/Activity/Details?titleId=%@";

NSString* const URL_REPLY_TO = @"https://live.xbox.com/xweb/live/passport/setCookies.ashx";

NSString* const PATTERN_EXTRACT_JSON = @"^[^\\{]+(\\{.*\\})\\);?\\s*$";
NSString* const PATTERN_EXTRACT_TICKS = @"[^\\(]+\\((\\d+)\\)";

NSString* const PATTERN_GAMERCARD_REP = @"class=\"Star ([^\"]*)\"";

NSString* const PATTERN_LOGIN_LIVE_AUTH_URL = @"var\\s*srf_uPost\\s*=\\s*'([^']*)'";
NSString* const PATTERN_LOGIN_PPSX = @"var\\s*srf_sRBlob\\s*=\\s*'([^']*)'";
NSString* const PATTERN_LOGIN_ATTR_LIST = @"<input((\\s+\\w+=\"[^\"]*\")+)[^>]*>";
NSString* const PATTERN_LOGIN_GET_ATTRS = @"(\\w+)=\"([^\"]*)\"";
NSString* const PATTERN_LOGIN_ACTION_URL = @"action=\"(https?://[^\"]+)\"";

NSString* const PATTERN_GAMES = @"<div *class=\"LineItem\">(.*?)<br clear=\"all\" />";
NSString* const PATTERN_GAME_TITLE = @"<h3><a href=\"([^\"]*)\"[^>]*?>([^<]*)<";
NSString* const PATTERN_GAME_GAMERSCORE = @"GamerScore Stat\">\\s*(\\d+)\\s*\\/\\s*(\\d+)\\s*<";
NSString* const PATTERN_GAME_ACHIEVEMENTS = @"Achievement Stat\">\\s*(\\d+)\\s*\\/\\s*(\\d+)\\s*<";
NSString* const PATTERN_GAME_ACHIEVEMENT_URL = @"href=\"([^\"]*Achievements\\?titleId=(\\d+)[^\"]*)\"";
NSString* const PATTERN_GAME_BOXART_URL = @"src=\"([^\"]*)\" class=\"BoxShot\"";
NSString* const PATTERN_GAME_LAST_PLAYED = @"class=\"lastPlayed\">\\s*(\\S+)\\s*<";

NSString* const PATTERN_ACH_JSON = @"loadActivityDetailsView\\((.*)\\);\\s*\\}\\);";

NSString* const URL_SECRET_ACHIEVE_TILE = @"http://live.xbox.com/Content/Images/HiddenAchievement.png";

-(id)initWithManagedObjectContext:(NSManagedObjectContext*)context
{
    if (!(self = [super init]))
        return nil;
    
    self.context = context;
    
    return self;
}

-(void)dealloc
{
    self.context = nil;
    self.lastError = nil;
    
    [super dealloc];
}

-(void)synchronizeAchievements:(NSDictionary*)arguments
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    XboxLiveAccount *account = [arguments objectForKey:@"account"];
    NSString *gameTitleId = [arguments objectForKey:@"id"];
    
    NSError *error = nil;
    NSDictionary *data = [self retrieveAchievementsWithAccount:account
                                                       titleId:gameTitleId
                                                         error:&error];
    
    if (data)
    {
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                              account, @"account",
                              data, @"data", nil];
        
        [self performSelectorOnMainThread:@selector(writeAchievementData:) 
                               withObject:args
                            waitUntilDone:YES];
    }
    else
    {
        self.lastError = error;
        
        [self postNotificationOnMainThread:BACHError
                                  userInfo:[NSDictionary dictionaryWithObject:self.lastError
                                                                       forKey:BACHNotificationNSError]];
    }
    
    [self postNotificationOnMainThread:BACHAchievementsSynced
                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                        account, BACHNotificationAccount, 
                                        gameTitleId, BACHNotificationGameTitleId, 
                                        nil]];
    
    [pool release];
}

-(void)postNotificationOnMainThread:(NSString*)postNotificationName
                           userInfo:(NSDictionary*)userInfo
{
    [self performSelectorOnMainThread:@selector(postNotificationSelector:) 
                           withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                       postNotificationName, @"postNotificationName", 
                                       userInfo, @"userInfo", nil]
                        waitUntilDone:YES];
}

-(void)postNotificationSelector:(NSDictionary*)args
{
    [[NSNotificationCenter defaultCenter] postNotificationName:[args objectForKey:@"postNotificationName"]
                                                        object:self
                                                      userInfo:[args objectForKey:@"userInfo"]];
}

-(NSDictionary*)retrieveGamesWithAccount:(XboxLiveAccount*)account
                                   error:(NSError**)error
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    
    // Try restoring the session
    
    if (![self restoreSessionForAccount:account])
    {
        // Session couldn't be restored. Try re-authenticating
        
        if (![self authenticateAccount:account
                                 error:error])
        {
            return nil;
        }
    }
    
    if (![self parseSynchronizeGames:dict
                          forAccount:account
                               error:NULL])
    {
        // Account parsing failed. Try re-authenticating
        
        if (![self authenticateAccount:account
                                 error:error])
        {
            return nil;
        }
        
        if (![self parseSynchronizeGames:dict
                              forAccount:account
                                   error:error])
        {
            return nil;
        }
    }
    
    [self saveSessionForAccount:account];
    
    return dict;
}

-(NSDictionary*)retrieveAchievementsWithAccount:(XboxLiveAccount*)account
                                        titleId:(NSString*)titleId
                                          error:(NSError**)error
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    
    // Try restoring the session
    
    if (![self restoreSessionForAccount:account])
    {
        // Session couldn't be restored. Try re-authenticating
        
        if (![self authenticateAccount:account
                                 error:error])
        {
            return nil;
        }
    }
    
    if (![self parseSynchronizeAchievements:dict
                                 forAccount:account
                                    titleId:titleId
                                      error:NULL])
    {
        // Account parsing failed. Try re-authenticating
        
        if (![self authenticateAccount:account
                                 error:error])
        {
            return nil;
        }
        
        if (![self parseSynchronizeAchievements:dict
                                     forAccount:account
                                        titleId:titleId
                                          error:error])
        {
            return nil;
        }
    }
    
    [self saveSessionForAccount:account];
    
    return dict;
}

-(NSDictionary*)retrieveProfileWithAccount:(XboxLiveAccount*)account
                                     error:(NSError**)error
{
    return [self retrieveProfileWithEmailAddress:account.emailAddress
                                        password:account.password
                                           error:error];
}

-(NSDictionary*)retrieveProfileWithEmailAddress:(NSString*)emailAddress
                                       password:(NSString*)password
                                          error:(NSError**)error;
{
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init] autorelease];
    
    // Try restoring the session
    
    if (![self restoreSessionForEmailAddress:emailAddress])
    {
        // Session couldn't be restored. Try re-authenticating
        
        if (![self authenticate:emailAddress
                   withPassword:password
                          error:error])
        {
            return nil;
        }
    }
    
    if (![self parseSynchronizeProfile:dict
                          emailAddress:emailAddress
                              password:password
                                 error:NULL])
    {
        // Account parsing failed. Try re-authenticating
        
        if (![self authenticate:emailAddress
                   withPassword:password
                          error:error])
        {
            return nil;
        }
        
        if (![self parseSynchronizeProfile:dict
                              emailAddress:emailAddress
                                  password:password
                                     error:error])
        {
            return nil;
        }
    }
    
    [self saveSessionForEmailAddress:emailAddress];
    
    return dict;
}

-(BOOL)synchronizeProfileWithAccount:(XboxLiveAccount*)account
                 withRetrievedObject:(NSDictionary*)dict
                               error:(NSError**)error
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxProfile"
                                                         inManagedObjectContext:self.context];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", account.uuid];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:predicate];
    
    NSArray *array = [self.context executeFetchRequest:request error:nil];
    
    [request release];
    
    NSManagedObject *profile = [array lastObject];
    if (!profile)
    {
        // The profile is gone/nonexistent. Create a new one
        
        profile = [NSEntityDescription insertNewObjectForEntityForName:@"XboxProfile" 
                                                inManagedObjectContext:self.context];
        
        [profile setValue:account.uuid forKey:@"uuid"];
    }
    
    [profile setValue:[dict objectForKey:@"screenName"] forKey:@"screenName"];
    [profile setValue:[dict objectForKey:@"iconUrl"] forKey:@"iconUrl"];
    [profile setValue:[dict objectForKey:@"tier"] forKey:@"tier"];
    [profile setValue:[dict objectForKey:@"pointsBalance"] forKey:@"pointsBalance"];
    [profile setValue:[dict objectForKey:@"gamerscore"] forKey:@"gamerscore"];
    [profile setValue:[dict objectForKey:@"isGold"] forKey:@"isGold"];
    [profile setValue:[dict objectForKey:@"unreadMessages"] forKey:@"unreadMessages"];
    [profile setValue:[dict objectForKey:@"unreadNotifications"] forKey:@"unreadNotifications"];
    [profile setValue:[dict objectForKey:@"rep"] forKey:@"rep"];
    
    if (![self.context save:nil])
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPCoreDataError
                                   localizationKey:@"ErrorCouldNotSaveProfile"];
        }
        
        return NO;
    }
    
    NSLog(@"synchronizeProfileWithAccount: %.04f", 
          CFAbsoluteTimeGetCurrent() - startTime);
    
    return YES;
}

-(BOOL)synchronizeGamesWithAccount:(XboxLiveAccount*)account
               withRetrievedObject:(NSDictionary*)dict
                             error:(NSError**)error
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    NSManagedObject *profile = [self profileForAccount:account];
    
    NSDate *lastUpdated = [NSDate date];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxGame"
                                                         inManagedObjectContext:self.context];
    
    int newItems = 0;
    int existingItems = 0;
    int listOrder = 0;
    
    NSArray *gameDicts = [dict objectForKey:@"games"];
    
    for (NSDictionary *gameDict in gameDicts)
    {
        listOrder++;
        
        // Fetch game, or create a new one
        NSManagedObject *game;
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid == %@ AND profile == %@", 
                                  [gameDict objectForKey:@"uid"], profile];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        [request setEntity:entityDescription];
        [request setPredicate:predicate];
        
        NSArray *array = [self.context executeFetchRequest:request 
                                                     error:nil];
        
        [request release];
        
        if (!(game = [array lastObject]))
        {
            newItems++;
            game = [NSEntityDescription insertNewObjectForEntityForName:@"XboxGame"
                                                 inManagedObjectContext:self.context];
            
            // These will not change, so just set them up the first time
            
            [game setValue:[gameDict objectForKey:@"uid"] forKey:@"uid"];
            [game setValue:profile forKey:@"profile"];
            [game setValue:[gameDict objectForKey:@"gameUrl"] forKey:@"gameUrl"];
            [game setValue:[gameDict objectForKey:@"title"] forKey:@"title"];
            [game setValue:[gameDict objectForKey:@"boxArtUrl"] forKey:@"boxArtUrl"];
            [game setValue:[NSNumber numberWithBool:YES] forKey:@"achievesDirty"];
        }
        else
        {
            existingItems++;
            if (![[game valueForKey:@"achievesUnlocked"] isEqualToNumber:[gameDict objectForKey:@"achievesUnlocked"]] ||
                ![[game valueForKey:@"achievesTotal"] isEqualToNumber:[gameDict objectForKey:@"achievesTotal"]] ||
                ![[game valueForKey:@"gamerScoreEarned"] isEqualToNumber:[gameDict objectForKey:@"gamerScoreEarned"]] ||
                ![[game valueForKey:@"gamerScoreTotal"] isEqualToNumber:[gameDict objectForKey:@"gamerScoreTotal"]])
            {
                [game setValue:[NSNumber numberWithBool:YES] forKey:@"achievesDirty"];
            }
        }
        
        // We now have a game object (new or existing)
        // Handle the rest of the data
        
        // Game achievements
        
        [game setValue:[gameDict objectForKey:@"achievesUnlocked"] forKey:@"achievesUnlocked"];
        [game setValue:[gameDict objectForKey:@"achievesTotal"] forKey:@"achievesTotal"];
        
        // Game score
        
        [game setValue:[gameDict objectForKey:@"gamerScoreEarned"] forKey:@"gamerScoreEarned"];
        [game setValue:[gameDict objectForKey:@"gamerScoreTotal"] forKey:@"gamerScoreTotal"];
        
        // Last played
        
        NSDate *lastPlayed = nil;
        if ([gameDict objectForKey:@"lastPlayed"] != [NSDate distantPast])
            lastPlayed = [gameDict objectForKey:@"lastPlayed"];
        
        [game setValue:lastPlayed forKey:@"lastPlayed"];
        [game setValue:lastUpdated forKey:@"lastUpdated"];
        [game setValue:[NSNumber numberWithInt:listOrder] forKey:@"listOrder"];
    }
    
    // Find "stale" games
    
    NSPredicate *stalePredicate = [NSPredicate predicateWithFormat:@"lastUpdated != %@ AND profile == %@", 
    lastUpdated, profile];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    [request setPredicate:stalePredicate];
    
    NSArray *staleObjs = [self.context executeFetchRequest:request 
                                                     error:NULL];
    [request release];
    
    // Delete "stale" games
    
    for (NSManagedObject *staleObj in staleObjs)
        [self.context deleteObject:staleObj];
    
    // Save
    
    if (![self.context save:NULL])
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPCoreDataError
                                   localizationKey:@"ErrorCouldNotSaveGameList"];
        }
        
        return NO;
    }
    
    account.lastGamesUpdate = [NSDate date];
    [account save];
    
    NSLog(@"synchronizeGamesWithAccount: (%i new, %i existing) %.04fs", 
          newItems, existingItems, CFAbsoluteTimeGetCurrent() - startTime);
    
    return YES;
}

-(void)writeAchievementData:(NSDictionary*)args
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    NSDictionary *data = [args objectForKey:@"data"];
    XboxLiveAccount *account = [args objectForKey:@"account"];
    
    NSManagedObject *game = [self getGameWithTitleId:[data objectForKey:@"titleId"]
                                             account:account];
    
    if (!game)
    {
        self.lastError = [XboxLiveParser errorWithCode:XBLPCoreDataError
                                       localizationKey:@"ErrorGameNotFound"];
        return;
    }
    
    NSDate *lastUpdated = [NSDate date];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxAchievement"
                                                         inManagedObjectContext:self.context];
    
    NSArray *inAchieves = [data objectForKey:@"achievements"];
    
    int newItems = 0;
    int existingItems = 0;
    
    for (NSDictionary *inAchieve in inAchieves)
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid == %@ AND game == %@", 
                                  [inAchieve objectForKey:@"uid"], game];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        
        [request setEntity:entityDescription];
        [request setPredicate:predicate];
        
        NSArray *array = [self.context executeFetchRequest:request 
                                                     error:nil];
        
        [request release];
        
        BOOL update = NO;
        NSManagedObject *achieve = [array lastObject];
        
        if (!achieve)
        {
            achieve = [NSEntityDescription insertNewObjectForEntityForName:@"XboxAchievement"
                                                    inManagedObjectContext:self.context];
            
            [achieve setValue:game forKey:@"game"];
            [achieve setValue:[inAchieve objectForKey:@"uid"] forKey:@"uid"];
            [achieve setValue:[inAchieve objectForKey:@"points"] forKey:@"points"];
            
            newItems++;
            update = YES;
        }
        else
        {
            existingItems++;
            update = [[inAchieve objectForKey:@"isLocked"] boolValue] 
                != [[achieve valueForKey:@"isLocked"] boolValue];
        }
        
        [achieve setValue:lastUpdated forKey:@"lastUpdated"];
        [achieve setValue:[inAchieve objectForKey:@"sortIndex"] forKey:@"sortIndex"];
        
        if (update)
        {
            [achieve setValue:[inAchieve objectForKey:@"isSecret"] forKey:@"isSecret"];
            [achieve setValue:[inAchieve objectForKey:@"isLocked"] forKey:@"isLocked"];
            [achieve setValue:[inAchieve objectForKey:@"title"] forKey:@"title"];
            [achieve setValue:[inAchieve objectForKey:@"iconUrl"] forKey:@"iconUrl"];
            [achieve setValue:[inAchieve objectForKey:@"achDescription"] forKey:@"achDescription"];
            [achieve setValue:[inAchieve objectForKey:@"acquired"] forKey:@"acquired"];
        }
    }
    
    NSDictionary *inGame = [data objectForKey:@"game"];
    if (inGame)
    {
        [game setValue:[inGame objectForKey:@"achievesTotal"]
                forKey:@"achievesTotal"];
        [game setValue:[inGame objectForKey:@"gamerScoreTotal"]
                forKey:@"gamerScoreTotal"];
        
        if ([inGame objectForKey:@"achievesUnlocked"])
            [game setValue:[inGame objectForKey:@"achievesUnlocked"]
                    forKey:@"achievesUnlocked"];
        if ([inGame objectForKey:@"gamerScoreEarned"])
            [game setValue:[inGame objectForKey:@"gamerScoreEarned"]
                    forKey:@"gamerScoreEarned"];
        if ([inGame objectForKey:@"lastPlayed"])
            [game setValue:[inGame objectForKey:@"lastPlayed"]
                    forKey:@"lastPlayed"];
        
        [game setValue:lastUpdated
                forKey:@"lastUpdated"];
        [game setValue:[NSNumber numberWithBool:NO]
                forKey:@"achievesDirty"];
    }
    
    // Find achievements no longer in the game (will it ever happen?)
    
    NSPredicate *removedPredicate = [NSPredicate predicateWithFormat:@"lastUpdated != %@ AND game == %@", 
                                     lastUpdated, game];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:removedPredicate];
    
    NSArray *removedObjs = [self.context executeFetchRequest:request 
                                                     error:NULL];
    
    [request release];
    
    // Delete removed achievements
    
    for (NSManagedObject *removedObj in removedObjs)
        [self.context deleteObject:removedObj];
    
    // Save
    
    if (![self.context save:NULL])
    {
        self.lastError = [XboxLiveParser errorWithCode:XBLPCoreDataError
                                       localizationKey:@"ErrorCouldNotSaveGameList"];
        return;
    }
    
    NSLog(@"synchronizeAchievementsWithAccount: (%i new, %i existing) %.04fs", 
          newItems, existingItems, CFAbsoluteTimeGetCurrent() - startTime);
}

-(BOOL)parseSynchronizeProfile:(NSMutableDictionary*)profile
                  emailAddress:(NSString*)emailAddress
                      password:(NSString*)password
                         error:(NSError**)error
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    int ticks = [[NSDate date] timeIntervalSince1970] * 1000;
    NSString *url = [NSString stringWithFormat:URL_JSON_PROFILE, 
                     LOCALE, ticks, ticks, ticks, ticks];
    NSString *referer = [NSString stringWithFormat:REFERER_JSON_PROFILE, LOCALE];
    NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys:
                             referer, @"Referer",
                             nil];
    
    NSString *jsonPage = [self loadWithMethod:XBLPGet
                                          url:url
                                       fields:nil
                                   addHeaders:headers
                                       useXhr:YES
                                        error:error];
    
    if (!jsonPage)
        return NO;
    
    NSDictionary *object = [XboxLiveParser jsonObjectFromLive:jsonPage
                                                        error:error];
    
    if (!object)
        return NO;
    
    NSString *gamertag = [object objectForKey:@"gamertag"];
    
    [profile setObject:gamertag forKey:@"screenName"];
    [profile setObject:[object objectForKey:@"gamerpic"] forKey:@"iconUrl"];
    [profile setObject:[object objectForKey:@"tiertext"] forKey:@"tier"];
    
    [profile setObject:[NSNumber numberWithInt:[[object objectForKey:@"pointsbalancetext"] intValue]] forKey:@"pointsBalance"];
    [profile setObject:[NSNumber numberWithInt:[[object objectForKey:@"gamerscore"] intValue]] forKey:@"gamerscore"];
    [profile setObject:[NSNumber numberWithInt:[[object objectForKey:@"tier"] intValue] >= 6] forKey:@"isGold"];
    [profile setObject:[NSNumber numberWithInt:[[object objectForKey:@"messages"] intValue]] forKey:@"unreadMessages"];
    [profile setObject:[NSNumber numberWithInt:[[object objectForKey:@"notifications"] intValue]] forKey:@"unreadNotifications"];
    
    url = [NSString stringWithFormat:URL_GAMERCARD, LOCALE,
           [gamertag gtm_stringByEscapingForURLArgument]];
    
    NSString *cardPage = [self loadWithGET:url
                                    fields:nil
                                    useXhr:NO
                                     error:nil];
    
    // An error for rep not fatal, so we ignore them
    if (cardPage)
    {
        [profile setObject:[XboxLiveParser getStarRatingFromPage:cardPage] forKey:@"rep"];
    }
    
    NSLog(@"parseSynchronizeProfile: %.04f", 
          CFAbsoluteTimeGetCurrent() - startTime);
    
    return YES;
}

-(BOOL)parseSynchronizeGames:(NSMutableDictionary*)games
                  forAccount:(XboxLiveAccount*)account
                       error:(NSError**)error
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    NSString *vtoken = [self parseObtainNewToken];
    if (!vtoken)
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPParsingError
                                   localizationKey:@"ErrorCannotObtainToken"];
        }
        
        return NO;
    }
    
    NSString *url = [NSString stringWithFormat:URL_JSON_GAME_LIST, LOCALE];
    NSDictionary *inputs = [NSDictionary dictionaryWithObject:vtoken 
                                                       forKey:@"__RequestVerificationToken"];
    
    NSString *page = [self loadWithPOST:url
                                 fields:inputs
                                 useXhr:YES
                                  error:error];
    
    if (!page)
        return NO;
    
    NSDictionary *data = [XboxLiveParser jsonDataObjectFromPage:page
                                                          error:error];
    
    if (!data)
        return NO;
    
    NSMutableArray *gameList = [[[NSMutableArray alloc] init] autorelease];
    [games setObject:gameList 
              forKey:@"games"];
    
    NSString *gamertag = [data objectForKey:@"CurrentGamertag"];
    NSArray *jsonGames = [data objectForKey:@"Games"];
    
    if (jsonGames)
    {
        for (NSDictionary *jsonGame in jsonGames)
        {
            NSDictionary *progRoot = [jsonGame objectForKey:@"Progress"];
            NSDictionary *progress = [progRoot objectForKey:gamertag];
            
            if (!progress)
                continue;
            
            NSDate *lastPlayed = [XboxLiveParser getTicksFromJSONString:[progress objectForKey:@"LastPlayed"]];
            
            NSMutableArray *objects = [[[NSMutableArray alloc] init] autorelease];
            
            [objects addObject:[[jsonGame objectForKey:@"Id"] stringValue]];
            [objects addObject:[progress objectForKey:@"Achievements"]];
            [objects addObject:[jsonGame objectForKey:@"PossibleAchievements"]];
            [objects addObject:[progress objectForKey:@"Score"]];
            [objects addObject:[jsonGame objectForKey:@"PossibleScore"]];
            [objects addObject:lastPlayed];
            [objects addObject:[jsonGame objectForKey:@"Url"]];
            [objects addObject:[jsonGame objectForKey:@"Name"]];
            [objects addObject:[jsonGame objectForKey:@"BoxArt"]];
            
            NSArray *keys = [NSArray arrayWithObjects:
                             @"uid",
                             @"achievesUnlocked",
                             @"achievesTotal",
                             @"gamerScoreEarned",
                             @"gamerScoreTotal",
                             @"lastPlayed",
                             @"gameUrl",
                             @"title",
                             @"boxArtUrl",
                             nil];
            
            [gameList addObject:[NSDictionary dictionaryWithObjects:objects
                                                            forKeys:keys]];
        }
    }
    
    // TODO: beacons
    
    NSLog(@"parseSynchronizeGames: %.04f", 
          CFAbsoluteTimeGetCurrent() - startTime);
    
    return YES;
}

-(BOOL)parseSynchronizeAchievements:(NSMutableDictionary*)achievements
                         forAccount:(XboxLiveAccount*)account
                            titleId:(NSString*)titleId
                              error:(NSError**)error
{
    CFTimeInterval startTime = CFAbsoluteTimeGetCurrent(); 
    
    NSString *url = [NSString stringWithFormat:URL_ACHIEVEMENTS, LOCALE, titleId];
    NSString *achievementPage = [self loadWithGET:url
                                           fields:nil
                                           useXhr:NO
                                            error:error];
    
    if (!achievementPage)
        return NO;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:PATTERN_ACH_JSON
                                                                           options:0
                                                                             error:NULL];
    
    NSTextCheckingResult *match = [regex firstMatchInString:achievementPage
                                                    options:0
                                                      range:NSMakeRange(0, [achievementPage length])];
    
    if (!match)
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPParsingError
                                   localizationKey:@"ErrorAchievementsNotFound"];
        }
        
        return NO;
    }
    
    NSString *jsonScript = [achievementPage substringWithRange:[match rangeAtIndex:1]];
    NSDictionary *data = [XboxLiveParser jsonObjectFromPage:jsonScript
                                                      error:error];
    
    if (!data)
        return NO;
    
    NSArray *jsonAchieves = [data objectForKey:@"Achievements"];
    NSArray *jsonPlayers = [data objectForKey:@"Players"];
    
    if ([jsonPlayers count] < 1)
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPParsingError 
                                           message:@"ErrorMissingGamertagInAchieves"];
        }
        
        return NO;
    }
    
    NSString *gamertag = [[jsonPlayers objectAtIndex:0] objectForKey:@"Gamertag"];
    
    NSMutableArray *achieveList = [[[NSMutableArray alloc] init] autorelease];
    
    [achievements setObject:achieveList forKey:@"achievements"];
    [achievements setObject:titleId forKey:@"titleId"];
    
    int index = 0;
    for (NSDictionary *jsonAchieve in jsonAchieves)
    {
        if (![jsonAchieve objectForKey:@"Id"])
            continue;
        
        NSDictionary *earnDates = [jsonAchieve objectForKey:@"EarnDates"];
        if (!earnDates)
            continue;
        
        NSMutableArray *objects = [[[NSMutableArray alloc] init] autorelease];
        
        if ([[jsonAchieve objectForKey:@"IsHidden"] boolValue])
        {
            [objects addObject:NSLocalizedString(@"SecretAchieveTitle", nil)]; // title
            [objects addObject:NSLocalizedString(@"SecretAchieveDesc", nil)]; // achDescription
            [objects addObject:URL_SECRET_ACHIEVE_TILE]; // iconUrl
            [objects addObject:[NSNumber numberWithBool:YES]]; // isSecret
        }
        else
        {
            [objects addObject:[jsonAchieve objectForKey:@"Name"]]; // title
            [objects addObject:[jsonAchieve objectForKey:@"Description"]]; // achDescription
            [objects addObject:[jsonAchieve objectForKey:@"TileUrl"]]; // iconUrl
            [objects addObject:[NSNumber numberWithBool:NO]]; // isSecret
        }
        
        NSDictionary *earnDate = [earnDates objectForKey:gamertag];
        if (earnDate)
        {
            [objects addObject:[NSNumber numberWithBool:NO]]; // isLocked
            [objects addObject:[XboxLiveParser getTicksFromJSONString:[earnDate objectForKey:@"EarnedOn"]]]; // acquired
        }
        else
        {
            [objects addObject:[NSNumber numberWithBool:YES]]; // isLocked
            [objects addObject:[NSDate distantPast]]; // acquired
        }
        
        [objects addObject:[[jsonAchieve objectForKey:@"Id"] stringValue]]; // uid
        [objects addObject:[NSNumber numberWithInt:[[jsonAchieve objectForKey:@"Score"] intValue]]]; // points
        [objects addObject:[NSNumber numberWithInt:index++]]; // sortIndex
        
        NSArray *keys = [NSArray arrayWithObjects:
                         @"title",
                         @"achDescription",
                         @"iconUrl",
                         @"isSecret",
                         @"isLocked",
                         @"acquired",
                         @"uid",
                         @"points",
                         @"sortIndex", 
                         nil];
        
        [achieveList addObject:[NSDictionary dictionaryWithObjects:objects
                                                           forKeys:keys]];
    }
    
    NSDictionary *jsonGame = [data objectForKey:@"Game"];
    if (jsonGame)
    {
        NSMutableArray *keys = [[[NSMutableArray alloc] init] autorelease];
        NSMutableArray *objects = [[[NSMutableArray alloc] init] autorelease];
        
        [objects addObject:[jsonGame objectForKey:@"PossibleAchievements"]];
        [objects addObject:[jsonGame objectForKey:@"PossibleScore"]];
        
        [keys addObject:@"achievesTotal"];
        [keys addObject:@"gamerScoreTotal"];
        
        NSDictionary *progRoot = [jsonGame objectForKey:@"Progress"];
        if (progRoot)
        {
            NSDictionary *progress = [progRoot objectForKey:gamertag];
            if (progress)
            {
                [objects addObject:[progress objectForKey:@"Achievements"]];
                [objects addObject:[progress objectForKey:@"Score"]];
                [objects addObject:[XboxLiveParser getTicksFromJSONString:[progress objectForKey:@"LastPlayed"]]];
                
                [keys addObject:@"achievesUnlocked"];
                [keys addObject:@"gamerScoreEarned"];
                [keys addObject:@"lastPlayed"];
            }
        }
        
        [achievements setObject:[NSDictionary dictionaryWithObjects:objects
                                                            forKeys:keys] 
                         forKey:@"game"];
    }
    
    NSLog(@"parseSynchronizeAchievements: %.04f", 
          CFAbsoluteTimeGetCurrent() - startTime);
    
    return YES;
}

-(NSManagedObject*)profileForAccount:(XboxLiveAccount*)account
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxProfile"
                                                         inManagedObjectContext:self.context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", account.uuid];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:predicate];
    
    NSArray *array = [self.context executeFetchRequest:request 
                                                 error:nil];
    
    [request release];
    
    return [array lastObject];
}

-(NSManagedObject*)getGameWithTitleId:(NSString*)titleId
                              account:(XboxLiveAccount*)account
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxGame"
                                                         inManagedObjectContext:self.context];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid == %@ AND profile.uuid = %@", 
                              titleId, account.uuid];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:predicate];
    
    NSArray *array = [self.context executeFetchRequest:request 
                                                 error:nil];
    
    [request release];
    
    return [array lastObject];
}

#pragma mark Authentication, sessions

-(void)clearAllSessions
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [cookieStorage cookies];
    
    for (NSHTTPCookie *cookie in cookies)
        [cookieStorage deleteCookie:cookie];
}

-(BOOL)restoreSessionForAccount:(XboxLiveAccount*)account
{
    return [self restoreSessionForEmailAddress:account.emailAddress];
}

-(BOOL)restoreSessionForEmailAddress:(NSString*)emailAddress
{
    NSLog(@"Restoring session for %@...", emailAddress);
    
    [self clearAllSessions];
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSString *cookieKey = [NSString stringWithFormat:@"Cookies:%@", emailAddress];
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:cookieKey];
    
    if (!data || [data length] <= 0)
        return NO;
    
    NSArray *cookies = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!cookies)
        return NO;
    
    for (NSHTTPCookie *cookie in cookies)
        [cookieStorage setCookie:cookie];
    
    return YES;
}

-(void)saveSessionForAccount:(XboxLiveAccount*)account
{
    [self saveSessionForEmailAddress:account.emailAddress];
}

-(void)saveSessionForEmailAddress:(NSString*)emailAddress
{
    NSLog(@"Saving session for %@...", emailAddress);
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSString *cookieKey = [NSString stringWithFormat:@"CookiesFor", emailAddress];
    NSArray *cookies = [cookieStorage cookies];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if ([cookies count] > 0)
    {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:cookies];
        [prefs setObject:data 
                  forKey:cookieKey];
    }
    
    [prefs synchronize];
}

+(NSError*)errorWithCode:(NSInteger)code
                 message:(NSString*)message
{
    NSDictionary *info = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObject:message]
                                                     forKeys:[NSArray arrayWithObject:NSLocalizedDescriptionKey]];
    
    return [NSError errorWithDomain:BachErrorDomain
                               code:code
                           userInfo:info];
}

+(NSError*)errorWithCode:(NSInteger)code
         localizationKey:(NSString*)key
{
    return [self errorWithCode:code
                       message:NSLocalizedString(key, nil)];
}

-(BOOL)authenticateAccount:(XboxLiveAccount *)account
                     error:(NSError **)error
{
    return [self authenticate:account.emailAddress
                 withPassword:account.password
                        error:error];
}

-(BOOL)authenticate:(NSString*)emailAddress
       withPassword:(NSString*)password
              error:(NSError**)error
{
    [self clearAllSessions];
    
    NSLog(@"Authenticating...");
    
    BOOL isMsn = [emailAddress hasSuffix:@"@msn.com"];
    NSString *url = [NSString stringWithFormat:isMsn ? URL_LOGIN_MSN : URL_LOGIN, 
                     URL_REPLY_TO];
    
    NSTextCheckingResult *match;
    
    NSString *loginPage = [self loadWithGET:url
                                     fields:nil
                                     useXhr:NO
                                      error:error];
    
    if (!loginPage)
        return NO;
    
    NSRegularExpression *getLiveAuthUrl = [NSRegularExpression regularExpressionWithPattern:PATTERN_LOGIN_LIVE_AUTH_URL
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:NULL];
    
    match = [getLiveAuthUrl firstMatchInString:loginPage
                                       options:0
                                         range:NSMakeRange(0, [loginPage length])];
    
    if (!match)
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPParsingError
                                   localizationKey:@"ErrorLoginStageOne"];
        }
        
        NSLog(@"Authentication failed in stage 1: URL");
        return NO;
    }
    
    NSString *postUrl = [loginPage substringWithRange:[match rangeAtIndex:1]];
    
    if (isMsn)
        postUrl = [postUrl stringByReplacingOccurrencesOfString:@"://login.live.com/" 
                                                     withString:@"://msnia.login.live.com/"];
    
    NSRegularExpression *getPpsxValue = [NSRegularExpression regularExpressionWithPattern:PATTERN_LOGIN_PPSX
                                                                                  options:0
                                                                                    error:NULL];
    
    match = [getPpsxValue firstMatchInString:loginPage
                                     options:0
                                       range:NSMakeRange(0, [loginPage length])];
    
    if (!match)
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPParsingError
                                   localizationKey:@"ErrorLoginStageOne"];
        }
        
        NSLog(@"Authentication failed in stage 1: PPSX");
        return NO;
    }
    
    NSString *ppsx = [loginPage substringWithRange:[match rangeAtIndex:1]];
    
    NSMutableDictionary *inputs = [XboxLiveParser getInputs:loginPage
                                                namePattern:nil];
    
    [inputs setValue:emailAddress forKey:@"login"];
    [inputs setValue:password forKey:@"passwd"];
    [inputs setValue:@"1" forKey:@"LoginOptions"];
    [inputs setValue:ppsx forKey:@"PPSX"];
    
    NSString *loginResponse = [self loadWithPOST:postUrl
                                          fields:inputs
                                          useXhr:NO
                                           error:error];
    
    if (!loginResponse)
        return NO;
    
    NSString *redirUrl = [XboxLiveParser getActionUrl:loginResponse];
    
    inputs = [XboxLiveParser getInputs:loginResponse
                           namePattern:nil];
    
    if (![inputs objectForKey:@"ANON"])
    {
        if (error)
        {
            *error = [XboxLiveParser errorWithCode:XBLPAuthenticationError
                                   localizationKey:@"ErrorLoginInvalidCredentials"];
        }
        
        NSLog(@"Authentication failed in stage 2");
        return NO;
    }
    
    if (![self loadWithPOST:redirUrl
                     fields:inputs
                     useXhr:NO
                      error:error])
    {
        return NO;
    }
    
    [self saveSessionForEmailAddress:emailAddress];
    
    return YES;
}

#pragma mark Helpers

+(NSNumber*)getStarRatingFromPage:(NSString*)html
{
    NSArray *starClasses = [NSArray arrayWithObjects:@"empty", @"quarter", 
                            @"half", @"threequarter", @"full", nil];
    NSRegularExpression *starMatcher = [NSRegularExpression regularExpressionWithPattern:PATTERN_GAMERCARD_REP
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:nil];
    
    __block NSUInteger rating = 0;
    [starMatcher enumerateMatchesInString:html 
                                  options:0
                                    range:NSMakeRange(0, [html length])
                               usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) 
     {
         NSString *starClass = [html substringWithRange:[result rangeAtIndex:1]];
         NSUInteger starValue = [starClasses indexOfObject:[starClass lowercaseString]];
         
         if (starValue != NSNotFound)
             rating += starValue;
     }];
    
    return [NSNumber numberWithUnsignedInteger:rating];
}

+(NSDictionary*)jsonObjectFromPage:(NSString*)json
                             error:(NSError**)error
{
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSDictionary *dict = [parser objectWithString:json 
                                            error:nil];
    [parser release];
    
    if (!dict)
    {
        if (error)
        {
            *error = [self errorWithCode:XBLPParsingError
                         localizationKey:@"ErrorParsingJSONFormat"];
        }
        
        return nil;
    }
    
    return dict;
}

+(NSDictionary*)jsonDataObjectFromPage:(NSString*)json
                                 error:(NSError**)error
{
    NSDictionary *object = [XboxLiveParser jsonObjectFromPage:json
                                                        error:error];
    
    if (!object)
        return nil;
    
    if (![[object objectForKey:@"Success"] boolValue])
    {
        if (error)
        {
            *error = [self errorWithCode:XBLPGeneralError
                         localizationKey:@"ErrorJSONDidNotSucceed"];
        }
        
        return nil;
    }
    
    return [object objectForKey:@"Data"];
}

+(NSDate*)getTicksFromJSONString:(NSString*)jsonTicks
{
    if (!jsonTicks)
        return [NSDate distantPast];
    
    NSRegularExpression *extractJson = [NSRegularExpression
                                        regularExpressionWithPattern:PATTERN_EXTRACT_TICKS
                                        options:0
                                        error:nil];
    
    NSTextCheckingResult *match = [extractJson
                                   firstMatchInString:jsonTicks
                                   options:0
                                   range:NSMakeRange(0, [jsonTicks length])];
    
    if (!match)
        return [NSDate distantPast];
    
    NSString *ticks = [jsonTicks substringWithRange:[match rangeAtIndex:1]];
    return [NSDate dateWithTimeIntervalSince1970:([ticks doubleValue]/1000.0)];
}

+(NSDictionary*)jsonObjectFromLive:(NSString*)script
                             error:(NSError**)error
{
    NSRegularExpression *extractJson = [NSRegularExpression
                                        regularExpressionWithPattern:PATTERN_EXTRACT_JSON
                                        options:0
                                        error:nil];
    
    NSTextCheckingResult *match = [extractJson
                                   firstMatchInString:script
                                   options:0
                                   range:NSMakeRange(0, [script length])];
    
    if (!match)
    {
        if (error)
        {
            *error = [self errorWithCode:XBLPParsingError
                         localizationKey:@"ErrorParsingJSONFormat"];
        }
        
        return nil;
    }
    
    NSString *json = [script substringWithRange:[match rangeAtIndex:1]];
    
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSDictionary *dict = [parser objectWithString:json 
                                            error:nil];
    [parser release];
    
    return dict;
}

+(NSString*)getActionUrl:(NSString*)text
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:PATTERN_LOGIN_ACTION_URL
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    
    NSTextCheckingResult *match = [regex firstMatchInString:text
                                                    options:0
                                                      range:NSMakeRange(0, [text length])];
    
    if (match)
        return [text substringWithRange:[match rangeAtIndex:1]];
    
    return nil;
}

+(NSMutableDictionary*)getInputs:(NSString*)response
                     namePattern:(NSRegularExpression*)namePattern
{
    NSMutableDictionary *inputs = [[NSMutableDictionary alloc] init];
    
    NSError *error = nil;
    NSRegularExpression *allAttrs = [NSRegularExpression regularExpressionWithPattern:PATTERN_LOGIN_ATTR_LIST
                                                                              options:NSRegularExpressionCaseInsensitive
                                                                                error:&error];
    
    NSRegularExpression *attrs = [NSRegularExpression regularExpressionWithPattern:PATTERN_LOGIN_GET_ATTRS
                                                                           options:0
                                                                             error:&error];
    
    [allAttrs enumerateMatchesInString:response 
                               options:0
                                 range:NSMakeRange(0, [response length])
                            usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) 
     {
         __block NSString *name = nil;
         __block NSString *value = nil;
         
         NSString *chunk = [response substringWithRange:[result rangeAtIndex:1]];
         
         [attrs enumerateMatchesInString:chunk 
                                 options:0
                                   range:NSMakeRange(0, [chunk length])
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) 
          {
              NSString *attrName = [chunk substringWithRange:[result rangeAtIndex:1]];
              NSString *attrValue = [chunk substringWithRange:[result rangeAtIndex:2]];
              
              if ([attrName caseInsensitiveCompare:@"name"] == NSOrderedSame)
                  name = attrValue;
              else if ([attrName caseInsensitiveCompare:@"value"] == NSOrderedSame)
                  value = attrValue;
          }];
         
         if (name != nil && value != nil)
         {
             BOOL add = true;
             
             if (namePattern != nil)
             {
                 NSTextCheckingResult *match = [namePattern firstMatchInString:name
                                                                       options:0
                                                                         range:NSMakeRange(0, [name length])];
                 
                 if (!match)
                     add = false;
             }
             
             if (add)
             {
                 for (NSString *key in inputs)
                 {
                     if ([key isEqualToString:name])
                     {
                         add = false;
                         break;
                     }
                 }
             }
             
             if (add)
                 [inputs setValue:value 
                           forKey:name];
         }
     }];
    
    return [inputs autorelease];
}

-(NSString*)parseObtainNewToken
{
    NSString *page = [self loadWithGET:[NSString stringWithFormat:URL_VTOKEN, LOCALE]
                                fields:nil
                                useXhr:NO
                                 error:NULL];
    
    if (!page)
        return nil;
    
    NSMutableDictionary *inputs = [XboxLiveParser getInputs:page
                                                namePattern:nil];
    
    if (!inputs)
        return nil;
    
    return [inputs objectForKey:@"__RequestVerificationToken"];
}

#pragma mark Core stuff

- (NSString*)loadWithMethod:(NSString*)method
                        url:(NSString*)requestUrl
                     fields:(NSDictionary*)fields
                 addHeaders:(NSDictionary*)headers
                     useXhr:(BOOL)useXhr
                      error:(NSError**)error
{
    NSString *httpBody = nil;
    NSURL *url = [NSURL URLWithString:requestUrl];
    
    NSLog(@"Fetching %@ ...", requestUrl);
    
    if (fields)
    {
        NSMutableArray *urlBuilder = [[NSMutableArray alloc] init];
        
        for (NSString *key in fields)
        {
            NSString *ueKey = [key gtm_stringByEscapingForURLArgument];
            NSString *ueValue = [[fields objectForKey:key] gtm_stringByEscapingForURLArgument];
            
            [urlBuilder addObject:[NSString stringWithFormat:@"%@=%@", ueKey, ueValue]];
        }
        
        httpBody = [urlBuilder componentsJoinedByString:@"&"];
        [urlBuilder release];
    }
    
    NSUInteger bodyLength = [httpBody lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"text/javascript, text/html, application/xml, text/xml, */*", @"Accept",
                                       @"ISO-8859-1,utf-8;q=0.7,*;q=0.7", @"Accept-Charset",
                                       [NSString stringWithFormat:@"%d", bodyLength], @"Content-Length",
                                       @"application/x-www-form-urlencoded", @"Content-Type",
                                       nil];
    
    if (useXhr)
    {
        [allHeaders setObject:@"XMLHttpRequest" 
                       forKey:@"X-Requested-With"];
    }
    
    if (headers)
    {
        for (NSString *header in headers)
            [allHeaders setObject:[headers objectForKey:header] 
                           forKey:header];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:TIMEOUT_SECONDS];
    
    [request setHTTPMethod:method];
    [request setHTTPBody:[httpBody dataUsingEncoding:NSUTF8StringEncoding]];
    [request setAllHTTPHeaderFields:allHeaders];
    
    NSURLResponse *response = nil;
    NSError *netError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&netError];
    
    if (!data)
    {
        if (error && netError)
        {
            *error = [XboxLiveParser errorWithCode:XBLPNetworkError
                                           message:[netError localizedDescription]];
        }
        
        return nil;
    }
    
    return [[[NSString alloc] initWithData:data 
                                  encoding:NSUTF8StringEncoding] autorelease];
}

- (NSString*)loadWithGET:(NSString*)url 
                  fields:(NSDictionary*)fields
                  useXhr:(BOOL)useXhr
                   error:(NSError**)error
{
    return [self loadWithMethod:@"GET"
                            url:url
                         fields:fields
                     addHeaders:nil
                         useXhr:useXhr
                          error:error];
}

- (NSString*)loadWithPOST:(NSString*)url 
                   fields:(NSDictionary*)fields
                   useXhr:(BOOL)useXhr
                    error:(NSError**)error
{
    return [self loadWithMethod:@"POST"
                            url:url
                         fields:fields
                     addHeaders:nil
                           useXhr:useXhr
                          error:error];
}

@end