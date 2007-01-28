#import "JVWebInterfacePlugin.h"

#import <WebKit/WebKit.h>

#import "JVChatController.h"
#import "JVChatEvent.h"
#import "JVChatMessage.h"
#import "JVChatRoomMember.h"
#import "JVChatRoomPanel.h"
#import "JVDirectChatPanel.h"
#import "JVEmoticonSet.h"
#import "JVStyle.h"
#import "JVStyleView.h"
#import "MVChatConnection.h"
#import "NSStringAdditions.h"
#import "nanohttpd.h"

static NSString *JVWebInterfaceRequest = @"JVWebInterfaceRequest";
static NSString *JVWebInterfaceRequestContent = @"JVWebInterfaceRequestContent";
static NSString *JVWebInterfaceResponse = @"JVWebInterfaceResponse";
static NSString *JVWebInterfaceClientIdentifier = @"JVWebInterfaceClientIdentifier";

static void processCommand( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	static NSSet *threadSafeCommands = nil;
	if( ! threadSafeCommands )
		threadSafeCommands = [[NSSet alloc] initWithObjects:@"checkActivity", @"logout", nil];

	JVWebInterfacePlugin *self = (JVWebInterfacePlugin *) server -> context;
	NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:req -> uri]];

	NSMutableDictionary *arguments = [[NSMutableDictionary alloc] initWithCapacity:10];
	[arguments setObject:[NSValue valueWithPointer:req] forKey:JVWebInterfaceRequest];
	[arguments setObject:[NSValue valueWithPointer:resp] forKey:JVWebInterfaceResponse];

	list_t *parameters = req -> get_parameters( req );
	if( parameters ) {
		for( char *key = (char *)parameters -> first( parameters ); key; key = (char *) parameters -> next( parameters ) ) {
			const char *value = req -> get_parameter( req, key );
			NSString *keyString = [NSString stringWithUTF8String:key];
			id valueObject = ( value ? [NSString stringWithUTF8String:value] : [NSNull null] );
			if( keyString && valueObject ) [arguments setObject:valueObject forKey:keyString];
		}
		parameters -> delete( parameters );
	}
	
	if( req -> content ) {
		NSData *content = [NSData dataWithBytes:req -> content length:req -> content_length];
		[arguments setObject:content forKey:JVWebInterfaceRequestContent];
	}

	NSString *command = [url path];
	if( [command hasPrefix:@"/command/"] )
		command = [command substringFromIndex:9];

	char *ident = req -> get_cookie( req, "identifier" );
	NSString *identifier = ( ident ? [NSString stringWithUTF8String:ident] : nil );
	if( ident ) free( ident );

	if( identifier ) [arguments setObject:identifier forKey:JVWebInterfaceClientIdentifier];

	SEL selector = NSSelectorFromString( [command stringByAppendingString:@"Command:"] );
	if( [self respondsToSelector:selector] ) {
		if( [threadSafeCommands containsObject:command] )
			[self performSelector:selector withObject:arguments];
		else [self performSelectorOnMainThread:selector withObject:arguments waitUntilDone:YES];
	}

	resp -> write( resp, "", 0 );

	[arguments release];
	[pool release];
}

static void passThruFile( NSString *path, http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	BOOL isDir = NO;
	if( ! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir ) {
		resp -> status_code = 404;
		resp -> reason_phrase = "Not Found";
		resp -> printf( resp, "404: Not Found" );
		return;
	}

	if( ! [[NSFileManager defaultManager] isReadableFileAtPath:path] ) {
		resp -> status_code = 403;
		resp -> reason_phrase = "Read Access Forbidden";
		resp -> printf( resp, "403: Read Access Forbidden" );
		return;
	}

	const char *ext = [[path pathExtension] UTF8String];
	const char *content_type = NULL;
	if( ext ) content_type = server -> get_mime( server, ext );
	if( content_type ) resp -> content_type = (char *) content_type;

	NSData *contents = [NSData dataWithContentsOfFile:path];
	resp -> write( resp, (char *)[contents bytes], [contents length] );
}

static void processResources( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// example: /resources/Colloquy.png
	NSString *path = [NSString stringWithUTF8String:req -> file_name];
	NSArray *parts = [path pathComponents];
	parts = [[path pathComponents] subarrayWithRange:NSMakeRange( 2, ( [parts count] - 2 ) )];

	path = [NSString pathWithComponents:parts];
	path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];

	passThruFile( path, req, resp, server );

	[pool release];
}

