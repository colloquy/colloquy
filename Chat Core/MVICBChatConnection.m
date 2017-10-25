/*
 * Chat Core
 * ICB Protocol Support
 *
 * Copyright (c) 2006, 2007, 2010 Julio M. Merino Vidal <jmmv@NetBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer.
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 *    3. The name of the author may not be used to endorse or promote
 *       products derived from this software without specific prior
 *       written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MVICBChatConnection.h"

#import <stdarg.h>
#import <Foundation/Foundation.h>

@import CocoaAsyncSocket;

#import "MVChatConnectionPrivate.h"
#import "MVChatRoomPrivate.h"
#import "MVChatUserPrivate.h"
#import "MVICBChatRoom.h"
#import "MVICBChatUser.h"

#import "ICBPacket.h"
#import "InterThreadMessaging.h"
#import "MVUtilities.h"
#import "NSStringAdditions.h"
#import "NSNotificationAdditions.h"
#import "RunOnMainThread.h"

@interface MVICBChatConnection () <GCDAsyncSocketDelegate>

@end


NS_ASSUME_NONNULL_BEGIN

#pragma mark Prototypes for auxiliary functions

static BOOL hasSubstring( NSString *str, NSString *substr, NSRange *r );

#pragma mark Bodies for auxiliary functions

/*
 * Takes a string and a substring within it and returns a boolean
 * indicating whether the latter was found inside the former.
 * If found, the given range is updated accordingly.
 *
 * The whole point of this function is to ease the usage of NSString's
 * rangeOfString in conditions.
 */
static BOOL hasSubstring( NSString *str, NSString *substr, NSRange *r ) {
	*r = [str rangeOfString:substr];
	return r->location != NSNotFound;
}

#pragma mark -

@interface MVICBChatConnection () <GCDAsyncSocketDelegate>
@end

@interface MVICBChatConnection (MVICBChatConnectionPrivate)
- (oneway void) _runloop;
- (void) _connect;
- (void) _startSendQueue;
- (void) _stopSendQueue;
- (void) _sendQueue;
- (void) _writeDataToServer:(id) raw;
- (void) _readNextMessageFromServer;
- (void) _joinChatRoomNamed:(NSString *) name
		 withPassphrase:(NSString * __nullable) passphrase
	     alreadyJoined:(BOOL) joined;
- (void) _updateKnownUser:(MVChatUser *) user
         withNewNickname:(NSString *) newNickname;
@end

#pragma mark -

@implementation MVICBChatConnection

#pragma mark Class accessors

+ (NSArray *) defaultServerPorts {
	return @[ @((unsigned short)7326) ];
}

+ (NSUInteger) maxMessageLength {
    // the actual length varies from 253 to 255 bytes based on the command. undercount to be safe everywhere: http://www.icb.net/_jrudd/icb/protocol.html
    return 250;
}

#pragma mark Constructors and finalizers

- (id) init {
	if( ( self = [super init] ) ) {
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_password = @"";
		_server = @"localhost";
		_serverPort = [[MVICBChatConnection defaultServerPorts][0] shortValue];
		_initialChannel = @"1";
		_room = nil;
		_threadWaitLock = [[NSConditionLock alloc] initWithCondition:0];
		_loggedIn = NO;
	}

	return self;
}

- (void) dealloc {
	[self disconnect];
    [super dealloc];
}

#pragma mark Accessors

@synthesize nickname = _nickname;
@synthesize password = _password;
@synthesize server = _server;
@synthesize serverPort = _serverPort;
@synthesize username = _username;

- (NSString *) preferredNickname {
	return _nickname;
}

- (MVChatConnectionType) type {
	return MVChatConnectionICBType;
}

- (NSString *) urlScheme {
	return @"icb";
}

#pragma mark Modifiers

- (void) setAwayStatusMessage:(MVChatString * __nullable) message {
}

- (void) setNickname:(NSString *__nullable) newNickname {
	NSParameterAssert( newNickname );
	NSParameterAssert( newNickname.length > 0 );

	if( ! [newNickname isEqualToString:_nickname] ) {
		if( [self isConnected] )
			[self performSelector:@selector( ctsCommandName: )
			      withObject:newNickname inThread:_connectionThread];
		else
			MVSafeCopyAssign( _nickname, newNickname );
	}
}

