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

#import "ViewMessageController.h"

#import "TaskController.h"

#import "ProfileController.h"
#import "MessageCompositionController.h"

#define OK_BUTTON_INDEX 1

@interface ViewMessageController (Private)

-(BOOL)updateMessage;

@end

@implementation ViewMessageController

@synthesize senderLabel = _senderLabel;
@synthesize sender = _sender;
@synthesize sent = _sent;
@synthesize messageBody = _messageBody;
@synthesize replyButton;

@synthesize senderScreenName = _senderScreenName;
@synthesize messageUid = _messageUid;

-(id)initWithUid:(NSString*)uid
         account:(XboxLiveAccount*)account
{
    if (self = [super initWithAccount:account
                              nibName:@"ViewMessageController"])
    {
        self.messageUid = uid;
        self.senderScreenName = nil;
    }
    
    return self;
}

-(void)dealloc
{
    self.messageUid = nil;
    self.senderScreenName = nil;
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncCompleted:)
                                                 name:BACHMessageSynced
                                               object:nil];
    
    self.senderLabel.text = NSLocalizedString(@"FromColon", nil);
    self.title = NSLocalizedString(@"Message", nil);
    
    if ([self updateMessage])
    {
        [[TaskController sharedInstance] syncMessageWithUid:self.messageUid
                                                    account:self.account
                                       managedObjectContext:managedObjectContext];
    }
    
    self.replyButton.enabled = [self.account canSendMessages];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BACHMessageSynced
                                                  object:nil];
}

-(void)alertView:(UIAlertView *)alertView 
clickedButtonAtIndex:(NSInteger)buttonIndex 
{
    if (buttonIndex == OK_BUTTON_INDEX)
    {
        [[TaskController sharedInstance] deleteMessageWithUid:self.messageUid
                                                      account:self.account
                                         managedObjectContext:managedObjectContext];
        
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Notification delegates

- (void)imageLoaded:(NSString*)url
{
    [self updateMessage];
}

-(void)syncCompleted:(NSNotification *)notification
{
    BACHLog(@"Got sync completed notification");
    
    XboxLiveAccount *account = [notification.userInfo objectForKey:BACHNotificationAccount];
    NSString *uid = [notification.userInfo objectForKey:BACHNotificationUid];
    
    if ([account isEqualToAccount:self.account] && 
        [uid isEqualToString:self.messageUid])
    {
        [self updateMessage];
    }
}

#pragma mark - Actions

- (IBAction)viewSenderProfile:(id)sender
{
    [ProfileController showProfileWithScreenName:self.senderScreenName
                                         account:self.account
                            managedObjectContext:managedObjectContext
                            navigationController:self.navigationController];
}

-(IBAction)refresh:(id)sender
{
    [[TaskController sharedInstance] syncMessageWithUid:self.messageUid
                                                account:self.account
                                   managedObjectContext:managedObjectContext];
}

-(IBAction)deleteMessage:(id)sender
{
    NSString *title = NSLocalizedString(@"AreYouSure", nil);
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"DeleteMessageFrom_f", nil),
                         self.senderScreenName];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title 
                                                        message:message
                                                       delegate:self 
                                              cancelButtonTitle:NSLocalizedString(@"Cancel",nil) 
                                              otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
    
    [alertView show];
    [alertView release];
}

-(IBAction)replyToMessage:(id)sender
{
    if (self.senderScreenName)
    {
        MessageCompositionController *ctlr = [[MessageCompositionController alloc] initWithRecipient:self.senderScreenName
                                                                                             account:self.account];
        
        [self.navigationController pushViewController:ctlr animated:YES];
        [ctlr release];
    }
}

#pragma mark - Misc

-(BOOL)updateMessage
{
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"XboxMessage"
                                                         inManagedObjectContext:managedObjectContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid == %@ AND profile.uuid == %@", 
                              self.messageUid, self.account.uuid];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    
    [request setEntity:entityDescription];
    [request setPredicate:predicate];
    
    NSManagedObject *message = [[managedObjectContext executeFetchRequest:request 
                                                                    error:nil] lastObject];
    
    [request release];
    
    if (!message)
        return YES; // message is dirty
    
    NSString *sent;
    NSString *messageBody = [message valueForKey:@"messageText"];
    self.senderScreenName = [message valueForKey:@"sender"];
    
    if (!messageBody || messageBody.length < 1)
        messageBody = NSLocalizedString(@"MessageHasNoText", nil);
    
    NSDateFormatter *fmtr = [[NSDateFormatter alloc] init];
    [fmtr setDateStyle:NSDateFormatterLongStyle];
    [fmtr setTimeStyle:NSDateFormatterShortStyle];
    sent = [fmtr stringFromDate:[message valueForKey:@"sent"]];
    [fmtr release];
    
    [self.sender setButtonText:self.senderScreenName];
    self.sent.text = sent;
    self.messageBody.text = messageBody;
    
    return [[message valueForKey:@"isDirty"] boolValue];
}

@end
