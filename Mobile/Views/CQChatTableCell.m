#import "CQChatTableCell.h"
#import "CQChatController.h"

#import <ChatCore/MVChatUser.h>

@interface UIRemoveControl : UIView
- (void) setRemoveConfirmationLabel:(NSString *) label;
@end

#pragma mark -

@interface UITableViewCell (UITableViewCellPrivate)
- (UIRemoveControl *) _createRemoveControl;
@end

#pragma mark -

@implementation CQChatTableCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];

	_maximumMessagePreviews = 2;
	_showsUserInMessagePreviews = YES;

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_nameLabel];

	_nameLabel.font = [UIFont boldSystemFontOfSize:18.];
	_nameLabel.textColor = self.textColor;
	_nameLabel.highlightedTextColor = self.selectedTextColor;

	_chatPreviewLabels = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	[_iconImageView release];
	[_nameLabel release];
	[_chatPreviewLabels release];
	[_removeConfirmationText release];
	[super dealloc];
}

#pragma mark -

- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller {
	self.name = controller.title;
	self.icon = controller.icon;
}

@synthesize maximumMessagePreviews = _maximumMessagePreviews;
@synthesize showsUserInMessagePreviews = _showsUserInMessagePreviews;

- (NSString *) name {
	return _nameLabel.text;
}

- (void) setName:(NSString *) name {
	_nameLabel.text = name;
}

- (UIImage *) icon {
	return _iconImageView.image;
}

- (void) setIcon:(UIImage *) icon {
	_iconImageView.image = icon;
}

@synthesize removeConfirmationText = _removeConfirmationText;

#pragma mark -

- (UIRemoveControl *) _createRemoveControl {
	UIRemoveControl *control = [super _createRemoveControl];
	if (_removeConfirmationText.length && [control respondsToSelector:@selector(setRemoveConfirmationLabel:)])
		[control setRemoveConfirmationLabel:_removeConfirmationText];
	return control;
}

#pragma mark -

#define LABEL_SPACING 2.

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated {
	CGRect nameFrame = _nameLabel.frame;

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.font = [UIFont systemFontOfSize:14.];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor colorWithWhite:0.4 alpha:1.];
	label.highlightedTextColor = [UIColor whiteColor];
	label.alpha = (animated ? 0. : 1.);

	if (action)
		label.text = [NSString stringWithFormat:@"%C %@ %@", 0x2022, user.displayName, message];
	else if (_showsUserInMessagePreviews)
		label.text = [NSString stringWithFormat:@"%@: %@", user.displayName, message];
	else label.text = message;

	NSTimeInterval animationDelay = 0.;

	if (_chatPreviewLabels.count == _maximumMessagePreviews) {
		UILabel *firstLabel = [[_chatPreviewLabels objectAtIndex:0] retain];
		[_chatPreviewLabels removeObjectAtIndex:0];

		if (animated) {
			[UIView beginAnimations:nil context:firstLabel];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
			[UIView setAnimationDuration:0.2];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(labelFadeOutAnimationDidStop:finished:context:)];

			firstLabel.alpha = 0.;

			[UIView commitAnimations];

			animationDelay = 0.15;
		} else {
			[firstLabel removeFromSuperview];
		}

		[firstLabel release];
	}

	CGFloat labelHeights = nameFrame.size.height;

	for (UILabel *label in _chatPreviewLabels)
		labelHeights += label.frame.size.height - LABEL_SPACING;

	CGRect labelFrame = label.frame;
	CGSize labelSize = [label sizeThatFits:labelFrame.size];

	labelHeights += labelSize.height;

	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDelay:animationDelay];
		[UIView setAnimationDuration:0.25];
	}

	nameFrame.origin.y = round((self.contentView.bounds.size.height / 2.) - (labelHeights / 2.));
	_nameLabel.frame = nameFrame;

	CGFloat newVerticalOrigin = nameFrame.origin.y + nameFrame.size.height - LABEL_SPACING;
	for (UILabel *label in _chatPreviewLabels) {
		CGRect labelFrame = label.frame;
		labelFrame.origin.y = newVerticalOrigin;
		label.frame = labelFrame;

		newVerticalOrigin = labelFrame.origin.y + labelFrame.size.height - LABEL_SPACING;
	}

	if (animated) {
		[UIView commitAnimations];

		animationDelay += 0.15;
	}

	labelFrame.origin.x = nameFrame.origin.x;
	labelFrame.origin.y = newVerticalOrigin;
	labelFrame.size.width = nameFrame.size.width;
	labelFrame.size.height = labelSize.height;
	label.frame = labelFrame;

	[self.contentView addSubview:label];
	[_chatPreviewLabels addObject:label];

	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
		[UIView setAnimationDuration:0.2];
		[UIView setAnimationDelay:animationDelay];

		label.alpha = 1.;

		[UIView commitAnimations];
	}
}

- (void) labelFadeOutAnimationDidStop:(NSString *) animation finished:(NSNumber *) finished context:(void *) context {
	UILabel *label = (UILabel *)context;
	[label removeFromSuperview];
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	for (UILabel *label in _chatPreviewLabels)
		[label removeFromSuperview];

	[_chatPreviewLabels removeAllObjects];

	self.name = @"";
	self.icon = nil;
	self.removeConfirmationText = nil;
	_showsUserInMessagePreviews = YES;
	_maximumMessagePreviews = 2;
}

- (void) layoutSubviews {
	[super layoutSubviews];

#define LEFT_MARGIN 10.
#define RIGHT_MARGIN 5.
#define ICON_RIGHT_MARGIN 10.

	CGRect contentRect = self.contentView.bounds;

	CGRect frame = _iconImageView.frame;
	frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
	frame.origin.x = contentRect.origin.x + LEFT_MARGIN;
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
	_iconImageView.frame = frame;

	frame = _nameLabel.frame;
	frame.size = [_nameLabel sizeThatFits:_nameLabel.bounds.size];

	CGFloat labelHeights = frame.size.height;

	for (UILabel *label in _chatPreviewLabels)
		labelHeights += label.frame.size.height - LABEL_SPACING;

	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = round((contentRect.size.height / 2.) - (labelHeights / 2.));
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	_nameLabel.frame = frame;

	CGFloat newVerticalOrigin = frame.origin.y + frame.size.height - LABEL_SPACING;
	for (UILabel *label in _chatPreviewLabels) {
		CGRect labelFrame = label.frame;
		labelFrame.origin.x = frame.origin.x;
		labelFrame.origin.y = newVerticalOrigin;
		labelFrame.size.width = frame.size.width;
		label.frame = labelFrame;

		newVerticalOrigin = labelFrame.origin.y + labelFrame.size.height - LABEL_SPACING;
	}
}
@end
