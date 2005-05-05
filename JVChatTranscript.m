#import "JVChatTranscript.h"
#import "JVChatSession.h"
#import "JVChatMessage.h"
#import "JVChatEvent.h"
#import "KAIgnoreRule.h"

#import <ChatCore/MVChatUser.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSDataAdditions.h>
#import <ChatCore/NSAttributedStringAdditions.h>

#import <libxml/xinclude.h>

#ifdef MAC_OS_X_VERSION_10_4
#include <sys/xattr.h>
#endif

// define these here so they weak link for Panther letting the binary will load
extern int setxattr(const char *path, const char *name, const void *value, size_t size, u_int32_t position, int options) __attribute__((weak_import));
extern int fsetxattr(int fd, const char *name, const void *value, size_t size, u_int32_t position, int options) __attribute__((weak_import));

#pragma mark -

/* Future method ideas (implement when needed):
- (void) prependMessage:(JVChatMessage *) message;
- (void) prependMessages:(NSArray *) messages;

- (void) prependChatTranscript:(JVChatTranscript *) transcript;

- (void) insertMessage:(JVChatMessage *) message atIndex:(unsigned) index;

- (void) replaceMessageAtIndex:(unsigned) index withMessage:(JVChatMessage *) message;
- (void) replaceMessagesInRange:(NSRange) range withMessages:(NSArray *) messages;

- (void) removeMessage:(JVChatMessage *) message;
- (void) removeMessageAtIndex:(unsigned) index;
- (void) removeMessageAtIndexes:(NSIndexSet *) indexes;
- (void) removeMessagesInRange:(NSRange) range;
- (void) removeMessagesInArray:(NSArray *) messages;
- (void) removeAllMessages;
*/

@interface JVChatSession (JVChatSessionPrivate)
+ (id) sessionWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (id) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) setNode:(xmlNode *) node;
@end

#pragma mark -

@interface JVChatMessage (JVChatMessagePrivate)
+ (id) messageWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (id) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) setNode:(xmlNode *) node;
@end

#pragma mark -

@interface JVChatEvent (JVChatEventPrivate)
+ (id) eventWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (id) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) setNode:(xmlNode *) node;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (void) _enforceElementLimit;
- (void) _incrementalWriteToLog:(xmlNodePtr) node continuation:(BOOL) cont;
- (void) _changeFileAttributesAtPath:(NSString *) path;
@end

#pragma mark -

@implementation JVChatTranscript
+ (id) chatTranscript {
	return [[[self alloc] init] autorelease];
}

+ (id) chatTranscriptWithChatTranscript:(JVChatTranscript *) transcript {
	return [[[self alloc] initWithChatTranscript:transcript] autorelease];
}

+ (id) chatTranscriptWithElements:(NSArray *) elements {
	return [[[self alloc] initWithElements:elements] autorelease];
}

+ (id) chatTranscriptWithContentsOfFile:(NSString *) path {
	return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

+ (id) chatTranscriptWithContentsOfURL:(NSURL *) url {
	return [[[self alloc] initWithContentsOfURL:url] autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_filePath = nil;
		_logFile = nil;
		_objectSpecifier = nil;
		_autoWriteChanges = NO;
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
		_elementLimit = 0;

		@synchronized( self ) {
			_messages = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:100];

			_xmlLog = xmlNewDoc( (xmlChar *) "1.0" );
			xmlDocSetRootElement( _xmlLog, xmlNewNode( NULL, (xmlChar *) "log" ) );
			xmlSetProp( xmlDocGetRootElement( _xmlLog ), (xmlChar *) "began", (xmlChar *) [[[NSDate date] description] UTF8String] );
		}
	}

	return self;
}

- (id) initWithChatTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) )
		[self appendChatTranscript:transcript];

	return self;
}

- (id) initWithElements:(NSArray *) elements {
	if( ( self = [self init] ) )
		[self appendElements:elements];

	return self;
}

