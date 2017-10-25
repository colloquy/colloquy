#import "JVChatTranscript.h"
#import "JVChatSession.h"
#import "JVChatMessage.h"
#import "JVChatEvent.h"
#import "KAIgnoreRule.h"
#import "NSAttributedStringMoreAdditions.h"
#import <ChatCore/NSDateAdditions.h>

#include <libxml/tree.h>

NS_ASSUME_NONNULL_BEGIN

NSString *JVChatTranscriptUpdatedNotification = @"JVChatTranscriptUpdatedNotification";

#pragma mark -

/* Future method ideas (implement when needed):
- (void) prependMessage:(JVChatMessage *) message;
- (void) prependMessages:(NSArray *) messages;

- (void) prependChatTranscript:(JVChatTranscript *) transcript;

- (void) insertMessage:(JVChatMessage *) message atIndex:(NSUInteger) index;

- (void) replaceMessageAtIndex:(NSUInteger) index withMessage:(JVChatMessage *) message;
- (void) replaceMessagesInRange:(NSRange) range withMessages:(NSArray *) messages;

- (void) removeMessage:(JVChatMessage *) message;
- (void) removeMessageAtIndex:(NSUInteger) index;
- (void) removeMessageAtIndexes:(NSIndexSet *) indexes;
- (void) removeMessagesInRange:(NSRange) range;
- (void) removeMessagesInArray:(NSArray *) messages;
- (void) removeAllMessages;
*/

@interface JVChatSession (JVChatSessionPrivate)
- (nullable instancetype) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript NS_RETURNS_RETAINED;
- (void) _setNode:(nullable xmlNode *) node;
@end

#pragma mark -

@interface JVChatMessage (JVChatMessagePrivate)
- (nullable instancetype) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript NS_RETURNS_RETAINED;
- (void) _setNode:(nullable xmlNode *) node;
- (void) _loadFromXML;
- (void) _loadSenderFromXML;
- (void) _loadBodyFromXML;
@end

#pragma mark -

@interface JVChatEvent (JVChatEventPrivate)
- (nullable instancetype) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript NS_RETURNS_RETAINED;
- (void) _setNode:(nullable xmlNode *) node;
@end

#pragma mark -

@implementation JVChatTranscript
@synthesize elementLimit = _elementLimit;

+ (instancetype) chatTranscript {
	return [[self alloc] init];
}

+ (instancetype) chatTranscriptWithChatTranscript:(JVChatTranscript *) transcript {
	return [[self alloc] initWithChatTranscript:transcript];
}

+ (instancetype) chatTranscriptWithElements:(NSArray *) elements {
	return [[self alloc] initWithElements:elements];
}

+ (nullable instancetype) chatTranscriptWithContentsOfFile:(NSString *) path {
	return [[self alloc] initWithContentsOfFile:path];
}

+ (nullable instancetype) chatTranscriptWithContentsOfURL:(NSURL *) url {
	return [[self alloc] initWithContentsOfURL:url];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_filePath = nil;
		_logFile = nil;
		_objectSpecifier = nil;
		_autoWriteChanges = NO;
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
		_elementLimit = 0;

		@synchronized( self ) {
			_messages = [[NSMutableArray alloc] initWithCapacity:100];

			_xmlLog = xmlNewDoc( (xmlChar *) "1.0" );
			xmlDocSetRootElement( _xmlLog, xmlNewNode( NULL, (xmlChar *) "log" ) );
			xmlSetProp( xmlDocGetRootElement( _xmlLog ), (xmlChar *) "began", (xmlChar *) [[[NSDate date] localizedDescription] UTF8String] );
		}
	}

	return self;
}

- (instancetype) initWithChatTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) )
		[self appendChatTranscript:transcript];

	return self;
}

- (instancetype) initWithElements:(NSArray *) elements {
	if( ( self = [self init] ) )
		[self appendElements:elements];

	return self;
}

- (nullable instancetype) initWithContentsOfFile:(NSString *) path {
	if( ( self = [self init] ) ) {
		path = [path stringByStandardizingPath];

		@synchronized( self ) {
			xmlFreeDoc( _xmlLog ); // release the empty document we made in [self init]
			if( ! ( _xmlLog = xmlParseFile( [path fileSystemRepresentation] ) ) ) {
				return nil;
			}
		}

		[self setAutomaticallyWritesChangesToFile:YES];
		[self setFilePath:path];
	}

	return self;
}

