#import "MVChatPluginManager.h"
#import "JVAppleScriptChatPlugin.h"
#import "MVChatUser.h"
#import "MVChatRoom.h"
#import "JVChatWindowController.h"
#import "JVChatMessage.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "NSColorAdditions.h"

@interface NSTerminologyRegistry : NSObject // Private Foundation Class
- (id) initWithSuiteName:(NSString *) name bundle:(NSBundle *) bundle;
- (NSString *) suiteName;
- (NSArray *) suiteNameArray;
- (NSString *) suiteDescription;
- (NSDictionary *) classTerminologyDictionary:(NSString *) className;
- (NSDictionary *) commandTerminologyDictionary:(NSString *) commandName;
- (NSDictionary *) enumerationTerminologyDictionary:(NSString *) enumName;
- (NSDictionary *) synonymTerminologyDictionary:(NSString *) synonymName;
@end

#pragma mark -

@interface NSScriptObjectSpecifier (NSScriptObjectSpecifierPrivate) // Private Foundation Methods
+ (id) _objectSpecifierFromDescriptor:(NSAppleEventDescriptor *) descriptor inCommandConstructionContext:(id) context;
- (NSAppleEventDescriptor *) _asDescriptor;
@end

#pragma mark -

@interface NSAEDescriptorTranslator : NSObject // Private Foundation Class
+ (id) sharedAEDescriptorTranslator;
- (NSAppleEventDescriptor *) descriptorByTranslatingObject:(id) object ofType:(id) type inSuite:(id) suite;
- (id) objectByTranslatingDescriptor:(NSAppleEventDescriptor *) descriptor toType:(id) type inSuite:(id) suite;
- (void) registerTranslator:(id) translator selector:(SEL) selector toTranslateFromClass:(Class) class;
- (void) registerTranslator:(id) translator selector:(SEL) selector toTranslateFromDescriptorType:(unsigned int) type;
@end

#pragma mark -

@interface NSString (NSStringFourCharCode)
- (unsigned long) fourCharCode;
@end

#pragma mark -

@implementation NSString (NSStringFourCharCode)
- (unsigned long) fourCharCode {
	unsigned long ret = 0, length = [self length];

	if( length >= 1 ) ret |= ( [self characterAtIndex:0] & 0x00ff ) << 24;
	else ret |= ' ' << 24;
	if( length >= 2 ) ret |= ( [self characterAtIndex:1] & 0x00ff ) << 16;
	else ret |= ' ' << 16;
	if( length >= 3 ) ret |= ( [self characterAtIndex:2] & 0x00ff ) << 8;
	else ret |= ' ' << 8;
	if( length >= 4 ) ret |= ( [self characterAtIndex:3] & 0x00ff );
	else ret |= ' ';

	return ret;
}
@end

#pragma mark -

@interface NSAppleScript (NSAppleScriptPrivate)
+ (struct ComponentInstanceRecord *) _defaultScriptingComponent;
@end

#pragma mark -

@implementation NSAppleScript (NSAppleScriptAdditions)
- (NSNumber *) scriptIdentifier {
	return [NSNumber numberWithUnsignedLong:_compiledScriptID];
}
@end

#pragma mark -

@implementation JVAppleScriptChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager {
	if( ( self = [self init] ) ) {
		_manager = manager;
		_doseNotRespond = [[NSMutableSet set] retain];
		_script = nil;
		_path = nil;
		_idleTimer = nil;
	}
	return self;
}

- (id) initWithScript:(NSAppleScript *) script atPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	if( ( self = [self initWithManager:manager] ) ) {
		_script = [script retain];
		_path = [path copyWithZone:[self zone]];
		_modDate = [[NSDate date] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( checkForModifications: ) name:NSApplicationWillBecomeActiveNotification object:[NSApplication sharedApplication]];

		[self performSelector:@selector( idle: ) withObject:nil afterDelay:1.];
	}
	return self;
}

- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager {
	NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:NULL] autorelease];
	if( ! [script compileAndReturnError:NULL] ) {
		[self release];
		return nil;
	}

	return ( self = [self initWithScript:script atPath:path withManager:manager] );
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[_idleTimer invalidate];
	[super release];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_script release];
	[_path release];
	[_doseNotRespond release];
	[_idleTimer release];
	[_modDate release];

	_script = nil;
	_path = nil;
	_doseNotRespond = nil;
	_idleTimer = nil;
	_modDate = nil;

	[super dealloc];
}

