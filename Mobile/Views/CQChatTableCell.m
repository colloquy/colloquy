#import "CQChatTableCell.h"
#import "CQChatController.h"
#import "CQUnreadCountView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@interface UIRemoveControl : UIView
- (void) setRemoveConfirmationLabel:(NSString *) label;
@end

#pragma mark -

@interface UITableViewCell (UITableViewCellPrivate)
- (UIRemoveControl *) _createRemoveControl;
@end
#endif

#pragma mark -

@implementation CQChatTableCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_unreadCountView = [[CQUnreadCountView alloc] initWithFrame:CGRectZero];

	_maximumMessagePreviews = 2;
	_showsUserInMessagePreviews = YES;
	_available = YES;

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_nameLabel];
	[self.contentView addSubview:_unreadCountView];

	_nameLabel.font = [UIFont boldSystemFontOfSize:18.];
	_nameLabel.textColor = self.textColor;
	_nameLabel.highlightedTextColor = self.selectedTextColor;

	_chatPreviewLabels = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	[_iconImageView release];
	[_unreadCountView release];
	[_nameLabel release];
#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	[_removeControl release];
	[_removeConfirmationText release];
#endif
	[_chatPreviewLabels release];

	[super dealloc];
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

- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller {
	self.name = controller.title;
	self.icon = controller.icon;
	self.available = controller.available;

	if ([controller respondsToSelector:@selector(unreadCount)])
		self.unreadCount = controller.unreadCount;
	else self.unreadCount = 0;

	if ([controller respondsToSelector:@selector(importantUnreadCount)])
		self.importantUnreadCount = controller.importantUnreadCount;
	else self.importantUnreadCount = 0;
}

@synthesize maximumMessagePreviews = _maximumMessagePreviews;
@synthesize showsUserInMessagePreviews = _showsUserInMessagePreviews;

- (BOOL) showsIcon {
	return !_iconImageView.hidden;
}

- (void) setShowsIcon:(BOOL) show {
	_iconImageView.hidden = !show;

	[self setNeedsLayout];
}

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

- (NSUInteger) unreadCount {
	return _unreadCountView.count;
}

- (void) setUnreadCount:(NSUInteger) messages {
	_unreadCountView.count = messages;

	[self setNeedsLayout];
}

- (NSUInteger) importantUnreadCount {
	return _unreadCountView.importantCount;
}

- (void) setImportantUnreadCount:(NSUInteger) messages {
	_unreadCountView.importantCount = messages;

	[self setNeedsLayout];
}

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@synthesize removeConfirmationText = _removeConfirmationText;

- (void) setRemoveConfirmationText:(NSString *) text {
	id old = _removeConfirmationText;
	_removeConfirmationText = [text copy];
	[old release];

	if (_removeConfirmationText.length && [_removeControl respondsToSelector:@selector(setRemoveConfirmationLabel:)])
		[_removeControl setRemoveConfirmationLabel:_removeConfirmationText];
}
#endif

@synthesize available = _available;

- (void) setAvailable:(BOOL) available {
	_available = available;

	CGFloat alpha = (available ? 1. : 0.5);
	_nameLabel.alpha = alpha;
	_iconImageView.alpha = alpha;

	for (UILabel *label in _chatPreviewLabels)
		label.alpha = alpha;
}

#pragma mark -

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
- (UIRemoveControl *) _createRemoveControl {
	[_removeControl release];
	_removeControl = [[super _createRemoveControl] retain];
	if (_removeConfirmationText.length && [_removeControl respondsToSelector:@selector(setRemoveConfirmationLabel:)])
		[_removeControl setRemoveConfirmationLabel:_removeConfirmationText];
	return _removeControl;
}
#endif

#pragma mark -

#define LABEL_SPACING 2.

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated {
	NSString *labelText = nil;
	if (action)
		labelText = [NSString stringWithFormat:@"%C %@ %@", 0x2022, user.displayName, message];
	else if (_showsUserInMessagePreviews)
		labelText = [NSString stringWithFormat:@"%@: %@", user.displayName, message];
	else labelText = message;

	if (_animating) {
		for (NSUInteger i = 0; i < _chatPreviewLabels.count; ++i) {
			if (i == 0)
				continue;
			UILabel *currentLabel = [_chatPreviewLabels objectAtIndex:i];
			UILabel *previousLabel = [_chatPreviewLabels objectAtIndex:(i - 1)];
			previousLabel.text = currentLabel.text;

			if (i == (_chatPreviewLabels.count - 1))
				currentLabel.text = labelText;
		}

		return;
	}

	if (animated)
		_animating = YES;

	NSTimeInterval animationDelay = 0.;

	if (_chatPreviewLabels.count >= _maximumMessagePreviews) {
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

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.font = [UIFont systemFontOfSize:14.];
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor colorWithWhite:0.4 alpha:1.];
	label.highlightedTextColor = [UIColor whiteColor];
	label.alpha = (animated ? 0. : (_available ? 1. : 0.5));
	label.text = labelText;

	[self.contentView addSubview:label];
	[_chatPreviewLabels addObject:label];

	[self layoutSubviewsWithAnimation:animated withDelay:animationDelay];

	if (animated) {
		animationDelay += 0.15;

		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
		[UIView setAnimationDuration:0.2];
		[UIView setAnimationDelay:animationDelay];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(labelFadeInAnimationDidStop:finished:context:)];

		label.alpha = (_available ? 1. : 0.5);

		[UIView commitAnimations];
	}

	[label release];
}

