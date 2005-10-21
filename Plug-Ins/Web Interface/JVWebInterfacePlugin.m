#import "JVWebInterfacePlugin.h"
#import "NSStringAdditions.h"
#import "JVChatController.h"
#import "JVDirectChatPanel.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVChatMessage.h"
#import "MVChatConnection.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVStyleView.h"
#import "nanohttpd.h"

static NSString *JVWebInterfaceRequest = @"JVWebInterfaceRequest";
static NSString *JVWebInterfaceRequestContent = @"JVWebInterfaceRequestContent";
static NSString *JVWebInterfaceResponse = @"JVWebInterfaceResponse";
static NSString *JVWebInterfaceClientIdentifier = @"JVWebInterfaceClientIdentifier";

void processCommand( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	JVWebInterfacePlugin *self = (JVWebInterfacePlugin *) server -> context;
	NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:req -> uri]];

	NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithCapacity:20];
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

	command = [command stringByAppendingString:@"Command:"];
	SEL selector = NSSelectorFromString( command );

	char *ident = req -> get_cookie( req, "identifier" );
	NSString *identifier = ( ident ? [NSString stringWithUTF8String:ident] : nil );
	if( ident ) free( ident );

	if( identifier ) [arguments setObject:identifier forKey:JVWebInterfaceClientIdentifier];

	if( [self respondsToSelector:selector] )
		[self performSelectorOnMainThread:selector withObject:arguments waitUntilDone:YES];

	[pool release];
}

void passThruFile( NSString *path, http_req_t *req, http_resp_t *resp, http_server_t *server ) {
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

void processResources( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
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

void processStyles( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
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

void processEmoticons( http_req_t *req, http_resp_t *resp, http_server_t *server ) {
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

@implementation JVWebInterfacePlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_clients = [[NSMutableDictionary alloc] initWithCapacity:5];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( newMessage: ) name:@"JVChatMessageWasProcessedNotification" object:nil];
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
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "png", "image/png" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "jpg", "image/jpeg" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "gif", "image/gif" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "tif", "image/tiff" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "tiff", "image/tiff" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "html", "text/html" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "xml", "text/xml" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "plist", "text/xml" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "txt", "text/plain" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "css", "text/plain" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "js", "text/plain" );
	_httpServer -> mime_types -> set( _httpServer -> mime_types, "rtf", "text/rtf" );

	_httpServer -> run( _httpServer ); // spawns 3 threads to handle incoming requests
}

- (void) unload {
	[self deallocServer];
}

- (JVDirectChatPanel *) panelForIdentifier:(NSString *) identifier {
	NSNumber *identifierNum = [NSNumber numberWithUnsignedInt:[identifier intValue]];
	NSEnumerator *enumerator = [[[JVChatController defaultController] allChatViewControllers] objectEnumerator];
	JVDirectChatPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) )
		if( [panel isKindOfClass:[JVDirectChatPanel class]] &&
			[[panel uniqueIdentifier] isEqual:identifierNum] ) break;

	return panel;
}

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

	NSURL *bodyShellLocation = [[panel style] bodyTemplateLocationWithName:[[panel display] bodyTemplate]];

	NSString *bodyShell = @"";
	if( bodyShellLocation )
		bodyShell = [NSString stringWithContentsOfURL:bodyShellLocation encoding:NSUTF8StringEncoding error:NULL];

	bodyShell = ( [bodyShell length] ? [NSString stringWithFormat:bodyShell, @"/resources", content] : content );

	int fontSize = [[[panel display] preferences] defaultFontSize];
	NSString *fontFamily = [[[panel display] preferences] sansSerifFontFamily];
	NSString *header = [NSString stringWithFormat:@"<style type=\"text/css\">body { font-size: %dpx; font-family: %@ }</style>", fontSize, fontFamily];

	return [NSString stringWithFormat:shell, [panel description], header, @"/resources", emoticonStyleSheet, mainStyleSheet, variant, baseLocation, bodyShell];
}

- (void) setupCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! [identifier length] )
		identifier = [NSString locallyUniqueString];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[_clients setObject:info forKey:identifier];

	NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:[NSXMLElement elementWithName:@"queue"]];
	[info setObject:doc forKey:@"activityQueue"];

	NSMutableDictionary *styles = [NSMutableDictionary dictionary];
	[info setObject:styles forKey:@"originalStyles"];

	doc = [NSXMLDocument documentWithRootElement:[NSXMLElement elementWithName:@"setup"]];
	NSXMLElement *node = [NSXMLElement elementWithName:@"panels"];
	[[doc rootElement] addChild:node];

	NSSet *chats = [[JVChatController defaultController] chatViewControllersKindOfClass:[JVDirectChatPanel class]];
	NSEnumerator *enumerator = [chats objectEnumerator];
	JVChatRoomPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) ) {
		NSXMLElement *chat = [NSXMLElement elementWithName:@"panel"];
		NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
		[attributes setObject:NSStringFromClass( [panel class] ) forKey:@"class"];
		[attributes setObject:[[panel target] description] forKey:@"name"];
		[attributes setObject:[[panel connection] server] forKey:@"server"];
		[attributes setObject:[panel uniqueIdentifier] forKey:@"identifier"];
		[attributes setObject:[[panel style] identifier] forKey:@"style"];
		[chat setAttributesAsDictionary:attributes];
		[node addChild:chat];
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
	NSDictionary *info = [_clients objectForKey:identifier];
	if( ! info ) return;

	JVDirectChatPanel *panel = [self panelForIdentifier:[arguments objectForKey:@"panel"]];

	if( panel ) {
		NSMutableDictionary *styles = [info objectForKey:@"originalStyles"];
		[styles setObject:[[panel style] identifier] forKey:[panel uniqueIdentifier]];

		DOMHTMLDocument *document = (DOMHTMLDocument *)[[[panel display] mainFrame] DOMDocument];
		DOMHTMLElement *bodyNode = (DOMHTMLElement *)[document getElementById:@"contents"];
		if( ! bodyNode ) bodyNode = (DOMHTMLElement *)[document body];

		NSString *body = [self displayHTMLForPanel:panel withContent:[bodyNode innerHTML]];
		char *bodyContent = (char *)[body UTF8String];
		resp -> content_type = "text/html";
		resp -> write( resp, bodyContent, strlen( bodyContent ) );
	} else resp -> printf( resp, "" );
}