#pragma mark -

- (NSAppleScript *) script {
	return _script;
}

- (void) setScript:(NSAppleScript *) script {
	[_script autorelease];
	_script = [script retain];
}

#pragma mark -

- (void) reloadFromDisk {
	NSString *filePath = [self scriptFilePath];
	MVChatPluginManager *manager = [self pluginManager];

	NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:NULL] autorelease];
	if( ! [script compileAndReturnError:nil] ) return;

	[self performSelector:@selector( unload )];

	[self setScript:script];
	[_doseNotRespond removeAllObjects];
	[self performSelector:@selector( idle: ) withObject:nil afterDelay:1.];

	[self performSelector:@selector( load )];
}

#pragma mark -

- (MVChatPluginManager *) pluginManager {
	return _manager;
}

#pragma mark -

- (NSString *) scriptFilePath {
	return _path;
}

- (void) setScriptFilePath:(NSString *) path {
	[_path autorelease];
	_path = [path copyWithZone:[self zone]];
}

#pragma mark -

- (id) callScriptHandler:(unsigned long) handler withArguments:(NSDictionary *) arguments forSelector:(SEL) selector {
	if( ! _script ) return nil;

	int pid = [[NSProcessInfo processInfo] processIdentifier];
	NSAppleEventDescriptor *targetAddress = [NSAppleEventDescriptor descriptorWithDescriptorType:typeKernelProcessID bytes:&pid length:sizeof( pid )];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:'cplG' eventID:handler targetDescriptor:targetAddress returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];

	NSEnumerator *enumerator = [arguments objectEnumerator];
	NSEnumerator *kenumerator = [arguments keyEnumerator];
	NSAppleEventDescriptor *descriptor = nil;
	NSString *key = nil;
	id value = nil;

	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		NSScriptObjectSpecifier *specifier = nil;
		if( [value isKindOfClass:[NSScriptObjectSpecifier class]] ) specifier = value;
		else specifier = [value objectSpecifier];

		if( specifier ) descriptor = [[value objectSpecifier] _asDescriptor]; // custom object, use it's object specitier
		else descriptor = [[NSAEDescriptorTranslator sharedAEDescriptorTranslator] descriptorByTranslatingObject:value ofType:nil inSuite:nil];

		if( ! descriptor ) descriptor = [NSAppleEventDescriptor nullDescriptor];
		[event setDescriptor:descriptor forKeyword:[key fourCharCode]];
	}

	NSDictionary *error = nil;
	NSAppleEventDescriptor *result = [_script executeAppleEvent:event error:&error];

	if( error && ! result ) { // an error
		int code = [[error objectForKey:NSAppleScriptErrorNumber] intValue];
		if( code == errAEEventNotHandled || code == errAEHandlerNotFound ) {
			[self doesNotRespondToSelector:selector]; // disable for future calls
		} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVEnableAppleScriptDebugging"] ) {
			NSString *errorDesc = [error objectForKey:NSAppleScriptErrorMessage];
			NSScriptCommandDescription *commandDesc = [[NSScriptSuiteRegistry sharedScriptSuiteRegistry] commandDescriptionWithAppleEventClass:'cplG' andAppleEventCode:handler];
			NSString *scriptSuiteName = [[NSScriptSuiteRegistry sharedScriptSuiteRegistry] suiteForAppleEventCode:'cplG'];
			NSTerminologyRegistry *term = [[[NSClassFromString( @"NSTerminologyRegistry" ) alloc] initWithSuiteName:scriptSuiteName bundle:[NSBundle mainBundle]] autorelease];
			NSString *handlerName = [[term commandTerminologyDictionary:[commandDesc commandName]] objectForKey:@"Name"];
			if( ! handlerName ) handlerName = @"unknown";
			if( NSRunCriticalAlertPanel( NSLocalizedString( @"AppleScript Plugin Error", "AppleScript plugin error title" ), NSLocalizedString( @"The AppleScript plugin \"%@\" had an error while calling the \"%@\" handler.\n\n%@", "AppleScript plugin error message" ), nil, NSLocalizedString( @"Edit...", "edit button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension], handlerName, errorDesc ) == NSCancelButton ) {
				[[NSWorkspace sharedWorkspace] openFile:[self scriptFilePath]];
			}
		}

		return [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:error];
	}

	if( [result descriptorType] == 'obj ' ) { // an object specifier result, evaluate it to the object
		NSScriptObjectSpecifier *specifier = [NSScriptObjectSpecifier _objectSpecifierFromDescriptor:result inCommandConstructionContext:nil];
		return [specifier objectsByEvaluatingSpecifier];
	}

	// a static result evaluate it to the proper object
	return [[NSAEDescriptorTranslator sharedAEDescriptorTranslator] objectByTranslatingDescriptor:result toType:nil inSuite:nil];
}

