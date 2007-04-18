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
// 
// $Id: JabberIQ.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"

NSString* QUERY_PATH = @"/iq[@id='%@']";

@implementation JabberIQ

+(id) constructIQGet:(NSString*)namespace withSession:(JabberSession*)s
{
    // Setup base IQ
    JabberIQ* result = [[JabberIQ alloc] initWithSession:s];
    [result putAttribute:@"type" withValue:@"get"];

    // Create query element in the specificed namespace
    result->_query_elem = [result addElementWithQName:[XMLQName construct:@"query"
                                                                  withURI:namespace]
                                       withDefaultURI:namespace];

    return result;
}

+(id) constructIQSet:(NSString*)namespace withSession:(JabberSession*)s
{
    // Setup base IQ
    JabberIQ* result = [[JabberIQ alloc] initWithSession:s];
    [result putAttribute:@"type" withValue:@"set"];

    // Create query element in the specified namespace
    result->_query_elem = [result addElementWithQName:[XMLQName construct:@"query"
                                                                  withURI:namespace]
                                       withDefaultURI:namespace];

    return result;
}

-(id) initWithSession:(JabberSession*)s 
{
    [super initWithQName:JABBER_IQ_QN];
    _session = s;
    _query = [NSString stringWithFormat:QUERY_PATH, [self addUniqueIDAttribute]];
    [_query retain];
    return self;
}

-(void) dealloc
{
    [_query release];
    [super dealloc];
}

-(void) setObserver:(id)observer withSelector:(SEL)selector
{
    _observer = observer;
    _callback = selector;
    _object = nil;
}

-(void) setObserver:(id)observer withSelector:(SEL)selector object:(id)object
{
    _observer = observer;
    _callback = selector;
    _object = object;
}

-(XMLElement*) queryElement
{
    return _query_elem;
}

-(id) copyWithZone:(NSZone*)zone
{
    return [self retain];
}

-(void) executeTo:(JabberID*)targetjid;
{
    [self putAttribute:@"to" withValue:[targetjid completeID]];
    [self execute];
}

-(void) execute
{
    [_session addObserver:self selector:@selector(handleCallback:) xpath:_query];
    [_session sendElement:self];
}

-(void) handleCallback:(NSNotification*) n
{
    [_session removeObserver:self];
    [_observer performSelector:_callback withObject:n withObject:_object];
    // Eww...cleanup myself
    [self release];
}

-(JabberID*) from
{
    return [JabberID withString:[self getAttribute:@"from"]];
}

@end
