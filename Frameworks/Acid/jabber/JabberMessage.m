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
//
// $Id: JabberMessage.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"

@interface JabberMessage ()
+(instancetype) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri NS_RETURNS_RETAINED;
@end

@implementation JabberMessage
@synthesize to;
@synthesize from;
@synthesize body;
@synthesize action = isAction;
@synthesize subject;
@synthesize encrypted;
@synthesize wasDelayed;
@synthesize delayedOnDate;
@synthesize eventType;

XPathQuery* QRY_BODY;
XPathQuery* QRY_ENCRYPT;
XPathQuery* QRY_SUBJECT;
XPathQuery* QRY_COMPOSING;
XPathQuery* QRY_CHATSTATE_COMPOSING;
XPathQuery* QRY_CHATSTATE_ACTIVE;
XPathQuery* QRY_MEVENT_ID;
XPathQuery* QRY_DELAY;

+(instancetype) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri
{
    if ([qname isEqual:JABBER_MESSAGE_QN])
        return [[JabberMessage alloc] initWithQName:qname withAttributes:atts withDefaultURI:default_uri];
    return nil;
}

+(void) initialize
{
    QRY_ENCRYPT = [[XPathQuery alloc] initWithPath:@"/message/x[%jabber:x:encrypted]"];
    QRY_BODY = [[XPathQuery alloc] initWithPath:@"/message/body"];
    QRY_SUBJECT = [[XPathQuery alloc] initWithPath:@"/message/subject"];
    QRY_COMPOSING = [[XPathQuery alloc] initWithPath:@"/message/x[%jabber:x:event]/composing"];
    QRY_CHATSTATE_COMPOSING = [[XPathQuery alloc] initWithPath:@"/message/composing[%http://jabber.org/protocol/chatstates]"];
    QRY_CHATSTATE_ACTIVE = [[XPathQuery alloc] initWithPath:@"/message/active[%http://jabber.org/protocol/chatstates]"];
    QRY_MEVENT_ID = [[XPathQuery alloc] initWithPath:@"/message/x[%jabber:x:event]/id"];
    QRY_DELAY = [[XPathQuery alloc] initWithPath:@"/message/x[%jabber:x:delay]@stamp"];
}

-(id) initWithRecipient:(JabberID*)jid
{
    if (!(self = [super initWithQName:JABBER_MESSAGE_QN])) return nil;

    // Setup "to" attribute
    to = [jid retain];
    [self putAttribute:@"to" withValue:[to completeID]];

    return self;
}

-(id) initWithRecipient:(JabberID*)jid andBody:(NSString*)b
{
    if (!(self = [self initWithRecipient:jid])) return nil;
    [self addUniqueIDAttribute];
    [[self addElementWithName:@"body"] addCData:b];
    body = [b retain];
    return self;
}

-(void) dealloc
{
    [to release];
    [from release];
    [body release];
    [subject release];
    [super dealloc];
}

-(void) setup
{
    BOOL isComposing = [QRY_COMPOSING matches:self];
    BOOL isComposingChatState = [QRY_CHATSTATE_COMPOSING matches:self];
    BOOL isActiveChatState = [QRY_CHATSTATE_ACTIVE matches:self];
    BOOL hasID = [QRY_MEVENT_ID matches:self];

    NSString* delaystamp = [QRY_DELAY queryForString:self];
    if ([delaystamp length] != 0)
    {
        // Append GMT timezone
        delaystamp = [delaystamp stringByAppendingString:@" 0000"];
        delayedOnDate = [[NSCalendarDate dateWithString:delaystamp
                                     calendarFormat:@"%Y%m%dT%H:%M:%S %z"] retain];
        wasDelayed = YES;
    }

    encrypted = [[QRY_ENCRYPT queryForString:self] retain];
    body = [[QRY_BODY queryForString:self] retain];
    subject = [[QRY_SUBJECT queryForString:self] retain];
    to = [[JabberID alloc] initWithString:[self getAttribute:@"to"]];
    from = [[JabberID alloc] initWithString:[self getAttribute:@"from"]];
    isAction = [[QRY_BODY queryForString:self] hasPrefix:@"/me "];

    if (isComposingChatState)
        eventType = JMEVENT_COMPOSING;
    else if (isComposing && hasID)
        eventType = JMEVENT_COMPOSING;
    else if (isComposing || isActiveChatState)
        eventType = JMEVENT_COMPOSING_REQUEST;
    else if (hasID || isActiveChatState)
        eventType = JMEVENT_COMPOSING_CANCEL;    
}

-(void) setTo:(JabberID*)jid
{
    [to release];
    to = [jid retain];
    [self putAttribute:@"to" withValue:[jid completeID]];
}

-(void)setFrom:(JabberID*)jid
{
    [from release];
    from = [jid retain];
    [self putAttribute:@"from" withValue:[jid completeID]];
}

-(NSString*) type
{
    return [self getAttribute:@"type"];
}

-(void) setType:(NSString*)value
{
    [self putAttribute:@"type" withValue:value];
}

-(void) setBody:(NSString*)s
{
    [body release];
    body = [s retain];
    // XXX: need to replace if existing already
    [[self addElementWithName:@"body"] addCData:s];
}

-(void) setEncrypted:(NSString*)s
{
    [encrypted release];
    XMLElement* elem;
    encrypted = [s retain];
    elem = [self addElementWithName:@"x"];
    [elem putAttribute:@"xmlns" withValue:@"jabber:x:encrypted"];
    // XXX: need to replace if existing already
    [elem addCData:s];
}

-(void) setSubject:(NSString*)s
{
    [subject release];
    subject = [s retain];
    // XXX: need to replace if existing already!
    [[self addElementWithName:@"subject"] addCData:s];
}

-(void) addComposingRequest
{
    XMLElement* elem = [self addElementWithName:@"active"];
    [elem putAttribute:@"xmlns" withValue:@"http://jabber.org/protocol/chatstates"];
    assert(eventType == JMEVENT_NONE);
    [[self addElementWithQName:JABBER_X_EVENT_QN] addElementWithName:@"composing"];
    eventType = JMEVENT_COMPOSING_REQUEST;
}

-(void) addComposingNotification:(NSString*)mid
{
    XMLElement* elem = [self addElementWithName:@"composing"];
    assert(eventType == JMEVENT_NONE);
    [elem putAttribute:@"xmlns" withValue:@"http://jabber.org/protocol/chatstates"];
    [self setType:@"chat"];
    elem = [self addElementWithQName:JABBER_X_EVENT_QN];
    [elem addElementWithName:@"composing"];
    [[elem addElementWithName:@"id"] addCData:mid];
    eventType = JMEVENT_COMPOSING;
}

-(void) cancelComposingNotification:(NSString*)mid
{
    XMLElement* elem = [self addElementWithQName:JABBER_X_EVENT_QN];
    assert(eventType == JMEVENT_NONE);
    [[elem addElementWithName:@"id"] addCData:mid];
    eventType = JMEVENT_COMPOSING_CANCEL;
}

@end
