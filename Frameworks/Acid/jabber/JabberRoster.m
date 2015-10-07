//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
//     Copyright (C) 2002 David Waite (mass@akuma.org)
// 
// $Id: JabberRoster.m,v 1.5 2005/05/05 05:11:55 gbooker Exp $
//============================================================================

#import "acid.h"

NSString* XP_ROSTERPUSH = @"/iq[@type='set']/query[%jabber:iq:roster]";

@interface JRItem : NSObject <JabberRosterItem>
{
    NSString* _subscription;
}
+(instancetype) itemWithJID:(JabberID*)jid;

@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, readonly, strong) JabberID *JID;
@property (nonatomic, readonly, copy) NSString *JIDString;
@property (nonatomic, readwrite, strong) id defaultPresence;

-(void) setGroups:(NSMutableSet*)groups withDelegate:(id)delegate;
@end

@implementation JRItem
@synthesize JID = _jid;
@synthesize displayName = _nickname;
@synthesize groups = _groups;

+(instancetype) itemWithJID:(JabberID*)jid
{
    JRItem* result = [[JRItem alloc] init];
    result->_jid = jid;
    return result;
}

-(NSString*) displayName
{
    return ([_nickname length] != 0) ? _nickname : [_jid username];
}

-(NSString*)  displayNameWithJID
{
    if ([_nickname length] != 0)
        return [NSString stringWithFormat:@"%@ (%@)", _nickname, [_jid userhost]];
    else
        return [_jid userhost];
}

-(NSString*) JIDString
{
    return [_jid description];
}

-(void) setGroups:(NSMutableSet*)groups withDelegate:(id)delegate
{
    // Setup enumerator stuff
    NSMutableSet* oldgroups;

    // Shortcut out if there are no groups
    if ([groups count] == 0)
    {
        // Notify delegate that all old groups (if any) are 
        // getting deleted
        for (id cur in _groups)
        {
            if (cur != nil)
                [delegate onItem:self removedFromGroup:cur];
        }

        // Release all the old groups
        _groups = [NSSet setWithObject:@"Unfiled"];
        [delegate onItem:self addedToGroup:@"Unfiled"];

        return;
    }

    // Save old groups for comparison work
    oldgroups = [NSMutableSet setWithSet:_groups];

    // Update groups to point to new final group set
    _groups = [[NSSet alloc] initWithSet:groups];

    // Determine groups which have been added (new - old)
    [groups minusSet:oldgroups];
    for (id cur in groups)
        [delegate onItem:self addedToGroup:cur];

    // Determine groups which need to be removed (old - new)
    [oldgroups minusSet:_groups];
    for (id cur in oldgroups)
    {
        [delegate onItem:self removedFromGroup:cur];
    }
}

@end

@implementation JabberRoster
{
    __weak JabberSession *_session;
    NSMutableDictionary* _items;
    XPathQuery* _groups_query;
    BOOL _viewOnlineOnly;
}
@synthesize delegate = _delegate;

-(void) parseItems:(NSArray*)items
{
    for (XMLElement *cur in items)
    {
        JabberID* jid = [JabberID withString:[cur getAttribute:@"jid"]];
        NSString* nick = [cur getAttribute:@"name"];

        NSMutableSet* groups =
	    [NSMutableSet setWithArray:[_groups_query queryForStringList:cur]];

        if (jid == nil)
        {
            NSLog(@"Invalid JabberID: %@", [cur getAttribute:@"jid"]);
            continue;
        }

        BOOL remove = [[cur getAttribute:@"subscription"] isEqual:@"remove"];
        JRItem* item = _items[[jid userhostJID]];

        if (remove)
        {
            // How did we get here? Remove for something which doesn't exist..guess
            // we just move along
            if (item == nil)
                continue;

            // Cleanup all groups
            for (id group_cur in item.groups)
                [_delegate onItem:item removedFromGroup:group_cur];

            // Remove the item
            [_items removeObjectForKey:[jid userhostJID]];
            continue;
        }
        else
        {
            if (item == nil)
            {
                item = [JRItem itemWithJID:jid];
                _items[[jid userhostJID]] = item;
            }

            [item setDisplayName:(nick != nil) ? nick : @""];

            // Process groups
            [item setGroups:groups withDelegate:_delegate];
        }
    }
}

