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
- (void) _incrementalWriteToLog:(xmlNodePtr) node continuation:(BOOL) cont;
- (void) _chnageFileAttributesAtPath:(NSString *) path;
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
		_autoWriteChanges = NO;
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;

		@synchronized( self ) {
			_messages = [[NSMutableArray allocWithZone:[self zone]] initWithCapacity:100];

			_xmlLog = xmlNewDoc( "1.0" );
			xmlDocSetRootElement( _xmlLog, xmlNewNode( NULL, "log" ) );
			xmlSetProp( xmlDocGetRootElement( _xmlLog ), "began", [[[NSDate date] description] UTF8String] );
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

	xmlFreeDoc( _xmlLog );

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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) )
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", node -> name, 7 ) )
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) )
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) )
				count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) ) {
						if( NSLocationInRange( i, range ) ) {
							JVChatMessage *msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
							if( msg ) [ret addObject:msg];
						}

						if( ++i > ( range.location + range.length ) ) goto done;
					}
				} while( subNode && ( subNode = subNode -> next ) ); 
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", node -> name, 7 ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatSession *session = [JVChatSession sessionWithNode:node andTranscript:self];
					if( session ) [ret addObject:session];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) )
						return [JVChatMessage messageWithNode:subNode andTranscript:self];
				} while( subNode && ( subNode = subNode -> prev ) );
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", node -> name, 7 ) ) {
				return [JVChatSession sessionWithNode:node andTranscript:self];
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) ) {
						if( NSLocationInRange( i, range ) ) {
							if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[JVChatMessage class]] ) {
								msg = [_messages objectAtIndex:i];
							} else if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
								msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" index:i] autorelease]];
								[_messages replaceObjectAtIndex:i withObject:msg];
							} else if( [_messages count] == i ) {
								msg = [JVChatMessage messageWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" index:i] autorelease]];
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) ) {
						xmlChar *prop = xmlGetProp( subNode, "id" );
						if( prop && ! strcmp( prop, ident ) ) foundNode = subNode;
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "message", node -> name, 7 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", node -> name, 8 ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "message", subNode -> name, 7 ) ) {
						xmlChar *prop = xmlGetProp( subNode, "id" );
						if( prop && ! strcmp( prop, ident ) ) found = YES;
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
			// check if the last node is an envelope by the same sender, if so append this message to that envelope
			xmlNode *lastChild = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
			if( lastChild && lastChild -> type == XML_ELEMENT_NODE && ! strncmp( "envelope", lastChild -> name, 8 ) ) {
				xmlNode *subNode = lastChild -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strncmp( "sender", subNode -> name, 6 ) ) {
						NSString *identifier = [message senderIdentifier];
						NSString *nickname = [message senderNickname];
						NSString *name = [message senderName];

						xmlChar *senderNameStr = xmlNodeGetContent( subNode );
						NSString *senderName = [NSString stringWithUTF8String:senderNameStr];
						xmlFree( senderNameStr );

						NSString *senderNickname = nil;
						NSString *senderIdentifier = nil;

						xmlChar *prop = xmlGetProp( subNode, "nickname" );
						if( prop ) senderNickname = [NSString stringWithUTF8String:prop];
						xmlFree( prop );

						prop = xmlGetProp( subNode, "identifier" );
						if( prop ) senderIdentifier = [NSString stringWithUTF8String:prop];
						xmlFree( prop );

						if( [senderIdentifier isEqualToString:identifier] || [senderNickname isEqualToString:nickname] || [senderName isEqualToString:name] )
							parent = lastChild;

						break;
					}
				} while( subNode && ( subNode = subNode -> next ) ); 
			}
		}

		if( ! parent ) { // make a new envelope to append
			root = xmlNewNode( NULL, "envelope" );
			root = xmlAddChild( xmlDocGetRootElement( _xmlLog ), root );

			xmlNode *subNode = ((xmlNode *) [message node]) -> parent -> children;

			do {
				if( ! strncmp( "sender", subNode -> name, 6 ) ) break;
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", node -> name, 7 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "session", node -> name, 7 ) )
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
	xmlNodePtr sessionNode = xmlNewNode( NULL, "session" );
	xmlSetProp( sessionNode, "started", [[startDate description] UTF8String] );
	xmlAddChild( xmlDocGetRootElement( _xmlLog ), sessionNode );
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) ) {
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) )
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strncmp( "event", node -> name, 5 ) ) {
				xmlChar *prop = xmlGetProp( node, "id" );
				if( prop && ! strcmp( prop, ident ) ) found = YES;
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

	[self _chnageFileAttributesAtPath:path];

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

		if( [url isFileURL] ) [self _chnageFileAttributesAtPath:[url path]];
	}

	return ret;
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptPrivate)
- (void) _incrementalWriteToLog:(xmlNode *) node continuation:(BOOL) cont {
	if( ! [self automaticallyWritesChangesToFile] ) return;

	BOOL format = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"];

	if( ! [[NSFileManager defaultManager] fileExistsAtPath:[self filePath]] ) {
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

		[logElement appendString:@">"];
		if( format ) [logElement appendString:@"\n"];
		[logElement appendString:@"</log>"];

		NSData *xml = [logElement dataUsingEncoding:NSUTF8StringEncoding];
		[xml writeToFile:[self filePath] atomically:NO];

		[self _chnageFileAttributesAtPath:[self filePath]];

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
		if( strncmp( "<envelope", [check bytes], 9 ) ) { // this is a bad offset!
			_requiresNewEnvelope = YES;
			_previousLogOffset = 0;
			return;
		} else [_logFile seekToFileOffset:_previousLogOffset]; // the check was fine, go back
	} else {
		unsigned int offset = 6;
		[_logFile seekToFileOffset:[_logFile seekToEndOfFile] - 1];
		NSData *check = [_logFile readDataOfLength:1]; // check to see if there is an trailing newline and correct
		if( ! strncmp( "\n", [check bytes], 1 ) ) offset++; // we need to eat the newline also

		[_logFile seekToFileOffset:[_logFile offsetInFile] - offset];
		check = [_logFile readDataOfLength:offset]; // check to see if there is a </log> here
		if( strncmp( ( offset == 7 ? "</log>\n" : "</log>" ), [check bytes], offset ) ) { // this is a bad file!
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

- (void) _chnageFileAttributesAtPath:(NSString *) path {
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, [NSNumber numberWithUnsignedLong:'coTr'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'coRC'], NSFileHFSCreatorCode, nil] atPath:path];
}
@end