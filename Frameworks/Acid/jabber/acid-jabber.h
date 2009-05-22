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
// $Id: acid-jabber.h,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import <Foundation/NSObject.h>
#import <Acid/JabberID.h>

/*!
  @header acid-jabber.h
  @discussion This file includes the Jabber-specific classes for use
  by Objective C code. 
*/

@class XMLQName,
    XMLElement,
    XMLCData,
    XMLElementStream,
    XMLElementStreamListener;
@class AsyncSocket;
@class JabberSession;

/*!
  @class JabberSocket
  @abstract Jabber-enabled socket class.
*/
@interface JabberSocket : NSObject <XMLElementStreamListener>
{
    AsyncSocket*      _socket;
    XMLElementStream* _parser;
    JabberSession*    _session;
    bool              _useSSL;
    NSTimer*          _timer;
}

/*!
  @method initWithJabberSession
  @abstract initialize a JabberSocket based on a JabberSession object
  @param session  information and state related to a client session
*/
-(id) initWithJabberSession:(JabberSession*)session;
-(void) dealloc;

/*!
  @method conectToHost:onport
  @abstract establish a connection with a server
  @param host  hostname to connect to
  @param port  port to connect on
*/
-(void) connectToHost:(NSString*)host onPort:(unsigned short)port;

/*!
  @method disconnect
  @abstract disconnect from established connection
*/
-(void) disconnect;

/*!
  @method sendString
  @abstract send a unicode string over the connection in UTF-8
  encoding
  @param data  unicode string to send
*/
-(void) sendString:(NSString*)data;

-(void) setUseSSL:(BOOL)useSSL;

@end

/*!
  @protocol JabberAuthManager
  @abstract authentication delegate
  @discussion delegate used to signal authentication should begin
 */
@protocol JabberAuthManager

/*!
  @method authenticateJID:forSession
  @abstract signals a session is ready for authentication for a
  particular Jabber Identifier
*/
-(void) authenticateJID:(JabberID*)jid forSession:(JabberSession*)s;
@end;

/*!
  @typedef SessionState
  @constant JSS_Closed closed session
  @constant JSS_Opened opened session
*/
typedef enum
{
    JSS_Closed,
    JSS_Opened
} SessionState;

/*!
  @protocol JabberRosterItem
  @abstract represents a single item for display within a roster
*/
@protocol JabberRosterItem
/*!
  @method displayName
  @abstract return the name chosen for display within the roster
  @result string holding display name
*/
-(NSString*)  displayName;
-(NSString*)  displayNameWithJID;
/*!
  @method JID
  @abstract return the JID of this roster item
  @result Jabber Identifier for item
*/
-(JabberID*)  JID;
-(NSString*)  JIDString;
/*!
  @method groups
  @abstract groups this item belongs to
*/
-(NSSet*)     groups;
/*!
  @method defaultPresence
  @abstract presence to show for this item
*/
-(id)         defaultPresence;
@end

/*!
  @protocol JabberRosterDelegate
  @abstract interface for receiving roster change events.
*/
@protocol JabberRosterDelegate
/*!
  @method onBeginUpdate
  @abstract signal the beginning of an update. This can be used to
  defer rendering for batch updates
*/
-(void) onBeginUpdate;
/*!
  @method onItem:addedToGroup
  @abstract signal an item added to a particular group
  @param item object handling the JabberRosterItem protocol
  @param group name of the group this item was added to
*/
-(void) onItem:(id)item addedToGroup:(NSString*)group;
/*!
  @method onItem:removedFromGroup
  @abstract signal an item removed from a particular group
  @param item object handling the JabberRosterItem protocol
  @param group name of the group this item was removed from
*/
-(void) onItem:(id)item removedFromGroup:(NSString*)group;
/*!
  @method onEndUpdate
  @abstract signal the end of an update. This can be used to resume
  rendering for a batch update
*/
-(void) onEndUpdate;
@end

/*!
  @class JabberRoster
  @abstract represents the entire roster belonging to a user
*/
@interface JabberRoster : NSObject <NSCopying>
{
    id _session;
    id _delegate;
    NSMutableDictionary* _items;
    XPathQuery* _groups_query;
    BOOL _viewOnlineOnly;
}
/*!
  @method initWithSession
  @abstract create a roster instance around a JabberSession
*/
-(id)   initWithSession:(id)session;
-(void) dealloc;

/*!
  @method itemEnumerator
  @abstract enumerate items within the roster
*/
-(NSEnumerator*) itemEnumerator;

