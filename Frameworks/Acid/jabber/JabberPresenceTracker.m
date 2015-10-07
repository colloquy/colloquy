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
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
//     Copyright (C) 2002 David Waite (mass@akuma.org)
// 
// $Id: JabberPresenceTracker.m,v 1.3 2005/05/05 05:11:55 gbooker Exp $
//============================================================================

#import "acid.h"

NSString* JPRESENCE_JID_DEFAULT_CHANGED = @"/presence/jid/defaultchanged";
NSString* JPRESENCE_JID_UNAVAILABLE = @"/presence/jid/defaultunavail";

/*!
 @class PGroup
 @abstract hold a group of related JabberPresence objects related to
 the same [node@]domain, but differing by resource.
 */
@interface PGroup : NSObject <NSFastEnumeration>
{
    NSMutableArray* _packets;
}
/*!
 @method initWithJID
 @abstract initialize around a userhost JID
 */
-(instancetype) initWithJID:(JabberID*)jid;

/*!
 @method presenceForJID
 @abstract return the JabberPresence object for a specific full JID
 */
-(JabberPresence*) presenceForJID:(JabberID*)j;

/*!
 @property userhostJID
 @abstract The userhost JID
 */
@property (readonly, strong) JabberID *userhostJID;

/*!
 @method updatePresence
 @abstract add a new presence to the group, updating any previous
 presence for the resource specified.
 @param pres the presence packet being added or replacing the item
 within the queue
 @return YES if this new entry becomes the default presence
 */
-(BOOL) updatePresence:(JabberPresence*)pres;

/*!
 @method removePresence
 @abstract remove a presence from the group
 @param pres the presence packet being removed
 @return YES if this removal causes another presence to become the
 default presence
 */
-(BOOL) removePresence:(JabberPresence*)pres;

/*!
 @property defaultPresence
 @abstract return the default presence for the group, being the
 presence with the highest priority
 */
@property (readonly, strong) JabberPresence *defaultPresence;

/*!
 @property empty
 @abstract return if the group contains no presence information
 */
@property (readonly, getter=isEmpty) BOOL empty;

/*!
 @method objectEnumerator
 @abstract return an enumerator for all contained presences
 */
-(NSEnumerator*)objectEnumerator;

@property (readonly) NSInteger count;

@end

@implementation PGroup
@synthesize userhostJID = _userhost_jid;

-(instancetype) initWithJID:(JabberID*)jid
{
	if (!(self = [super init])) return nil;
    _packets = [[NSMutableArray alloc] init];
    _userhost_jid = [jid userhostJID];
    return self;
}

-(JabberPresence*) presenceForJID:(JabberID*)j
{
    NSInteger i;
    NSInteger count = [_packets count];
    for (i = 0; i < count; i++)
    {
        JabberPresence* cur = _packets[i];
        if ([[cur from] isEqual:j])
	{
            return cur;
	}
    }
    return [self defaultPresence];
}

-(BOOL) updatePresence:(JabberPresence*)p
{
    NSInteger i = 0;
    NSInteger count;
    int priority = [p priority];
    // Check for an existing presence that matches this one
    [_packets removeObject:p];
    count = [_packets count];
    // Walk the list looking for a presence group with a priority
    // equal to or less than the new packet's priority
    while (i < count)
    {
        JabberPresence* cur = _packets[i];
        if (priority < [cur priority])
	{
	    ++i;
	}
	else
	{
            [_packets insertObject:p atIndex:i];
	    
            // If this item was inserted at the front of the array,
            // it is the new default presence
            return (i == 0) ? YES : NO;
        }
    }
    // No insert happened, add the presence packet at the end
    [_packets addObject:p];

    // If this item was inserted at the front of the array,
    // it is the new default presence
    return ([_packets count] == 1) ? YES : NO;
}

-(BOOL) removePresence:(JabberPresence*)p
{
    BOOL result = ([p isEqual:[self defaultPresence]] &&
		   ([_packets count] > 1));
    [_packets removeObject:p];
    return result;
}

-(BOOL) isEmpty
{
    return [_packets count] == 0;
}

-(NSInteger) count
{
    return [_packets count];
}

-(JabberPresence*) defaultPresence
{
    return _packets[0];
}

