//
//  XboxLiveParser.h
//  ListTest
//
//  Created by Akop Karapetyan on 8/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XboxLiveAccount.h"

extern NSString* const BachErrorDomain;

typedef enum _XboxLiveParserErrorType
{
    XBLPGeneralError = 0,
    XBLPAuthenticationError = 1,
    XBLPNetworkError = 2,
    XBLPParsingError = 3,
    XBLPCoreDataError = 4,
} XboxLiveParserErrorType;

@interface XboxLiveParser : NSObject

@property (nonatomic, retain) NSManagedObjectContext *context;

-(id)initWithManagedObjectContext:(NSManagedObjectContext*)context;

-(BOOL)authenticate:(NSString*)emailAddress
       withPassword:(NSString*)password
              error:(NSError**)error;

// Retrieve* are expected to be called from background threads, and have a
// valid autorelease pool. They don't need a managed context
-(NSDictionary*)retrieveProfileWithEmailAddress:(NSString*)emailAddress
                                       password:(NSString*)password
                                          error:(NSError**)error;
-(NSDictionary*)retrieveGamesWithEmailAddress:(NSString*)emailAddress
                                     password:(NSString*)password
                                        error:(NSError**)error;

// Synchronize* are expected to be called from the main thread
-(BOOL)synchronizeProfileWithAccount:(XboxLiveAccount*)account
                 withRetrievedObject:(NSDictionary*)retrieved
                               error:(NSError**)error;
-(BOOL)synchronizeGamesWithAccount:(XboxLiveAccount*)account
               withRetrievedObject:(NSDictionary*)retrieved
                             error:(NSError**)error;

@end
