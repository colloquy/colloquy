#import "JVWebInterfacePlugin.h"
#import "NSStringAdditions.h"
#import "JVChatController.h"
#import "JVChatRoomPanel.h"
#import "MVChatConnection.h"

static NSString *JVWebInterfaceRequest = @"JVWebInterfaceRequest";
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

@implementation JVWebInterfacePlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( self = [super init] ) {
		_clients = [[NSMutableDictionary alloc] initWithCapacity:5];
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

	_httpServer -> add_url( _httpServer, "^/command/", processCommand );

	_httpServer -> directory_index = list_new();
	_httpServer -> directory_index -> add( _httpServer -> directory_index, "index.html" );

	_httpServer -> run( _httpServer ); // spawns 3 threads to handle incoming requests
}

- (void) unload {
	[self deallocServer];
}

- (void) setupCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	if( ! [identifier length] )
		identifier = [NSString locallyUniqueString];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[_clients setObject:info forKey:identifier];

	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithRootElement:[[[NSXMLElement alloc] initWithName:@"queue"] autorelease]] autorelease];
	[info setObject:doc forKey:@"activityQueue"];

	doc = [[[NSXMLDocument alloc] initWithRootElement:[[[NSXMLElement alloc] initWithName:@"setup"] autorelease]] autorelease];

	NSXMLElement *node = [[[NSXMLElement alloc] initWithName:@"panels"] autorelease];
	[[doc rootElement] addChild:node];

	NSSet *chats = [[JVChatController defaultController] chatViewControllersKindOfClass:[JVDirectChatPanel class]];
	NSEnumerator *enumerator = [chats objectEnumerator];
	JVChatRoomPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) ) {
		NSXMLElement *chat = [[[NSXMLElement alloc] initWithName:@"panel"] autorelease];
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

- (void) logoutCommand:(NSDictionary *) arguments {
	http_resp_t *resp = [[arguments objectForKey:JVWebInterfaceResponse] pointerValue];
	if( ! resp ) return;

	NSString *identifier = [arguments objectForKey:JVWebInterfaceClientIdentifier];
	[_clients removeObjectForKey:identifier];
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
@end