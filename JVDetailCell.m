#import <Cocoa/Cocoa.h>
#import "JVDetailCell.h"

@implementation JVDetailCell
- (id) init {
	self = [super init];

	_altImage = nil;
	_mainText = nil;
	_infoText = nil;

	[self setImageAlignment:NSImageAlignLeft];
	[self setImageScaling:NSScaleProportionally];
	[self setImageFrameStyle:NSImageFrameNone];

	return self;
}

- (id) copyWithZone:(NSZone *) zone {
	JVDetailCell *cell = (JVDetailCell *)[super copyWithZone:zone];
	cell -> _altImage = [_altImage retain];
	cell -> _mainText = [_mainText copy];
	cell -> _infoText = [_infoText copy];
	return cell;
}

- (void) dealloc {
	[self setAlternateImage:nil];
	[self setMainText:nil];
	[self setInformationText:nil];

	[super dealloc];
}

#pragma mark -

- (void) setAlternateImage:(NSImage *) image {
	[_altImage autorelease];
	_altImage = [image retain];
}

- (NSImage *) alternateImage {
	return [[_altImage retain] autorelease];
}

#pragma mark -

- (void) setMainText:(NSString *) text {
	[_mainText autorelease];
	_mainText = [text copy];
}

- (NSString *) mainText {
	return [[_mainText retain] autorelease];
}

#pragma mark -

- (void) setInformationText:(NSString *) text {
	[_infoText autorelease];
	_infoText = [text copy];
}

- (NSString *) informationText {
	return [[_infoText retain] autorelease];
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	float imageWidth = 0.;
	BOOL highlighted = ( [self isHighlighted] && [[controlView window] firstResponder] == controlView && [[NSApplication sharedApplication] isActive] );
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont toolTipsFontOfSize:11.], NSFontAttributeName, ( highlighted ? [NSColor alternateSelectedControlTextColor] : [NSColor controlTextColor] ), NSForegroundColorAttributeName, nil];
	NSImage *mainImage = nil;

	if( highlighted && _altImage ) {
		mainImage = [[self image] retain];
		[self setImage:_altImage];
	}

	[super drawWithFrame:cellFrame inView:controlView];

	if( highlighted && mainImage ) {
		[self setImage:mainImage];
		[mainImage autorelease];
	}

	switch( [self imageScaling] ) {
	case NSScaleProportionally:
		if( NSHeight( cellFrame ) < [[self image] size].height )
			imageWidth = ( NSHeight( cellFrame ) / [[self image] size].height ) * [[self image] size].width;
		else imageWidth = [[self image] size].width;
		break;
	default:
	case NSScaleNone:
		imageWidth = [[self image] size].width;
		break;
	case NSScaleToFit:
		imageWidth = 0.;
		break;
	}

#define JVDetailCellImageLabelPadding 5.

	if( ! [_infoText length] && [_mainText length] ) {
		float mainYLocation = 0.;
		NSSize mainStringSize = [_mainText sizeWithAttributes:attributes];

		if( NSHeight( cellFrame ) >= mainStringSize.height ) {
			mainYLocation = cellFrame.origin.y + ( NSHeight( cellFrame ) / 2 ) - ( mainStringSize.height / 2 );
			[_mainText drawAtPoint:NSMakePoint( cellFrame.origin.x + imageWidth + JVDetailCellImageLabelPadding, mainYLocation ) withAttributes:attributes];
		}
	} else if( [_infoText length] && [_mainText length] ) {
		float mainYLocation = 0., subYLocation = 0.;
		NSDictionary *subAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont toolTipsFontOfSize:9.], NSFontAttributeName, ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.75] ), NSForegroundColorAttributeName, nil];
		NSSize mainStringSize = [_mainText sizeWithAttributes:attributes];
		NSSize subStringSize = [_infoText sizeWithAttributes:subAttributes];

		if( NSHeight( cellFrame ) >= mainStringSize.height ) {
			mainYLocation = cellFrame.origin.y + ( NSHeight( cellFrame ) / 2 ) - mainStringSize.height + 1.;
			[_mainText drawAtPoint:NSMakePoint( cellFrame.origin.x + imageWidth + JVDetailCellImageLabelPadding, mainYLocation ) withAttributes:attributes];

			subYLocation = cellFrame.origin.y + ( NSHeight( cellFrame ) / 2 ) + subStringSize.height - mainStringSize.height + 1.;
			[_infoText drawAtPoint:NSMakePoint( cellFrame.origin.x + imageWidth + JVDetailCellImageLabelPadding, subYLocation ) withAttributes:subAttributes];
		}
	}
}

#pragma mark -

- (void) setImageScaling:(NSImageScaling) newScaling {
	[super setImageScaling:( newScaling == NSScaleProportionally || newScaling == NSScaleNone ? newScaling : NSScaleProportionally )];
}

- (void) setImageAlignment:(NSImageAlignment) newAlign {
	[super setImageAlignment:NSImageAlignLeft];
}
@end