- (void) setPassword:(NSString *__nullable) newPassword {
	[_password release];

	if( ! newPassword )
		_password = @"";
	else
		_password = [newPassword copy];
}

- (void) setServer:(NSString *) newServer {
	if( newServer.length >= 6 && [newServer hasPrefix:@"icb://"] )
		newServer = [newServer substringFromIndex:6];
	NSParameterAssert( newServer );
	NSParameterAssert( newServer.length > 0 );

	MVSafeCopyAssign(_server, newServer);

	[super setServer:newServer];
}

- (void) setServerPort:(unsigned short) port {
	if( port != 0 )
		_serverPort = port;
	else
		_serverPort = [[MVICBChatConnection defaultServerPorts][0] shortValue];
}

- (void) setUsername:(NSString *__nullable) newUsername {
	NSParameterAssert( newUsername );
	NSParameterAssert( newUsername.length > 0 );

	MVSafeCopyAssign(_username, newUsername);
}

#pragma mark Connection handling

- (void) connect {
	if( _status != MVChatConnectionDisconnectedStatus &&
	    _status != MVChatConnectionServerDisconnectedStatus &&
		_status != MVChatConnectionSuspendedStatus )
		return;

	MVSafeRetainAssign(_lastConnectAttempt, [NSDate date]);

	_loggedIn = NO;
	[self _willConnect];

	// Spawn the thread to handle the connection to the server.
	[NSThread detachNewThreadSelector:@selector( _runloop )
	          toTarget:self withObject:nil];

	// Wait until the thread has initialized and set _connectionThread
	// to point to itself.
	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];

	// Start the connection.
	if( _connectionThread )
		[self performSelector:@selector( _connect )
		      inThread:_connectionThread];
}

- (void) disconnectWithReason:(MVChatString * __nullable) reason {
	[self cancelPendingReconnectAttempts];
	if( _sendQueueProcessing && _connectionThread )
		[self performSelector:@selector( _stopSendQueue )
		      withObject:nil inThread:_connectionThread];

	if( _status == MVChatConnectionConnectedStatus ) {
		[self _willDisconnect];
		[_chatConnection disconnect];
		[self _didDisconnect];
	} else if( _status == MVChatConnectionConnectingStatus ) {
		if( _connectionThread ) {
			[self _willDisconnect];
			[_chatConnection performSelector:@selector( disconnect )
							 inThread:_connectionThread];
			[self _didDisconnect];
		}
	}
}

- (void) sendCommand:(NSString *) command withArguments:(MVChatString * __nullable) arguments {
#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *argumentsString = [arguments string];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSString *argumentsString = arguments;
#endif

	if( [command compare:@"brick" ] == 0 ) {
		[self ctsCommandPersonal:@"server" withMessage:[NSString stringWithFormat:@"%@ %@", command, argumentsString]];
	} else {
		// XXX Unknown command.
	}
}

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
	NSParameterAssert( raw );

	// XXX Colloquy assumes in multiple places that sendRawMessage can
	// take a plain string and send it to the server as a valid message.
	// This is not the case for ICB, nor it is a proper abstraction
	// because different protocols need not share the same protocol syntax.
	// We simply discard such messages at the moment until the code in
	// the upper layers is "corrected".
	if( [raw isKindOfClass:[NSString class]] ) {
		NSLog(@"MVICBChatConnection: sendRawMessage ignored message %@",
		      raw);
		return;
	}

	NSParameterAssert( [raw isKindOfClass:[NSData class]] );

	if( now ) {
		if( _connectionThread )
			[self performSelector:@selector( _writeDataToServer: )
			      withObject:raw inThread:_connectionThread];
	} else {
		if( ! _sendQueue )
			_sendQueue = [[NSMutableArray alloc]
						  initWithCapacity:20];

		@synchronized( _sendQueue ) {
			[_sendQueue addObject:raw];
		}

		if( ! _sendQueueProcessing && _connectionThread )
			[self performSelector:@selector( _startSendQueue )
			      withObject:nil inThread:_connectionThread];
	}
}

