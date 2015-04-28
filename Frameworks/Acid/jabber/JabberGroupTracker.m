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
// $Id: JabberGroupTracker.m,v 1.2 2004/11/09 20:12:23 gbooker Exp $
//============================================================================

#import "acid.h"
#import "NSMutableArray+InsertSort.h"

@interface JRGroup : NSObject <JabberGroup>
{
    NSString*       _name;
    NSMutableArray* _items;
}
+(instancetype) groupWithName: (NSString*) name;

@property NSUInteger index;

@property (nonatomic, readonly, copy) NSString *displayName;

-(BOOL) addItem: (id) item;
-(BOOL) removeItem: (id) item;

-(id) itemAtIndex: (NSUInteger) index;
@property (readonly) NSUInteger count;
@end

@implementation JRGroup
@synthesize displayName = _name;

+(id) groupWithName: (NSString*) name
{
    JRGroup* result = [[JRGroup alloc] init];
    result->_name = [name retain];
    [result autorelease];
    return result;
}

-(id) init
{
	if (!(self = [super init])) return nil;
    _items = [[NSMutableArray alloc] init];
    return self;
}

-(void) dealloc
{
    [_items release];
    [_name release];
    [super dealloc];
}

-(NSUInteger) count
{
    return [_items count];
}

-(BOOL) addItem: (id) item
{
   return [_items addObject: item
         sortStringSelector: @selector(displayName)] != -1;
}

-(BOOL) removeItem: (id) item
{
    unsigned long index = [_items indexOfObject: item];
    if (index != NSNotFound)
    {
        [_items removeObjectAtIndex: index];
        return YES;
    }
    else
    {
        return NO;
    }
}

-(id) itemAtIndex: (NSUInteger) index
{
    return _items[index];
}
@end

@implementation JabberGroupTracker
- (NSUInteger) count
{
    return [_groupArray count];
}

- (NSEnumerator *) groupEnumerator
{
    return [_groupArray objectEnumerator];
}

- (id) groupAtIndex: (NSUInteger) i
{
    return _groupArray[i];
}

-(BOOL) onAddedItem: (id)item
{
    BOOL retval = NO;
    id groupName;
    NSEnumerator *e = [[item groups] objectEnumerator];
    while ((groupName = [e nextObject]))
    {
        if ([self item: item addedToGroup: groupName])
        {
            retval = YES;
        }
    }
    return retval;
}

-(BOOL) onRemovedItem: (id)item
{
    BOOL retval = NO;
    id groupName;
    NSEnumerator *e = [[item groups] objectEnumerator];
    while ((groupName = [e nextObject]))
    {
        if ([self item: item removedFromGroup: groupName])
        {
            retval = YES;
        }
    }
    return retval;
}

- (id) init
{
    if ((self = [super init]))
    {
        _groups = [[NSMutableDictionary alloc] init];
        _groupArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id) initFromRoster: (JabberRoster*) roster withFilter: (id) object selector: (SEL) selector
{
    if ((self = [self init]))
    {
        id item;
        NSEnumerator *e;
        _groups = [[NSMutableDictionary alloc] init];
        _groupArray = [[NSMutableArray alloc] init];

        e = [roster itemEnumerator];
        while ((item = [e nextObject]))
        {
            if (object != nil)
            {
                id add_item = [object performSelector: selector withObject: item];
                if (add_item != nil)
                {
                    [self onAddedItem: item];
                }
            }
            else
            {
                [self onAddedItem: item];
            }
        }
    }
    return self;
}


- (id) initFromRoster: (JabberRoster*) roster
{
    return [self initFromRoster: roster withFilter: nil selector: nil];
}


- (void) dealloc
{
    [_groups release];
    [_groupArray release];
    [super dealloc];
}

-(BOOL) item: (id) item addedToGroup: (NSString*) groupName
{
    JRGroup* group = _groups[groupName];
    if (group == nil)
    {
        NSUInteger i;
        NSInteger index;
        group = [JRGroup groupWithName: groupName];
        _groups[groupName] = group;
        index = [_groupArray addObject: group
                    sortStringSelector: @selector(displayName)];
        assert (index != -1);
        [group setIndex: index];
        // now update all group indices
        for (i = index + 1; i < [_groupArray count]; i++)
        {
            JRGroup* cur_group = _groupArray[i];
            [cur_group setIndex: i];
        }
    }
    return [group addItem: item];
}

-(BOOL) item: (id) item removedFromGroup: (NSString*) groupName
{
    BOOL retval;
    JRGroup* group = _groups[groupName];
    assert(group != nil);
    retval = [group removeItem: item];
    if ([group count] == 0)
    {
        NSUInteger index;
        [_groupArray removeObjectAtIndex: [group index]];
        for (index = [group index]; index < [_groupArray count]; index++)
        {
            JRGroup* cur_group = _groupArray[index];
            [cur_group setIndex: index];
        }
        [_groups removeObjectForKey: groupName];
    }
    return retval;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [_groupArray countByEnumeratingWithState:state objects:buffer count:len];
}
@end