-(id) copyWithZone:(NSZone*)zone
{
    return self;
}

-(instancetype) initWithSession:(JabberSession*)session
{
	if (!(self = [super init])) return nil;
    _session = session;
    [_session addObserver:self selector:@selector(onSessionStarted:)
                     name: JSESSION_STARTED];
    [_session addObserver:self selector:@selector(onRosterPush:)
                    xpath:XP_ROSTERPUSH];
    [_session addObserver:self selector:@selector(onDefaultPresenceChange:)
                     name:JPRESENCE_JID_DEFAULT_CHANGED];
    [_session addObserver:self selector:@selector(onUnavailable:)
                     name:JPRESENCE_JID_UNAVAILABLE];
    _groups_query = [[XPathQuery alloc] initWithPath:@"/item/group"];
    return self;
}

-(void) dealloc
{
    [_session removeObserver:self];
}

-(void) onSessionStarted:(NSNotification*)n
{
    // Setup items data structure
    _items = [[NSMutableDictionary alloc] initWithCapacity:50];

    // Construct IQ to do initial roster retrieval
    JabberIQ* iq = [JabberIQ constructIQGet:@"jabber:iq:roster" withSession:_session];
    [iq setObserver:self withSelector:@selector(onInitialRosterPush:)];
    [iq execute];
}

-(void) onRosterPush:(NSNotification*)n
{
	@autoreleasepool {
		NSArray* items = [XPathQuery queryForList:[n object] xpath:@"/iq/query/item"];
		[_delegate onBeginUpdate];
		[self parseItems:items];
		[_delegate onEndUpdate];
	}
}

-(void) onInitialRosterPush:(NSNotification*)n
{
    [self onRosterPush:n];
    [_session postNotificationName:JSESSION_INITIAL_ROSTER object:nil];
}


-(void) onDefaultPresenceChange:(NSNotification*)n
{
    JabberPresence* pres = [n object];
    JRItem* item = _items[[[pres from] userhostJID]];

    JabberPresence* default_presence = 
	[[_session presenceTracker] defaultPresenceForJID:[pres from]];
    [item setDefaultPresence:default_presence];
}

-(void) onUnavailable:(NSNotification*)n
{
    JabberID* jid = [n object];
    JRItem* item = _items[[jid userhostJID]];
    [item setDefaultPresence:nil];
}

-(void) onSessionEnded:(NSNotification*)n
{
    _items = nil;
}

-(NSEnumerator*) itemEnumerator
{
    return [_items objectEnumerator];
}

-(id) itemForJID:(JabberID*)jid
{
    return _items[[jid userhostJID]];
}

-(NSString*) nickForJID:(JabberID*)jid
{
    id item = _items[[jid userhostJID]];
    if (item != NULL)
        return [item displayName];
    else
        return [jid userhost];
}

-(void) updateJabberID:(JabberID*)jid withNickname:(NSString*)name andGroups:(NSSet*)groups
{
    // Construct IQ to do roster set
    JabberIQ *iq = [JabberIQ constructIQSet:@"jabber:iq:roster" withSession:_session];

    XMLElement *item = [(XMLElement *)[iq firstChild] addElementWithName:@"item"];
    [item putAttribute:@"jid" withValue:[jid userhost]];
    if (name)
        [item putAttribute:@"name" withValue:name];

    for (NSString *groupName in groups) {
        XMLElement *elem = [item addElementWithName:@"group"];
        [elem addCData:groupName];
    }

    [iq setObserver:self withSelector:@selector(onRosterResult:)];
    [iq execute];
}

-(void) removeJabberID:(JabberID*)jid
{
    // Construct IQ to do roster set
    JabberIQ *iq = [JabberIQ constructIQSet:@"jabber:iq:roster" withSession:_session];

    XMLElement *item = [[iq queryElement] addElementWithName:@"item"];
    [item putAttribute:@"jid" withValue:[jid userhost]];
    [item putAttribute:@"subscription" withValue:@"remove"];

    [iq setObserver:self withSelector:@selector(onRosterResult:)];
    [iq execute];
}

- (void)onRosterResult:(NSNotification *)n
{
    // XXX: There should probably be some code for handling errors here.
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [_items countByEnumeratingWithState:state objects:buffer count:len];
}

@end
