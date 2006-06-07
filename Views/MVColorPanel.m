#import "MVColorPanel.h"

@interface NSColorPanel (NSColorPanelPrivate)
- (void) _forceSendAction:(BOOL) action notification:(BOOL) notification firstResponder:(BOOL) firstResponder;
- (void) _sendActionAndNotification;
@end

#pragma mark -

@interface MVColorPanel (MVColorPanelPrivate)
- (NSView *) _makeAccessoryView;
@end

#pragma mark -

@implementation MVColorPanel
- (id) init {
	if( ( self = [super init] ) )
		[self setAccessoryView:[self _makeAccessoryView]];
	return self;
}

- (void) dealloc {
	[destination release];
	destination = nil;
	[super dealloc];
}

- (void) _forceSendAction:(BOOL) action notification:(BOOL) notification firstResponder:(BOOL) firstResponder {
	[super _forceSendAction:action notification:notification firstResponder:NO];

	if( firstResponder ) {
		NSResponder *responder = [[[NSApplication sharedApplication] keyWindow] firstResponder];
		if( [[destination selectedCell] tag] == 1 ) {
			while( responder && ! [responder respondsToSelector:@selector( changeColor: )] )
				responder = [responder nextResponder];
			[responder changeColor:self];
		} else if( [[destination selectedCell] tag] == 2 ) {
			while( responder && ! [responder respondsToSelector:@selector( changeBackgroundColor: )] )
				responder = [responder nextResponder];
			[responder changeBackgroundColor:self];
		}
	}
}
@end

#pragma mark -

@implementation MVColorPanel (MVColorPanelPrivate)
- (NSView *) _makeAccessoryView {
	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect( 0., 0., NSWidth( [self frame] ) - 10., 36. )];
	NSButtonCell *cell = [[NSButtonCell alloc] init];

	[cell setButtonType:NSRadioButton];
	[cell setControlSize:NSSmallControlSize];

	destination = [[NSMatrix alloc] initWithFrame:NSMakeRect( 0., 0., NSWidth( [self frame] ) - 10., 36. ) mode:NSRadioModeMatrix prototype:cell numberOfRows:2 numberOfColumns:1];
	[destination setAllowsEmptySelection:NO];
	[destination setAutosizesCells:YES];
	[destination setState:NSOnState atRow:0 column:0];

	[cell release]; // release the prototype cell

	cell = [destination cellAtRow:0 column:0];
	[cell setTitle:NSLocalizedString( @"Foreground Color", "color panel Foreground Color button" )];
	[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[cell setTag:1];

	cell = [destination cellAtRow:1 column:0];
	[cell setTitle:NSLocalizedString( @"Background Color", "color panel Background Color button" )];
	[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[cell setTag:2];

	[destination setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];
	[view addSubview:destination];
	[destination setBoundsOrigin:NSZeroPoint];

	return [view autorelease];
}
@end