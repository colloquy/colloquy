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
    JabberID* _jid;
    NSString* _nickname;
    NSString* _subscription;
    NSSet*    _groups;
    id        _defaultPresence;
}
+(id) itemWithJID:(JabberID*)jid;
-(void) dealloc;

-(NSString*) displayName;
-(JabberID*) JID;
-(NSString*) JIDString;
-(NSSet*)    groups;
-(id)        defaultPresence;

-(void) setDefaultPresence:(id)defaultPres;
-(void) setDisplayName:(NSString*)name;
-(void) setGroups:(NSMutableSet*)groups withDelegate:(id)delegate;
@end

@implementation JRItem

+(id) itemWithJID:(JabberID*)jid
{
    JRItem* result = [[JRItem alloc] init];
    result->_jid = [jid retain];
    [result autorelease];
    return result;
}

-(void) dealloc
{
    [_jid release];
    [_nickname release];
    [_subscription release];
    [_groups release];
    [super dealloc];
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


-(JabberID*) JID
{
    return _jid;
}

-(NSString*) JIDString
{
    return [_jid description];
}

-(NSSet*) groups
{
    return _groups;
}

-(id) defaultPresence
{
    return _defaultPresence;
}

-(void) setDefaultPresence:(id)defaultPres
{
    [_defaultPresence release];
    _defaultPresence = [defaultPres retain];
}

-(void) setDisplayName:(NSString*)name
{
    [_nickname release];
    _nickname = [name retain];
}

-(void) setGroups:(NSMutableSet*)groups withDelegate:(id)delegate
{
    // Setup enumerator stuff
    NSEnumerator* e;
    id cur;
    NSMutableSet* oldgroups;

    // Shortcut out if there are no groups
    if ([groups count] == 0)
    {
        // Notify delegate that all old groups (if any) are 
        // getting deleted
        e = [_groups objectEnumerator];
        while ((cur = [e nextObject]))
        {
            if (cur != nil)
                [delegate onItem:self removedFromGroup:cur];
        }

        // Release all the old groups
        [_groups release];
        _groups = [[NSSet setWithObject:@"Unfiled"] retain];
        [delegate onItem:self addedToGroup:@"Unfiled"];

        return;
    }

    // Save old groups for comparison work
    oldgroups = [NSMutableSet setWithSet:_groups];

    // Update groups to point to new final group set
    [_groups release];
    _groups = [[NSSet setWithSet:groups] retain];

    // Determine groups which have been added (new - old)
    [groups minusSet:oldgroups];
    e = [groups objectEnumerator];
    while ((cur = [e nextObject]))
        [delegate onItem:self addedToGroup:cur];

    // Determine groups which need to be removed (old - new)
    [oldgroups minusSet:_groups];
    e = [oldgroups objectEnumerator];
    while ((cur = [e nextObject]))
        [delegate onItem:self removedFromGroup:cur];
}

@end

@implementation JabberRoster

-(void) parseItems:(NSArray*)items
{
    NSEnumerator* e = [items objectEnumerator];
    XMLElement* cur;
    while ((cur = [e nextObject]))
    {
        JabberID* jid = [JabberID withString:[cur getAttribute:@"jid"]];
        NSString* nick = [cur getAttribute:@"name"];
        bool remove;
        JRItem* item;

        NSMutableSet* groups =
	    [NSMutableSet setWithArray:[_groups_query queryForStringList:cur]];

        if (jid == nil)
        {
            NSLog(@"Invalid JabberID: %@", [cur getAttribute:@"jid"]);
            continue;
        }

        remove = [[cur getAttribute:@"subscription"] isEqual:@"remove"];
        item = [_items objectForKey:[jid userhostJID]];

        if (remove)
        {
            NSEnumerator* group_itr;
            id group_cur;
            // How did we get here? Remove for something which doesn't exist..guess
            // we just move along
            if (item == nil)
                continue;

            // Cleanup all groups
            group_itr = [[item groups] objectEnumerator];
            while ((group_cur = [group_itr nextObject]))
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
                [_items setObject:item forKey:[jid userhostJID]];
            }

            [item setDisplayName:(nick != nil) ? nick : @""];

            // Process groups
            [item setGroups:groups withDelegate:_delegate];
        }
    }
}

