#import "JVRubyChatPlugin.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSStringAdditions.h"

NSString *JVRubyErrorDomain = @"JVRubyErrorDomain";

@implementation JVRubyChatPlugin
+ (void) initialize {
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		ruby_init();
		ruby_init_loadpath();
		RBRubyCocoaInit();
		tooLate = YES;
	}
}

- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_manager = manager;
		_path = nil;
		_modDate = [[NSDate date] retain];
	}

	return self;
}

- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_path = [path copyWithZone:[self zone]];
		_firstLoad = YES;

		[self reloadFromDisk];

		_firstLoad = NO;

		if( ! _script ) {
			[self release];
			return nil;
		}

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( checkForModifications: ) name:NSApplicationWillBecomeActiveNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_script release];
	[_path release];
	[_modDate release];

	_path = nil;
	_script = nil;
	_manager = nil;
	_modDate = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatPluginManager *) pluginManager {
	return _manager;
}

- (NSString *) scriptFilePath {
	return _path;
}

- (void) reloadFromDisk {
	if( [_script respondsToSelector:@selector( unload )] )
		[_script performSelector:@selector( unload )];

	NSString *contents = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		contents = [NSString stringWithContentsOfFile:[self scriptFilePath]];
	else contents = [NSString stringWithContentsOfFile:[self scriptFilePath] encoding:NSUTF8StringEncoding error:NULL];

	[_script autorelease];
	_script = [[RBObject alloc] initWithRubyScriptString:contents];

	if( ! _script ) {
		int result = NSRunCriticalAlertPanel( NSLocalizedStringFromTableInBundle( @"Ruby Script Error", nil, [NSBundle bundleForClass:[self class]], "Ruby script error title" ), NSLocalizedStringFromTableInBundle( @"The Ruby script \"%@\" had an error while loading.", nil, [NSBundle bundleForClass:[self class]], "Ruby script error message" ), nil, NSLocalizedStringFromTableInBundle( @"Edit...", nil, [NSBundle bundleForClass:[self class]], "edit button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] );
		if( result == NSCancelButton ) [[NSWorkspace sharedWorkspace] openFile:[self scriptFilePath]];
		return;
	}

	if( ! _firstLoad && [_script respondsToSelector:@selector( loadFromPath: )] )
		[_script performSelector:@selector( loadFromPath: ) withObject:[self scriptFilePath]];
}

#pragma mark -

- (void) promptForReload {
	if( NSRunInformationalAlertPanel( NSLocalizedStringFromTableInBundle( @"Ruby Script Changed", nil, [NSBundle bundleForClass:[self class]], "Ruby script file changed dialog title" ), NSLocalizedStringFromTableInBundle( @"The Ruby script \"%@\" has changed on disk. Any script variables will reset if reloaded.", nil, [NSBundle bundleForClass:[self class]], "Ruby script changed on disk message" ), NSLocalizedStringFromTableInBundle( @"Reload", nil, [NSBundle bundleForClass:[self class]], "reload button title" ), NSLocalizedStringFromTableInBundle( @"Keep Previous Version", nil, [NSBundle bundleForClass:[self class]], "keep previous version button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] ) == NSOKButton ) {
		[self reloadFromDisk];
	}
}

- (void) checkForModifications:(NSNotification *) notification {
	if( ! [[self scriptFilePath] length] ) return;

	NSFileManager *fm = [NSFileManager defaultManager];
	if( [fm fileExistsAtPath:[self scriptFilePath]] ) {
		NSDictionary *info = [fm fileAttributesAtPath:[self scriptFilePath] traverseLink:YES];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			[_modDate autorelease];
			_modDate = [[NSDate date] retain];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (BOOL) respondsToSelector:(SEL) selector {
	if( [_script respondsToSelector:selector] ) return YES;
	else return [super respondsToSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	if( [_script respondsToSelector:[invocation selector]] )
		[invocation invokeWithTarget:_script];
	else [super forwardInvocation:invocation];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
	if( [_script respondsToSelector:selector] )
		return [(NSObject *)_script methodSignatureForSelector:selector];
	else return [super methodSignatureForSelector:selector];
}

#pragma mark -

- (void) load { // call loadFromPath instead
	if( [_script respondsToSelector:@selector( loadFromPath: )] )
		[_script performSelector:@selector( loadFromPath: ) withObject:[self scriptFilePath]];
}
@end