static void processStyles( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// example: /styles/cc.javelin.colloquy.synapse/main.css
	// variant example: /styles/variants/cc.javelin.colloquy.synapse/VariantName.css
	NSString *path = [NSString stringWithUTF8String:req -> file_name];
	NSArray *parts = [path pathComponents];
	if( [parts count] < 3 ) {
		resp -> status_code = 404;
		resp -> reason_phrase = "Not Found";
		resp -> printf( resp, "404: Not Found" );
		return;
	}
	
	BOOL variantSearch = NO;
	NSString *bundleIdentifier = [parts objectAtIndex:2];
	if( [bundleIdentifier isEqualToString:@"variants"] ) {
		bundleIdentifier = [parts objectAtIndex:3];
		variantSearch = YES;
	}

	JVStyle *style = [JVStyle styleWithIdentifier:bundleIdentifier];
	if( ! style ) {
		resp -> status_code = 404;
		resp -> reason_phrase = "Not Found";
		resp -> printf( resp, "404: Not Found" );
		return;
	}

	if( variantSearch ) {
		parts = [[path pathComponents] subarrayWithRange:NSMakeRange( 4, ( [parts count] - 4 ) )];
	} else {
		parts = [[path pathComponents] subarrayWithRange:NSMakeRange( 3, ( [parts count] - 3 ) )];
	}

	path = [NSString pathWithComponents:parts];

	if( variantSearch ) {
		NSString *variantName = [[path lastPathComponent] stringByDeletingPathExtension];
		NSURL *location = [style variantStyleSheetLocationWithName:variantName];
		path = [location path];
	} else {
		path = [[[style bundle] resourcePath] stringByAppendingPathComponent:path];
	}

	passThruFile( path, req, resp, server );

	[pool release];
}

static void processEmoticons( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// example: /emoticons/cc.javelin.colloquy.standard/main.css
	NSString *path = [NSString stringWithUTF8String:req -> file_name];
	NSArray *parts = [path pathComponents];
	if( [parts count] < 3 ) {
		resp -> status_code = 404;
		resp -> reason_phrase = "Not Found";
		resp -> printf( resp, "404: Not Found" );
		return;
	}

	NSString *bundleIdentifier = [parts objectAtIndex:2];
	NSBundle *emoticons = [NSBundle bundleWithIdentifier:bundleIdentifier];
	if( ! emoticons ) {
		resp -> status_code = 404;
		resp -> reason_phrase = "Not Found";
		resp -> printf( resp, "404: Not Found" );
		return;
	}

	parts = [[path pathComponents] subarrayWithRange:NSMakeRange( 3, ( [parts count] - 3 ) )];

	path = [NSString pathWithComponents:parts];
	path = [[emoticons resourcePath] stringByAppendingPathComponent:path];

	passThruFile( path, req, resp, server );

	[pool release];
}

#pragma mark -

@implementation JVWebInterfacePlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [super init] ) ) {
		_clients = [[NSMutableDictionary alloc] initWithCapacity:5];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( newMessage: ) name:@"JVChatMessageWasProcessedNotification" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( newEvent: ) name:@"JVChatEventMessageWasProcessedNotification" object:nil];
	}

	return self;
}

- (void) deallocServer {
	if( _httpServer ) {
		_httpServer -> running = 0;
		_httpServer -> context = NULL;
		if( _httpServer -> document_root )
			free( _httpServer -> document_root );
		_httpServer -> document_root = NULL;
		if( _httpServer -> directory_index )
			_httpServer -> directory_index -> delete2( _httpServer -> directory_index );
		_httpServer -> directory_index = NULL;
		_httpServer -> delete( _httpServer );
		_httpServer = NULL;
	}
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self deallocServer];

	[_clients release];
	_clients = nil;

	[super dealloc];
}

#pragma mark -

- (void) load {
	[self deallocServer];

	_httpServer = http_server_new( NULL, "6667" ); // bind to any IP on port 6667
	_httpServer -> context = self;
	_httpServer -> document_root = strdup( [[[NSBundle bundleForClass:[self class]] resourcePath] fileSystemRepresentation] );

	_httpServer -> add_url( _httpServer, "^/resources/", processResources );
	_httpServer -> add_url( _httpServer, "^/styles/", processStyles );
	_httpServer -> add_url( _httpServer, "^/emoticons/", processEmoticons );
	_httpServer -> add_url( _httpServer, "^/command/", processCommand );

	_httpServer -> directory_index = list_new();
	_httpServer -> directory_index -> add( _httpServer -> directory_index, "index.html" );

	_httpServer -> mime_types = hash_new();
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"png", (char *)"image/png" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"jpg", (char *)"image/jpeg" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"gif", (char *)"image/gif" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"tif", (char *)"image/tiff" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"tiff", (char *)"image/tiff" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"html", (char *)"text/html" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"xml", (char *)"text/xml" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"plist", (char *)"text/xml" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"txt", (char *)"text/plain" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"css", (char *)"text/css" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"js", (char *)"text/javascript" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, (char *)"rtf", (char *)"text/rtf" );

	_httpServer -> run( _httpServer ); // spawns 3 threads to handle incoming requests
}

