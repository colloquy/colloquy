#import "CQTableViewSectionHeader.h"

@implementation CQTableViewSectionHeader
- (id) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	_backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];

	UIImage *image = [UIImage imageNamed:@"sectionHeader.png"];
	image = [image stretchableImageWithLeftCapWidth:0. topCapHeight:0.];

	_backgroundImage = [image retain];

	_backgroundImageView.alpha = 0.9;
	_backgroundImageView.image = image;

	image = [UIImage imageNamed:@"sectionHeaderHighlighted.png"];
	image = [image stretchableImageWithLeftCapWidth:0. topCapHeight:0.];

	_backgroundHighlightedImage = [image retain];

	_textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_textLabel.font = [UIFont boldSystemFontOfSize:18.];
	_textLabel.textColor = [UIColor whiteColor];
	_textLabel.backgroundColor = [UIColor clearColor];
	_textLabel.shadowOffset = CGSizeMake(0., 1.);
	_textLabel.shadowColor = [UIColor colorWithWhite:0. alpha:0.5];

	image = [UIImage imageNamed:@"disclosureArrow.png"];
	_disclosureImageView = [[UIImageView alloc] initWithImage:image];

	[self addSubview:_backgroundImageView];
	[self addSubview:_textLabel];
	[self addSubview:_disclosureImageView];

	return self;
}

- (void) dealloc {
	[_textLabel release];
	[_backgroundImageView release];
	[_disclosureImageView release];
	[_backgroundImage release];
	[_backgroundHighlightedImage release];

	[super dealloc];
}

#pragma mark -

- (void) setFrame:(CGRect) frame {
	_frame = frame;
	frame.origin.y -= 1.;
	frame.size.height += 1.;
	super.frame = frame;
}

- (CGRect) frame {
	return _frame;
}

#pragma mark -

- (void) setHighlighted:(BOOL) highlighted {
	[super setHighlighted:highlighted];

	_backgroundImageView.alpha = (highlighted || self.selected ? 1. : 0.9);
	_backgroundImageView.image = (highlighted || self.selected ? _backgroundHighlightedImage : _backgroundImage);
}

- (void) setSelected:(BOOL) selected {
	[super setSelected:selected];

	_backgroundImageView.alpha = (selected || self.highlighted ? 1. : 0.9);
	_backgroundImageView.image = (selected || self.highlighted ? _backgroundHighlightedImage : _backgroundImage);
}

#pragma mark -

- (void) layoutSubviews {
	_backgroundImageView.frame = self.bounds;

#define LEFT_TEXT_MARGIN 12.
#define RIGHT_TEXT_MARGIN 40.
#define TOP_IMAGE_MARGIN 5.
#define RIGHT_IMAGE_MARGIN 16.

	CGRect frame = self.bounds;
	frame.origin.x += LEFT_TEXT_MARGIN;
	frame.size.width -= (LEFT_TEXT_MARGIN + RIGHT_TEXT_MARGIN);

	_textLabel.frame = frame;

	frame = _disclosureImageView.bounds;
	frame.origin.x = CGRectGetMaxX(self.bounds) - frame.size.width - RIGHT_IMAGE_MARGIN;
	frame.origin.y = TOP_IMAGE_MARGIN;

	_disclosureImageView.frame = frame;

	[super layoutSubviews];
}

#pragma mark -

@synthesize disclosureImageView = _disclosureImageView;
@synthesize textLabel = _textLabel;
@synthesize section = _section;
@end
