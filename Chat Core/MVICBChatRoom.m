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

#import "MVICBChatConnection.h"
#import "MVICBChatRoom.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatString.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MVICBChatRoom

#pragma mark Constructors and finalizers

- (id) initWithName:(NSString *) name
       andConnection:(MVICBChatConnection *) connection {
	if( ( self = [self init] ) ) {
		_connection = connection;
		_name = name;
		_uniqueIdentifier = [name lowercaseString];
		[_connection _addKnownRoom:self];
	}
	return self;
}

#pragma mark Generic room handling

- (void) partWithReason:(MVChatString * __nullable) reason {
}

- (void) changeTopic:(MVChatString *) newTopic {
	NSParameterAssert( newTopic );
#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *newTopicString = [newTopic string];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSString *newTopicString = newTopic;
#endif
	[(MVICBChatConnection *)_connection ctsCommandTopicSet:newTopicString];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
#if USE(ATTRIBUTED_CHAT_STRING)
	NSString *messageString = [message string];
#elif USE(PLAIN_CHAT_STRING) || USE(HTML_CHAT_STRING)
	NSString *messageString = message;
#endif
	if( _memberUsers.count > 1 )
		[(MVICBChatConnection *)_connection ctsOpenPacket:messageString];
}

@end

NS_ASSUME_NONNULL_END