/*!
  @method delegate
  @abstract get the current delegate protocol handler
*/
-(id)   delegate;
/*!
  @method setDelegate
  @abstract set a delegate protocol handler
*/
-(void) setDelegate:(id)delegate;
/*!
  @method itemForJID
  @abstract return an item for a particular Jabber Identifier
*/
-(id) itemForJID:(JabberID*)jid;

-(NSString*) nickForJID:(JabberID*)jid;

/*!
  @method updateJabberID:withNickname:andGroups
  @abstract add or modify a roster item around a Jabber
  Identifier, a display name, and groups
*/
- (void)updateJabberID:(JabberID*)jid withNickname:(NSString*)name andGroups:(NSSet *)groups;
/*!
  @method removeJabberID
  @abstract remove the item for a particular Jabber Identifier
*/
-(void) removeJabberID:(JabberID*)jid;

@end;

/*!
  @class JabberPresence
  @abstract represent a XMPP presence chunk
*/
@interface JabberPresence : XMLElement
{
    JabberID*   to;
    JabberID*   from;
    int         priority;
    NSString*   show;
    NSString*   status;
    NSString*	sign;
}
/*!
  @method from
  @abstract return a JabberID object representing where the presence
  chunk was from
*/
-(JabberID*) from;
/*!
  @method to
  @abstract return a JabberID object representing where the presence
  chunk was addressed to
*/
-(JabberID*) to;
/*!
  @method priority
  @abstract return the priority of the presence chunk
*/
-(int)       priority;
/*!
  @method show
  @abstract return the visual indicator code for the presence state
*/
-(NSString*) show;
//Return signed data field
-(NSString*) sign;
/*!
  @method status
  @abstract return the textual description for the presence state
*/
-(NSString*) status;

-(NSComparisonResult) compareFromAddr:(id)object;
-(NSComparisonResult) compareFromResourcesIgnoringCase:(id)other;

@end


/*!
  @class JabberPresenceTracker
  @abstract caches the current presence sent by other entities within
  the system to a Jabber session
*/
@interface JabberPresenceTracker : NSObject <NSCopying>
{
    id _session;
    NSMutableDictionary* _items;
}

/*!
  @method initWithSession
  @abstract create a new instance around an existing Jabber Session
*/
-(id) initWithSession:(id)session;
-(void)dealloc;

/*!
  @method defaultPresenceForJID
  @abstract the presence which is known for a particular Jabber
  Identifier
*/
-(id) defaultPresenceForJID:(JabberID*)jid;
/*!
  @method presenceForJID
  @abstract the presence which is known for a particular Jabber
  Identifier
*/
-(id) presenceForJID:(JabberID*)jid;

/*!
  @method presenceEnumeratorForJID
  @abstract enumerator for the presences known for the resources
  associated with a particular Jabber Identifier
  @param jid user@host address to enumerate over. Any given resource
  is discarded
  @return enumerator for presence objects in priority order, or nil
  if jid does not have any presence being tracked.
*/
-(NSEnumerator*) presenceEnumeratorForJID:(JabberID*)jid;

@end

/*!
  @typedef JMEvent
  @abstract represent the type of a Message Event (see JEP-0022). Note
  that this only represents the composing event.
  @constant JMEVENT_NONE no event requested or given
  @constant JMEVENT_COMPOSING message is a notification that the other
  party in a conversation is composing a reply to an earlier request
  @constant JMEVENT_COMPOSING_REQUEST message is a request for
  composing notifications on any reply
  @constant JMEVENT_COMPOSING_CANCEL message is a notification that a
  response is no longer being composed in response to an earlier
  request.
*/
typedef enum
{
    JMEVENT_NONE,
    JMEVENT_COMPOSING,
    JMEVENT_COMPOSING_REQUEST,
    JMEVENT_COMPOSING_CANCEL
} JMEvent;

/*!
  @class JabberMessage
  @abstract represent a XMPP Message chunk
*/
@interface JabberMessage : XMLElement
{
    JabberID* to;
    JabberID* from;
    bool      isAction;
    JMEvent   eventType;
    NSString* body;
    NSString* subject;
    NSString* encrypted;
    BOOL      wasDelayed;
    NSDate*   delayedOnDate;
}

/*!
  @method initWithRecipient
  @abstract create an empty message around a recipient Jabber
  Identifier
*/
-(id) initWithRecipient:(JabberID*)jid;
/*!
  @method initWithRecipient:andBody
  @abstract create a message around a recipient Jabber Identifier and
  a body
*/
-(id) initWithRecipient:(JabberID*)jid andBody:(NSString*)body;

