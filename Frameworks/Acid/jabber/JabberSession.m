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
// $Id: JabberSession.m,v 1.3 2005/05/05 05:11:55 gbooker Exp $
//============================================================================

#import "acid.h"

NSString* JSESSION_ALL_PACKETS   = @"/packet";
NSString* JSESSION_ROOT_PACKET   = @"/session/root";
NSString* JSESSION_RAWDATA_OUT   = @"/session/raw/outbound";
NSString* JSESSION_RAWDATA_IN    = @"/session/raw/inbound";
NSString* JSESSION_PACKET_IN     = @"/session/packet/inbound";
NSString* JSESSION_PACKET_OUT    = @"/session/packet/outbound";
NSString* JSESSION_CONNECTED     = @"/session/connected";
NSString* JSESSION_DISCONNECTED  = @"/session/disconnected";
NSString* JSESSION_AUTHREADY     = @"/session/authready";
NSString* JSESSION_AUTHENTICATED = @"/session/authenticated";
NSString* JSESSION_REGISTERED    = @"/session/registered";
NSString* JSESSION_STARTED       = @"/session/started";
NSString* JSESSION_ENDED         = @"/session/ended";
NSString* JSESSION_INITIAL_ROSTER= @"/session/initialroster";


NSString* JSESSION_ERROR_SOCKET     = @"/error/socket";
NSString* JSESSION_ERROR_AUTHFAILED = @"/error/session/authFailed";
NSString* JSESSION_ERROR_AUTHMECHFAILED = @"/error/session/authMechanismFailed";
NSString* JSESSION_ERROR_BADUSER    = @"/error/session/badUser";
NSString* JSESSION_ERROR_REGFAILED  = @"/error/session/registrationFailed";
NSString* JSESSION_ERROR_XMLPARSER  = @"/error/session/xmlparser";
NSString* JSESSION_ERROR_CONNECT_FAILED = @"/error/session/connectFailed";

NSString* STREAM_ROOT = @"<stream:stream xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams' to='%@'>";


@implementation JabberSession

-(id) init
{
    [super init];
    _ncenter     = [NSNotificationCenter defaultCenter];
    _curr_id = (int)self;
    _expressions = [[NSMutableDictionary alloc] init];
    _observerMap = CFDictionaryCreateMutable( NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks );
    _authMgr     = [[JabberStdAuthManager alloc] init];
    _roster      = [[JabberRoster alloc] initWithSession:self];
    _pres        = [[JabberPresenceTracker alloc] initWithSession:self];
    _do_auth     = YES;

    // Register for events
    [self addObserver:self selector:@selector(onSocketConnected:)
                 name:JSESSION_CONNECTED];
    [self addObserver:self selector:@selector(onSessionRootPacket:)
                 name:JSESSION_ROOT_PACKET];
    [self addObserver:self selector:@selector(onSocketDisconnected:)
                 name:JSESSION_ENDED];
    [self addObserver:self selector:@selector(onSocketConnectFailed:)
                 name:JSESSION_ERROR_CONNECT_FAILED];
                                              
    return self;
}

-(void) dealloc
{
    [_ncenter removeObserver:self];
    [_authMgr release];
    [_roster release];
    [_pres release];
    [_expressions release];

	CFRelease(_observerMap);
    
    [super dealloc];
}

-(NSMutableArray*) getQueriesForObserver:(id)observer
{
    NSMutableArray* result = (NSMutableArray*)CFDictionaryGetValue(_observerMap, observer);
    if (result == nil)
    {
        result = [[NSMutableArray alloc] init];
		CFDictionarySetValue(_observerMap, observer, result);
        [result release];
    }

    return result;
}

-(BOOL) isConnected
{
    return (_state == JSS_Opened);
}

// ------------------------
//
// Observer management
//
// ------------------------
-(void) addObserver:(id)observer selector:(SEL)method
              xpath:(NSString*)path
{
    NSString* eventName = [NSString stringWithFormat:@"%i/packet/%@", _curr_id, path];
    XPathQuery* query         = [_expressions objectForKey:path];
    NSMutableArray* queryList = [self getQueriesForObserver:observer];

    assert(queryList != nil);

    // No xpath expression currently exists; create one
    if (query == nil)
    {
        query = [[XPathQuery alloc] initWithPath:path];
        [_expressions setObject:query forKey:path];
        [query release];
    }

    // Add the XPath expression to the observer query list
    [queryList addObject:query];
    
    // Now register the observer with the default notification center
    [_ncenter addObserver:observer selector:method
              name:eventName object:nil];
}

-(void) addObserver:(id)observer selector:(SEL)method
              xpathFormat:(NSString*)fmt, ...
{
    va_list argList;
    NSString* path;

    va_start(argList, fmt);
    path = [[NSString alloc] initWithFormat:fmt arguments:argList];
    va_end(argList);

    [self addObserver:observer selector:method xpath:path];

    [path release];
}


-(void) addObserver:(id)observer selector:(SEL)method
               name:(NSString*)eventName
{
    [_ncenter addObserver:observer selector:method
              name:[NSString stringWithFormat:@"%i%@", _curr_id, eventName] object:nil];
}

-(void) addObserver:(id)observer selector:(SEL)method
               name:(NSString*)eventName object:(id)anObject
{
    [_ncenter addObserver:observer selector:method
                     name:[NSString stringWithFormat:@"%i%@", _curr_id, eventName] object:anObject];
}