- (id) initWithContentsOfFile:(NSString *) path {
	if( ( self = [self init] ) ) {
		path = [path stringByStandardizingPath];

		@synchronized( self ) {
			xmlFreeDoc( _xmlLog ); // release the empty document we made in [self init]
			if( ! ( _xmlLog = xmlParseFile( [path fileSystemRepresentation] ) ) ) {
				[self autorelease]; // file failed to parse, return nil
				return nil;
			}
		}

		[self setAutomaticallyWritesChangesToFile:YES];
		[self setFilePath:path];
	}

	return self;
}

- (id) initWithContentsOfURL:(NSURL *) url {
	if( ( self = [self init] ) ) {
		NSData *contents = [NSData dataWithContentsOfURL:url];
		if( ! contents || ! [contents length] ) {
			[self release]; // URL failed to return content, return nil
			return nil;
		}

		@synchronized( self ) {
			xmlFreeDoc( _xmlLog ); // release the empty document we made in [self init]
			if( ! ( _xmlLog = xmlParseMemory( [contents bytes], [contents length] ) ) ) {
				[self autorelease]; // data failed to parse, return nil
				return nil;
			}
		}
	}

	return self;
}

- (void) dealloc {
	[_filePath release];
	[_logFile release];
	[_messages release];
	[_objectSpecifier release];

	xmlFreeDoc( _xmlLog );

	_objectSpecifier = nil;
	_filePath = nil;
	_logFile = nil;
	_messages = nil;
	_xmlLog = NULL;

	[super dealloc];
}

#pragma mark -

- (void *) document {
	return _xmlLog;
}

#pragma mark -

- (BOOL) isEmpty {
	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE )
				return NO;
		} while( node && ( node = node -> next ) );
	}

	return YES;
}

- (unsigned long) elementCount {
	unsigned long count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) )
						count++;
				} while( subNode && ( subNode = subNode -> next ) );
			} else if( node && node -> type == XML_ELEMENT_NODE ) count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (unsigned long) sessionCount {
	unsigned long count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) )
				count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (unsigned long) messageCount {
	unsigned long count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) )
						count++;
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (unsigned long) eventCount {
	unsigned long count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) )
				count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

#pragma mark -

- (void) setElementLimit:(unsigned int) limit {
	_elementLimit = limit;
	[self _enforceElementLimit];
}

- (unsigned int) elementLimit {
	return _elementLimit;
}

#pragma mark -

- (NSArray *) elements {
	return [self elementsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of elements.
}

- (NSArray *) elementsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		unsigned long i = 0;
		NSMutableArray *ret = [NSMutableArray arrayWithCapacity:( range.length - range.location )];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						if( NSLocationInRange( i, range ) ) {
							JVChatMessage *msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
							if( msg ) [ret addObject:msg];
						}

						if( ++i > ( range.location + range.length ) ) goto done;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatSession *session = [JVChatSession sessionWithNode:node andTranscript:self];
					if( session ) [ret addObject:session];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatEvent *event = [JVChatEvent eventWithNode:node andTranscript:self];
					if( event ) [ret addObject:event];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return [NSArray arrayWithArray:ret];
	}
}

- (id) elementAtIndex:(unsigned long) index {
	return [[self elementsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (id) lastElement {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) )
						return [JVChatMessage messageWithNode:subNode andTranscript:self];
				} while( subNode && ( subNode = subNode -> prev ) );
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) ) {
				return [JVChatSession sessionWithNode:node andTranscript:self];
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) ) {
				return [JVChatEvent eventWithNode:node andTranscript:self];
			}
		} while( node && ( node = node -> prev ) );
	}

	return nil;
}

#pragma mark -

- (NSArray *) appendElements:(NSArray *) elements {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[elements count]];
	NSEnumerator *enumerator = [elements objectEnumerator];
	id element = nil;

	while( ( element = [enumerator nextObject] ) ) {
		if( ! [element conformsToProtocol:@protocol( JVChatTranscriptElement )] ) continue;
		@synchronized( ( [element transcript] ? (id) [element transcript] : (id) element ) ) {
			id newElement = nil;
			if( [element isKindOfClass:[JVChatMessage class]] ) newElement = [self appendMessage:element];
			else if( [element isKindOfClass:[JVChatEvent class]] ) newElement = [self appendEvent:element];
			else if( [element isKindOfClass:[JVChatSession class]] ) newElement = [self appendSessionWithStartDate:[element startDate]];
			if( newElement ) [ret addObject:newElement];
		}
	}

	return [NSArray arrayWithArray:ret];
}

