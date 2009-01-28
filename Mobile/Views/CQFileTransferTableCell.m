//
//  CQFileTransferTableCell.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import "CQFileTransferTableCell.h"
#import "CQFileTransferController.h"

#import <ChatCore/MVFileTransfer.h>
#import <ChatCore/MVChatUser.h>

#define kNormalAlpha 1.
#define kOtherAlpha 0.5

#ifdef ENABLE_SECRETS
@interface UIRemoveControl : UIView
- (void) setRemoveConfirmationLabel:(NSString *) label;
@end

#pragma mark -

@interface UITableViewCell (UITableViewCellPrivate)
- (UIRemoveControl *) _createRemoveControl;
@end
#endif

#pragma mark -

@implementation CQFileTransferTableCell

- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
    if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;
	
	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	_userLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_userLabel.textColor = self.textColor;
	_userLabel.highlightedTextColor = self.selectedTextColor;
	_userTitle = [[UILabel alloc] initWithFrame:CGRectZero];
	_userTitle.font = [UIFont boldSystemFontOfSize:18.];
	_userTitle.textColor = self.textColor;
	_userTitle.highlightedTextColor = self.selectedTextColor;
	_fileLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_fileLabel.textColor = self.textColor;
	_fileLabel.highlightedTextColor = self.selectedTextColor;
	_fileTitle = [[UILabel alloc] initWithFrame:CGRectZero];
	_fileTitle.font = [UIFont boldSystemFontOfSize:18.];
	_fileTitle.textColor = self.textColor;
	_fileTitle.highlightedTextColor = self.selectedTextColor;
	
	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_progressView];
	[self.contentView addSubview:_userLabel];
	[self.contentView addSubview:_userTitle];
	[self.contentView addSubview:_fileLabel];
	[self.contentView addSubview:_fileTitle];
	
    return self;
}


- (void) dealloc {
	[_iconImageView release];
	[_progressView release];
	[_userLabel release];
	[_userTitle release];
	[_fileLabel release];
	[_fileTitle release];
#ifdef ENABLE_SECRETS
	[_removeControl release];
	[_removeConfirmationText release];
#endif
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
	self.status = controller.transfer.status;
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

#ifdef ENABLE_SECRETS
@synthesize removeConfirmationText = _removeConfirmationText;

- (void) setRemoveConfirmationText:(NSString *) text {
	id old = _removeConfirmationText;
	_removeConfirmationText = [text copy];
	[old release];
	
	if (_removeConfirmationText.length && [_removeControl respondsToSelector:@selector(setRemoveConfirmationLabel:)])
		[_removeControl setRemoveConfirmationLabel:_removeConfirmationText];
}
#endif

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
	_status = status;
	if (_status == MVFileTransferNormalStatus) {
		_userLabel.alpha = _userTitle.alpha = kNormalAlpha;
		_fileLabel.alpha = _fileTitle.alpha = kNormalAlpha;
		_iconImageView.alpha = _progressView.alpha = kNormalAlpha;
		if (_upload) {
			_iconImageView.image = [UIImage imageNamed:@""];
		} else {
			_iconImageView.image = [UIImage imageNamed:@""];
		}
	} else {
		_userLabel.alpha = _userTitle.alpha = kOtherAlpha;
		_fileLabel.alpha = _fileTitle.alpha = kOtherAlpha;
		_iconImageView.alpha = _progressView.alpha = kOtherAlpha;
		
		if (_status == MVFileTransferDoneStatus) {
			_iconImageView.image = [UIImage imageNamed:@""];
		} else if (_status == MVFileTransferHoldingStatus) {
			_iconImageView.image = [UIImage imageNamed:@""];
		} else if (_status == MVFileTransferStoppedStatus) {
			_iconImageView.image = [UIImage imageNamed:@""];
		} else if (_status == MVFileTransferErrorStatus) {
			_iconImageView.image = [UIImage imageNamed:@""];
		}
	}
	[self setNeedsLayout];
}

#pragma mark -

#ifdef ENABLE_SECRETS
- (UIRemoveControl *) _createRemoveControl {
	[_removeControl release];
	_removeControl = [[super _createRemoveControl] retain];
	if (_removeConfirmationText.length && [_removeControl respondsToSelector:@selector(setRemoveConfirmationLabel:)])
		[_removeControl setRemoveConfirmationLabel:_removeConfirmationText];
	return _removeControl;
}
#endif

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];
	
	self.user = @"";
	self.file = @"";
	[_iconImageView release];
	_iconImageView = nil;
	
#ifdef ENABLE_SECRETS
	self.removeConfirmationText = nil;
#endif
	
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];
	
	if (animated)
		[UIView beginAnimations:nil context:NULL];
	
	CGFloat alpha = (_status == MVFileTransferNormalStatus || selected ? kNormalAlpha : kOtherAlpha);
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
	
#define TOP_TEXT_MARGIN -1.
#define LEFT_MARGIN 10.
#define NO_ICON_LEFT_MARGIN 14.
#define RIGHT_MARGIN 6.
#define ICON_RIGHT_MARGIN 10.
#define LABEL_SPACING_VERTICAL 2.
#define LABEL_SPACING_HORIZONTAL 5.
	
	CGRect contentRect = self.contentView.bounds;
	
	CGRect frame;
	if (!_iconImageView.hidden) {
		frame = _iconImageView.frame;
		frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
		frame.origin.x = contentRect.origin.x + LEFT_MARGIN;
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
		_iconImageView.frame = frame;
	}
	
	frame = _userTitle.frame;
	frame.size = [_userTitle sizeThatFits:_userTitle.bounds.size];
	
	CGFloat labelHeights = frame.size.height;
	labelHeights += 2*(labelHeights - LABEL_SPACING_VERTICAL);
	
	CGFloat leftOrigin = (_iconImageView.hidden ? NO_ICON_LEFT_MARGIN : CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN);
	
	frame.origin.x = leftOrigin;
	frame.origin.y = round((contentRect.size.height / 2.) - (labelHeights / 2.)) + TOP_TEXT_MARGIN;
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	
	frame.size.height = _progressView.frame.size.height;
	_progressView.frame = frame;
	
	frame.size = _userTitle.frame.size;
	frame.origin.y = frame.origin.y + frame.size.height - LABEL_SPACING_VERTICAL;
	_userTitle.frame = frame;
	
	frame.origin.x = leftOrigin + frame.size.width + LABEL_SPACING_HORIZONTAL;
	frame.size = [_userLabel sizeThatFits:_userLabel.bounds.size];
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	_userLabel.frame = frame;
	
	frame.origin.x = leftOrigin;
	frame.origin.y = frame.origin.y + frame.size.height - LABEL_SPACING_VERTICAL;
	_fileTitle.frame = frame;
	
	frame.origin.x = leftOrigin + frame.size.width + LABEL_SPACING_HORIZONTAL;
	frame.size = [_fileLabel sizeThatFits:_fileLabel.bounds.size];
	frame.size.width = contentRect.size.width - frame.origin.x - (!self.showingDeleteConfirmation ? RIGHT_MARGIN : 0.);
	_fileLabel.frame = frame;
}


@end