- (nullable instancetype) initWithContentsOfURL:(NSURL *) url {
	if( ( self = [self init] ) ) {
		NSData *contents = [NSData dataWithContentsOfURL:url];
		if( ! contents || ! [contents length] || [contents length] > INT_MAX ) {
			 // URL failed to return content, return nil
			return nil;
		}

		@synchronized( self ) {
			xmlFreeDoc( _xmlLog ); // release the empty document we made in [self init]
			if( ! ( _xmlLog = xmlParseMemory( [contents bytes], (int)[contents length] ) ) ) {
				return nil;
			}
		}
	}

	return self;
}

- (void) dealloc {
	xmlFreeDoc( _xmlLog );

	_objectSpecifier = nil;
	_filePath = nil;
	_logFile = nil;
	_messages = nil;
	_xmlLog = NULL;
}

#pragma mark -

- (xmlDoc *) document {
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

- (NSUInteger) elementCount {
	NSUInteger count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) )
						count++;
				} while( subNode && ( subNode = subNode -> next ) );
			} else if( node && node -> type == XML_ELEMENT_NODE ) count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (NSUInteger) sessionCount {
	NSUInteger count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) )
				count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (NSUInteger) messageCount {
	NSUInteger count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) )
						count++;
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );
	}

	return count;
}

- (NSUInteger) eventCount {
	NSUInteger count = 0;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) )
				count++;
		} while( node && ( node = node -> next ) );
	}

	return count;
}

#pragma mark -

- (void) setElementLimit:(NSUInteger) limit {
	_elementLimit = limit;
	[self _enforceElementLimit];
}

- (NSUInteger) elementLimit {
	return _elementLimit;
}

#pragma mark -

- (nullable NSArray *) elements {
	return [self elementsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of elements.
}

- (nullable NSArray *) elementsInRange:(NSRange) range {
	if( ! range.length ) return @[];

	@synchronized( self ) {
		NSUInteger i = 0;
		NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:range.length];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
						if( NSLocationInRange( i, range ) ) {
							JVChatMessage *msg = [[JVChatMessage alloc] _initWithNode:subNode andTranscript:self];
							if( msg ) [ret addObject:msg];
						}

						if( ++i > ( range.location + range.length ) ) goto done;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatSession *session = [[JVChatSession alloc] _initWithNode:node andTranscript:self];
					if( session ) [ret addObject:session];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatEvent *event = [[JVChatEvent alloc] _initWithNode:node andTranscript:self];
					if( event ) [ret addObject:event];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return ret;
	} return nil;
}

- (nullable id) elementAtIndex:(NSUInteger) index {
	return [[self elementsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (nullable id) lastElement {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) )
						return [[JVChatMessage alloc] _initWithNode:subNode andTranscript:self];
				} while( subNode && ( subNode = subNode -> prev ) );
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) ) {
				return [[JVChatSession alloc] _initWithNode:node andTranscript:self];
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) ) {
				return [[JVChatEvent alloc] _initWithNode:node andTranscript:self];
			}
		} while( node && ( node = node -> prev ) );
	}

	return nil;
}

#pragma mark -

- (NSArray *) appendElements:(NSArray *) elements {
	NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:[elements count]];

	for( id element in elements ) {
		if( ! [element conformsToProtocol:@protocol( JVChatTranscriptElement )] ) continue;
		@synchronized( ( [element transcript] ? (id) [element transcript] : (id) element ) ) {
			id newElement = nil;
			if( [element isKindOfClass:[JVChatMessage class]] ) newElement = [self appendMessage:element];
			else if( [element isKindOfClass:[JVChatEvent class]] ) newElement = [self appendEvent:element];
			else if( [element isKindOfClass:[JVChatSession class]] ) newElement = [self appendSession:element];
			if( newElement ) [ret addObject:newElement];
		}
	}

	return ret;
}

- (void) appendChatTranscript:(JVChatTranscript *) transcript {
	[self appendElements:[transcript elements]];
}

#pragma mark -