- (void) appendChatTranscript:(JVChatTranscript *) transcript {
	[self appendElements:[transcript elements]];
}

#pragma mark -

- (NSArray *) messages {
	return [self messagesInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of messages.
}

- (NSArray *) messagesInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		if( [_messages count] >= ( range.location + range.length ) ) {
			NSArray *sub = [_messages subarrayWithRange:range];
			if( ! [sub containsObject:[NSNull null]] ) {
				return sub;
			}
		}

		unsigned long i = 0;

		if( [_messages count] < range.location )
			for( i = [_messages count]; i < range.location; i++ )
				[_messages insertObject:[NSNull null] atIndex:i];

		NSMutableArray *ret = [NSMutableArray arrayWithCapacity:( range.length - range.location )];
		JVChatMessage *msg = nil;

		i = 0;

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						if( NSLocationInRange( i, range ) ) {
							if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[JVChatMessage class]] ) {
								msg = [_messages objectAtIndex:i];
							} else if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
								msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" uniqueID:[msg messageIdentifier]] autorelease]];
								[_messages replaceObjectAtIndex:i withObject:msg];
							} else if( [_messages count] == i ) {
								msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" uniqueID:[msg messageIdentifier]] autorelease]];
								[_messages insertObject:msg atIndex:i];
							} else continue;
							if( msg ) [ret addObject:msg];
						}

						if( ++i > ( range.location + range.length ) ) goto done;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );

	done:
		return [NSArray arrayWithArray:ret];
	}
}

- (JVChatMessage *) messageAtIndex:(unsigned long) index {
	@synchronized( self ) {
		if( [_messages count] > index ) {
			id obj = [_messages objectAtIndex:index];
			if( ! [obj isKindOfClass:[NSNull class]] ) {
				return obj;
			}
		}
	}

	return [[self messagesInRange:NSMakeRange( index, 1 )] lastObject];
}

- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	@synchronized( self ) {
		const char *ident = [identifier UTF8String];
		xmlNode *foundNode = NULL;

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "id" );
						if( prop && ! strcmp( (char *) prop, ident ) ) foundNode = subNode;
						if( prop ) xmlFree( prop );
						if( foundNode ) break;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );

		return ( foundNode ? [JVChatMessage messageWithNode:foundNode andTranscript:self] : nil );
	}
}

- (NSArray *) messagesInEnvelopeWithMessage:(JVChatMessage *) message {
	NSParameterAssert( message != nil );
	NSParameterAssert( [message node] != NULL );

	@synchronized( self ) {
		xmlNode *envelope = ((xmlNode *)[message node]) -> parent;
		xmlNode *node = envelope -> children;
		NSMutableArray *results = [NSMutableArray array];

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) node -> name, 7 ) ) {
				JVChatMessage *msg = [JVChatMessage messageWithNode:node andTranscript:self];
				if( msg ) [results addObject:msg];
			}
		} while( node && ( node = node -> next ) );

		return [NSArray arrayWithArray:results];
	}

	return nil;
}

- (JVChatMessage *) lastMessage {
	@synchronized( self ) {
		xmlNode *foundNode = NULL;
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						foundNode = subNode;
						break;
					}
				} while( subNode && ( subNode = subNode -> prev ) );
			}
		} while( node && ( node = node -> prev ) );

		return ( foundNode ? [JVChatMessage messageWithNode:foundNode andTranscript:self] : nil );
	}
}

#pragma mark -

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		const char *ident = [identifier UTF8String];
		BOOL found = NO;

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "id" );
						if( prop && ! strcmp( (char *) prop, ident ) ) found = YES;
						if( prop ) xmlFree( prop );
						if( found ) return YES;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );

		return NO;
	}
}

#pragma mark -

