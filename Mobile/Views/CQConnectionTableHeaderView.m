#import "CQConnectionTableHeaderView.h"

#import "CQConnectionsController.h"

#import "CQBouncerSettings.h"

#import "UIViewAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQConnectionTableHeaderView {
	UIImageView *_iconImageView;
	UIImageView *_badgeImageView;
	UILabel *_serverLabel;
	UILabel *_nicknameLabel;
	UILabel *_timeLabel;
	NSDate *_connectDate;
	CQConnectionTableCellStatus _status;
	UIButton *_disclosureButton;

	UIColor *_originalBackgroundColor;
}

- (instancetype) initWithReuseIdentifier:(NSString *__nullable) reuseIdentifier {
	if (!(self = [super initWithReuseIdentifier:reuseIdentifier]))
		return nil;

	self.tintColor = [UIApplication sharedApplication].keyWindow.tintColor;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_badgeImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_serverLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_nicknameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_disclosureButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
#if !SYSTEM(TV)
	_disclosureButton.showsTouchWhenHighlighted = YES;
#endif
	_disclosureButton.adjustsImageWhenHighlighted = YES;

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_badgeImageView];
	[self.contentView addSubview:_timeLabel];
	[self.contentView addSubview:_nicknameLabel];
	[self.contentView addSubview:_serverLabel];
	[self.contentView addSubview:_disclosureButton];

	_disclosureButton.alpha = 0.;
	[_disclosureButton addTarget:self action:@selector(_disclosureButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

	_iconImageView.image = [UIImage imageNamed:@"server.png"];

	_serverLabel.font = [UIFont boldSystemFontOfSize:18.];
	_serverLabel.textColor = self.textLabel.textColor;
	_serverLabel.highlightedTextColor = self.textLabel.highlightedTextColor;

	_nicknameLabel.font = [UIFont systemFontOfSize:14.];
	_nicknameLabel.textColor = self.textLabel.textColor;
	_nicknameLabel.highlightedTextColor = self.textLabel.highlightedTextColor;

	_timeLabel.font = [UIFont systemFontOfSize:14.];
	_timeLabel.textColor = self.tintColor;
	_timeLabel.highlightedTextColor = self.textLabel.highlightedTextColor;

	self.layer.borderColor = [UIColor colorWithWhite:(208. / 255.) alpha:1.].CGColor;

	return self;
}

#pragma mark -

- (void) takeValuesFromConnection:(MVChatConnection *) connection {
	if (!connection)
		return;

	if ([connection isKindOfClass:[CQBouncerSettings class]]) {
		[self takeValuesFromBouncerSettings:(CQBouncerSettings *)connection];
		return;
	}

	self.server = connection.displayName;
	self.nickname = connection.nickname;

	if (connection.waitingToReconnect && connection.status != MVChatConnectionConnectingStatus)
		self.connectDate = connection.nextReconnectAttemptDate;
	else self.connectDate = connection.connectedDate;

	switch (connection.status) {
	case MVChatConnectionDisconnectedStatus:
		if (connection.waitingToReconnect)
			self.status = CQConnectionTableCellReconnectingStatus;
		else self.status = CQConnectionTableCellNotConnectedStatus;
		break;
	case MVChatConnectionServerDisconnectedStatus:
		if (connection.waitingToReconnect)
			self.status = CQConnectionTableCellReconnectingStatus;
		else self.status = CQConnectionTableCellServerDisconnectedStatus;
		break;
	case MVChatConnectionConnectingStatus:
		self.status = CQConnectionTableCellConnectingStatus;
		break;
	case MVChatConnectionConnectedStatus:
		self.status = CQConnectionTableCellConnectedStatus;
		break;
	case MVChatConnectionSuspendedStatus:
		self.status = CQConnectionTableCellReconnectingStatus;
		break;
	}

	if (connection.directConnection)
		_iconImageView.image = [UIImage imageNamed:@"server.png"];
	else _iconImageView.image = [UIImage imageNamed:@"bouncer.png"];
}

- (void) takeValuesFromBouncerSettings:(CQBouncerSettings *) bouncerSettings {
	_iconImageView.image = nil;

	self.nickname = bouncerSettings.displayName;
	self.server = bouncerSettings.server;	
}

- (NSString *) server {
	return _serverLabel.text;
}

- (void) setServer:(NSString *) server {
	self.textLabel.text = nil;
	_serverLabel.text = server;

	self.accessibilityLabel = server;
}

- (NSString *) nickname {
	return _nicknameLabel.text;
}

- (void) setNickname:(NSString *) nickname {
	_nicknameLabel.text = nickname;
}

- (void) updateConnectTime {
	NSString *newTime = nil;

	if (_connectDate) {
		NSTimeInterval interval = [_connectDate timeIntervalSinceNow];
		unsigned absoluteInterval = ABS(interval);
		unsigned seconds = (absoluteInterval % 60);
		unsigned minutes = ((absoluteInterval / 60) % 60);
		unsigned hours = (absoluteInterval / 3600);

		if (interval >= 1.) {
			if (UNLIKELY(hours)) newTime = [[NSString alloc] initWithFormat:NSLocalizedString(@"-%zd:%02zd:%02zd", @"Countdown time format with hours, minutes and seconds"), hours, minutes, seconds];
			else newTime = [[NSString alloc] initWithFormat:NSLocalizedString(@"-%u:%02zd", @"Countdown time format with minutes and seconds"), minutes, seconds];
		} else {
			if (UNLIKELY(hours)) newTime = [[NSString alloc] initWithFormat:NSLocalizedString(@"%u:%02zd:%02zd", @"Countup time format with hours, minutes and seconds"), hours, minutes, seconds];
			else newTime = [[NSString alloc] initWithFormat:NSLocalizedString(@"%u:%02zd", @"Countup time format with minutes and seconds"), minutes, seconds];
		}
	}

	_timeLabel.text = newTime;

	[self _layoutTimeLabel];
}

- (void) setConnectDate:(NSDate *) connectDate {
	_connectDate = [connectDate copy];

	[self updateConnectTime];
}

- (void) setStatus:(CQConnectionTableCellStatus) status {
	if (_status == status)
		return;

	_status = status;

	switch (status) {
	case CQConnectionTableCellNotConnectedStatus:
		_badgeImageView.image = nil;
		break;
	case CQConnectionTableCellReconnectingStatus:
	case CQConnectionTableCellServerDisconnectedStatus:
		_badgeImageView.image = [UIImage imageNamed:@"errorBadgeDim.png"];
		break;
	case CQConnectionTableCellConnectingStatus:
		_badgeImageView.image = [UIImage imageNamed:@"connectingBadgeDim.png"];
		break;
	case CQConnectionTableCellConnectedStatus:
		_badgeImageView.image = [UIImage imageNamed:@"connectedBadgeDim.png"];
		break;
	}

	[self setNeedsLayout];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[UIView animateWithDuration:(cq_shouldAnimate(animated) ? .3 : .0) delay:0. options:(editing ? UIViewAnimationOptionCurveEaseIn : UIViewAnimationOptionCurveEaseOut) animations:^{
		_timeLabel.alpha = editing ? 0. : 1.;
		_disclosureButton.alpha = editing ? 1. : 0.;
	} completion:NULL];

	self.editing = editing;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	self.layer.borderWidth = (1. / (self.window.screen.scale ?: [UIScreen mainScreen].scale));

	[self.textLabel removeFromSuperview];
	[self.detailTextLabel removeFromSuperview];

#define ICON_LEFT_MARGIN 10.
#define ICON_RIGHT_MARGIN 10.
#define TEXT_RIGHT_MARGIN 7.

	CGRect contentRect = self.contentView.frame;
	CGRect frame = _iconImageView.frame;
	frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
	frame.origin.x = ICON_LEFT_MARGIN;
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
	_iconImageView.frame = frame;

	frame = _badgeImageView.frame;
	frame.size = [_badgeImageView sizeThatFits:_badgeImageView.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) - (frame.size.width / 1.5);
	frame.origin.y = CGRectGetMaxY(_iconImageView.frame) - (frame.size.height / 1.33);
	_badgeImageView.frame = frame;

	[self _layoutTimeLabel];

	frame = _serverLabel.frame;
	frame.size = [_serverLabel sizeThatFits:_serverLabel.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = round((contentRect.size.height / 2.) - frame.size.height + 3.);
	frame.size.width = _timeLabel.frame.origin.x - frame.origin.x - TEXT_RIGHT_MARGIN;
	_serverLabel.frame = frame;

	frame = _nicknameLabel.frame;
	frame.size = [_nicknameLabel sizeThatFits:_nicknameLabel.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = round(contentRect.size.height / 2.);
	frame.size.width = _timeLabel.frame.origin.x - frame.origin.x - TEXT_RIGHT_MARGIN;
	_nicknameLabel.frame = frame;

	[_disclosureButton sizeToFit];
	frame = _disclosureButton.frame;
	frame.origin.x = contentRect.size.width - frame.size.width - TEXT_RIGHT_MARGIN;
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
	_disclosureButton.frame = frame;
}

- (void) _layoutTimeLabel {
	CGRect contentRect = self.contentView.frame;
	CGRect frame = _timeLabel.frame;
	frame.size = [_timeLabel sizeThatFits:_timeLabel.bounds.size];
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));

	if (UNLIKELY(self.showingDeleteConfirmation || self.showsReorderControl))
		frame.origin.x = self.bounds.size.width - contentRect.origin.x;
	else frame.origin.x = contentRect.size.width - frame.size.width - TEXT_RIGHT_MARGIN;

	_timeLabel.frame = frame;
}

- (void) touchesBegan:(NSSet *) touches withEvent:(UIEvent *__nullable) event {
	[super touchesBegan:touches withEvent:event];

	_originalBackgroundColor = [self.contentView.backgroundColor copy];
	self.contentView.backgroundColor = [UIColor colorWithWhite:(208. / 255.) alpha:1.];
}

- (void) touchesCancelled:(NSSet *__nullable) touches withEvent:(UIEvent *__nullable) event {
	[super touchesCancelled:touches withEvent:event];

	self.contentView.backgroundColor = _originalBackgroundColor;
}

- (void) touchesEnded:(NSSet *) touches withEvent:(UIEvent *__nullable) event {
	[super touchesEnded:touches withEvent:event];

	self.contentView.backgroundColor = _originalBackgroundColor;

	if (_selectedConnectionHeaderView)
		_selectedConnectionHeaderView();
}

- (void) tintColorDidChange {
	_timeLabel.textColor = self.tintColor;
}

#pragma mark -

- (void) _disclosureButtonPressed:(__nullable id) sender {
	if (_selectedConnectionHeaderView)
		_selectedConnectionHeaderView();
}
@end

NS_ASSUME_NONNULL_END
