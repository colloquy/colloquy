#import "JVSQLChatTranscript.h"
#import "JVChatMessage.h"
#import "JVChatEvent.h"
#import "NSAttributedStringMoreAdditions.h"

#import <Foundation/NSDebug.h>
#import <sys/stat.h>

@interface JVSQLChatTranscript (JVSQLChatTranscriptPrivate)
- (BOOL) _initializeDatabase;
- (sqlite3 *) _database;
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

- (BOOL) automaticallyWritesChangesToFile {
	return YES;
}

- (void) setAutomaticallyWritesChangesToFile:(BOOL) option {
	// this is not an option, SQL is always written to disk
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

- (unsigned long) elementCount {
	unsigned long count = 0;
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

- (unsigned long) sessionCount {
	unsigned long count = 0;
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

- (unsigned long) messageCount {
	unsigned long count = 0;
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

- (unsigned long) eventCount {
	unsigned long count = 0;
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

	if( ! strncmp( "message", fields[0], 7 ) ) {
		JVChatMessage *message = [[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:data -> transcript];
		if( message ) [data -> results addObject:message];
		[message release];
	} else if( ! strncmp( "event", fields[0], 5 ) ) {
		JVChatEvent *event = [[JVChatEvent allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:data -> transcript];
		if( event ) [data -> results addObject:event];
		[event release];
	}

	[identifier release];

	return 0;
}

- (NSArray *) elementsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
		struct _elementsInRangeCallbackData data = { self, results };
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT entity,link FROM digest ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );
		sqlite3_exec( _database, query, _elementsInRangeCallback, &data, NULL );
		return [results autorelease];
	}

	return nil;
}

- (id) lastElement {
	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
		struct _elementsInRangeCallbackData data = { self, results };
		sqlite3_exec( _database, "SELECT entity,link FROM digest ORDER BY position DESC LIMIT 1", _elementsInRangeCallback, &data, NULL );

		id last = [[results lastObject] retain];
		[results release];

		return [last autorelease];
	}

	return nil;
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

	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
		Class class = [JVChatMessage class];
		struct _specificElementsInRangeCallbackData data = { self, results, class };
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );
		return [results autorelease];
	}

	return nil;
}

- (JVChatMessage *) messageAtIndex:(unsigned long) index {
	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
		Class class = [JVChatMessage class];
		struct _specificElementsInRangeCallbackData data = { self, results, class };
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position ASC LIMIT 1 OFFSET %u", index );
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );

		id message = [[results lastObject] retain];
		[results release];

		return [message autorelease];
	}

	return nil;
}

- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier {
	if( [self containsEventWithIdentifier:identifier] )
		return [[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:identifier andTranscript:self];
	return nil;
}

- (NSArray *) messagesInEnvelopeWithMessage:(JVChatMessage *) message {
	// this might be hard to do. need to select all adjacent messages from the same user
	return nil;
}

- (id) lastMessage {
	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
		Class class = [JVChatMessage class];
		struct _specificElementsInRangeCallbackData data = { self, results, class };
		sqlite3_exec( _database, "SELECT link FROM digest WHERE entity = 'message' ORDER BY position DESC LIMIT 1", _specificElementsInRangeCallback, &data, NULL );

		id last = [[results lastObject] retain];
		[results release];

		return [last autorelease];
	}

	return nil;
}

#pragma mark -

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	BOOL contains = NO;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT COUNT(*) FROM message WHERE id = '%q'", identifier );
		sqlite3_get_table( _database, query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			contains = ! ( tables[1][0] == '0' && tables[1][1] == '\0' );
		sqlite3_free_table( tables );
	}

	return contains;
}

#pragma mark -

- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope {
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		unsigned long long userIdentifier = 0;
		NSString *senderName = [message senderName];
		NSString *senderNickname = [message senderNickname];
		NSString *senderIdentifier = [message senderIdentifier];
		NSString *senderHostmask = [message senderHostmask];
		NSString *senderClass = [message senderClass];
		NSString *senderBuddyIdentifier = [message senderBuddyIdentifier];

		char query[512] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT id FROM user WHERE self = %d AND name = '%q' AND (nickname IS NULL OR nickname = '%q') AND (identifier IS NULL OR identifier = '%q') AND (hostmask IS NULL OR hostmask = '%q') AND (class IS NULL OR class = '%q') AND (buddy IS NULL OR buddy = '%q')", [message senderIsLocalUser], ( senderName ? [senderName UTF8String] : "" ), ( senderNickname ? [senderNickname UTF8String] : "" ), ( senderIdentifier ? [senderIdentifier UTF8String] : "" ), ( senderHostmask ? [senderHostmask UTF8String] : "" ), ( senderClass ? [senderClass UTF8String] : "" ), ( senderBuddyIdentifier ? [senderBuddyIdentifier UTF8String] : "" ) );
		sqlite3_get_table( _database, query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			userIdentifier = strtoull( tables[1], NULL, 10 );
		sqlite3_free_table( tables );

		if( ! userIdentifier ) {
			char *query = "INSERT INTO user (self, name, nickname, identifier, hostmask, class, buddy) VALUES (?, ?, ?, ?, ?, ?, ?)";
			sqlite3_stmt *compiledQuery = NULL;
			sqlite3_prepare( _database, query, -1, &compiledQuery, NULL );

			sqlite3_bind_int( compiledQuery, 1, [message senderIsLocalUser] );
			if( senderName ) sqlite3_bind_text( compiledQuery, 2, [senderName UTF8String], -1, SQLITE_STATIC );
			if( senderNickname ) sqlite3_bind_text( compiledQuery, 3, [senderNickname UTF8String], -1, SQLITE_STATIC );
			if( senderIdentifier ) sqlite3_bind_text( compiledQuery, 4, [senderIdentifier UTF8String], -1, SQLITE_STATIC );
			if( senderHostmask ) sqlite3_bind_text( compiledQuery, 5, [senderHostmask UTF8String], -1, SQLITE_STATIC );
			if( senderClass ) sqlite3_bind_text( compiledQuery, 6, [senderClass UTF8String], -1, SQLITE_STATIC );
			if( senderBuddyIdentifier ) sqlite3_bind_text( compiledQuery, 7, [senderBuddyIdentifier UTF8String], -1, SQLITE_STATIC );

			sqlite3_step( compiledQuery );
			sqlite3_finalize( compiledQuery );

			userIdentifier = sqlite3_last_insert_rowid( _database );
			if( ! userIdentifier ) return nil;
		}

		char *msgQuery = "INSERT INTO message (context, session, user, received, action, highlighted, ignored, type, content) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
		sqlite3_stmt *compiledMsgQuery = NULL;
		sqlite3_prepare( _database, msgQuery, -1, &compiledMsgQuery, NULL );

		sqlite3_bind_int64( compiledMsgQuery, 1, 0 ); // context
		sqlite3_bind_int64( compiledMsgQuery, 2, 0 ); // session
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
		sqlite3_finalize( compiledMsgQuery );

		unsigned long long messageIdentifier = sqlite3_last_insert_rowid( _database );
		if( ! messageIdentifier ) return nil;

		JVChatMessage *ret = [[JVChatMessage allocWithZone:nil] _initWithSQLIdentifier:[NSString stringWithFormat:@"%qu", messageIdentifier] andTranscript:self];
		return [ret autorelease];
	}

	return nil;
}

- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope {
	
}

#pragma mark -

- (NSArray *) eventsInRange:(NSRange) range {
	if( ! range.length ) return [NSArray array];

	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:range.length];
		Class class = [JVChatEvent class];
		struct _specificElementsInRangeCallbackData data = { self, results, class };
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT link FROM digest WHERE entity = 'event' ORDER BY position ASC LIMIT %u OFFSET %u", range.length, range.location );
		sqlite3_exec( _database, query, _specificElementsInRangeCallback, &data, NULL );
		return [results autorelease];
	}

	return nil;
}

- (id) lastEvent {
	@synchronized( self ) {
		NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
		Class class = [JVChatEvent class];
		struct _specificElementsInRangeCallbackData data = { self, results, class };
		sqlite3_exec( _database, "SELECT link FROM digest WHERE entity = 'event' ORDER BY position DESC LIMIT 1", _specificElementsInRangeCallback, &data, NULL );

		id last = [[results lastObject] retain];
		[results release];

		return [last autorelease];
	}

	return nil;
}

#pragma mark -

- (BOOL) containsEventWithIdentifier:(NSString *) identifier {
	NSParameterAssert( identifier != nil );
	NSParameterAssert( [identifier length] > 0 );

	BOOL contains = NO;
	char **tables = NULL;
	int rows = 0, cols = 0;

	@synchronized( self ) {
		char query[128] = "";
		sqlite3_snprintf( sizeof( query ), query, "SELECT COUNT(*) FROM event WHERE id = '%q'", identifier );
		sqlite3_get_table( _database, query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 1 && tables[1] )
			contains = ! ( tables[1][0] == '0' && tables[1][1] == '\0' );
		sqlite3_free_table( tables );
	}

	return contains;
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
	@synchronized( self ) {
		if( NSDebugEnabled ) sqlite3_trace( _database, _printSQL, NULL );
		NSString *setup = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"transcriptSchema" ofType:@"sql"]];
		if( sqlite3_exec( _database, [setup UTF8String], NULL, NULL, NULL ) != SQLITE_OK )
			return NO;
	}

	return YES;
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

	unsigned long count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	char query[200] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT received, action, highlighted, ignored, type FROM message WHERE id = '%q' LIMIT 1", [_messageIdentifier UTF8String] );

	@synchronized( _transcript ) {
		sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 5 ) {
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
		}
		sqlite3_free_table( tables );
	}

	_loaded = YES;
}

- (void) _loadSenderFromSQL {
	if( _senderLoaded ) return;

	unsigned long count = 0;
	char **tables = NULL;
	int rows = 0, cols = 0;

	char query[200] = "";
	sqlite3_snprintf( sizeof( query ), query, "SELECT self, nickname, identifier, hostmask, class, buddy FROM user LEFT JOIN message ON message.user = user.id WHERE message.id = '%q' LIMIT 1", [_messageIdentifier UTF8String] );

	@synchronized( _transcript ) {
		sqlite3_get_table( [(JVSQLChatTranscript *)_transcript _database], query, &tables, &rows, &cols, NULL );
		if( rows == 1 && cols == 6 ) {
			char **results = tables + cols;

			_senderIsLocalUser = ( *results && ! ( **results == '0' && *(*results + 1) == '\0' ) );

			results++;
			id old = _senderNickname;
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

	unsigned long count = 0;
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