#pragma mark -

- (void) promptForReload {
	if( NSRunInformationalAlertPanel( NSLocalizedString( @"AppleScript Plugin Changed", "AppleScript plugin file changed dialog title" ), NSLocalizedString( @"The AppleScript plugin \"%@\" has changed on disk. Any script variables will reset if reloaded.", "AppleScript plugin changed on disk message" ), NSLocalizedString( @"Reload", "reload button title" ), NSLocalizedString( @"Keep Previous Version", "keep previous version button title" ), nil, [[[self scriptFilePath] lastPathComponent] stringByDeletingPathExtension] ) == NSOKButton ) {
		[self reloadFromDisk];
	}
}

- (void) checkForModifications:(NSNotification *) notification {
	if( [self scriptFilePath] && [[NSFileManager defaultManager] fileExistsAtPath:[self scriptFilePath]] ) {
		NSDictionary *info = [[NSFileManager defaultManager] fileAttributesAtPath:[self scriptFilePath] traverseLink:YES];
		NSDate *fileModDate = [info fileModificationDate];
		if( [fileModDate compare:_modDate] == NSOrderedDescending && [fileModDate compare:[NSDate date]] == NSOrderedAscending ) { // newer script file
			[_modDate autorelease];
			_modDate = [[NSDate date] retain];
			[self performSelector:@selector( promptForReload ) withObject:nil afterDelay:0.];
		}
	}
}

#pragma mark -

- (void) idle:(id) sender {
	[_idleTimer invalidate];
	[_idleTimer autorelease];
	_idleTimer = nil;

	NSNumber *newTime = [self callScriptHandler:'iDlX' withArguments:nil forSelector:_cmd];
	if( [newTime isMemberOfClass:[NSError class]] ) return;
	if( ! [newTime isKindOfClass:[NSNumber class]] ) _idleTimer = [[NSTimer scheduledTimerWithTimeInterval:5. target:self selector:_cmd userInfo:nil repeats:NO] retain];
	else _idleTimer = [[NSTimer scheduledTimerWithTimeInterval:[newTime doubleValue] target:self selector:_cmd userInfo:nil repeats:NO] retain];
}

#pragma mark -

- (BOOL) respondsToSelector:(SEL) selector {
	if( ! _script || [_doseNotRespond containsObject:NSStringFromSelector( selector )] ) return NO;
	return [super respondsToSelector:selector];
}

- (void) doesNotRespondToSelector:(SEL) selector {
	[_doseNotRespond addObject:NSStringFromSelector( selector )];
}

#pragma mark -

- (void) load {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[self scriptFilePath], @"lOd1", nil];
	[self callScriptHandler:'lOdX' withArguments:args forSelector:_cmd];
}

- (void) unload {
	[self callScriptHandler:'uldX' withArguments:nil forSelector:_cmd];
}

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psR1", user, @"psR2", [user connection], @"psR3", nil];
	id result = [self callScriptHandler:'psRX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psL1", user, @"psL2", [user connection], @"psL3", nil];
	id result = [self callScriptHandler:'psLX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	[self callScriptHandler:'cTsX' withArguments:args forSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	[self callScriptHandler:'dFsX' withArguments:args forSelector:_cmd];
}

- (IBAction) performContextualMenuItemAction:(id) sender {
	id object = [sender representedObject];
	NSMutableArray *submenu = [NSMutableArray array];
	
	NSMenu *menu = [sender menu];
	NSMenu *parent = nil;
	while( ( parent = [menu supermenu] ) ) {
		[submenu insertObject:[menu title] atIndex:0];
		menu = parent;
	}
	
	NSString *title = [sender title];
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:title, @"----", object, @"pcM1", submenu, @"pcM2", nil];
	[self callScriptHandler:'pcMX' withArguments:args forSelector:_cmd];
}

