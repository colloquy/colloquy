#import "CQUnreadCountView.h"

@implementation CQUnreadCountView
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;
	self.opaque = NO;
	return self;
}

@synthesize count = _normalCount;

- (void) setCount:(NSUInteger) count {
	if (_normalCount == count)
		return;
	_normalCount = count;
	[self setNeedsDisplay];
}

@synthesize importantCount = _importantCount;

- (void) setImportantCount:(NSUInteger) importantCount {
	if (_importantCount == importantCount)
		return;
	_importantCount = importantCount;
	[self setNeedsDisplay];
}

@synthesize highlighted = _highlighted;

- (void) setHighlighted:(BOOL) highlighted {
	if (_highlighted == highlighted)
		return;
	_highlighted = highlighted;
	[self setNeedsDisplay];
}

- (CGSize) sizeThatFits:(CGSize) size {
	if (!_importantCount && !_normalCount)
		return CGSizeZero;

	UIFont *font = [UIFont boldSystemFontOfSize:16.];
	NSString *numberString = [NSString stringWithFormat:@"%u", (_importantCount ? _importantCount : _normalCount)];
	CGSize textSize = [numberString sizeWithFont:font];

	CGFloat radius = 10.;
	CGRect enclosingRect = CGRectMake(0., 0., MAX(textSize.width + radius + (_importantCount && _normalCount ? radius * 1.2 : 0.), radius * 2.), radius * 2.);

	if (((NSUInteger)enclosingRect.size.width % 2) == 0 && ((NSUInteger)textSize.width % 2) != 0)
		enclosingRect.size.width += 1.;

	if (_importantCount && _normalCount) {
		CGSize previousTextSize = textSize;

		numberString = [NSString stringWithFormat:@"%u", _normalCount];
		textSize = [numberString sizeWithFont:font];

		enclosingRect = CGRectMake(previousTextSize.width + (radius * 1.2), 0., MAX(textSize.width + radius, radius * 2.), radius * 2.);

		if (((NSUInteger)enclosingRect.size.width % 2) == 0 && ((NSUInteger)textSize.width % 2) != 0)
			enclosingRect.size.width += 1.;
	}

	return CGSizeMake(CGRectGetMaxX(enclosingRect), enclosingRect.size.height);
}

- (void) drawRect:(CGRect) rect {
	if (!_importantCount && !_normalCount)
		return;

	UIFont *font = [UIFont boldSystemFontOfSize:16.];
	NSString *numberString = [NSString stringWithFormat:@"%u", (_importantCount ? _importantCount : _normalCount)];
	CGSize textSize = [numberString sizeWithFont:font];

	CGFloat radius = 10.;
	CGRect enclosingRect = CGRectMake(0., 0., MAX(textSize.width + radius + (_importantCount && _normalCount ? radius * 1.2 : 0.), radius * 2.), radius * 2.);
	if (((NSUInteger)enclosingRect.size.width % 2) == 0 && ((NSUInteger)textSize.width % 2) != 0)
		enclosingRect.size.width += 1.;
	CGRect pathCornersRect = CGRectInset(enclosingRect, radius, radius);

	CGMutablePathRef path = CGPathCreateMutable();

	CGPathAddArc(path, NULL, CGRectGetMinX(pathCornersRect), CGRectGetMinY(pathCornersRect), radius, M_PI, (M_PI + M_PI_2), 1);
	CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMinY(pathCornersRect), radius, (M_PI + M_PI_2), (M_PI + M_PI), 1);
	CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMaxY(pathCornersRect), radius, 0., M_PI_2, 1);
	CGPathAddArc(path, NULL, CGRectGetMinX(pathCornersRect), CGRectGetMaxY(pathCornersRect), radius, M_PI_2, M_PI, 1);

	CGContextRef ctx = UIGraphicsGetCurrentContext();

	if (_highlighted && _importantCount) CGContextSetGrayFillColor(ctx, 1., 0.9);
	else if (_highlighted) CGContextSetGrayFillColor(ctx, 1., 1.);
	else if (_importantCount) CGContextSetRGBFillColor(ctx, (220. / 255.), (20. / 255.), (20. / 255.), 1.);
	else CGContextSetRGBFillColor(ctx, (131. / 255.), (152. / 255.), (180. / 255.), 1.);

	CGContextAddPath(ctx, path);
	CGContextFillPath(ctx);

	CGPathRelease(path);

	CGContextSetBlendMode(ctx, kCGBlendModeClear);

	CGPoint textPoint = enclosingRect.origin;
	textPoint.x += round(((enclosingRect.size.width - (_importantCount && _normalCount ? radius * .8 : 0.)) / 2.) - (textSize.width / 2.));
	textPoint.y += round((enclosingRect.size.height / 2.) - (textSize.height / 2.));

	[numberString drawAtPoint:textPoint withFont:font];

	if (_importantCount && _normalCount) {
		CGSize previousTextSize = textSize;

		numberString = [NSString stringWithFormat:@"%u", _normalCount];
		textSize = [numberString sizeWithFont:font];

		enclosingRect = CGRectMake(previousTextSize.width + (radius * 1.2), 0., MAX(textSize.width + radius, radius * 2.), radius * 2.);
		if (((NSUInteger)enclosingRect.size.width % 2) == 0 && ((NSUInteger)textSize.width % 2) != 0)
			enclosingRect.size.width += 1.;
		pathCornersRect = CGRectInset(enclosingRect, radius, radius);

		path = CGPathCreateMutable();

		CGPathAddArc(path, NULL, CGRectGetMinX(pathCornersRect), CGRectGetMinY(pathCornersRect), radius, M_PI, (M_PI + M_PI_2), 1);
		CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMinY(pathCornersRect), radius, (M_PI + M_PI_2), (M_PI + M_PI), 1);
		CGPathAddArc(path, NULL, CGRectGetMaxX(pathCornersRect), CGRectGetMaxY(pathCornersRect), radius, 0., M_PI_2, 1);
		CGPathAddArc(path, NULL, CGRectGetMinX(pathCornersRect), CGRectGetMaxY(pathCornersRect), radius, M_PI_2, M_PI, 1);

		CGContextSetGrayFillColor(ctx, 0., 1.);
		CGContextSetGrayStrokeColor(ctx, 0., 1.);
		CGContextSetBlendMode(ctx, kCGBlendModeClear);
		CGContextSetLineWidth(ctx, 4.);

		CGContextAddPath(ctx, path);
		CGContextStrokePath(ctx);

		CGContextAddPath(ctx, path);
		CGContextFillPath(ctx);

		if (_highlighted) CGContextSetGrayFillColor(ctx, 1., 1.);
		else CGContextSetRGBFillColor(ctx, (131. / 255.), (152. / 255.), (180. / 255.), 1.);

		CGContextSetBlendMode(ctx, kCGBlendModeNormal);

		CGContextAddPath(ctx, path);
		CGContextFillPath(ctx);

		CGPathRelease(path);

		CGContextSetBlendMode(ctx, kCGBlendModeClear);

		textPoint = enclosingRect.origin;
		textPoint.x += round((enclosingRect.size.width / 2.) - (textSize.width / 2.));
		textPoint.y += round((enclosingRect.size.height / 2.) - (textSize.height / 2.));

		[numberString drawAtPoint:textPoint withFont:font];
	}
}
@end
