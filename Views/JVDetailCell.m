#import "JVDetailCell.h"
#import "NSImageAdditions.h"

@implementation JVDetailCell
- (id) init {
	if( ( self = [super init] ) ) {
		_altImage = nil;
		_statusImage = nil;
		_mainText = nil;
		_infoText = nil;
		_leftMargin = 0.;

		[self setImageAlignment:NSImageAlignLeft];
		[self setImageScaling:NSScaleProportionally];
		[self setImageFrameStyle:NSImageFrameNone];
		[self setLineBreakMode:NSLineBreakByTruncatingTail];
	}

	return self;
}

- (id) copyWithZone:(NSZone *) zone {
	JVDetailCell *cell = (JVDetailCell *)[super copyWithZone:zone];
	cell -> _statusImage = _statusImage;
	cell -> _altImage = _altImage;
	cell -> _mainText = [_mainText copyWithZone:zone];
	cell -> _infoText = [_infoText copyWithZone:zone];
	cell -> _lineBreakMode = _lineBreakMode;
	cell -> _leftMargin = _leftMargin;
	return cell;
}

- (void) dealloc {

	_altImage = nil;
	_statusImage = nil;
	_mainText = nil;
	_infoText = nil;

}

#pragma mark -

- (void) setStatusImage:(NSImage *) image {
	_statusImage = image;
}

- (NSImage *) statusImage {
	return _statusImage;
}

#pragma mark -

- (void) setStatusNumber:(NSUInteger) number {
	_statusNumber = number;
}

- (NSUInteger) statusNumber {
	return _statusNumber;
}

#pragma mark -

- (void) setImportantStatusNumber:(NSUInteger) number {
	_importantStatusNumber = number;
}

- (NSUInteger) importantStatusNumber {
	return _importantStatusNumber;
}

#pragma mark -

- (void) setHighlightedImage:(NSImage *) image {
	_altImage = image;
}

- (NSImage *) highlightedImage {
	return _altImage;
}

#pragma mark -

- (void) setMainText:(NSString *) text {
	_mainText = [text copy];
}

- (NSString *) mainText {
	return _mainText;
}

#pragma mark -

- (void) setInformationText:(NSString *) text {
	_infoText = [text copy];
}

- (NSString *) informationText {
	return _infoText;
}

#pragma mark -

- (void) setBoldAndWhiteOnHighlight:(BOOL) boldAndWhite {
	_boldAndWhiteOnHighlight = boldAndWhite;
}

- (BOOL) boldAndWhiteOnHighlight {
	return _boldAndWhiteOnHighlight;
}

#pragma mark -

- (void) setLeftMargin:(CGFloat) margin {
	_leftMargin = margin;
}

- (CGFloat) leftMargin {
	return _leftMargin;
}