/*!
  @method to
  @abstract return the Jabber Identifier for where this message was
  addressed to
*/
-(JabberID*) to;
-(void) setTo:(JabberID*)jid;
/*!
  @method from
  @abstract return the Jabber Identifier for where this message was
  from
*/
-(JabberID*) from;
-(void) setFrom:(JabberID*)jid;
/*!
  @method type
  @abstract return the type of this message, used for GUI display
*/
-(NSString*) type;
/*!
  @method body
  @abstract return the message body for this message
*/
-(NSString*) body;
-(void) setBody:(NSString*)body;

//Methods for encryption
-(void) setEncrypted:(NSString*)s;
-(NSString*) encrypted;

/*!
  @method subject
  @abstract return the subject of the conversation or an abstract for
  this message
*/
-(NSString*) subject;
/*!
  @method eventType
  @abstract retrieve any associated event type
*/
-(JMEvent) eventType;

/*!
  @method setType
  @abstract set the type of this message used for GUI display
*/
-(void) setType:(NSString*)type;
/*!
  @method setSubject
  @abstract set the subject for this message
*/
-(void) setSubject:(NSString*)s;
/*!
  @method isAction
  @abstract indicate if the message should be displayed as an
  action. This is indicated by a message beginning with "/me "
*/
-(BOOL) isAction;
/*!
  @method wasDelayed
  @abstract return if this message was delayed by offline delivery
*/
-(BOOL) wasDelayed;
/*!
  @method delayedOnDate
  @abstract return the UTC time of the original message (if the
  message was delayed)
*/
-(NSDate*) delayedOnDate;
/*!
  @method addComposingRequest
  @abstract indicate that notification should be sent as responses to
  this message are composed.
*/
-(void) addComposingRequest;
/*!
  @method addComposingNotification
  @abstract indicate that there is a response being composed to an
  earlier message
*/
-(void) addComposingNotification:(NSString*)mid;
/*!
  @method cancelComposingNotification
  @abstract indicate that a previous composing notification is cancelled
*/
-(void) cancelComposingNotification:(NSString*)mid;

@end

@class ChatManager;

/*! 
  @class JabberSession
  @abstract represent a session for a jabber user
*/
@interface JabberSession : NSObject
{
    CFMutableDictionaryRef _observerMap;
    NSMutableDictionary*   _expressions;
    NSNotificationCenter*  _ncenter;
    JabberSocket*          _jsocket;
    JabberRoster*          _roster;
    JabberPresenceTracker* _pres;
    ChatManager*     _chat;
    SessionState     _state;
    JabberID*        _jid;
    NSString*        _sid;
    unsigned long    _curr_id;
    id               _authMgr;
    bool             _useSSL;
    bool             _do_auth;
}

/*!
  @method init
  @abstract create a new JabberSession instance
*/
-(id)   init;
-(void) dealloc;

/*!
  @method addObserver:selector:xpath
  @abstract add an observer for incoming xml chunks matching an xpath
  expression
  @param observer object instance to receive notification
  @param method selector to call on event
  @param path xpath expression to match on incoming XML chunks.
*/
-(void) addObserver:(id)observer
	   selector:(SEL)method
	      xpath:(NSString*)path;

/*!
 @method addObserver:selector:xpathFormat
 @abstract add an observer for incoming xml chunks matching a formatted xpath
          expression
 @param observer object instance to receive notification
 @param method selector to call on event
 @param fmt xpath format expression to match on incoming XML chunks.
*/

-(void) addObserver:(id)observer selector:(SEL)method
        xpathFormat:(NSString*)fmt,...;
/*!
  @method addObserver:selector:name
  @abstract add an observer for incoming xml chunks matching an event
  name
  @param observer object instance to receive notification
  @param method selector to call on event
  @param eventName event to watch for notifications for
*/
-(void) addObserver:(id)observer selector:(SEL)method
               name:(NSString*)eventName;
/*!
  @method removeObserver
  @abstract remove a previously added observer
*/
-(void) removeObserver:(id)observer;
/*!
  @method removeObserver:name
  @abstract remove a previously added observer for an event name
*/
-(void) removeObserver:(id)observer name:(NSString*)eventName;
/*!
  @method removeObserver:xpath
  @abstract remove a previously added observer for an xpath expression
*/
-(void) removeObserver:(id)observer xpath:(NSString*)path;
-(void) removeObserver:(id)observer xpathFormat:(NSString*)fmt, ...;