- (void) unload {
	[self deallocServer];
}

#pragma mark -

- (JVDirectChatPanel *) panelForIdentifier:(NSString *) identifier {
	NSNumber *identifierNum = [NSNumber numberWithUnsignedInt:[identifier intValue]];
	NSEnumerator *enumerator = [[[JVChatController defaultController] allChatViewControllers] objectEnumerator];
	JVDirectChatPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) )
		if( [panel isKindOfClass:[JVDirectChatPanel class]] &&
			[[panel uniqueIdentifier] isEqual:identifierNum] ) break;

	return panel;
}

#pragma mark -

- (NSString *) displayHTMLForPanel:(JVDirectChatPanel *) panel withContent:(NSString *) content {
	NSString *variant = [[panel display] styleVariant];
	if( [variant length] ) {
		variant = [NSString stringWithFormat:@"/styles/variants/%@/%@.css", [[panel style] identifier], variant];
	} else variant = @"";

	NSString *baseLocation = [NSString stringWithFormat:@"/styles/%@", [[panel style] identifier]];
	NSString *mainStyleSheet = [NSString stringWithFormat:@"%@/main.css", baseLocation];

	NSString *emoticonStyleSheet = @"";
	if( ! [[[panel emoticons] bundle] isEqual:[NSBundle mainBundle]] )
		emoticonStyleSheet = [NSString stringWithFormat:@"/emoticons/%@/emoticons.css", [[panel emoticons] identifier]];

	NSString *shell = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"] encoding:NSUTF8StringEncoding error:NULL];

	NSString *bodyTemplate = [[panel style] contentsOfBodyTemplateWithName:[[panel display] bodyTemplate]];
	if( [bodyTemplate length] && [content length] ) {
		if( [bodyTemplate rangeOfString:@"%@"].location != NSNotFound )
			bodyTemplate = [NSString stringWithFormat:bodyTemplate, content];
		else bodyTemplate = [bodyTemplate stringByAppendingString:content];
	} else if( ! [bodyTemplate length] && [content length] ) {
		bodyTemplate = content;
	}

	int fontSize = [[[panel display] preferences] defaultFontSize];
	NSString *fontFamily = [[[panel display] preferences] sansSerifFontFamily];
	NSString *header = [NSString stringWithFormat:@"<style type=\"text/css\">body { font-size: %dpx; font-family: %@ }</style>", fontSize, fontFamily];

	return [NSString stringWithFormat:shell, [panel description], header, @"/resources", emoticonStyleSheet, mainStyleSheet, variant, baseLocation, bodyTemplate];
}

#pragma mark -

- (void) setupCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! [identifier length] )
		identifier = [NSString locallyUniqueString];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];

	NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:[NSXMLElement elementWithName:@"queue"]];
	[info setObject:doc forKey:@"activityQueue"];

	NSMutableDictionary *styles = [NSMutableDictionary dictionary];
	[info setObject:styles forKey:@"originalStyles"];

	doc = [NSXMLDocument documentWithRootElement:[NSXMLElement elementWithName:@"setup"]];
	NSXMLElement *node = [NSXMLElement elementWithName:@"panels"];
	[[doc rootElement] addChild:node];

	NSSet *chats = [[JVChatController defaultController] chatViewControllersKindOfClass:[JVDirectChatPanel class]];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSEnumerator *enumerator = [chats objectEnumerator];
	JVDirectChatPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) ) {
		NSXMLElement *chat = [NSXMLElement elementWithName:@"panel"];
		[attributes removeAllObjects];
		[attributes setObject:NSStringFromClass( [panel class] ) forKey:@"class"];
		[attributes setObject:[[panel target] description] forKey:@"name"];
		[attributes setObject:[[panel connection] server] forKey:@"server"];
		[attributes setObject:[panel uniqueIdentifier] forKey:@"identifier"];
		[chat setAttributesAsDictionary:attributes];
		[node addChild:chat];

		if( [panel isMemberOfClass:[JVChatRoomPanel class]] ) {
			NSEnumerator *members = [[panel children] objectEnumerator];
			JVChatRoomMember *member = nil;
			while( ( member = [members nextObject] ) ) {
				NSXMLElement *memberNode = [[NSXMLElement alloc] initWithXMLString:[member xmlDescription] error:NULL];
				if( memberNode ) [chat addChild:memberNode];
				[memberNode release];
			}
		}
	}

	@synchronized( _clients ) {
		[_clients setObject:info forKey:identifier];
	}

	resp -> content_type = "text/xml";
	resp -> add_cookie( resp, (char *)[[NSString stringWithFormat:@"identifier=%@; path=/", identifier] UTF8String] );

	NSData *xml = [doc XMLData];
	resp -> write( resp, (char *)[xml bytes], [xml length] );
}

