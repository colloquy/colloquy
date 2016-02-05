#import "JVInspectorController.h"

static JVInspectorController *sharedInstance = nil;
static NSPoint inspectorLastPoint = { 100., 800. };
static NSMutableSet *inspectors = nil;

@interface JVInspectorController (Private)
- (void) _loadInspector;
- (void) _resizeWindowForContentSize:(NSSize) size;
- (void) _inspectWindow:(NSWindow *) window;
- (void) _applicationQuitting:(NSNotification *) notification;
@end

#pragma mark -

@implementation JVInspectorController
+ (JVInspectorController *) sharedInspector {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithObject:nil lockedOn:NO] ) );
}

+ (void /*IBAction*/) showInspector:(id) sender {
	[[self sharedInspector] show:sender];
}

- (IBAction) showInspector:(id) sender {
	[[[self class] sharedInspector] show:sender];
}


+ (JVInspectorController *) inspectorOfObject:(id <JVInspection>) object {
	for( JVInspectorController *inspector in inspectors )
		if( [inspector inspectedObject] == object )
			return inspector;

	return [[self alloc] initWithObject:object lockedOn:YES];
}

#pragma mark -

- (instancetype) initWithObject:(id <JVInspection>) object lockedOn:(BOOL) locked {
	NSRect panelRect = NSZeroRect;
	panelRect.origin.x = 200; panelRect.origin.y = NSMaxY( [[NSScreen mainScreen] visibleFrame] ) + 400;
	panelRect.size.width = 175; panelRect.size.height = 200;

	NSWindow *panel = [[NSPanel alloc] initWithContentRect:panelRect styleMask:( ( ! locked ? NSUtilityWindowMask : 0 ) | NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask ) backing:NSBackingStoreBuffered defer:YES];

	if( locked ) {
		[(NSPanel *)panel setFloatingPanel:YES];
		[(NSPanel *)panel setHidesOnDeactivate:YES];
	} else {
		[panel setFrameUsingName:@"inspector"];
		[panel setFrameAutosaveName:@"inspector"];
	}

	if( ( self = [self initWithWindow:panel] ) ) {
		[panel setDelegate:self];
		_self = self;
		_locked = locked;
		_object = object;
		_inspector = [_object inspector];
		if( _locked ) {
			if( ! inspectors ) inspectors = [[NSMutableSet alloc] init];
			[inspectors addObject:self];
		} else [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( keyWindowChanged: ) name:NSWindowDidBecomeKeyNotification object:nil];
		if( _object == nil )
			[self _inspectWindow:[[NSApplication sharedApplication] keyWindow]];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationQuitting: ) name:NSApplicationWillTerminateNotification object:nil];
	return self;
}

- (void) dealloc {
	if( [self isWindowLoaded] )
		[[self window] close];

	if( [_inspector respondsToSelector:@selector( didUnload )] )
		[_inspector didUnload];

	_inspectorLoaded = NO;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	//This will never get called:
	//if( self == sharedInstance ) sharedInstance = nil;
}

#pragma mark -

- (void) windowDidLoad {
	NSWindowCollectionBehavior windowCollectionBehavior = (NSWindowCollectionBehaviorDefault | NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorTransient);
	if( floor( NSAppKitVersionNumber ) >= NSAppKitVersionNumber10_7 )
		windowCollectionBehavior |= NSWindowCollectionBehaviorFullScreenAuxiliary;

	[[self window] setCollectionBehavior:windowCollectionBehavior];
}

#pragma mark -

- (IBAction) show:(id) sender {
	[self _loadInspector];
	if( _locked && ! [[self window] isVisible] )
		inspectorLastPoint = [[self window] cascadeTopLeftFromPoint:inspectorLastPoint];
	[[self window] makeKeyAndOrderFront:nil];
}

- (BOOL) locked {
	return _locked;
}

#pragma mark -

- (void) inspectObject:(id <JVInspection>) object {
	if( object == _object ) return;

	if( [_inspector respondsToSelector:@selector( shouldUnload )] )
		if( ! [_inspector shouldUnload] ) return;

	_object = object;

	id oldInspector = _inspector;
	_inspector = [_object inspector];
	_inspectorLoaded = NO;

	if( [[self window] isVisible] ) {
		if( [oldInspector respondsToSelector:@selector( didUnload )] )
			[oldInspector didUnload];
		[self _loadInspector];
	}
}

#pragma mark -

- (id <JVInspection>) inspectedObject {
	return _object;
}

- (id <JVInspector>) inspector {
	return _inspector;
}

#pragma mark -

- (BOOL) windowShouldClose:(id) sender {
	BOOL should = YES;

	if( [_inspector respondsToSelector:@selector( shouldUnload )] )
		should = [_inspector shouldUnload];

	if( should ) {
		[inspectors removeObject:self];
		if( ! [inspectors count] ) {
			inspectors = nil;
		}

		_self = nil;
	}

	return should;
}

- (void) keyWindowChanged:(NSNotification *) notification {
	if( ! _locked )
		[self _inspectWindow:[notification object]];
}
@end

#pragma mark -

@implementation JVInspectorController (Private)
- (void) _loadInspector {
	NSView *view = [_inspector view];

	if( [_object respondsToSelector:@selector( willBeInspected )] )
		[_object willBeInspected];

	if( [_inspector respondsToSelector:@selector( willLoad )] )
		[_inspector willLoad];

	if( view && _inspector ) {
		NSRect windowFrame = [[[self window] contentView] frame];
		NSSize minSize = [_inspector minSize];
		if( NSWidth( windowFrame ) < minSize.width || NSHeight( windowFrame ) < minSize.height ) {
			NSSize newSize = windowFrame.size;
			if( NSWidth( windowFrame ) < minSize.width ) newSize.width = minSize.width;
			if( NSHeight( windowFrame ) < minSize.height ) newSize.height = minSize.height;
			[self _resizeWindowForContentSize:newSize];
		}
		[[self window] setTitle:[_inspector title]];
		[[self window] setMinSize:[NSWindow frameRectForContentRect:NSMakeRect( 0., 0., minSize.width, minSize.height) styleMask:[[self window] styleMask]].size];
		[[self window] setContentView:view];

		if( [_inspector respondsToSelector:@selector( didLoad )] )
			[_inspector didLoad];
		_inspectorLoaded = YES;
	} else {
		[[self window] setTitle:NSLocalizedString( @"No Info", "no info inspector title" )];
		[[self window] setContentView:[[NSView alloc] initWithFrame:[[[self window] contentView] frame]]];
	}
}

- (void) _resizeWindowForContentSize:(NSSize) size {
	NSRect windowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
	NSRect newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect( NSMinX( windowFrame ), NSMaxY( windowFrame ) - size.height, size.width, size.height ) styleMask:[[self window] styleMask]];
	[[self window] setFrame:newWindowFrame display:YES animate:[[self window] isVisible]];
}

- (void) _inspectWindow:(NSWindow *) window {
	if( [[window delegate] conformsToProtocol:@protocol( JVInspectionDelegator )] ) {
		id obj = [[window delegate] performSelector:@selector(objectToInspect)];
		if( obj != _object ) [self inspectObject:obj];
	}
}

- (void) _applicationQuitting:(NSNotification *) notification {
	if( _inspectorLoaded && [_inspector respondsToSelector:@selector( didUnload )] )
		[_inspector didUnload];
}
@end