#pragma mark Rooms handling

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );

	MVChatRoom *room = [self joinedChatRoomWithUniqueIdentifier:identifier];
	if( !room ) {
		room = [[[MVICBChatRoom alloc] initWithName:identifier andConnection:self] autorelease];
	}

	return room;
}

- (void) fetchChatRoomList {
}

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! rooms.count )
		return;

	for( NSString *room in rooms ) {
		if( room.length ) {
			[self joinChatRoomNamed:room];
			break;
		}
	}
}

- (void) joinChatRoomNamed:(NSString *) name withPassphrase:(NSString * __nullable) passphrase {
	if( _loggedIn )
		[self _joinChatRoomNamed:name withPassphrase:passphrase alreadyJoined:NO];
	else
		MVSafeCopyAssign( _initialChannel, name );
}

#pragma mark Users handling

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:nickname]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );
	MVChatUser *user = [super chatUserWithUniqueIdentifier:[identifier lowercaseString]];
	if( ! user ) user = [[[MVICBChatUser alloc] initWithNickname:identifier andConnection:self] autorelease];
	return user;
}

@end

#pragma mark -

@implementation MVICBChatConnection (MVICBChatConnectionPrivate)

#pragma mark Connection thread

- (oneway void) _runloop {
    @autoreleasepool {
        [_threadWaitLock lockWhenCondition:0];

        if( [_connectionThread respondsToSelector:@selector( cancel )] )
            [_connectionThread cancel];

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString *queueName = [NSString stringWithFormat:@"%@.connection-queue (%@)", bundleIdentifier, [self description]];
        _connectionDelegateQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        _connectionThread = [NSThread currentThread];
        if( [_connectionThread respondsToSelector:@selector( setName: )] )
            [_connectionThread setName:[self description]];
        [NSThread prepareForInterThreadMessages];

        [_threadWaitLock unlockWithCondition:1];
    }

	while( _status == MVChatConnectionConnectedStatus ||
           _status == MVChatConnectionConnectingStatus ||
           [_chatConnection isConnected] ) {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop]
                runMode:NSDefaultRunLoopMode
                beforeDate:[NSDate dateWithTimeIntervalSinceNow:5.]];
        }
	}

    @autoreleasepool {
        // Make sure the connection has sent all the delegate calls it
        // has scheduled.
        [[NSRunLoop currentRunLoop]
         runMode:NSDefaultRunLoopMode
         beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.]];

        if( [NSThread currentThread] == _connectionThread ) {
            _connectionThread = nil;
            dispatch_release(_connectionDelegateQueue);
        }
    }
}

- (void) _connect {
	[_chatConnection setDelegate:nil];
	[_chatConnection disconnect];
	[_chatConnection release];

	_chatConnection = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_connectionDelegateQueue socketQueue:_connectionDelegateQueue];

	if( ! [_chatConnection connectToHost:[self server]
	                       onPort:[self serverPort]
						   error:NULL] )
		[self _didNotConnect];
}

#pragma mark Outgoing queue management

- (void) _startSendQueue {
	if( ! _sendQueueProcessing ) {
		_sendQueueProcessing = YES;
		[self performSelector:@selector( _sendQueue ) withObject:nil];
	}
}

- (void) _stopSendQueue {
	_sendQueueProcessing = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self
	          selector:@selector( _sendQueue ) object:nil];
}

- (void) _sendQueue {
	@synchronized( _sendQueue ) {
		if( ! _sendQueue.count ) {
			_sendQueueProcessing = NO;
			return;
		}
	}

	NSData *data = nil;
	@synchronized( _sendQueue ) {
		data = [_sendQueue[0] retain];
		[_sendQueue removeObjectAtIndex:0];

		if( _sendQueue.count )
			[self performSelector:@selector( _sendQueue ) withObject:nil];
		else
			_sendQueueProcessing = NO;
	}

	[self _writeDataToServer:data];
	[data release];
}

#pragma mark Packet reading and writing

- (void) _readNextMessageFromServer {
	[_chatConnection readDataToLength:1 withTimeout:-1. tag:0];
}

- (void) _sendPacket:(ICBPacket *) packet immediately:(BOOL) now {
	NSData *data = [[packet rawData] retain];
	[self sendRawMessage:data immediately:now];
    [data release];

	// XXX The message reported should really be raw...
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification
	 object:self
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
               [packet description],    @"message",
               @YES,                    @"outbound", nil]];
}