- (nullable NSArray *) messages {
	return [self messagesInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of messages.
}

- (nullable NSArray *) messagesInRange:(NSRange) range {
	if( ! range.length ) return @[];

	@synchronized( self ) {
		if( [_messages count] >= ( range.location + range.length ) ) {
			NSArray *sub = [_messages subarrayWithRange:range];
			if( ! [sub containsObject:[NSNull null]] ) {
				return sub;
			}
		}

		if( [_messages count] < range.location )
			for( NSUInteger i = [_messages count]; i < range.location; i++ )
				[_messages insertObject:[NSNull null] atIndex:i];

		NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:range.length];
		JVChatMessage *msg = nil;

		NSUInteger i = 0;

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
						if( NSLocationInRange( i, range ) ) {
							if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[JVChatMessage class]] ) {
								msg = [_messages objectAtIndex:i];
							} else if( [_messages count] > i && [[_messages objectAtIndex:i] isKindOfClass:[NSNull class]] ) {
								msg = [[JVChatMessage alloc] _initWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" uniqueID:[msg messageIdentifier]]];
								_messages[i] = msg;
							} else if( [_messages count] == i ) {
								msg = [[JVChatMessage alloc] _initWithNode:subNode andTranscript:self];
								id classDesc = [NSClassDescription classDescriptionForClass:[self class]];
								[msg setObjectSpecifier:[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:[self objectSpecifier] key:@"messages" uniqueID:[msg messageIdentifier]]];
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
		return ret;
	} return nil;
}

- (nullable JVChatMessage *) messageAtIndex:(NSUInteger) index {
	NSRange range = NSMakeRange( index, 1 );

	@synchronized( self ) {
		if( [_messages count] > index ) {
			id obj = _messages[index];
			if( ! [obj isKindOfClass:[NSNull class]] ) {
				return obj;
			}
		}
	}

	return [[self messagesInRange:range] lastObject];
}

- (nullable JVChatMessage *) messageWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	@synchronized( self ) {
		const char *ident = [identifier UTF8String];
		xmlNode *foundNode = NULL;

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
						xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "id" );
						if( prop && ! strcmp( (char *) prop, ident ) ) foundNode = subNode;
						if( prop ) xmlFree( prop );
						if( foundNode ) break;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );

		return ( foundNode ? [[JVChatMessage alloc] _initWithNode:foundNode andTranscript:self] : nil );
	} return nil;
}

- (nullable JVChatMessage *) lastMessage {
	@synchronized( self ) {
		xmlNode *foundNode = NULL;
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = xmlGetLastChild( node );
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
						foundNode = subNode;
						break;
					}
				} while( subNode && ( subNode = subNode -> prev ) );
			}
		} while( node && ( node = node -> prev ) );

		return ( foundNode ? [[JVChatMessage alloc] _initWithNode:foundNode andTranscript:self] : nil );
	} return nil;
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
						xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "id" );
						if( prop && ! strcmp( (char *) prop, ident ) ) found = YES;
						if( prop ) xmlFree( prop );
						if( found ) return YES;
					}
				} while( subNode && ( subNode = subNode -> next ) );
			}
		} while( node && ( node = node -> next ) );
	}

	return NO;
}

#pragma mark -

- (nullable JVChatMessage *) appendMessage:(JVChatMessage *) message {
	return [self appendMessage:message forceNewEnvelope:NO];
}