#pragma mark -

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	float imageWidth = 0.;
	BOOL highlighted = ( [self isHighlighted] && [[controlView window] firstResponder] == controlView && [[controlView window] isKeyWindow] && [[NSApplication sharedApplication] isActive] );

	NSMutableParagraphStyle *paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paraStyle setLineBreakMode:_lineBreakMode];
	[paraStyle setAlignment:[self alignment]];

	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[self font], NSFontAttributeName, paraStyle, NSParagraphStyleAttributeName, ( [self isEnabled] ? ( highlighted ? [NSColor alternateSelectedControlTextColor] : [NSColor controlTextColor] ) : ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.50] ) ), NSForegroundColorAttributeName, nil];
	NSMutableDictionary *subAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSFont toolTipsFontOfSize:9.], NSFontAttributeName, paraStyle, NSParagraphStyleAttributeName, ( [self isEnabled] ? ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.75] ) : ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.40] ) ), NSForegroundColorAttributeName, nil];
	NSImage *mainImage = nil, *curImage = nil;
	NSSize mainStringSize = [_mainText sizeWithAttributes:attributes];
	NSSize subStringSize = [_infoText sizeWithAttributes:subAttributes];

	if( _boldAndWhiteOnHighlight && [self isHighlighted] ) {
		NSFont *boldFont = [[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:15 size:11.];
		NSShadow *shadow = [[NSShadow allocWithZone:nil] init];
		NSColor *whiteColor = [NSColor whiteColor];
		if( ! [self isEnabled] ) whiteColor = [whiteColor colorWithAlphaComponent:0.5];

        [shadow setShadowOffset:NSMakeSize( 0, -1 )];
		[shadow setShadowBlurRadius:0.1];
		[shadow setShadowColor:[[NSColor shadowColor] colorWithAlphaComponent:0.2]];

		[attributes setObject:boldFont forKey:NSFontAttributeName];
		[attributes setObject:whiteColor forKey:NSForegroundColorAttributeName];
		[attributes setObject:shadow forKey:NSShadowAttributeName];

		boldFont = [[NSFontManager sharedFontManager] fontWithFamily:@"Lucida Grande" traits:0 weight:15 size:9.];
		[subAttributes setObject:boldFont forKey:NSFontAttributeName];
		[subAttributes setObject:whiteColor forKey:NSForegroundColorAttributeName];
		[subAttributes setObject:shadow forKey:NSShadowAttributeName];
	}

	if( highlighted && _altImage ) {
		mainImage = [self image];
		[self setImage:_altImage];
	}

	if( ! [self isEnabled] && [self image] ) {
		NSImage *fadedImage = [[NSImage alloc] initWithSize:[[self image] size]];
		[fadedImage lockFocus];
		[[self image] cq_dissolveToPoint:NSMakePoint( 0., 0. ) fraction:0.5];
		[fadedImage unlockFocus];
		curImage = [self image]; // curImage is autoreleased 9 lines down, analyzer is just confused by the ifs
		[self setImage:fadedImage];
	}

	cellFrame = NSMakeRect( cellFrame.origin.x + 1. + _leftMargin, cellFrame.origin.y, cellFrame.size.width - 1. - _leftMargin, cellFrame.size.height );
	[super drawWithFrame:cellFrame inView:controlView];

	if( ! [self isEnabled] ) {
		[self setImage:curImage];
	}

	if( highlighted && mainImage ) {
		[self setImage:mainImage];
	}

	if( [self image] ) {
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
			imageWidth = [[self image] size].width;
			break;
		}
	}

