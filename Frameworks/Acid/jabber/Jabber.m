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
// $Id: Jabber.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"

XMLQName* JABBER_IQ_QN;
XMLQName* JABBER_MESSAGE_QN;
XMLQName* JABBER_PRESENCE_QN;
XMLQName* JABBER_STREAM_QN;
XMLQName* JABBER_X_EVENT_QN;
XMLQName* JABBER_TYPE_ATTRIB_QN;
XMLQName* JABBER_X_SIGNED_QN;
XMLQName* JABBER_IQ_VERSION_QN;
XMLQName* JABBER_IQ_LAST_QN;
XMLQName* JABBER_CLIENTCAP_QN;

@interface Jabber
{}
@end

@implementation Jabber
+(void) load
{
    [[NSAutoreleasePool alloc] init];

    // Setup QNames
    JABBER_IQ_QN = [XMLQName construct:@"iq" withURI:@"jabber:client"];
    JABBER_MESSAGE_QN = [XMLQName construct:@"message" withURI:@"jabber:client"];
    JABBER_PRESENCE_QN = [XMLQName construct:@"presence" withURI:@"jabber:client"];
    JABBER_STREAM_QN = [XMLQName construct:@"stream" withURI:@"http://etherx.jabber.org/streams"];
    JABBER_X_EVENT_QN = [XMLQName construct:@"x" withURI:@"jabber:x:event"];
    JABBER_TYPE_ATTRIB_QN = [XMLQName construct:@"type" withURI:@"jabber:client"];

    JABBER_X_SIGNED_QN = QNAME(@"jabber:x:signed", @"x");
    JABBER_IQ_VERSION_QN = QNAME(@"jabber:iq:version", @"query");
    JABBER_IQ_LAST_QN = QNAME(@"jabber:iq:last", @"query");
    JABBER_CLIENTCAP_QN = QNAME(@"http://jabber.org/protocols/caps", @"c");

    // Register packet classes
    [XMLElementStream registerElementFactory:[JabberPresence class]];
    [XMLElementStream registerElementFactory:[JabberMessage class]];
    [XMLElementStream registerElementFactory:[JabberSubscriptionRequest class]];
}


@end