- (void) labelFadeOutAnimationDidStop:(NSString *) animation finished:(NSNumber *) finished context:(void *) context {
	UILabel *label = (UILabel *)context;
	[label removeFromSuperview];
}

- (void) labelFadeInAnimationDidStop:(NSString *) animation finished:(NSNumber *) finished context:(void *) context {
	_animating = NO;

	[self setNeedsLayout];
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	for (UILabel *label in _chatPreviewLabels)
		[label removeFromSuperview];

	[_chatPreviewLabels removeAllObjects];

	self.name = @"";
	self.icon = nil;
	self.available = YES;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	self.removeConfirmationText = nil;
#endif

	_showsUserInMessagePreviews = YES;
	_maximumMessagePreviews = 2;
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	if (animated)
		[UIView beginAnimations:nil context:NULL];

	CGFloat alpha = (_available || selected ? 1. : 0.5);
	_nameLabel.alpha = alpha;
	_iconImageView.alpha = alpha;

	for (UILabel *label in _chatPreviewLabels)
		label.alpha = alpha;

	if (animated)
		[UIView commitAnimations];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationCurve:(editing ? UIViewAnimationCurveEaseIn : UIViewAnimationCurveEaseOut)];
	}

	[super setEditing:editing animated:animated];

	_unreadCountView.alpha = editing ? 0. : 1.;

	if (animated)
		[UIView commitAnimations];
}

- (void) layoutSubviewsWithAnimation:(BOOL) animated withDelay:(NSTimeInterval) animationDelay {
	[super layoutSubviews];

#define TOP_TEXT_MARGIN -1.
#define LEFT_MARGIN 10.
#define NO_ICON_LEFT_MARGIN 14.
#define RIGHT_MARGIN 10.
#define ICON_RIGHT_MARGIN 10.

	CGRect contentRect = self.contentView.bounds;

	CGRect frame = _unreadCountView.frame;
	frame.size = [_unreadCountView sizeThatFits:_unreadCountView.bounds.size];
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));

	if (self.showingDeleteConfirmation || self.showsReorderControl)
		frame.origin.x = self.bounds.size.width - contentRect.origin.x;
	else if (self.editing)
		frame.origin.x = contentRect.size.width - frame.size.width;
	else
		frame.origin.x = contentRect.size.width - frame.size.width - RIGHT_MARGIN;

	_unreadCountView.frame = frame;

	if (!_iconImageView.hidden) {
		frame = _iconImageView.frame;
		frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
		frame.origin.x = contentRect.origin.x + LEFT_MARGIN;
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
		_iconImageView.frame = frame;
	}

	if (!animated && _animating)
		return;

	frame = _nameLabel.frame;
	frame.size = [_nameLabel sizeThatFits:_nameLabel.bounds.size];

	CGFloat labelHeights = frame.size.height;

	for (UILabel *label in _chatPreviewLabels) {
		CGFloat height = label.frame.size.height;
		if (!height) {
			CGRect bounds = label.bounds;
			bounds.size = [label sizeThatFits:bounds.size];
			label.bounds = bounds;

			height = bounds.size.height;
		}

		labelHeights += height - LABEL_SPACING;
	}

	frame.origin.x = (_iconImageView.hidden ? NO_ICON_LEFT_MARGIN : CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN);
	frame.origin.y = round((contentRect.size.height / 2.) - (labelHeights / 2.)) + TOP_TEXT_MARGIN;
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	if (!self.editing && _unreadCountView.bounds.size.width)
		frame.size.width -= (contentRect.size.width - CGRectGetMinX(_unreadCountView.frame));

	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDelay:animationDelay];
		[UIView setAnimationDuration:0.25];
	}

	_nameLabel.frame = frame;

	CGFloat newVerticalOrigin = frame.origin.y + frame.size.height - LABEL_SPACING;
	for (UILabel *label in _chatPreviewLabels) {
		CGRect labelFrame = label.frame;

		BOOL disableAnimation = !labelFrame.origin.x;
		if (disableAnimation)
			[UIView setAnimationsEnabled:NO];

		labelFrame.origin.x = frame.origin.x;
		labelFrame.origin.y = newVerticalOrigin;
		labelFrame.size.width = frame.size.width;
		label.frame = labelFrame;

		if (disableAnimation)
			[UIView setAnimationsEnabled:YES];

		newVerticalOrigin = labelFrame.origin.y + labelFrame.size.height - LABEL_SPACING;
	}

	if (animated)
		[UIView commitAnimations];
}

- (void) layoutSubviews {
	[self layoutSubviewsWithAnimation:NO withDelay:0.];
}
@end