- (void) _writeDataToServer:(id) raw {
	NSMutableData *data = nil;
	NSString *string = nil;

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = [raw mutableCopy];
		string = [[NSString alloc]
		          initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopy];
		string = [[NSString alloc]
				  initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding]
		             allowLossyConversion:YES] mutableCopy];
		string = [raw retain];
	}

	[_chatConnection writeData:data withTimeout:-1. tag:0];

	[string release];
	[data release];
}

#pragma mark AsyncSocket notifications

- (void) socket:(GCDAsyncSocket *) sock
         didConnectToHost:(NSString *) host port:(UInt16) port {
	[self ctsLoginPacket];
	[self _readNextMessageFromServer];
}

- (void) socket:(GCDAsyncSocket *) sock
         didReadData:(NSData *) data withTag:(long) tag {
	if( tag == 0 ) {
		NSAssert( data.length == 1, @"read mismatch" );
		NSUInteger len = (NSUInteger)
			(((const char *)[data bytes])[0]) & 0xFF;
		if( len == 0 )
			[_chatConnection readDataToLength:1 withTimeout:-1. tag:0];
		else
			[_chatConnection readDataToLength:len withTimeout:-1. tag:1];
	} else {
		ICBPacket *packet = [[ICBPacket alloc] initFromRawData:data];
		[self stcDemux:packet];
		[packet release];
		[self _readNextMessageFromServer];
	}
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(nullable NSError *)err {
	[self _didDisconnect];
}

#pragma mark Error handling

- (void) _postProtocolError:(NSString *) reason {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[@"reason"] = reason;
	NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
	                          code:MVChatConnectionProtocolError
							  userInfo:userInfo];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _postError:error];
	});
}

#pragma mark Rooms handling

- (void) _joinChatRoomNamed:(NSString *) name
		 withPassphrase:(NSString * __nullable) passphrase
		 alreadyJoined:(BOOL) joined {
	[name retain];
	if( [name compare:[_room name] options:NSCaseInsensitiveSearch] != 0 ) {
		if( ! joined ) {
			[self ctsCommandGroup:[name retain]];

			if( [name compare:@"ICB" options:NSCaseInsensitiveSearch] != 0 ) {
				[[NSNotificationCenter chatCenter]
				 postNotificationOnMainThreadWithName:MVChatRoomPartedNotification
				 object:_room];
				[_room release];
				_room = nil;
			}
		} else {
			_room = (MVICBChatRoom *)[self chatRoomWithUniqueIdentifier:name];
			[_room _addMemberUser:_localUser];

			[_room _setDateJoined:[NSDate date]];
			[_room _setDateParted:nil];
			[_room _clearMemberUsers];
			[_room _clearBannedUsers];

			// Update the initial channel to point to the joined room so that
			// a reconnect after a disconnection works fine and rejoins us to
			// the (only) room that we left.
			MVSafeCopyAssign( _initialChannel, name );
			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification
			 object:_room];

			[self ctsCommandTopic];
			[self ctsCommandWho:name];
		}
	}
	[name release];
}

#pragma mark Users handling

- (void) _updateKnownUser:(MVChatUser *) user
         withNewNickname:(NSString *) newNickname {
	@synchronized( _knownUsers ) {
		[user retain];
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:[newNickname lowercaseString]];
		[user _setNickname:newNickname];
		[_knownUsers setObject:user forKey:[user uniqueIdentifier]];
		[user release];
	}
}

@end

#pragma mark -

@implementation MVICBChatConnection (MVICBChatConnectionProtocolHandlers)

#pragma mark Client to server

