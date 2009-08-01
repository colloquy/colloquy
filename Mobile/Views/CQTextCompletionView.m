#import "CQTextCompletionView.h"

#define MaximumCompletions 5
#define CompletionFont [UIFont boldSystemFontOfSize:16.]
#define CompletionMargin 10.
#define CompletionBubbleRadius 14.5
#define CompletionBubbleInset 6.5

@implementation CQTextCompletionView
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;
	self.opaque = NO;
	self.exclusiveTouch = YES;
	_selectedCompletion = NSNotFound;
	return self;
}

#pragma mark -

- (void) setIsAccessibilityElement:(BOOL) isElement {
	[super setIsAccessibilityElement:isElement];
}

- (void) setAccessibilityLabel:(NSString *) label {
	[super setAccessibilityLabel:label];
}

- (void) setAccessibilityTraits:(UIAccessibilityTraits) traits {
	[super setAccessibilityTraits:[super accessibilityTraits] | traits];
}

#pragma mark -

- (void) drawRect:(CGRect) rect {
	CGRect enclosingRect = CGRectMake(CompletionBubbleInset, CompletionBubbleInset, 40., CompletionBubbleRadius * 2.);

	for (NSUInteger i = 0; i < MaximumCompletions; ++i) {
		if (!_completionTextSizes[i].width)
			break;
		enclosingRect.size.width += (_completionTextSizes[i].width + (CompletionMargin * 2.));
	}

	CGRect pathCornersRect = CGRectInset(enclosingRect, CompletionBubbleRadius, CompletionBubbleRadius);

	CGMutablePathRef path = CGPathCreateMutable();

	CGPathMoveToPoint(path, NULL, CGRectGetMinX(enclosingRect), CGRectGetMaxY(enclosingRect));
	CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMaxY(pathCornersRect), CompletionBubbleRadius, M_PI_2, M_PI + M_PI_2, 1);
	CGPathAddLineToPoint(path, NULL, CGRectGetMinX(enclosingRect), CGRectGetMinY(enclosingRect));
	CGPathCloseSubpath(path);

	CGContextRef ctx = UIGraphicsGetCurrentContext();

	CGContextSetGrayFillColor(ctx, 1., 1.);
	CGContextSetRGBStrokeColor(ctx, (181. / 255.), (202. / 255.), 1., 1.);
	CGContextSetLineWidth(ctx, 1.);
	CGContextSetShadow(ctx, CGSizeMake(0., -2.), 6.);

	CGContextAddPath(ctx, path);
	CGContextFillPath(ctx);

	CGContextSetShadow(ctx, CGSizeMake(0., 0.), 0.);
	CGContextAddPath(ctx, path);
	CGContextStrokePath(ctx);

	CGPathRelease(path);

	NSUInteger i = 0;
	CGFloat offset = CompletionMargin;
	UIFont *font = CompletionFont;

	for (NSString *completion in _completions) {
		BOOL selected = (_selectedCompletion == i);
		CGSize textSize = _completionTextSizes[i++];

		CGPoint textPoint = CGPointZero;
		textPoint.x = round(enclosingRect.origin.x + offset);
		textPoint.y = round(enclosingRect.origin.y + (enclosingRect.size.height / 2.) - (textSize.height / 2.));

		if (selected) {
			CGContextSetRGBStrokeColor(ctx, (10. / 255.), (55. / 255.), (175. / 255.), 1.);
			CGContextSetRGBFillColor(ctx, (25. / 255.), (121. / 255.), (227. / 255.), 1.);

			CGContextFillRect(ctx, CGRectMake(enclosingRect.origin.x + offset - CompletionMargin, enclosingRect.origin.y, textSize.width + (CompletionMargin * 2.), enclosingRect.size.height));
			CGContextStrokeRect(ctx, CGRectMake(enclosingRect.origin.x + offset - CompletionMargin, enclosingRect.origin.y, textSize.width + (CompletionMargin * 2.), enclosingRect.size.height));
		} else {
			CGContextMoveToPoint(ctx, (enclosingRect.origin.x + offset + textSize.width + CompletionMargin), enclosingRect.origin.y);
			CGContextAddLineToPoint(ctx, (enclosingRect.origin.x + offset + textSize.width + CompletionMargin), CGRectGetMaxY(enclosingRect));

			CGContextSetRGBStrokeColor(ctx, (181. / 255.), (202. / 255.), 1., 1.);

			CGContextStrokePath(ctx);
		}

		if (selected) CGContextSetGrayFillColor(ctx, 1., 1.);
		else CGContextSetRGBFillColor(ctx, (25. / 255.), (121. / 255.), (227. / 255.), 1.);

		completion = [completion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[completion drawAtPoint:textPoint withFont:font];

		offset += textSize.width + (CompletionMargin * 2.);
	}

	if (_selectedCompletion == i) {
		path = CGPathCreateMutable();

		CGPathMoveToPoint(path, NULL, enclosingRect.origin.x + offset - CompletionMargin, CGRectGetMaxY(enclosingRect));
		CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMaxY(pathCornersRect), CompletionBubbleRadius, M_PI_2, M_PI + M_PI_2, 1);
		CGPathAddLineToPoint(path, NULL, enclosingRect.origin.x + offset - CompletionMargin, CGRectGetMinY(enclosingRect));
		CGPathCloseSubpath(path);

		CGContextRef ctx = UIGraphicsGetCurrentContext();

		CGContextSetRGBStrokeColor(ctx, (10. / 255.), (55. / 255.), (175. / 255.), 1.);
		CGContextSetRGBFillColor(ctx, (25. / 255.), (121. / 255.), (227. / 255.), 1.);

		CGContextAddPath(ctx, path);
		CGContextFillPath(ctx);

		CGContextAddPath(ctx, path);
		CGContextStrokePath(ctx);

		CGPathRelease(path);

		CGContextSetGrayFillColor(ctx, 1., 1.);
	} else {
		CGContextSetGrayFillColor(ctx, 0.6, 1.);
	}

	font = [UIFont systemFontOfSize:18.];

	CGSize textSize = [@"\u00d7" sizeWithFont:font];
	CGPoint textPoint = CGPointZero;
	textPoint.x = round(enclosingRect.origin.x + offset + 2.);
	textPoint.y = round(enclosingRect.origin.y + (enclosingRect.size.height / 2.) - (textSize.height / 2.) - 1.);

	[@"\u00d7" drawAtPoint:textPoint withFont:font];
}