- (void) buildMenuInto:(NSMutableArray *) itemList fromReturnContainer:(id) container withRepresentedObject:(id) object {
	if( [container respondsToSelector:@selector( objectEnumerator )] ) {
		NSEnumerator *enumerator = [container objectEnumerator];
		id item = nil;
		
		while( ( item = [enumerator nextObject] ) ) {
			if( [item isKindOfClass:[NSString class]] ) {
				if( [item isEqualToString:@"-"] ) {
					[itemList addObject:[NSMenuItem separatorItem]];
				} else {
					NSMenuItem *mitem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( performContextualMenuItemAction: ) keyEquivalent:@""] autorelease];
					[mitem setTarget:self];
					[mitem setRepresentedObject:object];
					[itemList addObject:mitem];
				}
			} else if( [item isKindOfClass:[NSDictionary class]] ) {
				NSString *title = [item objectForKey:@"title"];
				NSArray *sub = [item objectForKey:@"submenu"];
				NSNumber *enabled = [item objectForKey:@"enabled"];
				NSNumber *checked = [item objectForKey:@"checked"];
				NSNumber *indent = [item objectForKey:@"indent"];
				NSNumber *alternate = [item objectForKey:@"alternate"];
				id iconPath = [item objectForKey:@"icon"];
				id iconSize = [item objectForKey:@"iconsize"];
				NSString *tooltip = [item objectForKey:@"tooltip"];
				id context = [item objectForKey:@"context"];
				
				if( ! [title isKindOfClass:[NSString class]] ) continue;
				if( ! [tooltip isKindOfClass:[NSString class]] ) tooltip = nil;
				if( ! [enabled isKindOfClass:[NSNumber class]] ) enabled = nil;
				if( ! [checked isKindOfClass:[NSNumber class]] ) checked = nil;
				if( ! [indent isKindOfClass:[NSNumber class]] ) indent = nil;
				if( ! [alternate isKindOfClass:[NSNumber class]] ) alternate = nil;
				if( ! [iconPath isKindOfClass:[NSString class]] && ! [iconPath isKindOfClass:[NSArray class]] ) iconPath = nil;
				if( ! [iconSize isKindOfClass:[NSArray class]] && ! [iconSize isKindOfClass:[NSNumber class]] ) iconSize = nil;
				if( ! [sub isKindOfClass:[NSArray class]] && ! [sub isKindOfClass:[NSDictionary class]] ) sub = nil;
				
				NSMenuItem *mitem = [[[NSMenuItem alloc] initWithTitle:title action:@selector( performContextualMenuItemAction: ) keyEquivalent:@""] autorelease];
				if( context ) [mitem setRepresentedObject:context];
				else [mitem setRepresentedObject:object];
				if( ! enabled || ( enabled && [enabled boolValue] ) ) [mitem setTarget:self];
				if( enabled && ! [enabled boolValue] ) [mitem setEnabled:[enabled boolValue]];
				if( checked ) [mitem setState:[checked intValue]];
				if( indent ) [mitem setIndentationLevel:MIN( 15, [indent unsignedIntValue] )];
				if( tooltip ) [mitem setToolTip:tooltip];
				
				if( alternate && [alternate unsignedIntValue] == 1 ) {
					[mitem setKeyEquivalentModifierMask:NSAlternateKeyMask];
					[mitem setAlternate:YES];
				} else if( alternate && [alternate unsignedIntValue] == 2 ) {
					[mitem setKeyEquivalentModifierMask:( NSShiftKeyMask | NSAlternateKeyMask )];
					[mitem setAlternate:YES];
				} else if( alternate && [alternate unsignedIntValue] == 3 ) {
					[mitem setKeyEquivalentModifierMask:( NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask )];
					[mitem setAlternate:YES];
				}
				
				if( [iconPath isKindOfClass:[NSString class]] && [(NSString *)iconPath length] ) {
					NSURL *iconURL = nil;
					if( [iconPath hasPrefix:@"#"] ) {
						NSSize size = NSZeroSize;
						if( [iconSize isKindOfClass:[NSArray class]] && [(NSArray *)iconSize count] == 2 ) {
							size = NSMakeSize( [[iconSize objectAtIndex:0] unsignedIntValue], [[iconSize objectAtIndex:1] unsignedIntValue] );
						} else if( [iconSize isKindOfClass:[NSNumber class]] ) {
							size = NSMakeSize( [iconSize unsignedIntValue], [iconSize unsignedIntValue] );
						} else size = NSMakeSize( 24., 12. );
						
						NSColor *color = [NSColor colorWithHTMLAttributeValue:iconPath];
						NSImage *icon = [[[NSImage alloc] initWithSize:size] autorelease];
						
						[icon lockFocus];
						[[color shadowWithLevel:0.1] set];
						[NSBezierPath fillRect:NSMakeRect( 0., 0., size.width, size.height )];
						[color drawSwatchInRect:NSMakeRect( 1., 1., size.width - 2., size.height - 2. )];
						[icon unlockFocus];
						
						[mitem setImage:icon];
					} else if( ( iconURL = [NSURL URLWithString:iconPath] ) ) {
						// NSImage *icon = [[[NSImage allocWithZone:[self zone]] initByReferencingURL:[NSURL URLWithString:iconPath]] autorelease];
						// Lets download the icon with a 1-second timeout
						// Let's also ask for the cache if it exists rather than using protocol default
						NSURLRequest *iconRequest = [NSURLRequest requestWithURL:iconURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1.0];
						NSData *iconData = [NSURLConnection sendSynchronousRequest:iconRequest returningResponse:nil error:nil];
						NSImage *icon = [[[NSImage alloc] initWithData:iconData] autorelease];
						if( icon ) [mitem setImage:icon];
					} else {
						if( ! [iconPath isAbsolutePath] ) {
							NSString *dir = [[self scriptFilePath] stringByDeletingLastPathComponent];
							iconPath = [dir stringByAppendingPathComponent:iconPath];
						}
						
						NSImage *icon = [[[NSImage allocWithZone:[self zone]] initByReferencingFile:iconPath] autorelease];
						if( icon ) [mitem setImage:icon];
					}
					
					NSSize size = NSZeroSize;
					if( [iconSize isKindOfClass:[NSArray class]] && [(NSArray *)iconSize count] == 2 ) {
						size = NSMakeSize( [[iconSize objectAtIndex:0] unsignedIntValue], [[iconSize objectAtIndex:1] unsignedIntValue] );
					} else if( [iconSize isKindOfClass:[NSNumber class]] ) {
						size = NSMakeSize( [iconSize unsignedIntValue], [iconSize unsignedIntValue] );
					}
					
					if( [mitem image] && ! NSEqualSizes( size, NSZeroSize ) ) {
						[[mitem image] setScalesWhenResized:YES];
						[[mitem image] setSize:size];
					}
				} else if( [iconPath isKindOfClass:[NSArray class]] && [(NSArray *)iconPath count] == 3 ) {
					NSSize size = NSZeroSize;
					if( [iconSize isKindOfClass:[NSArray class]] && [(NSArray *)iconSize count] == 2 ) {
						size = NSMakeSize( [[iconSize objectAtIndex:0] unsignedIntValue], [[iconSize objectAtIndex:1] unsignedIntValue] );
					} else if( [iconSize isKindOfClass:[NSNumber class]] ) {
						size = NSMakeSize( [iconSize unsignedIntValue], [iconSize unsignedIntValue] );
					} else size = NSMakeSize( 24., 12. );
					
					NSColor *color = [NSColor colorWithCalibratedRed:( [[iconPath objectAtIndex:0] unsignedIntValue] / 65535. ) green:( [[iconPath objectAtIndex:1] unsignedIntValue] / 65535. ) blue:( [[iconPath objectAtIndex:2] unsignedIntValue] / 65535. ) alpha:1.];
					NSImage *icon = [[[NSImage alloc] initWithSize:size] autorelease];
					
					[icon lockFocus];
					[[color shadowWithLevel:0.1] set];
					[NSBezierPath fillRect:NSMakeRect( 0., 0., size.width, size.height )];
					[color drawSwatchInRect:NSMakeRect( 1., 1., size.width - 2., size.height - 2. )];
					[icon unlockFocus];
					
					[mitem setImage:icon];
				}
				
				[itemList addObject:mitem];
				
				if( [sub respondsToSelector:@selector( objectEnumerator )] && [sub respondsToSelector:@selector( count )] && [sub count] ) {
					NSMenu *submenu = [[[NSMenu allocWithZone:[self zone]] initWithTitle:title] autorelease];
					NSMutableArray *subArray = [NSMutableArray array];
					
					[self buildMenuInto:subArray fromReturnContainer:sub withRepresentedObject:object];
					
					id subItem = nil;
					NSEnumerator *subenumerator = [subArray objectEnumerator];
					while( ( subItem = [subenumerator nextObject] ) )
						[submenu addItem:subItem];
					
					[mitem setSubmenu:submenu];
				}
			}
		}
	}
}

- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:object, @"----", ( view ? (id) view : (id) [NSNull null] ), @"cMi1", nil];
	id result = [self callScriptHandler:'cMiX' withArguments:args forSelector:_cmd];
	NSMutableArray *ret = [NSMutableArray array];

	if( ! result ) return nil;
	if( ! [result isKindOfClass:[NSArray class]] )
		result = [NSArray arrayWithObject:result];

	[self buildMenuInto:ret fromReturnContainer:result withRepresentedObject:object];

	if( [ret count] ) return ret;
	return nil;
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context andPreferences:(NSDictionary *) preferences {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:identifier, @"----", context, @"nOt1", preferences, @"nOt2", nil];
	[self callScriptHandler:'nOtX' withArguments:args forSelector:_cmd];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", [arguments string], @"pcC1", view, @"pcC2", nil];
	id result = [self callScriptHandler:'pcCX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) handleClickedLink:(NSURL *) url inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[url absoluteString], @"----", view, @"hCl1", nil];
	id result = [self callScriptHandler:'hClX' withArguments:args forSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:[message isAction]], @"piM1", [message sender], @"piM2", view, @"piM3", nil];
	[self callScriptHandler:'piMX' withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:[message isAction]], @"poM1", view, @"poM2", nil];
	[self callScriptHandler:'poMX' withArguments:args forSelector:_cmd];
}

