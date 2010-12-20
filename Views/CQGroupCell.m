#import "CQGroupCell.h"

@implementation CQGroupCell
@synthesize unansweredActivityCount = _unansweredActivityCount;

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	NSMutableAttributedString *attributedString = [self.attributedStringValue mutableCopy];
	NSRange range = NSMakeRange(0, attributedString.length);

	[attributedString addAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:(117. / 255.) green:(117. / 255.) blue:(117. / 255.) alpha:1.] range:range]; // prevent the color from being white on mousedown/selection

	NSDictionary *attributes = [attributedString attributesAtIndex:0 effectiveRange:&range];

#define CellArrowMargin 4.
#define SideTextMargin 6.
#define TopTextMargin 1.

	if (_unansweredActivityCount) {
		NSString *unansweredActivityCount = [[NSString alloc] initWithFormat:@"%ld", _unansweredActivityCount];
		NSSize textSize = [unansweredActivityCount sizeWithAttributes:attributes];
		textSize.width = ceilf(textSize.width);
		textSize.height = ceilf(textSize.height);

		NSRect rect = NSMakeRect(((cellFrame.size.width + cellFrame.origin.x) - (textSize.width + SideTextMargin)), TopTextMargin, textSize.width, cellFrame.size.height); // TODO: center the text

		NSAttributedString *unreadAttributedString = [[NSAttributedString alloc] initWithString:unansweredActivityCount attributes:attributes];
		[unreadAttributedString drawWithRect:rect options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)];
		[unreadAttributedString release];

		cellFrame.size.width -= (textSize.width + SideTextMargin);

		[unansweredActivityCount release];
	}

	cellFrame.origin.x += CellArrowMargin;
	cellFrame.size.width -= CellArrowMargin;

	[attributedString drawWithRect:cellFrame options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine)];
	[attributedString release];
}
@end