- (nullable JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope {
	NSParameterAssert( message != nil );
	NSParameterAssert( [message node] != NULL );
	NSParameterAssert( [message transcript] != self );

	xmlNode *root = NULL, *child = NULL, *parent = NULL;

	@synchronized( self ) {
		if( ! _requiresNewEnvelope && ! forceEnvelope ) {
			// check if the last node is an envelope by the same sender (and maybe source), if so append this message to that envelope
			xmlNode *lastChild = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
			if( lastChild && lastChild -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) lastChild -> name ) ) {
				NSString *msgSource = [[message source] absoluteString];

				xmlChar *sourceStr = xmlGetProp( lastChild, (xmlChar *) "source" );
				NSString *source = ( sourceStr ? @((char *) sourceStr) : @"" );
				xmlFree( sourceStr );

				if( ( ! msgSource && ! source ) || [msgSource isEqualToString:source] ) { // same chat source, proceed to sender check
					xmlNode *subNode = lastChild -> children;
					do {
						if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "sender", (char *) subNode -> name ) ) {
							NSString *identifier = [message senderIdentifier];
							NSString *nickname = [message senderNickname];
							NSString *name = [message senderName];

							xmlChar *senderNameStr = xmlNodeGetContent( subNode );
							NSString *senderName = @((char *) senderNameStr);
							xmlFree( senderNameStr );

							NSString *senderNickname = nil;
							NSString *senderIdentifier = nil;

							xmlChar *prop = xmlGetProp( subNode, (xmlChar *) "nickname" );
							if( prop ) senderNickname = @((char *) prop);
							xmlFree( prop );

							prop = xmlGetProp( subNode, (xmlChar *) "identifier" );
							if( prop ) senderIdentifier = @((char *) prop);
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

			xmlNode *subNode = ([message node]) -> parent -> children;

			do {
				if( ! strcmp( "sender", (char *) subNode -> name ) ) break;
			} while( subNode && ( subNode = subNode -> next ) );

			child = xmlDocCopyNode( subNode, _xmlLog, 1 );
			xmlAddChild( root, child );

			child = xmlDocCopyNode( [message node], _xmlLog, 1 );
			xmlAddChild( root, child );
		} else { // append message to an existing envelope
			root = parent;
			child = [message node];
			child = xmlAddChild( parent, xmlDocCopyNode( child, _xmlLog, 1 ) );
		}

		[self _enforceElementLimit];
		[self _incrementalWriteToLog:root continuation:( parent ? YES : NO )];

		if( _logFile ) {
			NSString *lastDateString = [[message date] localizedDescription];
			fsetxattr( [_logFile fileDescriptor], "lastMessageDate", [lastDateString UTF8String], [lastDateString length], 0, 0 );
		}

		_requiresNewEnvelope = NO;

		return [[JVChatMessage alloc] _initWithNode:child andTranscript:self];
	} return nil;
}

- (NSArray *) appendMessages:(NSArray *) messages {
	return [self appendMessages:messages forceNewEnvelope:NO];
}

- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope {
	NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:[messages count]];

	if( forceEnvelope ) _requiresNewEnvelope = YES;

	for( __strong JVChatMessage *message in messages ) {
		if( ! [message isKindOfClass:[JVChatMessage class]] ) continue;
		@synchronized( ( [message transcript] ? (id) [message transcript] : (id) message ) ) {
			message = [self appendMessage:message];
			if( message ) [ret addObject:message];
		}
	}

	return ret;
}

#pragma mark -

- (NSArray *) sessions {
	return [self sessionsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of sessions.
}

- (NSArray *) sessionsInRange:(NSRange) range {
	if( ! range.length ) return @[];

	@synchronized( self ) {
		NSUInteger i = 0;
		NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:range.length];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatSession *session = [[JVChatSession alloc] _initWithNode:node andTranscript:self];
					if( session ) [ret addObject:session];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return ret;
	} return nil;
}

- (JVChatSession *) sessionAtIndex:(NSUInteger) index {
	return [[self sessionsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (nullable JVChatSession *) lastSession {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) )
				return [[JVChatSession alloc] _initWithNode:node andTranscript:self];
		} while( node && ( node = node -> prev ) );
	}

	return nil;
}

#pragma mark -

- (nullable JVChatSession *) startNewSession {
	return nil;
//	return [self appendSession:[NSDate date]];
}

- (JVChatSession *) appendSession:(JVChatSession *) session {
	xmlNodePtr sessionNode = xmlNewNode( NULL, (xmlChar *) "session" );
	xmlSetProp( sessionNode, (xmlChar *) "started", (xmlChar *) [[[session startDate] localizedDescription] UTF8String] );
	xmlAddChild( xmlDocGetRootElement( _xmlLog ), sessionNode );

	[self _enforceElementLimit];
	[self _incrementalWriteToLog:sessionNode continuation:NO];

	return [[JVChatSession alloc] _initWithNode:sessionNode andTranscript:self];
}

#pragma mark -

- (NSArray *) events {
	return [self eventsInRange:NSMakeRange( 0, -1 )]; // will stop at the total number of events.
}

