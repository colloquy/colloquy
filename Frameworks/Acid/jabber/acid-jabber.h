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
@class GCDAsyncSocket;
@class JabberSession;

/*!
  @class JabberSocket
  @abstract Jabber-enabled socket class.
*/
@interface JabberSocket : NSObject <XMLElementStreamListener>

@property (nonatomic) BOOL useSSL;

/*!
  @method initWithJabberSession
  @abstract initialize a JabberSocket based on a JabberSession object
  @param session  information and state related to a client session
*/
-(instancetype) initWithJabberSession:(JabberSession*)session;

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

@end

/*!
  @protocol JabberAuthManager
  @abstract authentication delegate
  @discussion delegate used to signal authentication should begin
 */
@protocol JabberAuthManager <NSObject>

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
typedef NS_ENUM(NSInteger, SessionState)
{
    JSS_Closed,
    JSS_Opened
};

/*!
  @protocol JabberRosterItem
  @abstract represents a single item for display within a roster
*/
@protocol JabberRosterItem
/*!
  @property displayName
  @abstract The name chosen for display within the roster
*/
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSString *displayNameWithJID;
/*!
  @property JID
  @abstract The Jabber Identifier of this roster item
*/
@property (nonatomic, readonly, retain) JabberID    *JID;
@property (nonatomic, readonly, copy) NSString      *JIDString;
/*!
  @property groups
  @abstract groups this item belongs to
*/
@property (nonatomic, readonly, retain) NSSet*     groups;
/*!
  @property defaultPresence
  @abstract presence to show for this item
*/
@property (nonatomic, readonly, retain) id         defaultPresence;
@end

/*!
  @protocol JabberRosterDelegate
  @abstract interface for receiving roster change events.
*/
@protocol JabberRosterDelegate <NSObject>
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
@interface JabberRoster : NSObject <NSCopying, NSFastEnumeration>

/*!
  @method initWithSession
  @abstract create a roster instance around a JabberSession
*/
-(instancetype)   initWithSession:(JabberSession*)session;

/*!
  @property itemEnumerator
  @abstract enumerate items within the roster
*/
@property (readonly, strong) NSEnumerator *itemEnumerator;

/*!
 @property delegate
 @abstract The delegate protocol handler
 */
@property (unsafe_unretained) id<JabberRosterDelegate> delegate;
/*!
  @method itemForJID
  @abstract return an item for a particular Jabber Identifier
*/
-(instancetype) itemForJID:(JabberID*)jid;

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

/*!
  @property from
  @abstract A JabberID object representing where the presence
  chunk was from
*/
@property (readonly, strong) JabberID *from;
/*!
  @property to
  @abstract A JabberID object representing where the presence
  chunk was addressed to
*/
@property (readonly, strong) JabberID *to;
/*!
  @property priority
  @abstract The priority of the presence chunk
*/
@property (readonly) int       priority;
/*!
  @property show
  @abstract The visual indicator code for the presence state
*/
@property (readonly, copy) NSString *show;
///Return signed data field
@property (readonly, copy) NSString *sign;
/*!
  @property status
  @abstract The textual description for the presence state
*/
@property (readonly, copy) NSString *status;

-(NSComparisonResult) compareFromAddr:(id)object;
-(NSComparisonResult) compareFromResourcesIgnoringCase:(id)other;

@end


/*!
  @class JabberPresenceTracker
  @abstract caches the current presence sent by other entities within
  the system to a Jabber session
*/
@interface JabberPresenceTracker : NSObject <NSCopying>

/*!
  @method initWithSession
  @abstract create a new instance around an existing Jabber Session
*/
-(instancetype) initWithSession:(id)session;

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
  @param jid user\@host address to enumerate over. Any given resource
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
typedef NS_ENUM(NSInteger, JMEvent)
{
    JMEVENT_NONE,
    JMEVENT_COMPOSING,
    JMEVENT_COMPOSING_REQUEST,
    JMEVENT_COMPOSING_CANCEL
};

/*!
  @class JabberMessage
  @abstract represent a XMPP Message chunk
*/
@interface JabberMessage : XMLElement

/*!
  @method initWithRecipient
  @abstract create an empty message around a recipient Jabber
  Identifier
*/
-(instancetype) initWithRecipient:(JabberID*)jid;
/*!
  @method initWithRecipient:andBody
  @abstract create a message around a recipient Jabber Identifier and
  a body
*/
-(instancetype) initWithRecipient:(JabberID*)jid andBody:(NSString*)body;

/*!
  @property to
  @abstract The Jabber Identifier for where this message was
  addressed to
*/
@property (nonatomic, strong) JabberID *to;
/*!
  @property from
  @abstract The Jabber Identifier for where this message was
  from
*/
@property (nonatomic, strong) JabberID *from;
/*!
  @property type
  @abstract The type of this message used for GUI display
*/
@property (readwrite, copy) NSString* type;
/*!
  @property body
  @abstract The message body for this message
*/
@property (nonatomic, copy) NSString *body;

///Methods for encryption
@property (nonatomic, copy) NSString *encrypted;

/*!
  @property subject
  @abstract The subject of the conversation or an abstract for
  this message
*/
@property (nonatomic, copy) NSString *subject;
/*!
  @property eventType
  @abstract retrieve any associated event type
*/
@property (readonly) JMEvent eventType;

