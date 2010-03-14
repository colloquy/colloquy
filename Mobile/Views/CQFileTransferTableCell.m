//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

#import "CQFileTransferTableCell.h"
#import "CQFileTransferController.h"

#import <ChatCore/MVFileTransfer.h>
#import <ChatCore/MVChatUser.h>

#define kNormalAlpha 1.
#define kOtherAlpha 0.5

#pragma mark -

@implementation CQFileTransferTableCell

- (void) dealloc {
	[_iconImageView release];
	[_progressView release];
	[_userLabel release];
	[_userTitle release];
	[_fileLabel release];
	[_fileTitle release];
	[_thumb release];

    [super dealloc];
}

#pragma mark -

- (void) takeValuesFromController:(CQFileTransferController *) controller {
	self.user = controller.transfer.user.displayName;
	if ([controller.transfer isKindOfClass:[MVDownloadFileTransfer class]]) {
		self.file = ((MVDownloadFileTransfer *)controller.transfer).originalFileName;
	}
	else {
		self.file = [((MVUploadFileTransfer *)controller.transfer).source lastPathComponent];
	}
	self.progress = (double)controller.transfer.transfered/(double)controller.transfer.finalSize;
	self.upload = controller.transfer.upload;

	if (!_thumb && controller.thumbnailAvailable)
		_thumb = [[controller thumbnailWithSize:CGSizeMake(55., 55.)] retain];

	self.status = controller.transfer.status;

	_controller = controller;
	controller.cell = self;
}


- (BOOL) showsIcon {
	return !_iconImageView.hidden;
}

- (void) setShowsIcon:(BOOL) show {
	_iconImageView.hidden = !show;
	[self setNeedsLayout];
}

- (NSString *) user {
	return _userLabel.text;
}

- (void) setUser:(NSString *) user {
	_userLabel.text = user;
	[self setNeedsLayout];
}

- (NSString *) file {
	return _fileLabel.text;
}

- (void) setFile:(NSString *) file {
	_fileLabel.text = file;
	[self setNeedsLayout];
}

- (BOOL) upload {
	return _upload;
}

- (void) setUpload:(BOOL) upload {
	_upload = upload;
	if (_upload) {
		_userTitle.text = NSLocalizedString(@"To:", @"To: label");
		_fileTitle.text = NSLocalizedString(@"Sending:", @"Sending: label");
	} else {
		_userTitle.text = NSLocalizedString(@"From:", @"From: label");
		_fileTitle.text = NSLocalizedString(@"Receiving:", @"Receiving: label");
	}
	[self setNeedsLayout];
}

- (float) progress {
	return _progressView.progress;
}

- (void) setProgress:(float) progress {
	_progressView.progress = progress;
}

- (MVFileTransferStatus) status {
	return _status;
}

- (void) setStatus:(MVFileTransferStatus) status {
	if (_status != status) {
		[UIView beginAnimations:nil context:NULL];
		_status = status;
		if (_status == MVFileTransferNormalStatus) {
			_userLabel.alpha = _userTitle.alpha = kNormalAlpha;
			_fileLabel.alpha = _fileTitle.alpha = kNormalAlpha;
			_iconImageView.alpha = _progressView.alpha = kNormalAlpha;
			if (_upload) {
				//_iconImageView.image = [UIImage imageNamed:@"directChatIcon.png"];
				_iconImageView.image = _thumb;
			} else {
				_iconImageView.image = [UIImage imageNamed:@"directChatIcon.png"];
			}
		} else {
			_userLabel.alpha = _userTitle.alpha = kOtherAlpha;
			_fileLabel.alpha = _fileTitle.alpha = kOtherAlpha;
			_iconImageView.alpha = _progressView.alpha = kOtherAlpha;

			if (_status == MVFileTransferDoneStatus) {
				//_iconImageView.image = [UIImage imageNamed:@""];
				_iconImageView.image = _thumb;
			} else if (_status == MVFileTransferHoldingStatus) {
				if (_upload) {
					_iconImageView.image = _thumb;
				}
				else {
					_iconImageView.image = [UIImage imageNamed:@"directChatIcon.png"];
				}
			} else if (_status == MVFileTransferStoppedStatus) {
				if (_upload) {
					_iconImageView.image = _thumb;
				}
				else {
					_iconImageView.image = [UIImage imageNamed:@"directChatIcon.png"];
				}
			} else if (_status == MVFileTransferErrorStatus) {
				if (_upload) {
					_iconImageView.image = _thumb;
				}
				else {
					_iconImageView.image = [UIImage imageNamed:@"directChatIcon.png"];
				}
			}
		}
		[UIView commitAnimations];
		[self setNeedsLayout];
	}
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	_iconImageView.image = nil;
	[_thumb release];
	_thumb = nil;
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	if (animated)
		[UIView beginAnimations:nil context:NULL];

	CGFloat alpha = (_status == MVFileTransferNormalStatus || selected) ? kNormalAlpha : kOtherAlpha;
	_userLabel.alpha = _userTitle.alpha = alpha;
	_fileLabel.alpha = _fileTitle.alpha = alpha;
	_iconImageView.alpha = _progressView.alpha = alpha;

	if (animated)
		[UIView commitAnimations];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationCurve:(editing ? UIViewAnimationCurveEaseIn : UIViewAnimationCurveEaseOut)];
	}

	[super setEditing:editing animated:animated];

	if (animated)
		[UIView commitAnimations];
}


- (void) layoutSubviews {
	[super layoutSubviews];

#define NO_ICON_LEFT_MARGIN 14.
#define RIGHT_MARGIN 8.
#define ICON_RIGHT_MARGIN 10.
#define LABEL_SPACING 5.

	CGRect contentRect = self.contentView.bounds;

	CGFloat leftOrigin = (_iconImageView.hidden ? NO_ICON_LEFT_MARGIN : CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN);

	CGRect frame;
	CGRect fileTitleFrame;

	frame = _progressView.frame;
	frame.origin.x = leftOrigin;
	frame.size.width = contentRect.size.width - leftOrigin - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	_progressView.frame = frame;

	[_fileTitle sizeToFit];

	frame = _fileTitle.frame;
	frame.origin.x = leftOrigin;
	_fileTitle.frame = fileTitleFrame = frame;

	frame = _userTitle.frame;
	frame.origin.x = fileTitleFrame.origin.x;
	frame.size.width = fileTitleFrame.size.width;
	_userTitle.frame = frame;

	frame = _userLabel.frame;
	frame.origin.x = fileTitleFrame.origin.x + fileTitleFrame.size.width + LABEL_SPACING;
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	_userLabel.frame = frame;

	frame = _fileLabel.frame;
	frame.origin.x = _userLabel.frame.origin.x;
	frame.size.width = _userLabel.frame.size.width;
	_fileLabel.frame = frame;
}

@end

#endif