- (void) dealloc {
	[_completions release];

	[super dealloc];
}

#pragma mark -

@synthesize delegate;

@synthesize completions = _completions;

- (void) setCompletions:(NSArray *) completions {
	UIFont *font = CompletionFont;

	NSMutableSet *existingCompletions = [NSMutableSet set];
	id objects[MaximumCompletions] = { nil };

	NSUInteger i = 0;
	for (NSString *completion in completions) {
		if ([existingCompletions containsObject:completion])
			continue;

		objects[i] = completion;
		_completionTextSizes[i] = [[completion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] sizeWithFont:font];

		[existingCompletions addObject:completion];

		if (++i >= MaximumCompletions) break;
	}

	id old = _completions;
	_completions = [[NSArray alloc] initWithObjects:objects count:i];
	[old release];

	_selectedCompletion = NSNotFound;

	for (; i < MaximumCompletions; ++i)
		_completionTextSizes[i] = CGSizeZero;

	[self setNeedsDisplay];
}

- (NSUInteger) selectedCompletion {
	if (_selectedCompletion >= MaximumCompletions || _selectedCompletion >= _completions.count)
		return NSNotFound;
	return _selectedCompletion;
}

- (void) setSelectedCompletion:(NSUInteger) selectedCompletion {
	if (_selectedCompletion == selectedCompletion)
		return;

	_selectedCompletion = selectedCompletion;

	[self setNeedsDisplay];
}

- (BOOL) isCloseSelected {
	return (_selectedCompletion != NSNotFound && (_selectedCompletion >= MaximumCompletions || _selectedCompletion >= _completions.count));
}

- (void) setCloseSelected:(BOOL) selected {
	if (!selected)
		return;
	self.selectedCompletion = _completions.count;
}

#pragma mark -

- (NSUInteger) completionIndexForPoint:(CGPoint) location {
	NSUInteger i = 0;
	CGFloat width = CompletionMargin;
	for (; i < MaximumCompletions; ++i) {
		if (!_completionTextSizes[i].width)
			break;

		width += (_completionTextSizes[i].width + (CompletionMargin * 2.));
		if (location.x < width)
			return i;
	}

	if (location.x >= width)
		return i;

	return NSNotFound;
}

- (CGSize) sizeThatFits:(CGSize) size {
	CGRect enclosingRect = CGRectMake(0., 0., 40., CompletionBubbleRadius * 2.);

	for (NSUInteger i = 0; i < MaximumCompletions; ++i) {
		if (!_completionTextSizes[i].width)
			break;
		enclosingRect.size.width += (_completionTextSizes[i].width + (CompletionMargin * 2.));
	}

	return CGRectInset(enclosingRect, -(CompletionBubbleInset + 2.), -(CompletionBubbleInset + 2.)).size;
}

- (BOOL) pointInside:(CGPoint) point withEvent:(UIEvent *) event {
	CGRect enclosingRect = CGRectMake(CompletionBubbleInset, CompletionBubbleInset, 40., CompletionBubbleRadius * 2.);

	for (NSUInteger i = 0; i < MaximumCompletions; ++i) {
		if (!_completionTextSizes[i].width)
			break;
		enclosingRect.size.width += (_completionTextSizes[i].width + (CompletionMargin * 2.));
	}

	return CGRectContainsPoint(enclosingRect, point);
}

- (void) touchesBegan:(NSSet *) touches withEvent:(UIEvent *) event {
	NSParameterAssert(touches.count == 1);

	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];

	self.selectedCompletion = [self completionIndexForPoint:location];
}

- (void) touchesMoved:(NSSet *) touches withEvent:(UIEvent *) event {
	NSParameterAssert(touches.count == 1);

	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];

	if ([self pointInside:location withEvent:event])
		self.selectedCompletion = [self completionIndexForPoint:location];
	else self.selectedCompletion = NSNotFound;
}

- (void) touchesEnded:(NSSet *) touches withEvent:(UIEvent *) event {
	if (_selectedCompletion == NSNotFound)
		return;

	[self retain];

	if (_selectedCompletion >= MaximumCompletions || _selectedCompletion >= _completions.count) {
		if ([delegate respondsToSelector:@selector(textCompletionViewDidClose:)])
			[delegate textCompletionViewDidClose:self];
	} else {
		if ([delegate respondsToSelector:@selector(textCompletionView:didSelectCompletion:)])
			[delegate textCompletionView:self didSelectCompletion:[_completions objectAtIndex:_selectedCompletion]];
	}

	self.selectedCompletion = NSNotFound;

	[self release];
}

- (void) touchesCancelled:(NSSet *) touches withEvent:(UIEvent *) event {
	self.selectedCompletion = NSNotFound;
}
@end
