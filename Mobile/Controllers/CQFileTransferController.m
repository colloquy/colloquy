//  Created by August Joki on 1/19/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#import "NSNotificationAdditions.h"

#import <ChatCore/MVFileTransfer.h>

NS_ASSUME_NONNULL_BEGIN

@implementation CQFileTransferController {
@protected
	NSTimer *_timer;
}

- (id) initWithTransfer:(MVFileTransfer *) transfer {
	if (!(self = [self init]))
		return nil;

	_transfer = transfer;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_fileStarted:) name:MVFileTransferStartedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_fileFinished:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_fileError:) name:MVFileTransferErrorOccurredNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
}

#pragma mark -

- (void) close {
	[_timer invalidate];
	_timer = nil;

	_cell = nil;

	_transfer = nil;
}

#pragma mark -

- (void) _timerFired:(NSTimer *) timer {
	if (_transfer.status == MVFileTransferDoneStatus || _transfer.status == MVFileTransferStoppedStatus) {
		[_timer invalidate];
		_timer = nil;
	} else {
		[_cell takeValuesFromController:self];
	}
}

- (void) _fileStarted:(NSNotification *)notification {
	if (!_cell || _timer)
		return;
	_timer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES];
}

- (void) _fileFinished:(NSNotification *) notification {
	[_cell takeValuesFromController:self];

	NSString *path;
	if (_transfer.upload) {
		MVUploadFileTransfer *upload = (MVUploadFileTransfer *)_transfer;
		path = upload.source;
	} else {
		MVDownloadFileTransfer *download = (MVDownloadFileTransfer *)_transfer;
		path = download.destination;

		if ([NSFileManager isValidImageFormat:path]) {
			UIImage *img = [UIImage imageWithContentsOfFile:path];
			UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
			return;
		} else if ([NSFileManager isValidVideoFormat:path] && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
			UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
		} else if ([NSFileManager isValidAudioFormat:path]) {
			
		}
	}

	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	[_timer invalidate];
	_timer = nil;
}

- (void) _fileError:(NSNotification *) notification {
	[_cell takeValuesFromController:self];

	if (_transfer.upload)
		[[NSFileManager defaultManager] removeItemAtPath:((MVUploadFileTransfer *)_transfer).source error:NULL];

	[_timer invalidate];
	_timer = nil;
}

- (void) image:(UIImage *) image didFinishSavingWithError:(NSError *) error contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *download = (MVDownloadFileTransfer *)_transfer;
	[[NSFileManager defaultManager] removeItemAtPath:download.destination error:NULL];
}

- (void) video:(NSString *) videoPath didFinishSavingWithError:(NSError *) error contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *download = (MVDownloadFileTransfer *)_transfer;
	[[NSFileManager defaultManager] removeItemAtPath:download.destination error:NULL];
}

#pragma mark -

- (BOOL) thumbnailAvailable {
	return (_transfer.upload || (_transfer.download && _transfer.status == MVFileTransferDoneStatus));
}

- (UIImage *) thumbnailWithSize:(CGSize) size {
	NSString *path = nil;
	if (_transfer.upload) {
		path = ((MVUploadFileTransfer *)_transfer).source;
	} else {
		if (_transfer.status == MVFileTransferDoneStatus)
			path = ((MVDownloadFileTransfer *)_transfer).destination;
	}

	if (![NSFileManager isValidImageFormat:path])
		return nil;

	return [[UIImage imageWithContentsOfFile:path] resizeToSize:size];
}

#pragma mark -

- (void) setCell:(CQFileTransferTableCell *) cell {
	_cell = cell;

	if (_cell && !_timer && (_transfer.upload || (_transfer.download && _transfer.status == MVFileTransferNormalStatus))) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES];
	} else {
		[_timer invalidate];
		_timer = nil;
	}
}
@end

NS_ASSUME_NONNULL_END

#endif
