#import "JVInspectorController.h"
#import <Cocoa/Cocoa.h>
#import "MVApplicationController.h"

static JVInspectorController *sharedInstance = nil;
static NSPoint inspectorLastPoint = { 100., 800. };

@interface JVInspectorController (JVInspectionControllerPrivate)
- (void) _loadInspector;
- (void) _resizeWindowForContentSize:(NSSize) size;
@end

#pragma mark -

@implementation JVInspectorController
+ (JVInspectorController *) sharedInspector {
	extern JVInspectorController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithObject:nil lockedOn:NO] ) );
}

+ (JVInspectorController *) inspectorOfObject:(id <JVInspection>) object {
	return [[self alloc] initWithObject:object lockedOn:YES];
}

#pragma mark -

- (id) initWithObject:(id <JVInspection>) object lockedOn:(BOOL) locked {
	NSWindow *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect( 20., 20., 175., 200. ) styleMask:( ( ! locked ? NSUtilityWindowMask : 0 ) | NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask ) backing:NSBackingStoreBuffered defer:YES] autorelease];
	[panel setDelegate:self];
	if( locked ) {
		[(NSPanel *)panel setFloatingPanel:YES];
		[(NSPanel *)panel setHidesOnDeactivate:YES];
	}
	if( ( self = [self initWithWindow:panel] ) ) {
		_locked = locked;
		_object = [object retain];
		_inspector = [[_object inspector] retain];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( keyWindowChanged: ) name:NSWindowDidBecomeKeyNotification object:nil];
	}
	return self;
}

- (void) dealloc {
	extern JVInspectorController *sharedInstance;

	[[self window] close];

	if( [_inspector respondsToSelector:@selector( didUnload )] )
		[(NSObject *)_inspector didUnload];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_object release];
	[_inspector release];

	_object = nil;
	_inspector = nil;

	[super dealloc];
}

#pragma mark -

- (IBAction) show:(id) sender {
	extern NSPoint inspectorLastPoint;
	[self _loadInspector];
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
		if( ! [(NSObject *)_inspector shouldUnload] ) return;

	[_object autorelease];
	_object = [object retain];

	id oldInspector = _inspector;
	[_inspector autorelease];
	_inspector = [[_object inspector] retain];

	if( [[self window] isVisible] ) {
		if( [oldInspector respondsToSelector:@selector( didUnload )] )
			[(NSObject *)oldInspector didUnload];

		[self _loadInspector];
	}
}

#pragma mark -

- (id <JVInspection>) inspectedObject {
	return [[_object retain] autorelease];
}

- (id <JVInspector>) inspector {
	return [[_inspector retain] autorelease];
}

#pragma mark -

- (BOOL) windowShouldClose:(id) sender {
	BOOL should = YES;

	if( [_inspector respondsToSelector:@selector( shouldUnload )] )
		should = [(NSObject *)_inspector shouldUnload];

	if( should ) [self autorelease];
	return should;
}

- (void) keyWindowChanged:(NSNotification *) notification {
	if( ! _locked && [[[notification object] delegate] conformsToProtocol:@protocol( JVInspectionDelegator )] ) {
		id obj = [[[notification object] delegate] objectToInspect];
		if( obj != _object ) [self inspectObject:obj];
	}
}
@end

#pragma mark -

@implementation JVInspectorController (JVInspectionControllerPrivate)
- (void) _loadInspector {
	NSView *view = [_inspector view];

	if( [_object respondsToSelector:@selector( willBeInspected )] )
		[(NSObject *)_object willBeInspected];

	if( [_inspector respondsToSelector:@selector( willLoad )] )
		[(NSObject *)_inspector willLoad];

	if( view && _inspector ) {
		NSRect windowFrame = [[[self window] contentView] frame];
		NSSize minSize = [_inspector minSize];
		if( NSWidth( windowFrame ) < minSize.width || NSHeight( windowFrame ) < minSize.height ) {
			NSSize newSize = windowFrame.size;
			if( NSWidth( windowFrame ) < minSize.width ) newSize.width = minSize.width;
			if( NSHeight( windowFrame ) < minSize.height ) newSize.height = minSize.height;
			[self _resizeWindowForContentSize:newSize];
		}
		[[self window] setTitle:[NSString stringWithFormat:NSLocalizedString( @"%@ \"%@\" Info", "inspector title format order: object type, object title/name" ), [_inspector type], [_inspector title]]];
		[[self window] setMinSize:[NSWindow frameRectForContentRect:NSMakeRect( 0., 0., minSize.width, minSize.height) styleMask:[[self window] styleMask]].size];
		[[self window] setContentView:view];

		if( [_inspector respondsToSelector:@selector( didLoad )] )
			[(NSObject *)_inspector didLoad];
	} else {
		[[self window] setTitle:NSLocalizedString( @"No Info", "no info inspector title" )];
		[[self window] setContentView:[[[NSView alloc] initWithFrame:[[[self window] contentView] frame]] autorelease]];
	}
}

- (void) _resizeWindowForContentSize:(NSSize) size {
	NSRect windowFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
	NSRect newWindowFrame = [NSWindow frameRectForContentRect:NSMakeRect( NSMinX( windowFrame ), NSMaxY( windowFrame ) - size.height, size.width, size.height ) styleMask:[[self window] styleMask]];
	[[self window] setFrame:newWindowFrame display:YES animate:[[self window] isVisible]];
}
@end