- (JVChatMessage *) appendMessage:(JVChatMessage *) message {
	return [self appendMessage:message forceNewEnvelope:NO];
}

- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope {
	NSParameterAssert( message != nil );
	NSParameterAssert( [message node] != NULL );
	NSParameterAssert( [message transcript] != self );

	xmlNode *root = NULL, *child = NULL, *parent = NULL;

	@synchronized( self ) {
		if( ! _requiresNewEnvelope && ! forceEnvelope ) {
			// check if the last node is an envelope by the same sender (and maybe source), if so append this message to that envelope
			xmlNode *lastChild = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
			if( lastChild && lastChild -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) lastChild -> name, 8 ) ) {
				NSString *msgSource = [[message source] absoluteString];

				xmlChar *sourceStr = xmlGetProp( lastChild, (xmlChar *) "source" );
				NSString *source = ( sourceStr ? [NSString stringWithUTF8String:(char *) sourceStr] : nil );
				xmlFree( sourceStr );

				if( ( ! msgSource && ! source ) || [msgSource isEqualToString:source] ) { // same chat source, proceed to sender check
					xmlNode *subNode = lastChild -> children;
					do {
						if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "sender", (char *) subNode -> name, 6 ) ) {
							NSString *identifier = [message senderIdentifier];
							NSString *nickname = [message senderNickname];
							NSString *name = [message senderName];

							xmlChar *senderNameStr = xmlNodeGetContent( subNode );
							NSString *senderName = [NSString stringWithUTF8String:(char *) senderNameStr];
							xmlFree( senderNameStr );

							NSString *senderNickname = nil;
							NSString *senderIdentifier = nil;

							xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "nickname" );
							if( prop ) senderNickname = [NSString stringWithUTF8String:(char *) prop];
							xmlFree( prop );

							prop = xmlGetProp( subNode, (xmlChar *) "identifier" );
							if( prop ) senderIdentifier = [NSString stringWithUTF8String:(char *) prop];
							xmlFree( prop );

							if( [senderIdentifier isEqualToString:identifier] || [senderNickname isEqualToString:nickname] || [senderName isEqualToString:name] )
								parent = lastChild;

							break;
						}
					} while( subNode && ( subNode = subNode -> next ) );
				}
			}
		}

		if( ! parent ) { // make a new envelope to append
			root = xmlNewNode( NULL, (xmlChar *) "envelope" );
			root = xmlAddChild( xmlDocGetRootElement( _xmlLog ), root );

			if( [message source] ) xmlSetProp( root, (xmlChar *) "source", (xmlChar *) [[[message source] absoluteString] UTF8String] );

			if( [message ignoreStatus] == JVUserIgnored )
				xmlSetProp( root, (xmlChar *) "ignored", (xmlChar *) "yes" );

			xmlNode *subNode = ((xmlNode *) [message node]) -> parent -> children;

			do {
				if( ! strncmp( "sender", (char *) subNode -> name, 6 ) ) break;
			} while( subNode && ( subNode = subNode -> next ) );

			child = xmlDocCopyNode( subNode, _xmlLog, 1 );
			xmlAddChild( root, child );

			child = xmlDocCopyNode( (xmlNode *) [message node], _xmlLog, 1 );
			xmlAddChild( root, child );
		} else { // append message to an existing envelope
			root = parent;
			child = (xmlNode *) [message node];
			child = xmlAddChild( parent, xmlDocCopyNode( child, _xmlLog, 1 ) );
		}

		[self _enforceElementLimit];
		[self _incrementalWriteToLog:root continuation:( parent ? YES : NO )];

		_requiresNewEnvelope = NO;

		return [JVChatMessage messageWithNode:child andTranscript:self];
	}
}

- (NSArray *) appendMessages:(NSArray *) messages {
	return [self appendMessages:messages forceNewEnvelope:NO];
}

- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope {
	NSEnumerator *enumerator = [messages objectEnumerator];
	JVChatMessage *message = nil;
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[messages count]];

	if( forceEnvelope ) _requiresNewEnvelope = YES;

	while( ( message = [enumerator nextObject] ) ) {
		if( ! [message isKindOfClass:[JVChatMessage class]] ) continue;
		@synchronized( ( [message transcript] ? (id) [message transcript] : (id) message ) ) {
			message = [self appendMessage:message];
			if( message ) [ret addObject:message];
		}
	}

	return [NSArray arrayWithArray:ret];
}

