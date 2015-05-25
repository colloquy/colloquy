/*
 * Chat Core
 * ICB Protocol Support
 *
 * Copyright (c) 2006, 2007 Julio M. Merino Vidal <jmmv@NetBSD.org>
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

#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

@class GCDAsyncSocket;
@class MVICBChatRoom;

@interface MVICBChatConnection : MVChatConnection {
@private
	NSString *_username;
	NSString *_nickname;
	NSString *_password;
	NSString *_server;
	unsigned short _serverPort;
	NSString *_initialChannel;

	MVICBChatRoom *_room;

	GCDAsyncSocket *_chatConnection;
    dispatch_queue_t _connectionDelegateQueue;
	NSThread *_connectionThread;
	NSConditionLock *_threadWaitLock;
	BOOL _loggedIn;

	NSMutableArray *_sendQueue;
	BOOL _sendQueueProcessing : 1;
}
+ (NSArray *) defaultServerPorts;

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier;
@end

@class ICBPacket;

@interface MVICBChatConnection (MVICBChatConnectionProtocolHandlers)
- (void) ctsCommandGroup:(NSString *) name;
- (void) ctsCommandName:(NSString *) name;
- (void) ctsCommandPersonal:(NSString *) who withMessage:(NSString *) message;
- (void) ctsCommandTopic;
- (void) ctsCommandTopicSet:(NSString *) topic;
- (void) ctsCommandWho:(NSString *) group;
- (void) ctsLoginPacket;
- (void) ctsOpenPacket:(NSString *) message;
- (void) ctsPongPacket;
- (void) ctsPongPacketWithId:(NSString *) ident;
- (void) stcDemux:(ICBPacket *) packet;
@end

NS_ASSUME_NONNULL_END
