#import <Cocoa/Cocoa.h>
#import "MVStatusView.h"

NSString *MVStatusViewWillStartScrollingNotification = @"MVStatusViewWillStartScrollingNotification";
NSString *MVStatusViewDidStopScrollingNotification = @"MVStatusViewDidStopScrollingNotification";

@interface MVStatusView (MVStatusViewPrivate)
- (void) _pauseVerticalScrollFor:(NSTimeInterval) delay;
- (void) _restartVerticalScroll;
- (NSSize) _sizeOfString:(id) string;
- (void) _drawString:(id) drawString atPoint:(NSPoint) point withAttributes:(NSDictionary *) attributes;
@end

@implementation MVStatusView
- (id) initWithFrame:(NSRect) frame {
	if( ( self = [super initWithFrame:frame] ) ) {
		currentMessage = nil;
		cycledMessages = nil;
		updateTimer = nil;
		delayTimer = nil;
		waitingMessages = [[NSMutableArray array] retain];
		foregroundColor = [[NSColor blackColor] retain];
		defaultFont = [[NSFont labelFontOfSize:10.] retain];
		cycleDelay = 18.;
		x = 4.;
		y = -NSHeight([self bounds]);
		i = 0;
	}
	return self;
}

- (void) dealloc {
	[updateTimer invalidate];
	[updateTimer autorelease];
	[delayTimer invalidate];
	[delayTimer autorelease];
	[currentMessage autorelease];
	[waitingMessage autorelease];
	[waitingMessages autorelease];
	[cycledMessages autorelease];
	[self setDefaultFont:nil];
	[self setForegroundColor:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	updateTimer = nil;
	delayTimer = nil;
	currentMessage = nil;
	waitingMessage = nil;
	waitingMessages = nil;
	cycledMessages = nil;
	[super dealloc];
}

- (void) drawRect:(NSRect) rect {
	NSDictionary *attrib = nil;
	NSSize size;

	if( ! currentMessage ) return;
	size = [self _sizeOfString:currentMessage];
	attrib = [NSDictionary dictionaryWithObjectsAndKeys:defaultFont,NSFontAttributeName,foregroundColor,NSForegroundColorAttributeName,nil];

	if( oneStep && ! verticalPause && ! dontPause && y >= ( ( NSHeight([self bounds]) / 2 ) - ( size.height / 2 ) ) && y < ( ( NSHeight([self frame]) / 2 ) - ( size.height / 2 ) ) + 1. )
		[self _pauseVerticalScrollFor:cycleDelay * ( size.width / NSWidth([self bounds]) )];
	else if( oneStep && y >= ( ( NSHeight([self bounds]) / 2 ) - ( size.height / 2 ) ) && y < ( ( NSHeight([self frame]) / 2 ) - ( size.height / 2 ) ) + 1. )
		dontPause = NO;

	if( oneStep && ( ! verticalPause || dontPause ) ) y += 1.;
	if( oneStep && verticalPause && size.width >= NSWidth([self bounds]) ) x -= 1.;
	[self _drawString:currentMessage atPoint:NSMakePoint(x, y) withAttributes:attrib];
	if( size.width >= NSWidth([self bounds]) && ( x + size.width + 30. ) <= NSWidth([self bounds]) )
		[self _drawString:currentMessage atPoint:NSMakePoint(x + size.width + 30., y) withAttributes:attrib];
	if( oneStep && ( x + size.width + 30. ) >= -1. && ( x + size.width + 30. ) < 0. )
		x = ( x + size.width + 30. );

	if( ( ! verticalPause || dontPause ) && y > ( ( NSHeight([self bounds]) / 2 ) - ( size.height / 2 ) ) ) {
		static double tansY = 0., tansX = 0.;
		static unsigned tansI = 0;
		if( oneStep && ! waitingMessage ) {
			if( [waitingMessages count] ) {
				waitingMessage = [[waitingMessages objectAtIndex:0] retain];
				[waitingMessages removeObjectAtIndex:0];
				if( ! [waitingMessages count] ) dontPause = NO;
				else dontPause = YES;
			} else if( [cycledMessages count] ) {
				dontPause = NO;
				tansI = ( [cycledMessages count] > i + 1 ? ++i : 0 );
				waitingMessage = [[cycledMessages objectAtIndex:tansI] retain];
			} else {
				// should never happen. if it does fix it semi-cleanly
				waitingMessage = nil;
				dontPause = NO;
				verticalPause = YES;
				y -= 1.;
				[self setNeedsDisplay:YES];
			}
		}
		if( waitingMessage ) {
			size = [self _sizeOfString:waitingMessage];
			if( ! tansY ) tansY = -NSHeight([self bounds]);
			if( ! tansX ) tansX = ( size.width >= NSWidth([self bounds]) ? 4. : ( NSWidth([self bounds]) / 2. ) - ( size.width / 2. ) );
			if( oneStep ) tansY += 1.;
			[self _drawString:waitingMessage atPoint:NSMakePoint(tansX, tansY) withAttributes:attrib];
			if( oneStep && y >= NSHeight([self bounds]) ) {
				y = tansY;
				x = tansX;
				i = tansI;
				tansY = 0.;
				tansX = 0.;
				[currentMessage autorelease];
				currentMessage = [waitingMessage retain];
				[waitingMessage autorelease];
				waitingMessage = nil;
			}
		}
	}
	oneStep = NO;
}

- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return NO;
}