#pragma mark -

- (NSArray *) sessions {
	return [self sessionsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of sessions.
}

- (NSArray *) sessionsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		unsigned long i = 0;
		NSMutableArray *ret = [NSMutableArray arrayWithCapacity:( range.length - range.location )];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatSession *session = [JVChatSession sessionWithNode:node andTranscript:self];
					if( session ) [ret addObject:session];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return [NSArray arrayWithArray:ret];
	}
}

- (JVChatSession *) sessionAtIndex:(unsigned long) index {
	return [[self sessionsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (JVChatSession *) lastSession {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) )
				return [JVChatSession sessionWithNode:node andTranscript:self];
		} while( node && ( node = node -> prev ) );
	}

	return nil;
}

#pragma mark -

- (JVChatSession *) startNewSession {
	return [self appendSessionWithStartDate:[NSDate date]];
}

- (JVChatSession *) appendSessionWithStartDate:(NSDate *) startDate {
	xmlNodePtr sessionNode = xmlNewNode( NULL, (xmlChar *) "session" );
	xmlSetProp( sessionNode, (xmlChar *) "started", (xmlChar *) [[startDate description] UTF8String] );
	xmlAddChild( xmlDocGetRootElement( _xmlLog ), sessionNode );
	[self _enforceElementLimit];
	[self _incrementalWriteToLog:sessionNode continuation:NO];
	return [JVChatSession sessionWithNode:sessionNode andTranscript:self];
}

#pragma mark -

- (NSArray *) events {
	return [self eventsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of events.
}

- (NSArray *) eventsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		unsigned long i = 0;
		NSMutableArray *ret = [NSMutableArray arrayWithCapacity:( range.length - range.location )];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatEvent *event = [JVChatEvent eventWithNode:node andTranscript:self];
					if( event ) [ret addObject:event];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return [NSArray arrayWithArray:ret];
	}
}

- (JVChatEvent *) eventAtIndex:(unsigned long) index {
	return [[self eventsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (JVChatEvent *) lastEvent {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) )
				return [JVChatEvent eventWithNode:node andTranscript:self];
		} while( node && ( node = node -> prev ) );
	}

	return nil;
}

#pragma mark -

- (BOOL) containsEventWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	@synchronized( self ) {
		const char *ident = [identifier UTF8String];
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		BOOL found = NO;

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) ) {
				xmlChar *prop = xmlGetProp( node, (xmlChar *) "id" );
				if( prop && ! strcmp( (char *) prop, ident ) ) found = YES;
				if( prop ) xmlFree( prop );
				if( found ) return YES;
			}
		} while( node && ( node = node -> next ) );

		return NO;
	}
}

#pragma mark -

- (JVChatEvent *) appendEvent:(JVChatEvent *) event {
	NSParameterAssert( event != nil );
	NSParameterAssert( [event node] != NULL );
	NSParameterAssert( [event transcript] != self );

	@synchronized( self ) {
		xmlNode *root = xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( [event node], _xmlLog, 1 ) );
		[self _enforceElementLimit];
		[self _incrementalWriteToLog:root continuation:NO];
		return [JVChatEvent eventWithNode:root andTranscript:self];
	}
}

#pragma mark -

- (NSString *) filePath {
	return _filePath;
}

- (void) setFilePath:(NSString *) filePath {
	if( filePath && ! [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
		BOOL success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
		if( success ) [[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil]; // remove the blank until we need to write the real file, since we now know it will likely work
		else filePath = nil; // since we can't write no use in keeping the path
	} else if( filePath && ! [[NSFileManager defaultManager] isWritableFileAtPath:filePath] ) {
		filePath = nil; // the file isn't writable, no use in keeping the path
	}

	filePath = [filePath stringByStandardizingPath];
	if( [filePath isEqualToString:_filePath] ) return;

	[_filePath autorelease];
	_filePath = [filePath copyWithZone:[self zone]];

	if( _logFile ) {
		[_logFile synchronizeFile];
		[_logFile closeFile];
		[_logFile autorelease];
		_logFile = nil;
	}

	if( [_filePath length] && [self automaticallyWritesChangesToFile] ) {
		_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:_filePath] retain];
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
	}
}