- (NSArray *) eventsInRange:(NSRange) range {
	if( ! range.length ) return @[];

	@synchronized( self ) {
		NSUInteger i = 0;
		NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:range.length];

		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) ) {
				if( NSLocationInRange( i, range ) ) {
					JVChatEvent *event = [[JVChatEvent alloc] _initWithNode:node andTranscript:self];
					if( event ) [ret addObject:event];
				}

				if( ++i > ( range.location + range.length ) ) goto done;
			}
		} while( node && ( node = node -> next ) );

	done:
		return ret;
	} return nil;
}

- (JVChatEvent *) eventAtIndex:(NSUInteger) index {
	return [[self eventsInRange:NSMakeRange( index, 1 )] lastObject];
}

- (nullable JVChatEvent *) lastEvent {
	@synchronized( self ) {
		xmlNode *node = xmlGetLastChild( xmlDocGetRootElement( _xmlLog ) );
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) )
				return [[JVChatEvent alloc] _initWithNode:node andTranscript:self];
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
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) ) {
				xmlChar *prop = xmlGetProp( node, (xmlChar *) "id" );
				if( prop && ! strcmp( (char *) prop, ident ) ) found = YES;
				if( prop ) xmlFree( prop );
				if( found ) return YES;
			}
		} while( node && ( node = node -> next ) );
	}

	return NO;
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
		return [[JVChatEvent alloc] _initWithNode:root andTranscript:self];
	} return nil;
}

#pragma mark -

@synthesize filePath = _filePath;

- (void) setFilePath:(nullable NSString *) filePath {
	if( filePath && ! [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
		BOOL success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
		if( success ) [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil]; // remove the blank until we need to write the real file, since we now know it will likely work
		else filePath = nil; // since we can't write no use in keeping the path
	} else if( filePath && ! [[NSFileManager defaultManager] isWritableFileAtPath:filePath] ) {
		filePath = nil; // the file isn't writable, no use in keeping the path
	}

	filePath = [filePath stringByStandardizingPath];
	if( ! filePath ) return;
	if( [_filePath isEqualToString:filePath] ) return;

	_filePath = [filePath copy];

	if( _logFile ) {
		[_logFile synchronizeFile];
		[_logFile closeFile];
		_logFile = nil;
	}

	if( [_filePath length] && [self automaticallyWritesChangesToFile] ) {
		_logFile = [NSFileHandle fileHandleForUpdatingAtPath:_filePath];
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
	}
}

#pragma mark -

- (NSDateComponents *__nullable) dateBegan {
	if( ! _xmlLog ) return nil;

	xmlNode *node = xmlDocGetRootElement( _xmlLog );
	if( ! node ) return nil;

	xmlChar *prop = xmlGetProp( node, (xmlChar *) "began" );
	if( prop ) {
		NSString *dateString = [NSString stringWithUTF8String:(char *) prop];
		NSDate *date = [dateString dateFromFormat:@"yyyy-MM-DD HH:mm:ss ZZZZZ"];
		const NSCalendarUnit requestedComponents = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitTimeZone);
		NSDateComponents *ret = [[NSCalendar autoupdatingCurrentCalendar] components:requestedComponents fromDate:date];
		xmlFree( prop );
		return ret;
	}

	return nil;
}

#pragma mark -

- (null_unspecified NSURL *) source {
	if( ! _xmlLog ) return nil;

	xmlNode *node = xmlDocGetRootElement( _xmlLog );
	if( ! node ) return nil;

	xmlChar *prop = xmlGetProp( node, (xmlChar *) "source" );
	if( prop ) {
		NSString *urlString = @((char *) prop);
		NSURL *ret = [NSURL URLWithString:urlString];
		xmlFree( prop );
		return ret;
	}

	return nil;
}

- (void) setSource:(null_unspecified NSURL *) source {
	NSParameterAssert( source != nil );
	xmlSetProp( xmlDocGetRootElement( _xmlLog ), (xmlChar *) "source", (xmlChar *) [[source absoluteString] UTF8String] );
}

#pragma mark -

- (BOOL) automaticallyWritesChangesToFile {
	return _autoWriteChanges;
}

- (void) setAutomaticallyWritesChangesToFile:(BOOL) option {
	if( _autoWriteChanges == option ) return;

	_autoWriteChanges = option;

	if( _logFile ) {
		[_logFile synchronizeFile];
		[_logFile closeFile];
		_logFile = nil;
	}

	if( _autoWriteChanges && [[self filePath] length] ) {
		_logFile = [NSFileHandle fileHandleForUpdatingAtPath:[self filePath]];
		_requiresNewEnvelope = YES;
		_previousLogOffset = 0;
	}
}