-(void) removeObserver:(id)observer name:(NSString*)eventName
{
    // Remove the actual observer from the NC
    [_ncenter removeObserver:observer name:[NSString stringWithFormat:@"%i%@", _curr_id, eventName] object:nil];
}

-(void) removeObserver:(id)observer
{
    // Remove observer from _observerMap and unregister with the
    // notification centre
	CFDictionaryRemoveValue(_observerMap, observer);
    [_ncenter removeObserver:observer];
}

-(void) removeObserver:(id)observer xpath:(NSString*)path
{
    NSString* eventName = [NSString stringWithFormat:@"/packet/%@", path];
    XPathQuery* query = [_expressions objectForKey:path];
    NSMutableArray* queryList = (NSMutableArray*)CFDictionaryGetValue(_observerMap, observer);

    if ((query == nil) || (queryList == nil))
    {
        NSLog(@"Attempt to register unknown/invalid expression: %@", path);
        return;
    }

    // Remove the query from the observer's query list
    [queryList removeObject:query];

    // If the queryList is now empty, go ahead and remove the observer
    // from the observer map
    if ([queryList count] == 0)
    {
		CFDictionaryRemoveValue(_observerMap, observer);
    }

    // If the retainCount is 1, there are no observers interested in
    // this query anymore, so we can remove it from the list
    if ([query retainCount] == 1)
    {
        [_expressions removeObjectForKey:path];
    }

    // Remove the actual observer from the NC
    [_ncenter removeObserver:observer name:[NSString stringWithFormat:@"%i%@", _curr_id, eventName] object:nil];
}

-(void) removeObserver:(id)observer xpathFormat:(NSString*)fmt, ...
{
    va_list argList;
    NSString* path;

    va_start(argList, fmt);
    path = [[NSString alloc] initWithFormat:fmt arguments:argList];
    va_end(argList);

    [self removeObserver:observer xpath:path];

    [path release];
}

-(void) postNotificationForElement:(XMLElement*)elem
{
    // Walk list of xpath queries passing this element off to each one
    // that matches
    NSArray* values = [_expressions allValues];
    NSEnumerator* en = [values objectEnumerator];
    id curr;
    while ((curr = [en nextObject]))
    {
        if ([curr matches:elem])
        {
            NSString* eventName = [NSString stringWithFormat:@"/packet/%@", [curr path]];
            [_ncenter postNotificationName:[NSString stringWithFormat:@"%i%@", _curr_id, eventName] object:elem];
        }
    }
}

-(void) postNotificationName:(NSString*)name object:(NSObject*)obj
{
    [_ncenter postNotificationName:[NSString stringWithFormat:@"%i%@", _curr_id, name] object:obj];
}

// ------------------------
//
// Session control
//
// ------------------------
-(void) startSession:(JabberID*)jid onPort:(int)port
{
    [self startSession:jid onPort:port withServer:[jid hostname]];
}

-(void) startSession:(JabberID*)jid onPort:(int)port withServer:(NSString*)server
{
    assert(jid != nil);
    assert (_state == JSS_Closed);
    _state = JSS_Opened;
    
    // Store session JID
    [_jid release];
    _jid = [jid retain];
    
    // Startup a connection
    _jsocket = [[JabberSocket alloc] initWithJabberSession:self];
    [_jsocket setUseSSL:_useSSL];
    [_jsocket connectToHost:server onPort:port];
}

-(void) stopSession
{
    [_jsocket disconnect];
    _state = JSS_Closed;
}

// ------------------------
//
// Notifications
//
// ------------------------
-(void) onSocketConnected:(NSNotification*)n
{
    // Generate the stream header
    NSString* root = [NSString stringWithFormat:STREAM_ROOT, [_jid hostname]];

    // Write stream header
    [_jsocket sendString:root];
}

-(void) onSessionRootPacket:(NSNotification*)n
{
    XMLElement* root_elem = [n object];

    // Store root element ID
    _sid = [[root_elem getAttribute:@"id"] retain];

    // Do auth, if so instructed
    if (_do_auth)
    {
        // Start the authentication 
        [_authMgr authenticateJID:_jid forSession:self];
    }
}

-(void) onSocketDisconnected:(NSNotification*)n
{
    [_jsocket release];
    _jsocket = nil;
    _state = JSS_Closed;
}

-(void) onSocketConnectFailed:(NSNotification*)n
{
    [_jsocket release];
    _jsocket = nil;
    _state = JSS_Closed;
}

// ------------------------
//
// Transmission interfaces
//
// ------------------------
-(void) sendElement:(XMLElement*)elem
{
    if ([elem getAttribute:@"from"] == nil)
        [elem putAttribute:@"from" withValue:[_jid description]];
    [_ncenter postNotificationName:[NSString stringWithFormat:@"%i%@", _curr_id, JSESSION_PACKET_OUT] object:elem];
    [_jsocket sendString:[elem description]];
}

-(void) sendString:(NSString*)string
{
    [_jsocket sendString:string];
}

// ------------------------
//
// Accessors
//
// ------------------------
-(JabberID*) jid
{
    return _jid;
}

-(NSString*) sessionID
{
    return _sid;
}

-(id) authManager
{
    return _authMgr;
}

-(JabberRoster*) roster
{
    return _roster;
}

-(void) setRoster:(JabberRoster*)r
{
    [_roster release];
    _roster = [r retain];
}

-(JabberPresenceTracker*) presenceTracker
{
    return _pres;
}

-(void) setUseSSL:(BOOL)useSSL
{
    _useSSL = useSSL;
}

-(void) setAuthOnConnected:(BOOL)doauth
{
    _do_auth = doauth;
}

@end