#pragma mark -

- (NSURL *) source {
	return _source;
}

- (void) setSource:(NSURL *) source {
	[_source autorelease];
	_source = [source copyWithZone:[self zone]];
	xmlSetProp( xmlDocGetRootElement( _xmlLog ), (xmlChar *) "source", (xmlChar *) [[_source absoluteString] UTF8String] );
}

#pragma mark -

- (BOOL) automaticallyWritesChangesToFile {
	return _autoWriteChanges;
}

- (BOOL) setAutomaticallyWritesChangesToFile:(BOOL) option {
	if( _autoWriteChanges == option ) return;

	_autoWriteChanges = option;

	if( _logFile ) {
		[_logFile synchronizeFile];
		[_logFile closeFile];
		[_logFile autorelease];
		_logFile = nil;
	}

	if( _autoWriteChanges && [[self filePath] length] ) {
		_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:[self filePath]] retain];
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
	}
}

#pragma mark -

- (BOOL) writeToFile:(NSString *) path atomically:(BOOL) useAuxiliaryFile {
	BOOL ret = NO;

	@synchronized( self ) {
		int size = 0;
		xmlChar *buf = NULL;
		xmlDocDumpFormatMemory( _xmlLog, &buf, &size, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );

		if( ! buf ) return NO;

		NSData *xmlData = [[NSData allocWithZone:[self zone]] initWithBytesNoCopy:buf length:size freeWhenDone:YES];
		ret = [xmlData writeToFile:path atomically:useAuxiliaryFile];
		[xmlData release];
	}

	[self _changeFileAttributesAtPath:path];

	return ret;
}

- (BOOL) writeToURL:(NSURL *) url atomically:(BOOL) atomically {
	BOOL ret = NO;

	@synchronized( self ) {
		int size = 0;
		xmlChar *buf = NULL;
		xmlDocDumpFormatMemory( _xmlLog, &buf, &size, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );

		if( ! buf ) return NO;

		NSData *xmlData = [[NSData allocWithZone:[self zone]] initWithBytesNoCopy:buf length:size freeWhenDone:YES];
		ret = [xmlData writeToURL:url atomically:atomically];
		[xmlData release];

		if( [url isFileURL] ) [self _changeFileAttributesAtPath:[url path]];
	}

	return ret;
}

#pragma mark -

- (NSScriptObjectSpecifier *) objectSpecifier {
	return _objectSpecifier;
}

- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier {
	[_objectSpecifier autorelease];
	_objectSpecifier = [objectSpecifier retain];
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptPrivate)
- (void) _enforceElementLimit {
	if( ! [self elementLimit] ) return;

	unsigned long limit = [self elementLimit];
	unsigned long count = [self elementCount];
	if( count <= limit ) return;

	unsigned long total = ( count - limit );
	xmlNode *tmp = NULL;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", (char *) node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				BOOL removedAllMessages = YES;

				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", (char *) subNode -> name, 7 ) ) {
						if( total > 0 ) {
							tmp = subNode -> prev;
							xmlUnlinkNode( subNode );
							xmlFreeNode( subNode );
							subNode = ( tmp ? tmp : node -> children );
							total--;
							if( [_messages count] > 1 ) [_messages removeObjectAtIndex:0];
						} else if( ! total ) {
							removedAllMessages = NO;
							break;
						}
					}
				} while( subNode && ( subNode = subNode -> next ) );

				if( total > 0 || removedAllMessages ) { // remove the envelope since there are no messages in it
					tmp = node -> prev;
					xmlUnlinkNode( node );
					xmlFreeNode( node );
					node = ( tmp ? tmp : xmlDocGetRootElement( _xmlLog ) -> children );
				}
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", (char *) node -> name, 7 ) ) {
				tmp = node -> prev;
				xmlUnlinkNode( node );
				xmlFreeNode( node );
				node = ( tmp ? tmp : xmlDocGetRootElement( _xmlLog ) -> children );
				total--;
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", (char *) node -> name, 5 ) ) {
				tmp = node -> prev;
				xmlUnlinkNode( node );
				xmlFreeNode( node );
				node = ( tmp ? tmp : xmlDocGetRootElement( _xmlLog ) -> children );
				total--;
			}
		} while( total > 0 && node && ( node = node -> next ) );
	}
}

