#import "JVSQLChatTranscript.h"
#import "JVChatMessage.h"
#import "JVChatEvent.h"
#import "JVChatRoomMember.h"
#import "JVBuddy.h"
#import "NSAttributedStringMoreAdditions.h"

#import <sys/stat.h>
#import <unistd.h>

#define DEBUG_SQL 0

@interface JVSQLChatTranscript (JVSQLChatTranscriptPrivate)
- (BOOL) _initializeDatabase;
- (sqlite3 *) _database;
- (unsigned long long) _findOrInsertUserRowForObject:(id) user;
@end

#pragma mark -

@interface JVChatMessage (JVChatMessageSQLChatTranscriptPrivate)
- (id) _initWithSQLIdentifier:(NSString *) identifier andTranscript:(JVSQLChatTranscript *) transcript;
- (void) _loadFromSQL;
- (void) _loadSenderFromSQL;
- (void) _loadBodyFromSQL;
@end

#pragma mark -

@interface JVChatEvent (JVChatEventSQLChatTranscriptPrivate)
- (id) _initWithSQLIdentifier:(NSString *) identifier andTranscript:(JVSQLChatTranscript *) transcript;
@end

#pragma mark -

@implementation JVSQLChatTranscript
- (id) init {
	if( ( self = [super init] ) ) {
		char *tmpName = strdup( "/tmp/ColloquyTranscriptXXXXXX" );
		tmpName = mktemp( tmpName );
		if( sqlite3_open( tmpName, &_database ) != SQLITE_OK ) {
			free( tmpName );
			[self release];
			return nil;
		}

		// Set permissions so only this user can read and write this file
		chmod( tmpName, S_IRUSR | S_IWUSR );

		[self setFilePath:[NSString stringWithUTF8String:tmpName]];
		free( tmpName );

		if( ! [self _initializeDatabase] ) {
			[self release];
			return nil;
		}
	}

	return self;
}

- (id) initWithContentsOfFile:(NSString *) path {
	if( ( self = [super init] ) ) {
		path = [path stringByStandardizingPath];

		if( sqlite3_open( [path UTF8String], &_database ) != SQLITE_OK ) {
			[self release];
			return nil;
		}

		[self _initializeDatabase];

		[self setFilePath:path];
	}

	return self;
}

- (id) initWithContentsOfURL:(NSURL *) url {
	return [self initWithContentsOfFile:[url path]];
}

- (void) dealloc {
	sqlite3_close( _database );
	_database = NULL;

	[super dealloc];
}

#pragma mark -

- (BOOL) isEmpty {
	BOOL empty = YES;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, "SELECT COUNT(*) FROM digest", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			empty = ( tables[1][0] == '0' && tables[1][1] == '\0' );
		sqlite3_free_table( tables );
	}

	return empty;
}

- (NSUInteger) elementCount {
	NSUInteger count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, "SELECT COUNT(*) FROM session", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count += strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );

		sqlite3_get_table( _database, "SELECT COUNT(*) FROM message", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count += strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );

		sqlite3_get_table( _database, "SELECT COUNT(*) FROM event", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count += strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );
	}

	return count;
}

- (NSUInteger) sessionCount {
	NSUInteger count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, "SELECT COUNT(*) FROM session", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count = strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );
	}

	return count;
}

- (NSUInteger) messageCount {
	NSUInteger count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, "SELECT COUNT(*) FROM message", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count = strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );
	}

	return count;
}

- (NSUInteger) eventCount {
	NSUInteger count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, "SELECT COUNT(*) FROM message", &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			count = strtol( tables[1], NULL, 10 );
		sqlite3_free_table( tables );
	}

	return count;
}

#pragma mark -

struct _elementsInRangeCallbackData {
	JVSQLChatTranscript *transcript;
	NSMutableArray *results;
};