-(id) copyWithZone:(NSZone*)zone
{
    return [self retain];
}

-(id) initWithSession:(id)session
{
    [super init];
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
    [_items release];
    [_groups_query release];
    [super dealloc];
}

-(void) onSessionStarted:(NSNotification*)n
{
    JabberIQ* iq;
    // Setup items data structure
    _items = [[NSMutableDictionary alloc] initWithCapacity:50];

    // Construct IQ to do initial roster retrieval
    iq = [JabberIQ constructIQGet:@"jabber:iq:roster" withSession:_session];
    [iq setObserver:self withSelector:@selector(onInitialRosterPush:)];
    [iq execute];
}

-(void) onRosterPush:(NSNotification*)n
{
    NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
    NSArray* items = [XPathQuery queryForList:[n object] xpath:@"/iq/query/item"];
    [_delegate onBeginUpdate];
    [self parseItems:items];
    [_delegate onEndUpdate];
    [p release];
}

-(void) onInitialRosterPush:(NSNotification*)n
{
    [self onRosterPush:n];
    [_session postNotificationName:JSESSION_INITIAL_ROSTER object:nil];
}


-(void) onDefaultPresenceChange:(NSNotification*)n
{
    JabberPresence* pres = [n object];
    JRItem* item = [_items objectForKey:[[pres from] userhostJID]];

    JabberPresence* default_presence = 
	[[_session presenceTracker] defaultPresenceForJID:[pres from]];
    [item setDefaultPresence:default_presence];
}

-(void) onUnavailable:(NSNotification*)n
{
    JabberID* jid = [n object];
    JRItem* item = [_items objectForKey:[jid userhostJID]];
    [item setDefaultPresence:nil];
}

-(void) onSessionEnded:(NSNotification*)n
{
    [_items release];
    _items = nil;
}

-(id) delegate
{
    return _delegate;
}

-(void) setDelegate:(id)delegate
{
    _delegate = delegate;
}

-(NSEnumerator*) itemEnumerator
{
    return [_items objectEnumerator];
}

-(id) itemForJID:(JabberID*)jid
{
    return [_items objectForKey:[jid userhostJID]];
}

-(NSString*) nickForJID:(JabberID*)jid
{
    id item = [_items objectForKey:[jid userhostJID]];
    if (item != NULL)
        return [item displayName];
    else
        return [jid userhost];
}

-(void) updateJabberID:(JabberID*)jid withNickname:(NSString*)name andGroups:(NSSet*)groups
{
    NSString *groupName;
    JabberIQ *iq;
    XMLElement *item;
    NSEnumerator *e;
    
    // Construct IQ to do roster set
    iq = [JabberIQ constructIQSet:@"jabber:iq:roster" withSession:_session];

    item = [(XMLElement *)[iq firstChild] addElementWithName:@"item"];
    [item putAttribute:@"jid" withValue:[jid userhost]];
    if (name)
        [item putAttribute:@"name" withValue:name];

    e = [groups objectEnumerator];
    while ((groupName = [e nextObject]))
    {
        XMLElement *elem = [item addElementWithName:@"group"];
        [elem addCData:groupName];
    }

    [iq setObserver:self withSelector:@selector(onRosterResult:)];
    [iq execute];
}

-(void) removeJabberID:(JabberID*)jid
{
    JabberIQ *iq;
    XMLElement *item;

    // Construct IQ to do roster set
    iq = [JabberIQ constructIQSet:@"jabber:iq:roster" withSession:_session];

    item = [[iq queryElement] addElementWithName:@"item"];
    [item putAttribute:@"jid" withValue:[jid userhost]];
    [item putAttribute:@"subscription" withValue:@"remove"];

    [iq setObserver:self withSelector:@selector(onRosterResult:)];
    [iq execute];
}

- (void)onRosterResult:(NSNotification *)n
{
    // XXX: There should probably be some code for handling errors here.
    //NSLog(@"Roster update result: %@", n);
}

@end