- (void) ctsCommandGroup:(NSString *) name {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"g", name, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandName:(NSString *) name {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"name", name, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandPersonal:(NSString *) who
         withMessage:(NSString *) message {
	NSParameterAssert( message );
	NSParameterAssert( who );

	size_t maxlen = 250 - who.length;

    NSString *msg = message;
	do {
		NSString *part;
		if( msg.length < maxlen ) {
			part = msg;
			msg = nil;
		} else {
			part = [msg substringToIndex:maxlen - 1];
			msg = [msg substringFromIndex:maxlen - 1];
		}

		ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
		NSString *cmd = [NSString stringWithFormat:@"%@ %@", who, part];
		[packet addFields:@"m", cmd, nil];
		[self _sendPacket:packet immediately:NO];
		[packet release];
	} while( msg );
}

- (void) ctsCommandTopic {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"topic", @"", nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandTopicSet:(NSString *) topic {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"topic", topic, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsCommandWho:(NSString *) group {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'h'];
	[packet addFields:@"w", group, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsLoginPacket {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'a'];
	[packet addFields:_username, _nickname, _initialChannel,
	                  @"login", _password, @"", @"", nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsOpenPacket:(NSString *) message {
	NSParameterAssert( message );

    NSString *msg = message;
	do {
		NSString *part;
		if( msg.length < 255 ) {
			part = msg;
			msg = nil;
		} else {
			part = [msg substringToIndex:254];
			msg = [msg substringFromIndex:254];
		}

		ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'b'];
		[packet addFields:part, nil];
		[self _sendPacket:packet immediately:NO];
		[packet release];
	} while( msg );
}

- (void) ctsPongPacket {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'m'];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

- (void) ctsPongPacketWithId:(NSString *) ident {
	ICBPacket *packet = [[ICBPacket alloc] initWithPacketType:'m'];
	[packet addFields:ident, nil];
	[self _sendPacket:packet immediately:NO];
	[packet release];
}

#pragma mark Server to client

- (void) stcDemux:(ICBPacket *) packet {
	static const struct info {
		char type;
		NSString *selector;
		NSInteger minfields;
		NSInteger maxfields;
	} info[] = {
		{ 'a',  @"stcLoginPacket:",         0,  0 },
		{ 'b',  @"stcOpenPacket:",          2,  2 },
		{ 'c',  @"stcPersonalPacket:",      2,  2 },
		{ 'd',  @"stcStatusPacket:",        2,  2 },
		{ 'e',  @"stcErrorPacket:",         1,  1 },
		{ 'f',  @"stcImportantPacket:",     2,  2 },
		{ 'g',  @"stcExitPacket:",          0,  0 },
		{ 'i',  @"stcCommandOutputPacket:", 1, -1 },
		{ 'j',  @"stcProtocolPacket:",      1,  3 },
		{ 'k',  @"stcBeepPacket:",          1,  1 },
		{ 'l',  @"stcPingPacket:",          0,  1 },
		{ 'm',  @"stcPongPacket:",          0,  1 },
		{ '\0', nil,                        0,  0 }
	};

	// XXX The message reported should really be raw...
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotRawMessageNotification
	 object:self
	 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
               [packet description], @"message",
               @NO,                  @"outbound", nil]];

	const struct info *i = &info[0];
	while( i->type != '\0' ) {
		if( i->type == [packet type] ) {
			NSArray *fields = [packet fields];
			NSInteger count = fields.count;

			if( count < i->minfields || ( i->maxfields != -1 &&
										  count > i->maxfields ) ) {
				[self _postProtocolError:[NSString stringWithFormat:@"Received a "
					"packet of type \"%c\" with an incorrect number of fields.",
					[packet type]]];
			} else {
				SEL selector = NSSelectorFromString(i->selector);
				[self performSelector:selector withObject:fields];
				break;
			}
		}
		i++;
	}

	if( i->type == '\0' )
		[self _postProtocolError:[NSString stringWithFormat:@"Received an "
		      "ICB packet with unknown type (%c).",
			  [packet type]]];
}

- (void) stcBeepPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 1 );

	NSString *who = fields[0];

	NSDictionary *userInfo = @{@"user": [self chatUserWithUniqueIdentifier:who],
							  @"identifier": [NSString locallyUniqueString]};
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotBeepNotification
	 object:self userInfo:userInfo];
}

- (void) stcCommandOutputPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count >= 1 );

	NSString *type = fields[0];
	NSString *selname = [NSString stringWithFormat:@"stcCommandOutputPacket%@:",
	                                               [type uppercaseString]];
	SEL selector = NSSelectorFromString(selname);
	if( [self respondsToSelector:selector] )
		[self performSelector:selector withObject:fields];
	else
		[self _postProtocolError:[NSString stringWithFormat:@"Received a "
		      "command output packet with unknown type (%@).", type]];
}

