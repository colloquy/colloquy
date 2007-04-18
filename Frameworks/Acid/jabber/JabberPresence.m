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
// $Id: JabberPresence.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"

XPathQuery* QRY_PRIORITY;
XPathQuery* QRY_SHOW;
XPathQuery* QRY_STATUS;
XPathQuery* QRY_SIGN;

@implementation JabberPresence

+(id) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri
{
    if ([qname isEqual:JABBER_PRESENCE_QN])
    {
        NSString* type = [atts objectForKey:JABBER_TYPE_ATTRIB_QN];
        if ((type == nil) || ([type isEqual:@"unavailable"]))
            return [[JabberPresence alloc] initWithQName:qname withAttributes:atts withDefaultURI:default_uri];
        else
            return nil;
    }
    else
        return nil;
}

+(void) initialize
{
    QRY_PRIORITY = [[XPathQuery alloc] initWithPath:@"/presence/priority"];
    QRY_SHOW     = [[XPathQuery alloc] initWithPath:@"/presence/show"];
    QRY_STATUS   = [[XPathQuery alloc] initWithPath:@"/presence/status"];
    QRY_SIGN  	 = [[XPathQuery alloc] initWithPath:@"/presence/x[%jabber:x:signed]"];
}

-(void) setup
{
    to = [[JabberID alloc] initWithString:[self getAttribute:@"to"]];
    from = [[JabberID alloc] initWithString:[self getAttribute:@"from"]];
    priority = [[QRY_PRIORITY queryForString:self] intValue];
    show = [[QRY_SHOW queryForString:self] retain];
    status = [[QRY_STATUS queryForString:self] retain];
    sign = [[QRY_SIGN queryForString:self] retain];
}

-(void) dealloc
{
    [status release];
    [show release];
    [to release];
    [from release];
    [sign release];
    [super dealloc];
}

-(BOOL) isEqual:(JabberPresence*)other
{
    return [to isEqual:[other to]] && [from isEqual:[other from]];
}

-(NSComparisonResult) compareFromAddr:(id)other
{
    return [from compare:[other from]];
}

-(NSComparisonResult) compareFromResourcesIgnoringCase:(id)other
{
    return [[from resource] caseInsensitiveCompare:[[other from] resource]];
}


-(JabberID*) from
{
    return from;
}

-(JabberID*) to
{
    return to;
}

-(int) priority
{
    return priority;
}

-(NSString*) show
{
    return show;
}

-(NSString*) sign
{
    return sign;
}

-(NSString*) status
{
    return status;
}

@end