/*- (void) userNamed:(NSString *) nickname isNowKnownAs:(NSString *) newNickname inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:nickname, @"----", newNickname, @"uNc1", view, @"uNc2", nil];
	[self callScriptHandler:'uNcX' withArguments:args forSelector:_cmd];
}*/

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mJr1", nil];
	[self callScriptHandler:'mJrX' withArguments:args forSelector:_cmd];
}

- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mPr1", [reason string], @"mPr2", nil];
	[self callScriptHandler:'mPrX' withArguments:args forSelector:_cmd];
}

- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", room, @"mKr1", by, @"mKr2", [reason string], @"mKr3", nil];
	[self callScriptHandler:'mKrX' withArguments:args forSelector:_cmd];
}

- (void) memberPromoted:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:"cOpr" objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	[self callScriptHandler:'mScX' withArguments:args forSelector:_cmd];
}

- (void) memberDemoted:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:( [member voice] ? "VoIc" : "noRm" ) objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	[self callScriptHandler:'mScX' withArguments:args forSelector:_cmd];
}

- (void) memberVoiced:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:"VoIc" objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	[self callScriptHandler:'mScX' withArguments:args forSelector:_cmd];
}

- (void) memberDevoiced:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:member, @"----", [NSValue valueWithBytes:( [member operator] ? "cOpr" : "noRm" ) objCType:@encode( char * )], @"mSc1", by, @"mSc2", room, @"mSc3", nil];
	[self callScriptHandler:'mScX' withArguments:args forSelector:_cmd];
}

- (void) joinedRoom:(JVChatRoomPanel *) room; {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", nil];
	[self callScriptHandler:'jRmX' withArguments:args forSelector:_cmd];
}

- (void) partingFromRoom:(JVChatRoomPanel *) room; {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", nil];
	[self callScriptHandler:'pRmX' withArguments:args forSelector:_cmd];
}

- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:room, @"----", by, @"kRm1", [reason string], @"kRm2", nil];
	[self callScriptHandler:'kRmX' withArguments:args forSelector:_cmd];
}

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[topic string], @"rTc1", member, @"rTc2", room, @"rTc3", nil];
	[self callScriptHandler:'rTcX' withArguments:args forSelector:_cmd];
}
@end