- (void) stcCommandOutputPacketCO:(NSArray *) fields {
	NSString *message = fields[1];
	if( [message hasPrefix:@"The topic is: "] ) {
		[_room _setTopic:[[message substringFromIndex:14]
		                  dataUsingEncoding:[self encoding]]];
		[[NSNotificationCenter chatCenter]
		 postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification
		 object:_room];
	} else {
		[[NSNotificationCenter chatCenter]
		 postNotificationOnMainThreadWithName:MVChatConnectionGotInformationalMessageNotification
		 object:self
		 userInfo:@{@"message": message}];
	}
}

- (void) stcCommandOutputPacketWH:(NSArray *) fields {
}

- (void) stcCommandOutputPacketWL:(NSArray *) fields {
	MVChatUser *who = [self chatUserWithUniqueIdentifier:fields[2]];
	[_room _addMemberUser:who];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomMemberUsersSyncedNotification
	 object:_room
	 userInfo:@{@"added": @[who]}];
}

- (void) stcExitPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 0 );

	RunOnMainThreadAsync(^{
		[self disconnect];
	});
}

- (void) stcErrorPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 1 );

	NSString *message = fields[0];
	NSRange r;

	if( [message compare:@"Open messages not permitted in quiet groups."] == 0 ) {
		NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
					 			  code:MVChatConnectionCantSendToRoomError
								  userInfo:@{@"room": _room}];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _postError:error];
		});
	} else if( [message compare:@"Nickname already in use."] == 0 ) {
		if( _loggedIn ) {
			// XXX
		} else {
			NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
									  code:MVChatConnectionErroneusNicknameError
									  userInfo:@{@"nickname": _nickname}];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self _postError:error];
			});

			// The server will probably send us an exit packet, but let's be
			// sure to disconnect ourselves.
			dispatch_async(dispatch_get_main_queue(), ^{
				[self disconnect];
			});
		}
	} else if( [message compare:@"You are out of bricks."] == 0 ) {
		NSError *error = [NSError errorWithDomain:MVChatConnectionErrorDomain
						          code:MVChatConnectionOutOfBricksError
								  userInfo:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _postError:error];
		});
	} else if( [message compare:@"You aren't the moderator."] == 0 ) {
		// XXX
	} else if( hasSubstring( message, @" is not in the database.", &r ) ) {
		// XXX
	} else
		[self _postProtocolError:[NSString stringWithFormat:@"Received an "
		      "unhandled error packet: %@", fields[0]]];
}

- (void) stcImportantPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 2 );

	NSString *category = fields[0];
	NSString *text = fields[1];
	NSString *message = [NSString stringWithFormat:@"%@, %@",
						 category, text];

	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotImportantMessageNotification
	 object:self
	 userInfo:@{@"message": message}];
}

- (void) stcLoginPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 0 );

	RunOnMainThreadAsync(^{
		[self _didConnect];
	});

	_loggedIn = YES;

	[_localUser release];
	_localUser = [[MVICBChatUser alloc] initLocalUserWithConnection:self];
	[self _markUserAsOnline:_localUser];

	_room = (MVICBChatRoom *)[self chatRoomWithUniqueIdentifier:_initialChannel];
	[_room _setDateJoined:[NSDate date]];
	[_room _setDateParted:nil];
	[_room _clearMemberUsers];
	[_room _clearBannedUsers];

	[_room _addMemberUser:_localUser];
	[self ctsCommandTopic];
	[self ctsCommandWho:[_room name]];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomJoinedNotification
	 object:_room];
}

- (void) stcOpenPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 2 );

	NSString *who = fields[0];
	NSString *msg = fields[1];

	MVChatUser *user = [self chatUserWithUniqueIdentifier:who];
	[user _setIdleTime:0.];

	NSDictionary *userInfo = @{@"user": user,
							  @"message": [msg dataUsingEncoding:[self encoding]],
							  @"identifier": [NSString locallyUniqueString]};
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomGotMessageNotification
	 object:_room userInfo:userInfo];
}