- (void) logoutCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	[_clients removeObjectForKey:identifier];
}

- (void) sendCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	NSDictionary *info = [_clients objectForKey:identifier];
	if( ! info ) return;

	JVDirectChatPanel *panel = [self panelForIdentifier:[arguments objectForKey:@"panel"]];

	if( panel ) {
		NSString *text = [[[NSString alloc] initWithData:[arguments objectForKey:JVWebInterfaceRequestContent] encoding:NSUTF8StringEncoding] autorelease];
		NSArray *strings = [text componentsSeparatedByString:@"\n"];
		NSEnumerator *enumerator = [strings objectEnumerator];

		while( ( text = [enumerator nextObject] ) ) {
			if( ! [text length] ) continue;
			if( [text hasPrefix:@"/"] && ! [text hasPrefix:@"//"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:text];
				NSString *command = nil;
				id arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [text length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [text substringWithRange:NSMakeRange( [scanner scanLocation], [text length] - [scanner scanLocation] )];
				arguments = [[[NSAttributedString alloc] initWithString:arguments] autorelease];

				if( ! ( handled = [panel processUserCommand:command withArguments:arguments] ) && [[panel connection] isConnected] )
					[[panel connection] sendRawMessage:[command stringByAppendingFormat:@" %@", [arguments string]]];
			} else {
				if( [text hasPrefix:@"//"] ) text = [text substringWithRange:NSMakeRange( 1, [text length] - 1 )];
				JVMutableChatMessage *message = [JVMutableChatMessage messageWithText:@"" sender:[[panel connection] localUser]];
				[message setBodyAsHTML:text];
				[panel echoSentMessageToDisplay:message];
				[panel sendMessage:message];
			}
		}
	}

	resp -> printf( resp, "" );
}

- (void) checkActivityCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	NSDictionary *info = [_clients objectForKey:identifier];
	if( ! info ) return;

	NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
	if( ! doc ) return;

	if( [[doc rootElement] childCount] ) {
		NSData *xml = [doc XMLData];
		resp -> content_type = "text/xml";
		resp -> write( resp, (char *)[xml bytes], [xml length] );
		[[doc rootElement] setChildren:nil]; // clear the queue
	} else {
		resp -> printf( resp, "" );
	}
}

- (void) addElementToClientQueues:(NSXMLElement *) element {
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

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	
}

- (void) newMessage:(NSNotification *) notification {
	if( ! [_clients count] ) return;

	JVMutableChatMessage *message = [[notification userInfo] objectForKey:@"message"];
	JVDirectChatPanel *view = [notification object];
	if( ! [view isKindOfClass:[JVDirectChatPanel class]] ) return;

	NSXMLElement *element = [NSXMLElement elementWithName:@"message"];

	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:[view uniqueIdentifier] forKey:@"panel"];
	[attributes setObject:[[message date] description] forKey:@"received"];
	[element setAttributesAsDictionary:attributes];

	NSEnumerator *enumerator = [_clients objectEnumerator];
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		NSXMLDocument *doc = [info objectForKey:@"activityQueue"];
		if( ! doc ) continue;

		JVStyle *style = [JVStyle styleWithIdentifier:[[info objectForKey:@"originalStyles"] objectForKey:[view uniqueIdentifier]]];
		NSString *tmessage = [style transformChatMessage:message withParameters:[[view display] styleParameters]]; // this will break once styles use custom styleParameters!!

		NSXMLNode *body = [[[NSXMLNode alloc] initWithKind:NSXMLTextKind options:NSXMLNodeIsCDATA] autorelease];
		[body setStringValue:tmessage];

		NSXMLElement *copy = [element copyWithZone:[self zone]];
		[copy addChild:body];
		[[doc rootElement] addChild:copy];
		[copy release];
	}
}

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	
}

- (void) joinedRoom:(JVChatRoomPanel *) room {
	if( ! [_clients count] ) return;

	NSXMLElement *element = [NSXMLElement elementWithName:@"open"];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:NSStringFromClass( [room class] ) forKey:@"class"];
	[attributes setObject:[[room target] description] forKey:@"name"];
	[attributes setObject:[[room connection] server] forKey:@"server"];
	[attributes setObject:[room uniqueIdentifier] forKey:@"identifier"];
	[attributes setObject:[[room style] identifier] forKey:@"style"];
	[element setAttributesAsDictionary:attributes];

	[self addElementToClientQueues:element];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room {
	if( ! [_clients count] ) return;

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