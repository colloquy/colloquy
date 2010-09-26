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
//
//============================================================================

#import "acid.h"

NSString* JXML_SUB_REQUEST = @"/presence[@type='subscribe']";        // subscribe
NSString* JXML_SUB_GRANTED = @"/presence[@type='subscribed']";        // subscribed
NSString* JXML_SUB_CANCELED = @"/presence[@type='unsubscribed']";       // unsubscribed
NSString* JXML_SUB_CANCEL_REQUEST = @"/presence[@type='unsubscribe']"; // unsubscribe

@implementation JabberSubscriptionRequest

+(id) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri
{
    if ([qname isEqual:JABBER_PRESENCE_QN])
    {
        NSString* type = [atts objectForKey:JABBER_TYPE_ATTRIB_QN];
        if ([type isEqual:@"subscribe"] || [type isEqual:@"subscribed"] ||
            [type isEqual:@"unsubscribe"] || [type isEqual:@"unsubscribed"])
            return [[JabberSubscriptionRequest alloc] initWithQName:qname withAttributes:atts
                                                     withDefaultURI:default_uri];
        else
            return nil;
    }
    else
        return nil;
}

-(id) initWithRecipient:(JabberID*)jid
{
    [super initWithQName:JABBER_PRESENCE_QN];

    // Setup "to" attribute
    [self putAttribute:@"to" withValue:[jid completeID]];
    
    return self;
}

-(void) setup
{
    [self resync];
}

-(void) resync
{
    static XPathQuery *QRY_MESSAGE = nil;
    static NSDictionary *PRESSUBTYPE = nil;

    if(!QRY_MESSAGE)
        QRY_MESSAGE = [[XPathQuery alloc] initWithPath:@"/presence/status"];

    if(!PRESSUBTYPE) {
        PRESSUBTYPE = [[NSDictionary alloc] initWithObjectsAndKeys:
            [NSNumber numberWithLong:JSUBSCRIBE], @"subscribe",
            [NSNumber numberWithLong:JSUBSCRIBED], @"subscribed",
            [NSNumber numberWithLong:JUNSUBSCRIBE], @"unsubscribed",
            [NSNumber numberWithLong:JUNSUBSCRIBED], @"unsubscribed", nil];
    }

    [_to release];
    _to      = [[JabberID alloc] initWithString:[self getAttribute:@"to"]];
    [_from release];
    _from    = [[JabberID alloc] initWithString:[self getAttribute:@"from"]];
    [_message release];
    _message = [[QRY_MESSAGE queryForString:self] retain];
    _type    = [[PRESSUBTYPE objectForKey:[self getAttribute:@"type"]] longValue];
}


-(JabberSubscriptionType) type
{
    return _type;
}

-(NSString*) message
{
    return _message;
}

-(JabberID*) to
{
    return _to;
}

-(JabberID*) from
{
    return _from;
}

-(JabberSubscriptionRequest*) grant
{
    JabberSubscriptionRequest* r;

    r = [[JabberSubscriptionRequest alloc] initWithRecipient:_from];
    [r putAttribute:@"type" withValue:@"subscribed"];

    [r autorelease];
    return r;
}

-(JabberSubscriptionRequest*) deny
{
    JabberSubscriptionRequest* r = [[JabberSubscriptionRequest alloc] initWithRecipient:_from];
    [r putAttribute:@"type" withValue:@"unsubscribed"];

    [r autorelease];
    return r;    
}
    
+(JabberSubscriptionRequest*) subscribeTo:(JabberID*)jid withMessage:(NSString*)message
{
    JabberSubscriptionRequest* r = [[JabberSubscriptionRequest alloc] initWithRecipient:jid];
    [r putAttribute:@"type" withValue:@"subscribe"];
    if (message != nil)
        [[r addElementWithName:@"status"] addCData:message];

    [r autorelease];
    return r;    
}

+(JabberSubscriptionRequest*) grantSubscriptionTo:(JabberID*)jid
{
    JabberSubscriptionRequest* r = [[JabberSubscriptionRequest alloc] initWithRecipient:jid];
    [r putAttribute:@"type" withValue:@"subscribed"];

    [r autorelease];
    return r; 
}

+(JabberSubscriptionRequest*) unsubscribeFrom:(JabberID*)jid
{
    JabberSubscriptionRequest* r = [[JabberSubscriptionRequest alloc] initWithRecipient:jid];
    [r putAttribute:@"type" withValue:@"unsubscribed"];

    [r autorelease];
    return r;
}


@end