- (void) stcPersonalPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 2 );

	NSString *who = fields[0];
	NSString *msg = fields[1];

	MVChatUser *user = [self chatUserWithUniqueIdentifier:who];

	NSDictionary *userInfo = @{@"message": [msg dataUsingEncoding:[self encoding]],
							  @"identifier": [NSString locallyUniqueString]};
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification
	 object:user userInfo:userInfo];
}

- (void) stcPingPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count <= 1 );

	if( fields.count == 1 ) {
		NSString *ident = fields[0];
		[self ctsPongPacketWithId:ident];
	} else
		[self ctsPongPacket];
}

- (void) stcPongPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count <= 1 );
}

- (void) stcProtocolPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count >= 1 && fields.count <= 3 );
}

- (void) stcStatusPacket:(NSArray *) fields {
	NSParameterAssert( fields );
	NSParameterAssert( fields.count == 2 );

	NSString *category = fields[0];

	NSMutableString *tmp = [NSMutableString stringWithCapacity:category.length];
	[tmp setString:category];
	[tmp replaceOccurrencesOfString:@"-" withString:@""
	     options:NSLiteralSearch range:NSMakeRange(0, category.length)];
	NSString *selname = [NSString stringWithFormat:@"stcStatusPacket%@:", tmp];

	SEL selector = NSSelectorFromString(selname);
	if( [self respondsToSelector:selector] )
		[self performSelector:selector withObject:fields];
	else
		[self _postProtocolError:[NSString stringWithFormat:@"Received a "
		      "status message with an unsupported category (%@).",
			  category]];
}

- (void) stcStatusPacketArrive:(NSArray *) fields {
	NSString *msg = fields[1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:words[0]];
	[sender _setIdleTime:0.];
	[_room _addMemberUser:sender];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification
	 object:_room
	 userInfo:@{@"user": sender}];
}

- (void) stcStatusPacketBoot:(NSArray *) fields {
	NSString *msg = fields[1];

	NSRange r;

	r = [msg rangeOfString:@" was auto-booted "];
	if( r.location != NSNotFound ) {
		MVChatUser *who = [self chatUserWithUniqueIdentifier:
			                    [msg substringToIndex:r.location]];
		MVChatUser *server = [self chatUserWithUniqueIdentifier:@"server"];
		NSData *reason = [@"Spamming" dataUsingEncoding:_encoding];

		if( [who isLocalUser] ) {
			[_room _setDateParted:[NSDate date]];
			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomKickedNotification
			 object:_room
			 userInfo:@{@"reason": reason,
			                                                     @"byUser": server}];
		} else {
			[_room _removeMemberUser:who];
			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomUserKickedNotification
			 object:_room
			 userInfo:@{@"reason": reason,
				                                                 @"byUser": server,
																 @"user": who}];
		}
	}
}

- (void) stcStatusPacketDepart:(NSArray *) fields {
	NSString *msg = fields[1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:words[0]];
	[_room _removeMemberUser:sender];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification
	 object:_room
	 userInfo:@{@"user": sender}];
}

- (void) stcStatusPacketFYI:(NSArray *) fields {
	NSString *msg = fields[1];

	NSRange r;

	if( [msg compare:@"A brick flies off into the ether."] == 0 ) {
		[[NSNotificationCenter chatCenter]
		 postNotificationOnMainThreadWithName:MVChatRoomUserBrickedNotification
		 object:_room];
	} else if( hasSubstring(msg, @" has been bricked.", &r) ) {
		NSString *nick = [msg substringToIndex:r.location];
		MVChatUser *who = [self chatUserWithUniqueIdentifier:nick];

		[[NSNotificationCenter chatCenter]
		 postNotificationOnMainThreadWithName:MVChatRoomUserBrickedNotification
		 object:_room
		 userInfo:@{@"user": who}];
	} else {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:@"server"];
		NSData *msgdata = [msg dataUsingEncoding:[self encoding]];

		NSDictionary *userInfo = @{@"message": msgdata,
								  @"identifier": [NSString locallyUniqueString],
								  @"notice": @"yes"};
		[[NSNotificationCenter chatCenter]
		 postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification
		 object:user userInfo:userInfo];
	}
}