- (void) _incrementalWriteToLog:(xmlNode *) node continuation:(BOOL) cont {
	if( ! [self automaticallyWritesChangesToFile] ) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	if( [fm fileExistsAtPath:[self filePath]] && ! [fm isWritableFileAtPath:[self filePath]] ) return;

	unsigned long long fileSize = [[fm fileAttributesAtPath:[self filePath] traverseLink:YES] objectForKey:NSFileSize];
	if( fileSize != nil && [fileSize intValue] < 6 ) { // the file is too small to be a viable log file, return now
		[self setAutomaticallyWritesChangesToFile:NO];
		return;
	}

	BOOL format = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"];

	if( ! fileSize || ! [fm fileExistsAtPath:[self filePath]] ) {
		xmlNode *root = xmlDocGetRootElement( _xmlLog );

		// Save out the <log> element since this is a new file. build it by hand
		NSMutableString *logElement = [NSMutableString string];
		[logElement appendFormat:@"<%s", root -> name];

		xmlAttrPtr prop = NULL;
		for( prop = root -> properties; prop; prop = prop -> next ) {
			xmlChar *value = xmlGetProp( root, prop -> name );
			if( value ) {
				[logElement appendFormat:@" %s=\"%s\"", prop -> name, value];
				xmlFree( value );
			}
		}

		NSString *dateString = [[NSCalendarDate date] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]];

		[logElement appendString:@">"];
		if( format ) [logElement appendString:@"\n"];
		[logElement appendString:@"</log>"];

		NSData *xml = [logElement dataUsingEncoding:NSUTF8StringEncoding];
		if( ! [xml writeToFile:[self filePath] atomically:NO] ) return;

#ifdef MAC_OS_X_VERSION_10_4
		if( floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_3 && setxattr != NULL )
			setxattr( [[self filePath] fileSystemRepresentation], "dateStarted", [dateString UTF8String], [dateString length], 0, 0 );
#endif

		[self _changeFileAttributesAtPath:[self filePath]];

		if( ! _logFile && [self automaticallyWritesChangesToFile] ) {
			_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:[self filePath]] retain];
			_requiresNewEnvelope = YES;
			_previousLogOffset = 0;
		}
	}

	if( ! node || ! _logFile ) return;

	// To keep the XML valid at all times, we need to preserve a </log> close tag at the end of
	// the file at all times. So, we seek to the end of the file minus 6 or 7 characters.
	if( cont && _previousLogOffset ) {
		[_logFile seekToFileOffset:_previousLogOffset];
		NSData *check = [_logFile readDataOfLength:9]; // check to see if there is an <envelope> here
		if( [check length] != 9 || strncmp( "<envelope", [check bytes], 9 ) ) { // this is a bad offset!
			_requiresNewEnvelope = YES;
			_previousLogOffset = 0;
			return;
		} else [_logFile seekToFileOffset:_previousLogOffset]; // the check was fine, go back
	} else {
		unsigned int offset = 6;
		[_logFile seekToFileOffset:[_logFile seekToEndOfFile] - 1];
		NSData *check = [_logFile readDataOfLength:1]; // check to see if there is an trailing newline and correct
		if( [check length] == 1 && ! strncmp( "\n", [check bytes], 1 ) ) offset++; // we need to eat the newline also

		[_logFile seekToFileOffset:[_logFile offsetInFile] - offset];
		check = [_logFile readDataOfLength:offset]; // check to see if there is a </log> here
		if( [check length] != offset || strncmp( ( offset == 7 ? "</log>\n" : "</log>" ), [check bytes], offset ) ) { // this is a bad file!
			[self setAutomaticallyWritesChangesToFile:NO];
			return;
		} else [_logFile seekToFileOffset:[_logFile offsetInFile] - offset]; // the check was fine, go back
	}

	xmlBufferPtr buf = xmlBufferCreate();
	xmlNodeDump( buf, node -> doc, node, 1, (int) format );

	if( format && ! cont ) [_logFile writeData:[@"  " dataUsingEncoding:NSUTF8StringEncoding]];

	_previousLogOffset = [_logFile offsetInFile];
	[_logFile truncateFileAtOffset:_previousLogOffset];

	[_logFile writeData:[NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO]];

	if( format ) [_logFile writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[_logFile writeData:[@"</log>" dataUsingEncoding:NSUTF8StringEncoding]];

	xmlBufferFree( buf );
}