/*!
  @property action
  @abstract indicate if the message should be displayed as an
  action. This is indicated by a message beginning with "/me "
*/
@property (readonly, getter=isAction) BOOL action;
/*!
  @property wasDelayed
  @abstract return if this message was delayed by offline delivery
*/
@property (readonly) BOOL wasDelayed;
/*!
  @property delayedOnDate
  @abstract return the UTC time of the original message (if the
  message was delayed)
*/
@property (readonly, strong) NSDate *delayedOnDate;
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

/*!
  @method init
  @abstract create a new JabberSession instance
*/
-(instancetype)   init;

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
  @property connected
  @abstract indicate if this session is established
*/
@property (readonly, getter=isConnected) BOOL connected;
/*!
  @property jid
  @abstract The Jabber Identifier associated with this session
*/
@property (readonly, retain) JabberID *jid;
/*!
  @property sessionID
  @abstract The session identifier (given within the server's
  stream header response)
*/
@property (readonly, copy) NSString *sessionID;
/*!
  @property authManager
  @abstract The current authManager
*/
@property (readonly, retain) id authManager;
/*!
  @property roster
  @abstract The roster cache for the session
*/
@property (retain) JabberRoster *roster;

/*!
  @property presenceTracker
  @abstract return the presence cache for the session
*/
@property (readonly, retain) JabberPresenceTracker *presenceTracker;

/*!
  @property useSSL
 @abstract Enable SSL on this session; call before startSession
 */
@property BOOL useSSL;

/*! Toggle authentication on connected; by setting this to NO, one
   can do other interesting things once connected to the system, 
   like register. By default, the session immediately starts the
   authentication process once the stream has been opened */
@property BOOL authOnConnected;

@end;

/*!
  @class JabberIQ
  @abstract represence an InfoQuery request or response
  @discussion this object represents an XMPP IQ chunk. It also
  tracks requests and responses, providing a callback mechanism on
  results for these methods.
*/
@interface JabberIQ : XMLElement <NSCopying>

/*!
  @method constructIQGet:withSession
  @abstract return a temporary object with type set to "get" and
  containing a "query" element within the specified namespace
*/
+(JabberIQ*) constructIQGet:(NSString*)namespace withSession:(JabberSession*)s;
/*!
  @method constructIQSet:withSession
  @abstract return a temporary object with type set to "set" and
  containing a "query" element within the specified namespace
*/
+(JabberIQ*) constructIQSet:(NSString*)namespace withSession:(JabberSession*)s;
/*!
  @method initWithSession
  @abstract initialize around a JabberSession object
*/
-(instancetype) initWithSession:(JabberSession*)s;

/*!
  @method setObserver:withSelector
  @abstract set an object and a message to be signalled when the
  request returns.
*/
-(void) setObserver:(id)observer withSelector:(SEL)selector;
-(void) setObserver:(id)observer withSelector:(SEL)selector object:(id)object;
/*!
  @property queryElement
  @abstract The query element, if set in the initializer called
*/
@property (readonly, strong) XMLElement *queryElement;
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

@property (readonly, strong) JabberID *from;

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
typedef NS_ENUM(NSInteger, JAuthType)
{
    JAUTH_DIGEST,
    JAUTH_PLAINTEXT
};

/*!
  @class JabberStdAuthManager
  @abstract represents the logic needed to negotiate and authenticate
  using the jabber:iq:auth mechanism.
*/
@interface JabberStdAuthManager : NSObject <JabberAuthManager>
/*!
  @method authenticatewithPassword
  @abstract authenticate using the specified password
*/
-(void) authenticateWithPassword: (NSString *) password;
@end

@protocol JabberGroup <NSObject>
@property (nonatomic, readonly, copy) NSString *displayName;
- (id <JabberRosterItem>) itemAtIndex: (NSUInteger) index;
@property (readonly) NSUInteger count;
@end

@interface JabberGroupTracker : NSObject <NSFastEnumeration>

- (instancetype) init;
- (instancetype) initFromRoster: (JabberRoster*) roster;
- (instancetype) initFromRoster: (JabberRoster*) roster withFilter: (id) object selector: (SEL) selector;

@property (readonly) NSUInteger count;
@property (readonly, strong) NSEnumerator *groupEnumerator;
- (id) groupAtIndex: (NSUInteger) i;

- (BOOL) item: (id) item addedToGroup: (NSString*) group;
- (BOOL) item: (id) item removedFromGroup: (NSString*) group;
- (BOOL) onAddedItem: (id) item;
- (BOOL) onRemovedItem: (id) item;
@end

typedef NS_ENUM(NSInteger, JabberSubscriptionType)
{
    JSUBSCRIBE, JSUBSCRIBED, JUNSUBSCRIBE, JUNSUBSCRIBED
};

@interface JabberSubscriptionRequest : XMLElement

-(instancetype) initWithRecipient:(JabberID*)jid;

-(void) resync;

@property (readonly) JabberSubscriptionType type;
@property (readonly, copy) NSString *message;
@property (readonly, strong) JabberID *to;
@property (readonly, strong) JabberID *from;

-(JabberSubscriptionRequest*) grant;
-(JabberSubscriptionRequest*) deny;

+(JabberSubscriptionRequest*) subscribeTo:(JabberID*)jid withMessage:(NSString *)message;
+(JabberSubscriptionRequest*) unsubscribeFrom:(JabberID*)jid;
+(JabberSubscriptionRequest*) grantSubscriptionTo:(JabberID*)jid;

@end