-(NSEnumerator*)objectEnumerator
{
    return [_packets objectEnumerator];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [_packets countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@implementation JabberPresenceTracker
{
    id _session;
    NSMutableDictionary* _items;
}
-(instancetype) initWithSession:(id)session
{
	if (!(self = [super init])) return nil;
    _items = [[NSMutableDictionary alloc] init];
    _session = session;
    [_session addObserver:self selector:@selector(onSessionStarted:)
                     name:JSESSION_STARTED];
    [_session addObserver:self selector:@selector(onSessionEnded:)
                     name:JSESSION_ENDED];
    return self;
}

-(void)dealloc
{
    [_session removeObserver:self];
}

-(void) onSessionStarted:(NSNotification*)n
{
    // Watch for presence changes related to availability
    [_session addObserver:self selector:@selector(onAvailPresence:)
                    xpath:@"/presence[!@type]"];
    [_session addObserver:self selector:@selector(onUnavailPresence:)
                    xpath:@"/presence[@type='unavailable']"];
    // Watch for unsubscription events
    [_session addObserver:self selector:@selector(onUnsubscribedPresence:)
                    xpath:@"/presence[@type='unsubscribed']"];
}

-(void) onSessionEnded:(NSNotification*)n
{
    [_session removeObserver:self xpath:@"/presence[!@type]"];
    [_session removeObserver:self xpath:@"/presence[@type='unavailable']"];
    [_session removeObserver:self xpath:@"/presence[@type='unsubscribed']"];
    // XXX: It may be desirable to fire notifications for all the presences
    // going unavailable
    _items = [[NSMutableDictionary alloc] init];
}

-(id) copyWithZone:(NSZone*)zone
{
    return self;
}

-(void) onAvailPresence:(NSNotification*)n
{
    JabberPresence* pres = [n object];
    JabberID* userhost_jid = [[pres from] userhostJID];

    // Lookup presence group in the tracker; add if the group isn't there.
    PGroup* pgroup = _items[userhost_jid];
    if (pgroup == nil)
    {
        pgroup = [[PGroup alloc] initWithJID:userhost_jid];
        _items[userhost_jid] = pgroup;
    }
    
    // If the updatePresence call indicates the default was changed,
    // generate the appropriate event
    if ([pgroup updatePresence:pres])
    {
        [_session postNotificationName:JPRESENCE_JID_DEFAULT_CHANGED
                                object:pres];
    }
}

-(void) onUnavailPresence:(NSNotification*)n
{
    JabberPresence* pres = [n object];
    JabberID* userhost_jid = [[pres from] userhostJID];

    // Lookup presence group in the tracker
    PGroup* pgroup = _items[userhost_jid];
    if (pgroup != nil)
    {
        // Remove this particular presence packet; return value indicates
        // if default presence for this JID has been affected/changed
        bool defaultChanged = [pgroup removePresence:pres];

        // If there are no more presence packets in this group (i.e. we've
        // removed the last one), fire the UNAVAILABLE event
        if ([pgroup isEmpty])
        {
            [_session postNotificationName:JPRESENCE_JID_UNAVAILABLE
                                    object:userhost_jid];
            [_items removeObjectForKey:userhost_jid];            
        }
        // Otherwise, fire an event only if the default presence packet
        // for this JID has changed
        else if (defaultChanged)
        {
            [_session postNotificationName:JPRESENCE_JID_DEFAULT_CHANGED
                                    object:pres];
        }
    }
}

-(void) onUnsubscribedPresence:(NSNotification*)n
{
    JabberSubscriptionRequest* r = [n object];
    JabberID* userhost_jid = [[r from] userhostJID];

    // Lookup presence group in the tracker
    PGroup* pgroup = _items[userhost_jid];
    if (pgroup != nil)
    {
        // Remove all presence packets and fire the appropriate events
        [_items removeObjectForKey:userhost_jid];
        [_session postNotificationName:JPRESENCE_JID_UNAVAILABLE object:userhost_jid];            
    }
}

-(id) defaultPresenceForJID:(JabberID*)jid
{
    PGroup* pgroup = _items[[jid userhostJID]];
    return [pgroup defaultPresence];
}

-(id) presenceForJID:(JabberID*)jid
{
    PGroup* pgroup = _items[[jid userhostJID]];
    return [pgroup presenceForJID:jid];
    
}
-(NSEnumerator*) presenceEnumeratorForJID:(JabberID*)jid
{
    PGroup* pgroup = _items[[jid userhostJID]];
    return [pgroup objectEnumerator];
}

-(NSInteger) presenceCountForJID:(JabberID*)jid
{
    PGroup* pgroup = _items[[jid userhostJID]];
    return [pgroup count];
}

@end