#pragma mark -

- (BOOL) writeToFile:(NSString *) path atomically:(BOOL) atomically {
	BOOL ret = NO;

	@synchronized( self ) {
		int size = 0;
		xmlChar *buf = NULL;
		xmlDocDumpFormatMemory( _xmlLog, &buf, &size, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );

		if( ! buf ) return NO;

		NSData *xmlData = [[NSData alloc] initWithBytesNoCopy:buf length:size freeWhenDone:YES];
		ret = [xmlData writeToFile:path atomically:atomically];
	}

	[self _changeFileAttributesAtPath:path];

	[[NSNotificationCenter chatCenter] postNotificationName:JVChatTranscriptUpdatedNotification object:self];

	return ret;
}

- (BOOL) writeToURL:(NSURL *) url atomically:(BOOL) atomically {
	BOOL ret = NO;

	@synchronized( self ) {
		int size = 0;
		xmlChar *buf = NULL;
		xmlDocDumpFormatMemory( _xmlLog, &buf, &size, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );

		if( ! buf ) return NO;

		NSData *xmlData = [[NSData alloc] initWithBytesNoCopy:buf length:size freeWhenDone:YES];
		ret = [xmlData writeToURL:url atomically:atomically];

		if( [url isFileURL] ) {
			[self _changeFileAttributesAtPath:[url path]];
			[[NSNotificationCenter chatCenter] postNotificationName:JVChatTranscriptUpdatedNotification object:self];
		}
	}

	return ret;
}

#pragma mark -

- (nullable NSScriptObjectSpecifier *) objectSpecifier {
	return _objectSpecifier;
}

- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier {
	_objectSpecifier = objectSpecifier;
}
@end

#pragma mark -