- (void) panelContentsCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! identifier ) return;

	@synchronized( _clients ) {
		NSDictionary *info = [_clients objectForKey:identifier];
		if( ! info ) return;

		JVDirectChatPanel *panel = [self panelForIdentifier:[arguments objectForKey:@"panel"]];

		if( panel ) {
			NSMutableDictionary *styles = [info objectForKey:@"originalStyles"];
			[styles setObject:[[panel style] identifier] forKey:[panel uniqueIdentifier]];

			DOMHTMLDocument *document = (DOMHTMLDocument *)[[[[panel display] mainFrame] findFrameNamed:@"content"] DOMDocument];
			DOMHTMLElement *bodyNode = (DOMHTMLElement *)[document getElementById:@"contents"];
			if( ! bodyNode ) bodyNode = (DOMHTMLElement *)[document body];

			NSString *body = [self displayHTMLForPanel:panel withContent:[bodyNode innerHTML]];
			char *bodyContent = (char *)[body UTF8String];
			resp -> content_type = "text/html";
			resp -> write( resp, bodyContent, strlen( bodyContent ) );
		}
	}
}

- (void) logoutCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! identifier ) return;

	@synchronized( _clients ) {
		[_clients removeObjectForKey:identifier];
	}
}

- (void) sendCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	JVDirectChatPanel *panel = [self panelForIdentifier:[arguments objectForKey:@"panel"]];

	if( panel ) {
		NSString *text = [[NSString alloc] initWithData:[arguments objectForKey:JVWebInterfaceRequestContent] encoding:NSUTF8StringEncoding];
		NSArray *strings = [text componentsSeparatedByString:@"\n"];
		NSEnumerator *enumerator = [strings objectEnumerator];
		[text release];

		while( ( text = [enumerator nextObject] ) ) {
			if( ! [text length] ) continue;
			if( [text hasPrefix:@"/"] && ! [text hasPrefix:@"//"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:text];
				NSString *command = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [text length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				NSString *subArgs = [text substringWithRange:NSMakeRange( [scanner scanLocation], [text length] - [scanner scanLocation] )];
				NSAttributedString *cmdArguments = [[NSAttributedString alloc] initWithString:subArgs];

				if( ! ( handled = [panel processUserCommand:command withArguments:cmdArguments] ) && [[panel connection] isConnected] )
					[[panel connection] sendRawMessage:[command stringByAppendingFormat:@" %@", [cmdArguments string]]];

				[cmdArguments release];
			} else {
				if( [text hasPrefix:@"//"] ) text = [text substringWithRange:NSMakeRange( 1, [text length] - 1 )];
				JVMutableChatMessage *message = [JVMutableChatMessage messageWithText:@"" sender:[[panel connection] localUser]];
				[message setBodyAsHTML:text];
				[panel echoSentMessageToDisplay:message];
				[panel sendMessage:message];
			}
		}
	}
}

- (void) checkActivityCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! identifier ) return;

	@synchronized( _clients ) {
		NSDictionary *info = [_clients objectForKey:identifier];
		if( ! info ) return;

		NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
		if( ! doc ) return;

		if( [[doc rootElement] childCount] ) {
			NSData *xml = [doc XMLData];
			resp -> content_type = "text/xml";
			resp -> write( resp, (char *)[xml bytes], [xml length] );
			[[doc rootElement] setChildren:nil]; // clear the queue
		}
	}
}

#pragma mark -

- (void) addElementToClientQueues:(NSXMLElement *) element {
	@synchronized( _clients ) {
		if( ! [_clients count] ) return;

		NSEnumerator *enumerator = [_clients objectEnumerator];
		NSDictionary *info = nil;

		while( ( info = [enumerator nextObject] ) ) {
			NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
			if( ! doc ) continue;

			NSXMLElement *copy = [element copyWithZone:[self zone]];
			[[doc rootElement] addChild:copy];
			[copy release];
		}
	}
}

#pragma mark -

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	
}