- (void) stcStatusPacketMessage:(NSArray *) fields {
	NSString *msg = fields[1];

	/*
	 * Known message notifications.  Maybe they should be handled in some
	 * other way, but for now we just report these as notices:
	 *
	 * You owe %d bricks.
	 * You have no bricks remaining.
	 * You have %d bricks remaining.
	 */

	MVChatUser *user = [self chatUserWithUniqueIdentifier:@"server"];

	NSDictionary *userInfo = @{@"message": [msg dataUsingEncoding:[self encoding]],
							  @"identifier": [NSString locallyUniqueString],
							  @"notice": @"yes"};
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatConnectionGotPrivateMessageNotification
	 object:user userInfo:userInfo];
}

- (void) stcStatusPacketName:(NSArray *) fields {
	NSString *msg = fields[1];

	NSRange r;

	r = [msg rangeOfString:@" changed nickname to "];
	if( r.location != NSNotFound ) {
		NSString *oldnick = [msg substringToIndex:r.location];
		NSString *newnick = [msg substringFromIndex:r.location + r.length];

		MVChatUser *who = [self chatUserWithUniqueIdentifier:oldnick];
		if( [who isLocalUser] ) {
			MVSafeCopyAssign( _nickname, newnick );
			[who _setUniqueIdentifier:[newnick lowercaseString]];

			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatConnectionNicknameAcceptedNotification
			 object:self];
		} else {
			[self _updateKnownUser:who withNewNickname:newnick];

			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatUserNicknameChangedNotification
			 object:who
			 userInfo:@{@"oldNickname": oldnick}];
		}
	}
}

- (void) stcStatusPacketNoPass:(NSArray *) fields {
}

- (void) stcStatusPacketSignoff:(NSArray *) fields {
	NSString *msg = fields[1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:words[0]];
	[_room _removeMemberUser:sender];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserPartedNotification
	 object:_room
	 userInfo:@{@"user": sender}];
}

- (void) stcStatusPacketSignon:(NSArray *) fields {
	NSString *msg = fields[1];

	NSArray *words = [msg componentsSeparatedByString:@" "];
	MVChatUser *sender = [self chatUserWithUniqueIdentifier:words[0]];
	[sender _setIdleTime:0.];
	[_room _addMemberUser:sender];
	[[NSNotificationCenter chatCenter]
	 postNotificationOnMainThreadWithName:MVChatRoomUserJoinedNotification
	 object:_room
	 userInfo:@{@"user": sender}];
}

- (void) stcStatusPacketStatus:(NSArray<NSString*> *) fields {
	NSString *msg = fields[1];

	NSRange r;

	r = [msg rangeOfString:@"You are now in group "];
	if( r.location == 0 ) {
		NSString *name = nil;

		NSString *part = [msg substringFromIndex:r.length];
		r = [part rangeOfString:@" as moderator"];
		if( r.location != NSNotFound )
			name = [part substringToIndex:r.location];
		else
			name = part;

		[name retain]; // XXX Needed to avoid a crash, but may cause a leak...
		[self _joinChatRoomNamed:name withPassphrase:nil alreadyJoined:YES];
		[name release];
	}
}

- (void) stcStatusPacketTopic:(NSArray<NSString*> *) fields {
	NSString *msg = fields[1];

	NSRange r;

	r = [msg rangeOfString:@" changed the topic to "];
	if( r.location != NSNotFound ) {
		MVChatUser *sender =
		    [self chatUserWithUniqueIdentifier:[msg substringToIndex:r.location]];
		NSString *topic = [msg substringFromIndex:r.location + r.length];
		NSUInteger l = topic.length;
		if( l < 2 || ( [topic characterAtIndex:0] != '"' ||
			           [topic characterAtIndex:l - 1] != '"' ) ) {
			[self _postProtocolError:@"Received an invalid topic"];
		} else {
			[_room _setTopic:[[topic substringWithRange:NSMakeRange(1, l - 2)]
			       dataUsingEncoding:[self encoding]]];
			[_room _setTopicAuthor:sender];
			[_room _setTopicDate:[NSDate date]];
			[[NSNotificationCenter chatCenter]
			 postNotificationOnMainThreadWithName:MVChatRoomTopicChangedNotification
			 object:_room];
		}
	}
}

@end

NS_ASSUME_NONNULL_END