@implementation JVChatTranscript (Private)
- (void) _enforceElementLimit {
	if( ! [self elementLimit] ) return;

	NSUInteger limit = [self elementLimit];
	NSUInteger count = [self elementCount];
	if( ! limit || count <= limit ) return;

	NSUInteger total = ( count - limit );
	xmlNode *tmp = NULL;

	@synchronized( self ) {
		xmlNode *node = xmlDocGetRootElement( _xmlLog ) -> children;
		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "envelope", (char *) node -> name ) ) {
				xmlNode *subNode = node -> children;
				BOOL removedAllMessages = YES;

				do {
					if( subNode && subNode -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) subNode -> name ) ) {
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
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "session", (char *) node -> name ) ) {
				tmp = node -> prev;
				xmlUnlinkNode( node );
				xmlFreeNode( node );
				node = ( tmp ? tmp : xmlDocGetRootElement( _xmlLog ) -> children );
				total--;
			} else if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "event", (char *) node -> name ) ) {
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

	unsigned long long fileSize = [[fm attributesOfItemAtPath:[self filePath] error:nil] fileSize];
	if( fileSize > 0 && fileSize < 6 ) { // the file is too small to be a viable log file, return now
		[self setAutomaticallyWritesChangesToFile:NO];
		return;
	}

	BOOL format = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"];

	if( ! fileSize || ! [fm fileExistsAtPath:[self filePath]] ) {
		xmlNode *root = xmlDocGetRootElement( _xmlLog );

		// Save out the <log> element since this is a new file. build it by hand
		NSMutableString *logElement = [NSMutableString string];
		[logElement appendFormat:@"<%s", root -> name];

		for( xmlAttrPtr prop = root -> properties; prop; prop = prop -> next ) {
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
		if( ! [xml writeToFile:[self filePath] atomically:YES] ) return;

		if( ! _logFile ) {
			_logFile = [NSFileHandle fileHandleForUpdatingAtPath:[self filePath]];
			_requiresNewEnvelope = YES;
			_previousLogOffset = 0;
		}

		[self _changeFileAttributesAtPath:[self filePath]];
	}

	if( ! node ) return;

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
		NSUInteger offset = 6;
		NSUInteger eof = [_logFile seekToEndOfFile];
		if( eof < 1 ) {
			[self setAutomaticallyWritesChangesToFile:NO];
			return;
		}

		[_logFile seekToFileOffset:( eof - 1 )];
		NSData *check = [_logFile readDataOfLength:1]; // check to see if there is an trailing newline and correct
		if( [check length] == 1 && ! strncmp( "\n", [check bytes], 1 ) ) offset++; // we need to eat the newline also

		if( [_logFile offsetInFile] <= offset ) {
			[self setAutomaticallyWritesChangesToFile:NO];
			return;
		}

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

	[[NSNotificationCenter chatCenter] postNotificationName:JVChatTranscriptUpdatedNotification object:self];

	xmlBufferFree( buf );
}

- (void) _changeFileAttributesAtPath:(NSString *) path {
	[[NSFileManager defaultManager] setAttributes:@{NSFileExtensionHidden: @YES, NSFileHFSTypeCode: @((OSType)'coTr'), NSFileHFSCreatorCode: @((OSType)'coRC')} ofItemAtPath:path error:nil];

	if( _logFile ) {
		NSDate *began = [[NSCalendar autoupdatingCurrentCalendar] dateFromComponents:[self dateBegan]];
		NSString *beganDateString = [began localizedDescription];
		NSString *lastDateString = [[[self lastMessage] date] localizedDescription];
		NSURL *source = [self source];
		NSString *target = [source path];
		if( [target length] > 1 ) target = [target substringFromIndex:1];
		int fd = [_logFile fileDescriptor];

		fsetxattr( fd, "sourceAddress", [[source absoluteString] UTF8String], [[source absoluteString] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, 0 );
		fsetxattr( fd, "server", [[source host] UTF8String], [[source host] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, 0 );
		fsetxattr( fd, "target", [target UTF8String], [target lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, 0 );
		fsetxattr( fd, "dateBegan", [beganDateString UTF8String], [beganDateString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, 0 );
		if( [lastDateString length] )
			fsetxattr( fd, "lastMessageDate", [lastDateString UTF8String], [lastDateString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0, 0 );
	}
}

- (void) _loadMessage:(JVChatMessage *) message {
	[message _loadFromXML];
}

- (void) _loadSenderForMessage:(JVChatMessage *) message {
	[message _loadSenderFromXML];
}

- (void) _loadBodyForMessage:(JVChatMessage *) message {
	[message _loadBodyFromXML];
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptScripting)
- (void) saveScriptCommand:(NSScriptCommand *) command {
	NSDictionary *args = [command evaluatedArguments];
	id path = args[@"File"];

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

- (nullable id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The transcript doesn't have the \"%@\" property.", key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(nullable id) value forUndefinedKey:(NSString *) key {
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
	return [NSNumber numberWithUnsignedLong:(intptr_t)self];
}

- (JVChatMessage *) valueInMessagesAtIndex:(long long) index {
	if( index == -1 ) return [self lastMessage];

	if( index < 0 ) {
		NSUInteger count = [self messageCount];
		if( (NSUInteger)ABS( index ) > count ) return nil;
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

- (void) insertInMessages:(JVChatMessage *) message atIndex:(NSUInteger) index {
	[self scriptErrorCantInsertMessageException];
}

- (void) removeFromMessagesAtIndex:(NSUInteger) index {
	[self scriptErrorCantRemoveMessageException];
}

- (void) replaceInMessages:(JVChatMessage *) message atIndex:(NSUInteger) index {
	[self scriptErrorCantRemoveMessageException];
}
@end

#pragma mark -

@implementation JVChatSession (JVChatSessionChatTranscriptPrivate)
- (nullable id) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference

		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			return nil;
		}

		@synchronized( _transcript ) {

			xmlChar *startedStr = xmlGetProp( (xmlNode *) _node, (xmlChar *) "started" );
			_startDate = ( startedStr ? [[NSString stringWithUTF8String:(char *) startedStr] dateFromFormat:@"yyyy-MM-DD HH:mm:ss ZZZZZ"] : nil );
			xmlFree( startedStr );
		}
	}

	return self;
}
@end

#pragma mark -

@implementation JVChatMessage (JVChatMessageChatTranscriptPrivate)
- (nullable id) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference

		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			return nil;
		}

		@synchronized( _transcript ) {
			xmlChar *idStr = xmlGetProp( (xmlNode *) _node, (xmlChar *) "id" );
			_messageIdentifier = ( idStr ? [[NSString alloc] initWithUTF8String:(char *) idStr] : nil );
			xmlFree( idStr );
		}
	}

	return self;
}

- (void) _loadFromXML {
	if( _loaded || ! _node ) return;

	@synchronized( _transcript ) {
		xmlChar *prop = xmlGetProp( _node, (xmlChar *) "received" );
		_date = ( prop ? [[NSString stringWithUTF8String:(char *) prop] dateFromFormat:@"yyyy-MM-DD HH:mm:ss ZZZZZ"] : nil );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "action" );
		_action = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? YES : NO );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "highlight" );
		_highlighted = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? YES : NO );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "ignored" );
		_ignoreStatus = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? JVMessageIgnored : _ignoreStatus );
		xmlFree( prop );

		prop = xmlGetProp( _node, (xmlChar *) "type" );
		_type = ( ( prop && ! strcmp( (char *) prop, "notice" ) ) ? JVChatMessageNoticeType : JVChatMessageNormalType );
		xmlFree( prop );

		xmlNode *envelope = (_node) -> parent;

		prop = xmlGetProp( envelope, (xmlChar *) "ignored" );
		_ignoreStatus = ( ( prop && ! strcmp( (char *) prop, "yes" ) ) ? JVUserIgnored : _ignoreStatus );
		xmlFree( prop );

		prop = xmlGetProp( envelope, (xmlChar *) "source" );
		_source = ( prop ? [[NSURL alloc] initWithString:[NSString stringWithUTF8String:(char *) prop]] : nil );
		xmlFree( prop );

		xmlNode *node = envelope -> children;

		do {
			if( node && node -> type == XML_ELEMENT_NODE && ! strcmp( "message", (char *) node -> name ) ) {
				if( node == _node ) break;
				_consecutiveOffset++;
			}
		} while( node && ( node = node -> next ) );
	}

	_loaded = YES;
}

