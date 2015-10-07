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
// $Id: JabberStdAuthManager.m,v 1.2 2005/04/29 18:44:44 gbooker Exp $
//============================================================================

#import "Acid.h"
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonDigest.h>

#define DFMT @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"

@implementation JabberStdAuthManager
{
    JabberID*      _jid;
    JabberSession* _session;
    NSString*      _0k_token;
    int            _0k_sequence;
    JAuthType      _type;
}

-(void) authenticateJID:(JabberID*)jid forSession:(JabberSession*)session
{
    JabberIQ* auth_query;

    // Save JID and session info
    _jid = jid;
    _session = session;
    
    // Build an auth query
    auth_query = [JabberIQ constructIQGet:@"jabber:iq:auth" withSession:_session];
    [auth_query setObserver:self withSelector:@selector(onIQAuthGet:)];
    [[[auth_query queryElement] addElementWithName:@"username"] addCData:[_jid username]];

    // Execute auth query
    [auth_query execute];
    
}


-(void) onIQAuthGet:(NSNotification*)n
{
    XMLElement* result = [n object];
    // Check for error
    if ([result cmpAttribute:@"type" withValue:@"error"])
    {
        // For the moment, assume an error on auth-get is an Unauthorized error
        [_session postNotificationName:JSESSION_ERROR_BADUSER object:_session];
        return;
    }

    // Digest -- <digest> element required
    if ([XPathQuery matches:result xpath:@"/iq/query/digest"])
    {
        _type = JAUTH_DIGEST;
    }
    // Plaintext -- <password> element required
    else if ([XPathQuery matches:result xpath:@"/iq/query/password"])
    {
        _type = JAUTH_PLAINTEXT;
    }
    else
    {
        [_session postNotificationName:JSESSION_ERROR_AUTHFAILED object:self];
        return;
    }
    [_session postNotificationName:JSESSION_AUTHREADY object:self];
}

static NSString* generateDigest(NSString* password)
{
    CC_SHA1_CTX ctx;
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];

    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];

    CC_SHA1_Init(&ctx);
    CC_SHA1_Update(&ctx, [passwordData bytes], (CC_LONG)[passwordData length]);
    CC_SHA1_Final(digest, &ctx);

    return [NSString stringWithFormat:DFMT,
        digest[0], digest[1], digest[2], digest[3],
        digest[4], digest[5], digest[6], digest[7],
        digest[8], digest[9], digest[10], digest[11],
        digest[12], digest[13], digest[14], digest[15],
        digest[16], digest[17], digest[18], digest[19]];
}

-(void) setupDigestAuth:(JabberIQ*)iq withPassword:(NSString*)password
{
    // Calculate digest
    NSString* key = [NSString stringWithFormat:@"%@%@", [_session sessionID], password];
    NSString* digest = generateDigest(key);

    [[[iq queryElement] addElementWithName:@"digest"] addCData:digest];
}


-(void) authenticateWithPassword:(NSString*)password
{
    JabberIQ* auth_iq = [JabberIQ constructIQSet:@"jabber:iq:auth"
                                     withSession:_session];
    [auth_iq setObserver:self withSelector:@selector(onAuthResult:)];
    [[[auth_iq queryElement] addElementWithName:@"username"] addCData:[_jid username]];
    [[[auth_iq queryElement] addElementWithName:@"resource"] addCData:[_jid resource]];
    switch(_type)
    {
        case JAUTH_DIGEST:
            [self setupDigestAuth:auth_iq withPassword:password];
            break;
        case JAUTH_PLAINTEXT:
            [[[auth_iq queryElement] addElementWithName:@"password"] addCData:password];
            break;
    }
    [auth_iq execute];
}

-(void) onAuthResult:(NSNotification*)n
{
    XMLElement* result = [n object];
    if ([[result getAttribute:@"type"] isEqual:@"result"])
    {
        [_session postNotificationName:JSESSION_STARTED object:nil];
    }
    else
    {
        [_session postNotificationName:JSESSION_ERROR_AUTHFAILED object:nil];
    }
}

@end
