#import "CQConnectionTableCell.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionTableCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if( ! ( self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier] ) )
		return nil;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_badgeImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_serverLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_nicknameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_badgeImageView];
	[self.contentView addSubview:_timeLabel];
	[self.contentView addSubview:_nicknameLabel];
	[self.contentView addSubview:_serverLabel];

	_iconImageView.image = [UIImage imageNamed:@"server.png"];

	_serverLabel.font = [UIFont boldSystemFontOfSize:18.];
	_serverLabel.textColor = self.textColor;
	_serverLabel.highlightedTextColor = self.selectedTextColor;

	_nicknameLabel.font = [UIFont systemFontOfSize:14.];
	_nicknameLabel.textColor = self.textColor;
	_nicknameLabel.highlightedTextColor = self.selectedTextColor;

	_timeLabel.font = [UIFont systemFontOfSize:14.];
	_timeLabel.textColor = [UIColor colorWithRed:0.19607843 green:0.29803922 blue:0.84313725 alpha:1.];
	_timeLabel.highlightedTextColor = self.selectedTextColor;

	return self;
}

- (void) dealloc {
	[_iconImageView release];
	[_badgeImageView release];
	[_serverLabel release];
	[_nicknameLabel release];
	[_timeLabel release];
	[_connectDate release];

	[super dealloc];
}

- (void) takeValuesFromConnection:(MVChatConnection *) connection {
	self.server = connection.server;
	self.nickname = connection.nickname;

	NSDictionary *extraInfo = [connection.persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"];
	self.connectDate = [extraInfo objectForKey:@"connectDate"];

	switch( connection.status ) {
	default:
	case MVChatConnectionDisconnectedStatus:
		self.status = CQConnectionTableCellNotConnectedStatus;
		break;
	case MVChatConnectionServerDisconnectedStatus:
		self.status = CQConnectionTableCellServerDisconnectedStatus;
		break;
	case MVChatConnectionConnectingStatus:
		self.status = CQConnectionTableCellConnectingStatus;
		break;
	case MVChatConnectionConnectedStatus:
		self.status = CQConnectionTableCellConnectedStatus;
		break;
	}
}

- (NSString *) server {
	return _serverLabel.text;
}

- (void) setServer:(NSString *) server {
	_serverLabel.text = server;
}

- (NSString *) nickname {
	return _nicknameLabel.text;
}

- (void) setNickname:(NSString *) nickname {
	_nicknameLabel.text = nickname;
}

- (void) updateConnectTime {
	NSString *newTime = nil;

	if( _connectDate ) {
		NSTimeInterval interval = ABS( [_connectDate timeIntervalSinceNow] );
		unsigned seconds = ((unsigned)interval % 60);
		unsigned minutes = ((unsigned)(interval / 60) % 60);
		unsigned hours = (interval / 3600);

		if( hours ) newTime = [[NSString alloc] initWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
		else newTime = [[NSString alloc] initWithFormat:@"%d:%02d", minutes, seconds];
	}

	if( [_timeLabel.text isEqualToString:newTime] )
		return;

	_timeLabel.text = newTime ? newTime : @"";

	[newTime release];

	[self setNeedsLayout];
}

@synthesize connectDate = _connectDate;

- (void) setConnectDate:(NSDate *) connectDate {
	id old = _connectDate;
	_connectDate = [connectDate retain];
	[old release];

	[self updateConnectTime];
}

@synthesize status = _status;

- (void) setStatus:(CQConnectionTableCellStatus) status {
	if( _status == status )
		return;

	_status = status;

	switch( status ) {
	default:
	case CQConnectionTableCellNotConnectedStatus:
		_badgeImageView.image = nil;
		break;
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

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	UIColor *backgroundColor = nil;
	if( selected || animated ) backgroundColor = nil;
	else backgroundColor = [UIColor whiteColor];

	_serverLabel.backgroundColor = backgroundColor;
	_serverLabel.highlighted = selected;
	_serverLabel.opaque = !selected && !animated;

	_nicknameLabel.backgroundColor = backgroundColor;
	_nicknameLabel.highlighted = selected;
	_nicknameLabel.opaque = !selected && !animated;

	_timeLabel.backgroundColor = backgroundColor;
	_timeLabel.highlighted = selected;
	_timeLabel.opaque = !selected && !animated;
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[UIView beginAnimations:@"CQConnectionTableCellEditing" context:NULL];

	[super setEditing:editing animated:animated];

	_timeLabel.alpha = editing ? 0. : 1.;

	[UIView commitAnimations];
}

- (void) layoutSubviews {
	[super layoutSubviews];

#define ICON_LEFT_MARGIN 10.
#define ICON_RIGHT_MARGIN 10.
#define TEXT_RIGHT_MARGIN 5.

	CGRect contentRect = self.contentView.frame;

	CGRect frame = _iconImageView.frame;
	frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
	frame.origin.x = ICON_LEFT_MARGIN;
	frame.origin.y = (contentRect.size.height / 2.) - (frame.size.height / 2.);
	_iconImageView.frame = frame;

	frame = _badgeImageView.frame;
	frame.size = [_badgeImageView sizeThatFits:_badgeImageView.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) - (frame.size.width / 1.5);
	frame.origin.y = CGRectGetMaxY(_iconImageView.frame) - (frame.size.height / 1.33);
	_badgeImageView.frame = frame;

	frame = _timeLabel.frame;
	frame.size = [_timeLabel sizeThatFits:_timeLabel.bounds.size];
	frame.origin.y = (contentRect.size.height / 2.) - (frame.size.height / 2.);

	if( self.editing )
		frame.origin.x = self.bounds.size.width - contentRect.origin.x;
	else
		frame.origin.x = contentRect.size.width - frame.size.width - TEXT_RIGHT_MARGIN;

	_timeLabel.frame = frame;

	frame = _serverLabel.frame;
	frame.size = [_serverLabel sizeThatFits:_serverLabel.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = (contentRect.size.height / 2.) - frame.size.height + 3.;
	frame.size.width = _timeLabel.frame.origin.x - frame.origin.x - TEXT_RIGHT_MARGIN;
	_serverLabel.frame = frame;

	frame = _nicknameLabel.frame;
	frame.size = [_nicknameLabel sizeThatFits:_nicknameLabel.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = (contentRect.size.height / 2.);
	frame.size.width = _timeLabel.frame.origin.x - frame.origin.x - TEXT_RIGHT_MARGIN;
	_nicknameLabel.frame = frame;
}
@end