- (void) _loadSenderFromXML {
	if( _senderLoaded || ! _node ) return;

	@synchronized( _transcript ) {
		xmlNode *subNode = ( _node) -> parent -> children;

		do {
			if( subNode -> type == XML_ELEMENT_NODE && ! strcmp( "sender", (char *) subNode -> name ) ) {
				xmlChar *prop = xmlNodeGetContent( subNode );
				if( prop ) _senderName = [[NSString alloc] initWithUTF8String:(char *) prop];
				else _senderName = nil;
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "nickname" );
				if( prop ) _senderNickname = [[NSString alloc] initWithUTF8String:(char *) prop];
				else _senderNickname = nil;
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "identifier" );
				if( prop ) _senderIdentifier = [[NSString alloc] initWithUTF8String:(char *) prop];
				else _senderIdentifier = nil;
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "hostmask" );
				if( prop ) _senderHostmask = [[NSString alloc] initWithUTF8String:(char *) prop];
				else _senderHostmask = nil;
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "class" );
				if( prop ) _senderClass = [[NSString alloc] initWithUTF8String:(char *) prop];
				else _senderClass = nil;
				xmlFree( prop );

				prop = xmlGetProp( subNode, (xmlChar *) "self" );
				if( prop && ! strcmp( (char *) prop, "yes" ) ) _senderIsLocalUser = YES;
				else _senderIsLocalUser = NO;
				xmlFree( prop );

				break;
			}
		} while( ( subNode = subNode -> next ) );
	}

	_senderLoaded = YES;
}

- (void) _loadBodyFromXML {
	if( _bodyLoaded || ! _node ) return;

	@synchronized( _transcript ) {
		_attributedMessage = [[NSTextStorage alloc] initWithXHTMLTree:_node baseURL:nil defaultAttributes:nil];
	}

	_bodyLoaded = YES;
}
@end

#pragma mark -

@implementation JVChatEvent (JVChatEventChatTranscriptPrivate)
- (nullable id) _initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_node = node;
		_transcript = transcript; // weak reference

		if( ! _node || node -> type != XML_ELEMENT_NODE ) {
			return nil;
		}

		@synchronized( _transcript ) {
			xmlChar *prop = xmlGetProp( _node, (xmlChar *) "id" );
			_eventIdentifier = ( prop ? [[NSString alloc] initWithUTF8String:(char *) prop] : nil );
			xmlFree( prop );
		}
	}

	return self;
}
@end

NS_ASSUME_NONNULL_END