/*!
  @method postNotificationForElement
  @abstract post a notification for a specific element. This will
  notify all observers based on xpath expression
*/
-(void) postNotificationForElement:(XMLElement*)elem;
/*!
  @method postNotificationName:object
  @abstract post a notification for a specific event name, passing in
  an object to distribute to the observers
*/
-(void) postNotificationName:(NSString*)name object:(NSObject*)object;
/*!
 @method startSession
 @abstract start this session for a particular jid. This will connect to
 the server specified in the JID and send appropriate stream headers
*/
-(void) startSession:(JabberID*)jid onPort:(int)port;
-(void) startSession:(JabberID*)jid onPort:(int)port withServer:(NSString*)server;

/*!
  @method stopSession
  @abstract stop this session, including disconnecting any connection
  held.
*/ 
-(void) stopSession;


/*!
  @method sendElement
  @abstract send an element out over an established session
*/
-(void) sendElement:(XMLElement*)elem;
/*!
  @method sendString
  @abstract send a string out over an established session
*/
-(void) sendString:(NSString*)string;
/*!
  @method isConnected
  @abstract indicate if this session is established
*/
-(BOOL) isConnected;
/*!
  @method jid
  @abstract return the Jabber Identifier associated with this session
*/
-(JabberID*) jid;
/*!
  @method sessionID
  @abstract return the session identifier (given within the server's
  stream header response)
*/
-(NSString*) sessionID;
/*!
  @method authmanager
  @abstract return the current authManager
*/
-(id) authManager;
/*!
  @method roster
  @abstract return the roster cache for the session
*/
-(JabberRoster*) roster;
-(void) setRoster:(JabberRoster*)r;

/*!
  @method presenceTracker
  @abstract return the presence cache for the session
*/
-(JabberPresenceTracker*) presenceTracker;

/*!
  @method setUseSSL
 @abstract Enable SSL on this session; call before startSession
 */
-(void) setUseSSL:(BOOL)useSSL;

/* Toggle authentication on connected; by setting this to NO, one
   can do other interesting things once connected to the system, 
   like register. By default, the session immediately starts the
   authentication process once the stream has been opened */
-(void) setAuthOnConnected:(BOOL)doauth;

@end;

/*!
  @class JabberIQ
  @abstract represence an InfoQuery request or response
  @discussion this object represents an XMPP IQ chunk. It also
  tracks requests and responses, providing a callback mechanism on
  results for these methods.
*/
@interface JabberIQ : XMLElement <NSCopying>
{
    JabberSession* _session;
    XMLElement*    _query_elem;
    NSString*      _query;
    id             _observer;
    SEL            _callback;
	id             _object;
}
/*!
  @method constructIQGet:withSession
  @abstract return a temporary object with type set to "get" and
  containing a "query" element within the specified namespace
*/
+(id) constructIQGet:(NSString*)namespace withSession:(JabberSession*)s;
/*!
  @method constructIQSet:withSession
  @abstract return a temporary object with type set to "set" and
  containing a "query" element within the specified namespace
*/
+(id) constructIQSet:(NSString*)namespace withSession:(JabberSession*)s;
/*!
  @method initWithSession
  @abstract initialize around a JabberSession object
*/
-(id) initWithSession:(JabberSession*)s;
-(void) dealloc;
/*!
  @method setObserver:withSelector
  @abstract set an object and a message to be signalled when the
  request returns.
*/
-(void) setObserver:(id)observer withSelector:(SEL)selector;
-(void) setObserver:(id)observer withSelector:(SEL)selector object:(id)object;
/*!
  @method queryElement
  @abstract retrieve query element, if set in the initializer called
*/
-(XMLElement*) queryElement;
/*!
  @method execute
  @abstract send the IQ request to specified JID, signalling the object
  specified by setObserver on completion.
*/
-(void) execute;
-(void) executeTo:(JabberID*)targetjid;
/*!
  @method copyWithZone
  @abstract Returns a new instance that's a copy of the receiver.
  @discussion Returns a new instance that's a copy of the
  receiver. Memory for the new instance is allocated from zone, which
  may be NULL.  If zone is NULL, the new instance is allocated from
  the default zone, which is returned from the NSDefaultMallocZone.
  The returned object is implicitly retained by the sender, who is
  responsible for releasing it.  The copy returned is immutable if the
  consideration "immutable vs. mutable" applies to the receiving
  object; otherwise the exact nature of the copy is determined by the
  class.
 */
-(id) copyWithZone:(NSZone*)zone;

-(JabberID*) from;

@end


/*
 Events
*/
extern NSString* JSESSION_ALL_PACKETS;
extern NSString* JSESSION_ROOT_PACKET;
extern NSString* JSESSION_RAWDATA_OUT;
extern NSString* JSESSION_RAWDATA_IN;
extern NSString* JSESSION_PACKET_IN;
extern NSString* JSESSION_PACKET_OUT;
extern NSString* JSESSION_CONNECTED;
extern NSString* JSESSION_AUTHREADY;
extern NSString* JSESSION_REGISTERED;
extern NSString* JSESSION_STARTED;
extern NSString* JSESSION_ENDED;
extern NSString* JSESSION_INITIAL_ROSTER;