#define JVDetailCellLabelPadding 3.
#define JVDetailCellImageLabelPadding 5.
#define JVDetailCellTextLeading 3.
#define JVDetailCellStatusImageLeftPadding 2.
#define JVDetailCellStatusImageRightPadding JVDetailCellStatusImageLeftPadding

	float statusWidth = ( _statusImage ? [_statusImage size].width + JVDetailCellStatusImageRightPadding : 0. );
	if( ! _statusImage && ( _statusNumber || _importantStatusNumber ) ) {
		NSColor *textColor = [NSColor whiteColor];
		NSColor *backgroundColor = [NSColor colorWithCalibratedRed:0.6 green:0.6705882352941176 blue:0.7725490196078431 alpha:1.];
		NSColor *importantColor = [NSColor colorWithCalibratedRed:0.831372549019608 green:0.572549019607843 blue:0.541176470588235 alpha:1.];

		if( ! _statusNumber && _importantStatusNumber )
			backgroundColor = importantColor;

		if( [self isHighlighted] ) {
			textColor = [backgroundColor shadowWithLevel:0.2];
			backgroundColor = [backgroundColor highlightWithLevel:0.7];
		}

		NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSBoldFontMask weight:9 size:11.];
		NSMutableParagraphStyle *numberParaStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[numberParaStyle setAlignment:NSCenterTextAlignment];

		NSDictionary *statusNumberAttributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, numberParaStyle, NSParagraphStyleAttributeName, textColor, NSForegroundColorAttributeName, [NSNumber numberWithFloat:1.0], NSKernAttributeName, nil];

		NSString *statusText = [NSString stringWithFormat:@"%ld", ( _statusNumber ? _statusNumber : _importantStatusNumber )];
		NSSize numberSize = [statusText sizeWithAttributes:statusNumberAttributes];
		statusWidth = numberSize.width + 12.;

		if( imageWidth + ( imageWidth ? JVDetailCellImageLabelPadding : JVDetailCellLabelPadding ) + statusWidth < NSWidth( cellFrame ) ) {
			float radius = ( _importantStatusNumber ? 8. : 7. );
			NSRect mainRect = NSMakeRect( NSMinX( cellFrame ) + NSWidth( cellFrame ) - statusWidth - 2., NSMinY( cellFrame ) + ( ( NSHeight( cellFrame ) / 2 ) - radius ), statusWidth, radius * 2 );
			NSRect pathRect = NSInsetRect( mainRect, radius, radius );

			NSBezierPath *mainPath = [NSBezierPath bezierPath];
			[mainPath appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( pathRect ), NSMinY( pathRect ) ) radius:radius startAngle:180. endAngle:270.];
			[mainPath appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( pathRect ), NSMinY( pathRect ) ) radius:radius startAngle:270. endAngle:360.];
			[mainPath appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( pathRect ), NSMaxY( pathRect ) ) radius:radius startAngle:0. endAngle:90.];
			[mainPath appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( pathRect ), NSMaxY( pathRect ) ) radius:radius startAngle:90. endAngle:180.];
			[mainPath closePath];

			if( _importantStatusNumber ) {
				NSString *importantStatusText = [NSString stringWithFormat:@"%ld", _importantStatusNumber];
				numberSize = [importantStatusText sizeWithAttributes:statusNumberAttributes];
				float mainStatusWidth = statusWidth;
				statusWidth += numberSize.width + 10.;
				radius = 7.;

				NSRect rect = NSMakeRect( NSMinX( cellFrame ) + NSWidth( cellFrame ) - statusWidth - 2., NSMinY( cellFrame ) + ( ( NSHeight( cellFrame ) / 2 ) - radius ), statusWidth - mainStatusWidth + 10., radius * 2 );
				pathRect = NSInsetRect( rect, radius, radius );

				NSBezierPath *path = [NSBezierPath bezierPath];
				[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( pathRect ), NSMinY( pathRect ) ) radius:radius startAngle:180. endAngle:270.];
				[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( pathRect ), NSMinY( pathRect ) ) radius:radius startAngle:270. endAngle:360.];
				[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( pathRect ), NSMaxY( pathRect ) ) radius:radius startAngle:0. endAngle:90.];
				[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( pathRect ), NSMaxY( pathRect ) ) radius:radius startAngle:90. endAngle:180.];
				[path closePath];

				if( [self isHighlighted] ) [[NSColor whiteColor] set];
				else [[NSColor colorWithCalibratedRed:0.92156862745098 green:0.231372549019608 blue:0.243137254901961 alpha:0.85] set];
				[path fill];

				rect.origin.x -= 3.;
				[importantStatusText drawInRect:rect withAttributes:statusNumberAttributes];
			}

			[backgroundColor set];
			[mainPath fill];

			if( _importantStatusNumber ) {
				if( [self isHighlighted] ) [[NSColor colorWithCalibratedRed:0.5803921568627451 green:0.6705882352941176 blue:0.7882352941176471 alpha:1.] set];
				else [[NSColor whiteColor] set];

				[mainPath setLineWidth:1.25];
				[mainPath stroke];
			}

			if( _importantStatusNumber ) mainRect.origin.y += 1.;
			[statusText drawInRect:mainRect withAttributes:statusNumberAttributes];

			statusWidth += JVDetailCellStatusImageRightPadding + 3.;

		} else statusWidth = 0.;
	}

	if( ( ! [_infoText length] && [_mainText length] ) || ( ( subStringSize.height + mainStringSize.height ) >= NSHeight( cellFrame ) - 2. ) ) {
		float mainYLocation = 0.;

		if( NSHeight( cellFrame ) >= mainStringSize.height ) {
			mainYLocation = NSMinY( cellFrame ) + ( NSHeight( cellFrame ) / 2 ) - ( mainStringSize.height / 2 );
			[_mainText drawInRect:NSMakeRect( NSMinX( cellFrame ) + imageWidth + ( imageWidth ? JVDetailCellImageLabelPadding : JVDetailCellLabelPadding ), mainYLocation, NSWidth( cellFrame ) - imageWidth - ( JVDetailCellImageLabelPadding * 1. ) - statusWidth, [_mainText sizeWithAttributes:attributes].height ) withAttributes:attributes];
		}
	} else if( [_infoText length] && [_mainText length] ) {
		float mainYLocation = 0., subYLocation = 0.;

		if( NSHeight( cellFrame ) >= mainStringSize.height ) {
			mainYLocation = NSMinY( cellFrame ) + ( NSHeight( cellFrame ) / 2 ) - mainStringSize.height + ( JVDetailCellTextLeading / 2. );
			[_mainText drawInRect:NSMakeRect( cellFrame.origin.x + imageWidth + ( imageWidth ? JVDetailCellImageLabelPadding : JVDetailCellLabelPadding ), mainYLocation, NSWidth( cellFrame ) - imageWidth - ( JVDetailCellImageLabelPadding * 1. ) - statusWidth, [_mainText sizeWithAttributes:attributes].height ) withAttributes:attributes];

			subYLocation = NSMinY( cellFrame ) + ( NSHeight( cellFrame ) / 2 ) + subStringSize.height - mainStringSize.height + ( JVDetailCellTextLeading / 2. );
			[_infoText drawInRect:NSMakeRect( NSMinX( cellFrame ) + imageWidth + ( imageWidth ? JVDetailCellImageLabelPadding : JVDetailCellLabelPadding ), subYLocation, NSWidth( cellFrame ) - imageWidth - ( JVDetailCellImageLabelPadding * 1. ) - statusWidth, [_infoText sizeWithAttributes:subAttributes].height ) withAttributes:subAttributes];
		}
	}

	if( _statusImage && NSHeight( cellFrame ) >= [_statusImage size].height ) {
		  [_statusImage cq_compositeToPoint:NSMakePoint( NSMaxX( cellFrame ) - statusWidth, NSMaxY( cellFrame ) - ( ( NSHeight( cellFrame ) / 2 ) - ( [_statusImage size].height / 2 ) ) ) operation:NSCompositeSourceAtop fraction:( [self isEnabled] ? 1. : 0.5)];
	}
}