- (void) newMessage:(NSNotification *) notification {
	@synchronized( _clients ) {
		if( ! [_clients count] ) return;

		JVMutableChatMessage *message = [[notification userInfo] objectForKey:@"message"];
		JVDirectChatPanel *view = [notification object];
		if( ! [view isKindOfClass:[JVDirectChatPanel class]] ) return;

		if( [view isMemberOfClass:[JVDirectChatPanel class]] ) {
			NSXMLElement *element = [NSXMLElement elementWithName:@"open"];
			NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
			[attributes setObject:NSStringFromClass( [view class] ) forKey:@"class"];
			[attributes setObject:[[view target] description] forKey:@"name"];
			[attributes setObject:[[view connection] server] forKey:@"server"];
			[attributes setObject:[view uniqueIdentifier] forKey:@"identifier"];
			[element setAttributesAsDictionary:attributes];

			[self addElementToClientQueues:element];
		}

		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		[attributes setObject:[view uniqueIdentifier] forKey:@"panel"];
		[attributes setObject:[[message date] description] forKey:@"received"];
		if( [message isHighlighted] ) [attributes setObject:@"yes" forKey:@"highlighted"];

		NSMutableDictionary *styleParams = [[[view display] styleParameters] mutableCopy];

		if( [message consecutiveOffset] > 0 )
			[styleParams setObject:@"'yes'" forKey:@"consecutiveMessage"];

		NSEnumerator *enumerator = [_clients objectEnumerator];
		NSDictionary *info = nil;

		while( ( info = [enumerator nextObject] ) ) {
			JVStyle *style = [JVStyle styleWithIdentifier:[[info objectForKey:@"originalStyles"] objectForKey:[view uniqueIdentifier]]];
			NSString *tmessage = [style transformChatMessage:message withParameters:styleParams]; // this will break once styles use custom styleParameters!!

			NSXMLNode *body = [[NSXMLNode alloc] initWithKind:NSXMLTextKind options:NSXMLNodeIsCDATA];
			[body setStringValue:tmessage];

			NSXMLElement *element = [NSXMLElement elementWithName:@"message"];
			[element setAttributesAsDictionary:attributes];
			[element addChild:body];
			[body release];

			NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
			[[doc rootElement] addChild:element];
		}

		[styleParams release];
	}
}

- (void) newEvent:(NSNotification *) notification {
	@synchronized( _clients ) {
		if( ! [_clients count] ) return;

		JVMutableChatEvent *event = [[notification userInfo] objectForKey:@"event"];
		JVDirectChatPanel *view = [notification object];
		if( ! [view isKindOfClass:[JVDirectChatPanel class]] ) return;

		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		[attributes setObject:[view uniqueIdentifier] forKey:@"panel"];
		[attributes setObject:[[event date] description] forKey:@"received"];

		NSMutableDictionary *styleParams = [[[view display] styleParameters] mutableCopy];

		NSEnumerator *enumerator = [_clients objectEnumerator];
		NSDictionary *info = nil;

		while( ( info = [enumerator nextObject] ) ) {
			JVStyle *style = [JVStyle styleWithIdentifier:[[info objectForKey:@"originalStyles"] objectForKey:[view uniqueIdentifier]]];
			NSString *tmessage = [style transformChatTranscriptElement:event withParameters:styleParams]; // this will break once styles use custom styleParameters!!

			NSXMLNode *body = [[NSXMLNode alloc] initWithKind:NSXMLTextKind options:NSXMLNodeIsCDATA];
			[body setStringValue:tmessage];

			NSXMLElement *element = [NSXMLElement elementWithName:@"event"];
			[element setAttributesAsDictionary:attributes];
			[element addChild:body];
			[body release];

			NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
			[[doc rootElement] addChild:element];
		}

		[styleParams release];
	}
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	NSXMLElement *element = [NSXMLElement elementWithName:@"open"];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:NSStringFromClass( [room class] ) forKey:@"class"];
	[attributes setObject:[[room target] description] forKey:@"name"];
	[attributes setObject:[[room connection] server] forKey:@"server"];
	[attributes setObject:[room uniqueIdentifier] forKey:@"identifier"];
	[element setAttributesAsDictionary:attributes];

	[self addElementToClientQueues:element];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	NSXMLElement *element = [NSXMLElement elementWithName:@"close"];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:[room uniqueIdentifier] forKey:@"identifier"];
	[element setAttributesAsDictionary:attributes];

	[self addElementToClientQueues:element];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	
}

- (void) connected:(MVChatConnection *) connection {
	
}

- (void) disconnecting:(MVChatConnection *) connection {
	
}
@end