- (void) startUpdatingAtInterval:(NSTimeInterval) interval {
	[updateTimer invalidate];
	[updateTimer autorelease];
	updateInterval = interval;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVStatusViewWillStartScrollingNotification object:self];
	updateTimer = [[NSTimer scheduledTimerWithTimeInterval:updateInterval target:self selector:@selector( step: ) userInfo:nil repeats:YES] retain];
	[self setNeedsDisplay:YES];
}

- (IBAction) stopUpdate:(id) sender {
	[updateTimer invalidate];
	[updateTimer autorelease];
	updateTimer = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVStatusViewDidStopScrollingNotification object:self];
	[self setNeedsDisplay:YES];
}

- (void) step:(id) sender {
	if( ! verticalPause || [self _sizeOfString:currentMessage].width > NSWidth([self bounds]) ) {
		oneStep = YES;
		[self setNeedsDisplay:YES];
	}
}

- (IBAction) next:(id) sender {
	dontPause = YES;
	[self _restartVerticalScroll];
}

- (void) setCurrentMessage:(id) newMessage {
	if( ! currentMessage ) {
		NSSize size;
		[currentMessage autorelease];
		currentMessage = [newMessage copy];
		size = [self _sizeOfString:currentMessage];
		x = ( size.width >= NSWidth([self bounds]) ? 4. : ( NSWidth([self bounds]) / 2. ) - ( size.width / 2. ) );
		y = -NSHeight([self frame]);
		dontPause = NO;
	} else if( ! waitingMessage && ! [waitingMessages count] ) {
		waitingMessage = [newMessage copy];
		dontPause = YES;
	} else {
		[waitingMessages addObject:newMessage];
		dontPause = YES;
	}
	[self _restartVerticalScroll];
}

- (id) currentMessage {
	return [[currentMessage retain] autorelease];	
}

- (void) setCycleDelay:(NSTimeInterval) delay {
	cycleDelay = delay;
}

- (NSTimeInterval) cycleDelay {
	return cycleDelay;
}

- (void) setCycledMessages:(id) newCycle withContinuedPosition:(BOOL) cont {
	[cycledMessages autorelease];
	cycledMessages = [newCycle copy];
	if( ! cont ) i = 0;
	if( ! currentMessage ) {
		NSSize size;
		[currentMessage autorelease];
		currentMessage = [[cycledMessages objectAtIndex:i] retain];
		size = [self _sizeOfString:currentMessage];
		x = ( size.width >= NSWidth([self bounds]) ? 4. : ( NSWidth([self bounds]) / 2. ) - ( size.width / 2. ) );
		y = -NSHeight([self frame]);
	} else if( ! waitingMessage ) {
		waitingMessage = [[cycledMessages objectAtIndex:i] retain];
	} else {
		[waitingMessages addObject:[cycledMessages objectAtIndex:i]];
	}
}

- (NSArray *) cycledMessages {
	return [[cycledMessages retain] autorelease];	
}

- (void) setDefaultFont:(id) newFont {
	[defaultFont autorelease];
	defaultFont = [newFont copy];
}

- (NSFont *) defaultFont {
	return [[defaultFont retain] autorelease];	
}

- (void) setForegroundColor:(id) color {
	[foregroundColor autorelease];
	foregroundColor = [color copy];
}

- (NSColor *) foregroundColor {
	return [[foregroundColor retain] autorelease];	
}
@end

@implementation MVStatusView (MVStatusViewPrivate)
- (void) _pauseVerticalScrollFor:(NSTimeInterval) delay {
	[delayTimer invalidate];
	[delayTimer autorelease];
	delayTimer = [[NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector( _restartVerticalScroll ) userInfo:nil repeats:NO] retain];
	verticalPause = YES;
}

- (void) _restartVerticalScroll {
	if( ( [cycledMessages count] || [waitingMessages count] || waitingMessage ) && currentMessage ) {
		verticalPause = NO;
		[delayTimer invalidate];
		[delayTimer autorelease];
		delayTimer = nil;
	}
}

- (NSSize) _sizeOfString:(id) string {
	NSDictionary *attrib = nil;
	if( [string isKindOfClass:[NSString class]] ) {
		attrib = [NSDictionary dictionaryWithObjectsAndKeys:defaultFont,NSFontAttributeName,foregroundColor,NSForegroundColorAttributeName,nil];
		return [string sizeWithAttributes:attrib];
	} else if( [string isKindOfClass:[NSAttributedString class]] ) {
		return [string size];
	} else return NSZeroSize;
}

- (void) _drawString:(id) drawString atPoint:(NSPoint) point withAttributes:(NSDictionary *) attributes {
	if( [drawString isKindOfClass:[NSString class]] ) {
		[(NSString *)drawString drawAtPoint:point withAttributes:attributes];
	} else if( [drawString isKindOfClass:[NSAttributedString class]] ) {
		[(NSAttributedString *)drawString drawAtPoint:point];
	}
}
@end