#pragma mark -

- (void) setImageScaling:(NSImageScaling) newScaling {
	[super setImageScaling:( newScaling == NSScaleProportionally || newScaling == NSScaleNone ? newScaling : NSScaleProportionally )];
}

- (void) setImageAlignment:(NSImageAlignment) newAlign {
	[super setImageAlignment:NSImageAlignLeft];
}

- (void) setLineBreakMode:(NSLineBreakMode) mode {
	_lineBreakMode = mode;
}

- (NSLineBreakMode) lineBreakMode {
	return _lineBreakMode;
}

- (void) setStringValue:(NSString *) string {
	[self setMainText:string];
}

- (void) setObjectValue:(id <NSCopying>) obj {
	if( ! obj || [(NSObject *)obj isKindOfClass:[NSImage class]] ) {
		[super setObjectValue:obj];
	} else if( [(NSObject *)obj isKindOfClass:[NSString class]] ) {
		[self setMainText:(NSString *)obj];
	}
}

- (NSString *) stringValue {
	return _mainText;
}


#pragma mark - Accessibility

- (NSArray *) accessibilityAttributeNames {
	static NSMutableArray *attributes = nil;
	if (!attributes) {
		attributes = [[super accessibilityAttributeNames] mutableCopy];

		for (NSString *attribute in @[NSAccessibilityValueDescriptionAttribute])
			if (![attributes containsObject:attribute])
				[attributes addObject:attribute];
	}

	return attributes;
}

- (id) accessibilityAttributeValue:(NSString *) attribute {
	if ([attribute isEqualToString:NSAccessibilityValueDescriptionAttribute]) {
		NSMutableArray *bits = [NSMutableArray array];
		NSString *statusText = (!_statusImage && _statusNumber) ? [NSString stringWithFormat:NSLocalizedString(@"%d items", nil), _statusNumber]: nil;
		NSString *importantStatusText = (!_statusImage && _importantStatusNumber) ? [NSString stringWithFormat:NSLocalizedString(@"%d important items", nil), _importantStatusNumber]: nil;
#define NIL_TO_EMPTY_STRING(a) ((a) ? (a) : @"")
		NSArray *candidates = @[NIL_TO_EMPTY_STRING(_mainText), NIL_TO_EMPTY_STRING(_infoText), NIL_TO_EMPTY_STRING(importantStatusText), NIL_TO_EMPTY_STRING(statusText), NIL_TO_EMPTY_STRING([_statusImage accessibilityDescription]), NIL_TO_EMPTY_STRING([_altImage accessibilityDescription])];
#undef NIL_TO_EMPTY_STRING

		for (NSString *candidate in candidates)
			if (candidate && [candidate length])
				[bits addObject:candidate];
		return [bits componentsJoinedByString:@", "];
	} else return [super accessibilityAttributeValue:attribute];
}
@end