extern NSString* JXML_SUB_REQUEST;        // subscribe
extern NSString* JXML_SUB_GRANTED;        // subscribed
extern NSString* JXML_SUB_CANCELED;       // unsubscribed
extern NSString* JXML_SUB_CANCEL_REQUEST; // unsubscribe

extern NSString* JPRESENCE_JID_DEFAULT_CHANGED;
extern NSString* JPRESENCE_JID_UNAVAILABLE;

extern NSString* JSESSION_ERROR_SOCKET;
extern NSString* JSESSION_ERROR_CONNECT_FAILED;
extern NSString* JSESSION_ERROR_AUTHFAILED;
extern NSString* JSESSION_ERROR_BADUSER;
extern NSString* JSESSION_ERROR_REGFAILED;
extern NSString* JSESSION_ERROR_XMLPARSER;

extern XMLQName* JABBER_IQ_QN;
extern XMLQName* JABBER_MESSAGE_QN;
extern XMLQName* JABBER_PRESENCE_QN;
extern XMLQName* JABBER_STREAM_QN;
extern XMLQName* JABBER_X_EVENT_QN;
extern XMLQName* JABBER_TYPE_ATTRIB_QN;

extern XMLQName* JABBER_X_SIGNED_QN;
extern XMLQName* JABBER_IQ_VERSION_QN;
extern XMLQName* JABBER_IQ_LAST_QN;
extern XMLQName* JABBER_CLIENTCAP_QN;

/*!
  @typedef JAuthType
  @abstract authentication types understood by JabberStdAuthManager,
  which implements jabber:iq:auth support
  @constant JAUTH_DIGEST SHA1-digest auth
  @constant JAUTH_PLAINTEXT nonencoded plaintext auth
*/
typedef enum
{
    JAUTH_DIGEST,
    JAUTH_PLAINTEXT
} JAuthType;

/*!
  @class JabberStdAuthManager
  @abstract represents the logic needed to negotiate and authenticate
  using the jabber:iq:auth mechanism.
*/
@interface JabberStdAuthManager : NSObject <JabberAuthManager> {
    JabberID*      _jid;
    JabberSession* _session;
    NSString*      _0k_token;
    int            _0k_sequence;
    JAuthType      _type;
}
/*!
  @method authenticatewithPassword
  @abstract authenticate using the specified password
*/
-(void) authenticateWithPassword: (NSString *) password;
@end

@protocol JabberGroup
- (NSString *) displayName;
- (id <JabberRosterItem>) itemAtIndex: (unsigned) index;
- (unsigned) count;
@end

@interface JabberGroupTracker : NSObject
{
    NSMutableDictionary* _groups;
    NSMutableArray*      _groupArray;    
}
- (id) init;
- (id) initFromRoster: (JabberRoster*) roster;
- (id) initFromRoster: (JabberRoster*) roster withFilter: (id) object selector: (SEL) selector;
- (void) dealloc;

- (unsigned) count;
- (NSEnumerator *) groupEnumerator;
- (id) groupAtIndex: (unsigned) i;

- (BOOL) item: (id) item addedToGroup: (NSString*) group;
- (BOOL) item: (id) item removedFromGroup: (NSString*) group;
- (BOOL) onAddedItem: (id) item;
- (BOOL) onRemovedItem: (id) item;
@end

typedef enum
{
    JSUBSCRIBE, JSUBSCRIBED, JUNSUBSCRIBE, JUNSUBSCRIBED
} JabberSubscriptionType;

@interface JabberSubscriptionRequest : XMLElement
{
    NSString 	*_message;
    JabberID 	*_from;
    JabberID 	*_to;
    JabberSubscriptionType _type;
}

-(id) initWithRecipient:(JabberID*)jid;

-(void) resync;

-(JabberSubscriptionType) type;
-(NSString *) message;
-(JabberID*)  to;
-(JabberID *) from;

-(JabberSubscriptionRequest*) grant;
-(JabberSubscriptionRequest*) deny;

+(JabberSubscriptionRequest*) subscribeTo:(JabberID*)jid withMessage:(NSString *)message;
+(JabberSubscriptionRequest*) unsubscribeFrom:(JabberID*)jid;
+(JabberSubscriptionRequest*) grantSubscriptionTo:(JabberID*)jid;

@end