- (void) _changeFileAttributesAtPath:(NSString *) path {
	NSString *dateString = [[NSCalendarDate date] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]];

	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, [NSNumber numberWithUnsignedLong:'coTr'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'coRC'], NSFileHFSCreatorCode, nil] atPath:path];

#ifdef MAC_OS_X_VERSION_10_4
	if( floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_3 && fsetxattr != NULL ) {
		FILE *logs = fopen( [path fileSystemRepresentation], "w+" );
		if( logs ) {
			int logsFd = fileno( logs );
			fsetxattr( logsFd, "server", [[[self source] host] UTF8String], [[[self source] host] length], 0, 0 );
			fsetxattr( logsFd, "target", [[[self source] path] UTF8String], [[[self source] path] length], 0, 0 );
			fsetxattr( logsFd, "lastDate", [dateString UTF8String], [dateString length], 0, 0 );
			fclose( logs );
		}
	}
#endif
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptScripting)
- (void) saveScriptCommand:(NSScriptCommand *) command {
	NSDictionary *args = [command evaluatedArguments];
	id path = [args objectForKey:@"File"];

	if( path && ! [path isKindOfClass:[NSString class]] ) {
		[command setScriptErrorNumber:1000];
		[command setScriptErrorString:@"The file path needs to be a string."];
		return;
	}

	if( ! path && ! [self filePath] ) {
		[command setScriptErrorNumber:1000];
		[command setScriptErrorString:@"A file must be specified since the transcript has no associated file."];
		return;
	}

	if( ! path ) path = [self filePath];

	[self writeToFile:path atomically:YES];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The transcript doesn't have the \"%@\" property.", key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of the transcript is read only.", key]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}

#pragma mark -

- (void) scriptErrorCantRemoveMessageException {
	[[NSScriptCommand currentCommand] setScriptErrorString:@"Can't remove or replace a message in a transcript."];
	[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
}

- (void) scriptErrorCantInsertMessageException {
	[[NSScriptCommand currentCommand] setScriptErrorString:@"Can't insert a message in the middle of a transcript. You can only add to the end."];
	[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
}

#pragma mark -

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (JVChatMessage *) valueInMessagesAtIndex:(long long) index {
	if( index == -1 ) return [self lastMessage];

	if( index < 0 ) {
		unsigned long count = [self messageCount];
		if( ABS( index ) > count ) return nil;
		index = count + index;
	}

	return [self messageAtIndex:index];
}

- (JVChatMessage *) valueInMessagesWithUniqueID:(id) identifier {
	return [self messageWithIdentifier:identifier];
}

- (void) addInMessages:(JVChatMessage *) message {
	[self appendMessage:message];
}

- (void) insertInMessages:(JVChatMessage *) message {
	[self appendMessage:message];
}

- (void) insertInMessages:(JVChatMessage *) message atIndex:(unsigned) index {
	[self scriptErrorCantInsertMessageException];
}

- (void) removeFromMessagesAtIndex:(unsigned) index {
	[self scriptErrorCantRemoveMessageException];
}

- (void) replaceInMessages:(JVChatMessage *) message atIndex:(unsigned) index {
	[self scriptErrorCantRemoveMessageException];
}
@end