static int _elementsInRangeCallback( void *context, int fieldCount, char **fields, char **columns ) {
	if( fieldCount != 2 ) return -1;

	struct _elementsInRangeCallbackData *data = (struct _elementsInRangeCallbackData *) context;
	NSString *identifier = [[NSString allocWithZone:nil] initWithUTF8String:fields[1]];

	if( ! strcmp( "message", fields[0] ) ) {
		JVChatMessage *message = [[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:data -> transcript];
		if( message ) [data -> results addObject:message];
		[message release];
	} else if( ! strcmp( "event", fields[0] ) ) {
		JVChatEvent *event = [[JVChatEvent allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:data -> transcript];
		if( event ) [data -> results addObject:event];
		[event release];
	}

	[identifier release];

	return 0;
}

- (NSArray *) elementsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
	struct _elementsInRangeCallbackData data = { self, results };

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT entity,link FROM digest ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );

	@synchronized( self ) {
		sqlite3_exec( _database, query, _elementsInRangeCallback, &data, NULL );
	}

	return [results autorelease];
}

- (id) lastElement {
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
	struct _elementsInRangeCallbackData data = { self, results };

	@synchronized( self ) {
		sqlite3_exec( _database, "SELECT entity,link FROM digest ORDER BY position DESC LIMIT 1", _elementsInRangeCallback, &data, NULL );
	}

	id last = [[results lastObject] retain];
	[results release];

	return [last autorelease];
}

#pragma mark -

struct _specificElementsInRangeCallbackData {
	JVSQLChatTranscript *transcript;
	NSMutableArray *results;
	Class class;
};

static int _specificElementsInRangeCallback( void *context, int fieldCount, char **fields, char **columns ) {
	if( fieldCount != 1 ) return -1;

	struct _specificElementsInRangeCallbackData *data = (struct _specificElementsInRangeCallbackData *) context;
	NSString *identifier = [[NSString allocWithZone:nil] initWithUTF8String:fields[0]];

	id element = [[data -> class allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:data -> transcript];
	if( element ) [data -> results addObject:element];
	[element release];

	[identifier release];

	return 0;
}

- (NSArray *) messagesInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
	Class class = [JVChatMessage class];
	struct _specificElementsInRangeCallbackData data = { self, results, class };

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );

	@synchronized( self ) {
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );
	}

	return [results autorelease];
}

- (JVChatMessage *) messageAtIndex:(NSUInteger) index {
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
	Class class = [JVChatMessage class];
	struct _specificElementsInRangeCallbackData data = { self, results, class };

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position ASC LIMIT 1 OFFSET %u", index );

	@synchronized( self ) {
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );
	}

	id message = [[results lastObject] retain];
	[results release];

	return [message autorelease];
}

- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier {
	if( [self containsEventWithIdentifier:identifier] )
		return [[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:self];
	return nil;
}

- (id) lastMessage {
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
	Class class = [JVChatMessage class];
	struct _specificElementsInRangeCallbackData data = { self, results, class };

	@synchronized( self ) {
		sqlite3_exec( _database, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position DESC LIMIT 1", _specificElementsInRangeCallback, &data, NULL );
	}

	id last = [[results lastObject] retain];
	[results release];

	return [last autorelease];
}

#pragma mark -

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT COUNT(*) FROM message WHERE id = '%q'", identifier );

	BOOL contains = NO;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			contains = ! ( tables[1][0] == '0' && tables[1][1] == '\0' );
		sqlite3_free_table( tables );
	}

	return contains;
}

#pragma mark -

- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope {
	NSParameterAssert( message != nil );
	NSParameterAssert( [message transcript] != self );

	unsigned long long userIdentifier = 0;
	unsigned long long messageIdentifier = 0;

	@synchronized( self ) {
		if( sqlite3_exec( _database, "BEGIN TRANSACTION", NULL, NULL, NULL ) != SQLITE_OK )
			return nil;

		userIdentifier = [self _findOrInsertUserRowForObject:message];

		const char *msgQuery = "INSERT INTO message (context, session, user, received, action, highlighted, ignored, type, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
		sqlite3_stmt *compiledMsgQuery = NULL;
		if( sqlite3_prepare( _database, msgQuery, -1, &compiledMsgQuery, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		sqlite3_bind_int64( compiledMsgQuery, 1, _currentContext ); // context
		sqlite3_bind_int64( compiledMsgQuery, 2, _currentSession ); // session
		sqlite3_bind_int64( compiledMsgQuery, 3, userIdentifier ); // user
		if( [message date] ) sqlite3_bind_text( compiledMsgQuery, 4, [[[message date] description] UTF8String], -1, SQLITE_STATIC ); // received
		else sqlite3_bind_text( compiledMsgQuery, 4, [[[NSDate date] description] UTF8String], -1, SQLITE_STATIC ); // received
		sqlite3_bind_int( compiledMsgQuery, 5, [message isAction] ); // action
		sqlite3_bind_int( compiledMsgQuery, 6, [message isHighlighted] ); // highlighted
		if( [message ignoreStatus] == JVUserIgnored ) sqlite3_bind_text( compiledMsgQuery, 7, "user", 4, SQLITE_STATIC ); // ignored
		else if( [message ignoreStatus] == JVUserIgnored ) sqlite3_bind_text( compiledMsgQuery, 7, "message", 7, SQLITE_STATIC ); // ignored
		if( [message type] == JVChatMessageNoticeType ) sqlite3_bind_text( compiledMsgQuery, 8, "notice", 6, SQLITE_STATIC ); // type
		if( [message bodyAsHTML] ) sqlite3_bind_text( compiledMsgQuery, 9, [[message bodyAsHTML] UTF8String], -1, SQLITE_STATIC ); // content

		sqlite3_step( compiledMsgQuery );
		if( sqlite3_finalize( compiledMsgQuery ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		messageIdentifier = sqlite3_last_insert_rowid( _database );
		if( ! messageIdentifier ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		if( sqlite3_exec( _database, "COMMIT TRANSACTION", NULL, NULL, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}
	}

	return [[[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:[NSString stringWithFormat:@"%qu", messageIdentifier] andTranscript:self] autorelease];
}

#pragma mark -

- (NSArray *) eventsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
	Class class = [JVChatEvent class];
	struct _specificElementsInRangeCallbackData data = { self, results, class };
	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'event' ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );

	@synchronized( self ) {
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );
	}

	return [results autorelease];
}

- (id) lastEvent {
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
	Class class = [JVChatEvent class];
	struct _specificElementsInRangeCallbackData data = { self, results, class };

	@synchronized( self ) {
		sqlite3_exec( _database, "SELECT link FROM digest WHERE entity = 'event' ORDER BY position DESC LIMIT 1", _specificElementsInRangeCallback, &data, NULL );
	}

	id last = [[results lastObject] retain];
	[results release];

	return [last autorelease];
}
#pragma mark -

- (JVChatEvent *) appendEvent:(JVChatEvent *) event {
	NSParameterAssert( event != nil );
	NSParameterAssert( [event transcript] != self );

	unsigned long long eventIdentifier = 0;

	@synchronized( self ) {
		if( sqlite3_exec( _database, "BEGIN TRANSACTION", NULL, NULL, NULL ) != SQLITE_OK )
			return nil;

		const char *query = "INSERT INTO event (context, session, name, occurred, content) VALUES (?, ?, ?, ?, ?)";
		sqlite3_stmt *compiledQuery = NULL;
		if( sqlite3_prepare( _database, query, -1, &compiledQuery, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		sqlite3_bind_int64( compiledQuery, 1, _currentContext ); // context
		sqlite3_bind_int64( compiledQuery, 2, _currentSession ); // session
		if( [event name] ) sqlite3_bind_text( compiledQuery, 3, [[event name] UTF8String], -1, SQLITE_STATIC ); // name
		if( [event date] ) sqlite3_bind_text( compiledQuery, 4, [[[event date] description] UTF8String], -1, SQLITE_STATIC ); // occurred
		else sqlite3_bind_text( compiledQuery, 4, [[[NSDate date] description] UTF8String], -1, SQLITE_STATIC ); // occurred
		if( [event messageAsHTML] ) sqlite3_bind_text( compiledQuery, 5, [[event messageAsHTML] UTF8String], -1, SQLITE_STATIC ); // content

		sqlite3_step( compiledQuery );
		if( sqlite3_finalize( compiledQuery ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		eventIdentifier = sqlite3_last_insert_rowid( _database );
		if( ! eventIdentifier ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		query = "INSERT INTO attribute (entity, link, identifier, value, type) VALUES (?, ?, ?, ?, ?)";
		if( sqlite3_prepare( _database, query, -1, &compiledQuery, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		for( NSString *key in [self attributes] ) {
			id value = [[self attributes] objectForKey:key];

			sqlite3_reset( compiledQuery );
			sqlite3_bind_text( compiledQuery, 1, "event", 5, SQLITE_STATIC ); // entity
			sqlite3_bind_int64( compiledQuery, 2, eventIdentifier ); // link
			sqlite3_bind_text( compiledQuery, 3, [key UTF8String], -1, SQLITE_STATIC ); // identifier

			if( [value isKindOfClass:[MVChatUser class]] ) {
				unsigned long long userIdentifier = [self _findOrInsertUserRowForObject:value];
				sqlite3_bind_int64( compiledQuery, 4, userIdentifier ); // value
				sqlite3_bind_text( compiledQuery, 5, "table/user", 10, SQLITE_STATIC ); // type
			} else if( [value isKindOfClass:[JVChatRoomMember class]] ) {
				unsigned long long userIdentifier = [self _findOrInsertUserRowForObject:value];
				sqlite3_bind_int64( compiledQuery, 4, userIdentifier ); // value
				sqlite3_bind_text( compiledQuery, 5, "table/user", 10, SQLITE_STATIC ); // type
			} else if( [value isKindOfClass:[NSAttributedString class]] ) {
				NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
				value = [value HTMLFormatWithOptions:options];
				sqlite3_bind_text( compiledQuery, 4, [value UTF8String], -1, SQLITE_STATIC ); // value
				sqlite3_bind_text( compiledQuery, 5, "text/html", 9, SQLITE_STATIC ); // type
			} else if( [value isKindOfClass:[NSString class]] ) {
				sqlite3_bind_text( compiledQuery, 4, [value UTF8String], -1, SQLITE_STATIC ); // value
				sqlite3_bind_text( compiledQuery, 5, "text/plain", 10, SQLITE_STATIC ); // type
			} else if( [value isKindOfClass:[NSData class]] ) {
				sqlite3_bind_blob( compiledQuery, 4, [value bytes], [value length], SQLITE_STATIC ); // value
				sqlite3_bind_text( compiledQuery, 5, "application/octet-stream", 24, SQLITE_STATIC ); // type
			} else {
				sqlite3_bind_null( compiledQuery, 4 ); // value
				sqlite3_bind_text( compiledQuery, 5, "", 0, SQLITE_STATIC ); // type
			}

			sqlite3_step( compiledQuery );
		}

		if( sqlite3_finalize( compiledQuery ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}

		if( sqlite3_exec( _database, "COMMIT TRANSACTION", NULL, NULL, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return nil;
		}
	}

	return [[[JVChatEvent allocWithZone:nil] _initWithSQLIdentifier:[NSString stringWithFormat:@"%qu", eventIdentifier] andTranscript:self] autorelease];
}

#pragma mark -

- (BOOL) containsEventWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT COUNT(*) FROM event WHERE id = '%q'", identifier );

	BOOL contains = NO;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		sqlite3_get_table( _database, query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			contains = ! ( tables[1][0] == '0' && tables[1][1] == '\0' );
		sqlite3_free_table( tables );
	}

	return contains;
}

#pragma mark -

- (NSCalendarDate *) dateBegan {
	return nil;
}

#pragma mark -

- (NSURL *) source {
	return nil;
}

- (void) setSource:(NSURL *) source {
	NSParameterAssert( source != nil );
}

#pragma mark -

- (BOOL) automaticallyWritesChangesToFile {
	return YES;
}

- (void) setAutomaticallyWritesChangesToFile:(BOOL) option {
	// this is not an option, SQL is always written to disk
}

#pragma mark -

- (void) setFilePath:(NSString *) filePath {
	id old = _filePath;
	_filePath = [filePath copyWithZone:nil];
	[old release];
}

#pragma mark -

- (BOOL) writeToFile:(NSString *) path atomically:(BOOL) atomically {
	return NO;
}

- (BOOL) writeToURL:(NSURL *) url atomically:(BOOL) atomically {
	if( [url isFileURL] ) return [self writeToFile:[url path] atomically:atomically];
	return NO;
}
@end

#pragma mark -

@implementation JVSQLChatTranscript (JVSQLChatTranscriptPrivate)
- (sqlite3 *) _database {
	return _database;
}

static void _printSQL( void *context, const char *sql ) {
	NSLog( @"SQL: %s", sql );
}

- (BOOL) _initializeDatabase {
	NSString *setup = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"transcriptSchema" ofType:@"sql"] encoding:NSUTF8StringEncoding error:NULL];

	@synchronized( self ) {
		if( DEBUG_SQL ) sqlite3_trace( _database, _printSQL, NULL );
		sqlite3_busy_timeout( _database, 2500 ); // 2.5 seconds
		if( sqlite3_exec( _database, [setup UTF8String], NULL, NULL, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return NO;
		}
	}

	return YES;
}

#pragma mark -

- (unsigned long long) _findOrInsertUserRowForObject:(id) object {
	unsigned long long userIdentifier = 0;

	NSString *senderName = nil;
	NSString *senderNickname = nil;
	NSString *senderHostmask = nil;
	NSString *senderClass = nil;
	NSString *senderBuddyIdentifier = nil;
	id senderIdentifier = nil;
	BOOL senderLocalUser = NO;

	if( [object isKindOfClass:[JVChatMessage class]] ) {
		JVChatMessage *message = object;
		senderName = [message senderName];
		senderNickname = [message senderNickname];
		senderIdentifier = [message senderIdentifier];
		senderHostmask = [message senderHostmask];
		senderClass = [message senderClass];
		senderBuddyIdentifier = [message senderBuddyIdentifier];
		senderLocalUser = [message senderIsLocalUser];
	} else if( [object isKindOfClass:[JVChatRoomMember class]] ) {
		JVChatRoomMember *member = object;
		senderName = [member displayName];
		senderNickname = [member nickname];
		senderIdentifier = [[member user] uniqueIdentifier];
		senderHostmask = [member hostmask];
		if( [member serverOperator] ) senderClass = @"server operator";
		else if( [member roomFounder] ) senderClass = @"room founder";
		else if( [member roomAdministrator] ) senderClass = @"room administrator";
		else if( [member operator] ) senderClass = @"operator";
		else if( [member halfOperator] ) senderClass = @"half operator";
		else if( [member voice] ) senderClass = @"voice";
		if( ! [member isLocalUser] )
			senderBuddyIdentifier = [[member buddy] uniqueIdentifier];
		senderLocalUser = [member isLocalUser];
	} else if( [object isKindOfClass:[MVChatUser class]] ) {
		MVChatUser *chatUser = object;
		senderName = [chatUser displayName];
		senderNickname = [chatUser nickname];
		senderIdentifier = [chatUser uniqueIdentifier];
		if( [[chatUser username] length] && [[chatUser address] length] )
			senderHostmask = [NSString stringWithFormat:@"%@@%@", [chatUser username], [chatUser address]];
		senderLocalUser = [chatUser isLocalUser];
	}

	if( [senderIdentifier isKindOfClass:[NSData class]] )
		senderIdentifier = [senderIdentifier base64Encoding];
	else if( ! [senderIdentifier isKindOfClass:[NSString class]] )
		senderIdentifier = [senderIdentifier description];

	char userQuery[512] = "";
	sqlite3_snprintf( sizeof( userQuery ), userQuery, "SELECT id FROM user WHERE self = %d AND name = '%q' AND (identifier IS NULL OR identifier = '%q') AND (nickname IS NULL OR nickname = '%q') AND (hostmask IS NULL OR hostmask = '%q') AND (class IS NULL OR class = '%q') AND (buddy IS NULL OR buddy = '%q') ORDER BY identifier, nickname, hostmask, class, buddy DESC LIMIT 1", senderLocalUser, ( senderName ? [senderName UTF8String] : "" ), ( senderIdentifier ? [senderIdentifier UTF8String] : "" ), ( senderNickname ? [senderNickname UTF8String] : "" ), ( senderHostmask ? [senderHostmask UTF8String] : "" ), ( senderClass ? [senderClass UTF8String] : "" ), ( senderBuddyIdentifier ? [senderBuddyIdentifier UTF8String] : "" ) );

	char **tables = NULL;
	int rows = 0, cols = 0;
	sqlite3_get_table( _database, userQuery, &tables, &rows, &cols, NULL );
	if( rows == 1 && cols == 1 && tables[1] )
		userIdentifier = strtoull( tables[1], NULL, 10 );
	sqlite3_free_table( tables );

	if( ! userIdentifier ) {
		const char *query = "INSERT INTO user (self, name, nickname, identifier, hostmask, class, buddy) VALUES (?, ?, ?, ?, ?, ?, ?)";
		sqlite3_stmt *compiledQuery = NULL;
		if( sqlite3_prepare( _database, query, -1, &compiledQuery, NULL ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return 0;
		}

		sqlite3_bind_int( compiledQuery, 1, senderLocalUser );
		if( senderName ) sqlite3_bind_text( compiledQuery, 2, [senderName UTF8String], -1, SQLITE_STATIC );
		if( senderNickname ) sqlite3_bind_text( compiledQuery, 3, [senderNickname UTF8String], -1, SQLITE_STATIC );
		if( senderIdentifier ) sqlite3_bind_text( compiledQuery, 4, [senderIdentifier UTF8String], -1, SQLITE_STATIC );
		if( senderHostmask ) sqlite3_bind_text( compiledQuery, 5, [senderHostmask UTF8String], -1, SQLITE_STATIC );
		if( senderClass ) sqlite3_bind_text( compiledQuery, 6, [senderClass UTF8String], -1, SQLITE_STATIC );
		if( senderBuddyIdentifier ) sqlite3_bind_text( compiledQuery, 7, [senderBuddyIdentifier UTF8String], -1, SQLITE_STATIC );

		sqlite3_step( compiledQuery );
		if( sqlite3_finalize( compiledQuery ) != SQLITE_OK ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return 0;
		}

		userIdentifier = sqlite3_last_insert_rowid( _database );
		if( ! userIdentifier ) {
			if( DEBUG_SQL ) NSLog( @"SQL ERROR: %s", sqlite3_errmsg( _database ) );
			sqlite3_exec( _database, "ROLLBACK TRANSACTION", NULL, NULL, NULL );
			return 0;
		}
	}

	return userIdentifier;
}

#pragma mark -

- (void) _loadMessage:(JVChatMessage *) message {
	[message _loadFromSQL];
}

- (void) _loadSenderForMessage:(JVChatMessage *) message {
	[message _loadSenderFromSQL];
}

- (void) _loadBodyForMessage:(JVChatMessage *) message {
	[message _loadBodyFromSQL];
}

#pragma mark -

- (void) _enforceElementLimit {
	// not used for SQL
}

- (void) _incrementalWriteToLog:(void *) node continuation:(BOOL) cont {
	// not used for SQL
}
@end

#pragma mark -

@implementation JVChatMessage (JVChatMessageSQLChatTranscriptPrivate)
- (id) _initWithSQLIdentifier:(NSString *) identifier andTranscript:(JVSQLChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_transcript = transcript; // weak reference
		_messageIdentifier = [identifier copyWithZone:nil];
	}

	return self;
}

- (void) _loadFromSQL {
	if( _loaded ) return;

	char query[512] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT received, action, highlighted, ignored, type, user FROM message WHERE id = '%q' LIMIT 1", [_messageIdentifier UTF8String] );

	char **tables = NULL;
	int rows = 0, cols = 0;
	char *userIdentifier = NULL;

	@synchronized( _transcript ) {
		sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 6 ) {
			char **results = tables + cols;

			id old = _date;
			_date = ( *results ? [[NSDate allocWithZone:nil] initWithString:[NSString stringWithUTF8String:*results]] : nil );
			[old release];

			results++;
			_action = ( *results && ! ( **results == '0' && *(*results + 1) == '\0' ) );

			results++;
			_highlighted = ( *results && ! ( **results == '0' && *(*results + 1) == '\0' ) );

			results++;
			if( *results ) {
				if( ! strncasecmp( *results, "user", 4 ) ) _ignoreStatus = JVUserIgnored;
				else if( ! strncasecmp( *results, "message", 7 ) ) _ignoreStatus = JVMessageIgnored;
				else _ignoreStatus = JVNotIgnored;
			} else _ignoreStatus = JVNotIgnored;

			results++;
			if( *results ) {
				if( ! strncasecmp( *results, "notice", 6 ) ) _type = JVChatMessageNoticeType;
				else if( ! strncasecmp( *results, "normal", 6 ) ) _type = JVChatMessageNormalType;
				else _type = JVChatMessageNormalType;
			} else _type = JVChatMessageNormalType;

			results++;
			if( *results ) userIdentifier = strdup( *results );
		}

		sqlite3_free_table( tables );

		if( userIdentifier ) {
			char *digestPosition = NULL;

			sqlite3_snprintf( sizeof( query ), query, "SELECT position FROM digest WHERE entity = 'message' AND link = '%q' LIMIT 1", [_messageIdentifier UTF8String] );
			sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
			if( rows == 1 && cols == 1 && tables[1] )
				digestPosition = strdup( tables[1] );

			sqlite3_free_table( tables );

			if( digestPosition ) {
				sqlite3_snprintf( sizeof( query ), query, "SELECT '%q' - ( position + 1 ) FROM (SELECT position, entity, user FROM digest LEFT OUTER JOIN message ON message.id = link WHERE position <= '%q' ORDER BY position DESC) WHERE user != '%q' OR entity != 'message' LIMIT 1", digestPosition, digestPosition, userIdentifier );

				sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
				if( rows == 1 && cols == 1 ) {
					if( tables[1] && tables[1][0] != '-' ) _consecutiveOffset = strtoull( tables[1], NULL, 10 );
				} else _consecutiveOffset = strtoull( digestPosition, NULL, 10 ) - 1;
				sqlite3_free_table( tables );

				free( digestPosition );
			}

			free( userIdentifier );
		}
	}

	_loaded = YES;
}

- (void) _loadSenderFromSQL {
	if( _senderLoaded ) return;

	char **tables = NULL;
	int rows = 0, cols = 0;

	char query[200] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT self, name, nickname, identifier, hostmask, class, buddy FROM user, message WHERE message.user = user.id AND message.id = '%q' LIMIT 1", [_messageIdentifier UTF8String] );

	@synchronized( _transcript ) {
		sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 7 ) {
			char **results = tables + cols;

			_senderIsLocalUser = ( *results && ! ( **results == '0' && *(*results + 1) == '\0' ) );

			results++;
			id old = _senderName;
			_senderName = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];

			results++;
			old = _senderNickname;
			_senderNickname = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];

			results++;
			old = _senderIdentifier;
			_senderIdentifier = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];

			results++;
			old = _senderHostmask;
			_senderHostmask = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];

			results++;
			old = _senderClass;
			_senderClass = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];

			results++;
			old = _senderBuddyIdentifier;
			_senderBuddyIdentifier = ( *results ? [[NSString allocWithZone:nil] initWithUTF8String:*results] : nil );
			[old release];
		}

		sqlite3_free_table( tables );
	}

	_senderLoaded = YES;
}

- (void) _loadBodyFromSQL {
	if( _bodyLoaded ) return;

	char **tables = NULL;
	int rows = 0, cols = 0;

	char query[128] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT content FROM message WHERE id = '%q' LIMIT 1", [_messageIdentifier UTF8String] );

	NSString *body = nil;

	@synchronized( _transcript ) {
		sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			body = [[NSString allocWithZone:nil] initWithUTF8String:tables[1]];
		sqlite3_free_table( tables );
	}

	id old = _attributedMessage;
	_attributedMessage = ( body ? [[NSTextStorage allocWithZone:nil] initWithXHTMLFragment:body baseURL:nil defaultAttributes:nil] : nil );
	[old release];

	[body release];

	_bodyLoaded = YES;
}
@end

#pragma mark -

@implementation JVChatEvent (JVChatEventSQLChatTranscriptPrivate)
- (id) _initWithSQLIdentifier:(NSString *) identifier andTranscript:(JVSQLChatTranscript *) transcript {
	if( ( self = [self init] ) ) {
		_transcript = transcript; // weak reference
		_eventIdentifier = [identifier copyWithZone:nil];
	}

	return self;
}
@end
