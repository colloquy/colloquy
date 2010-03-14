//  Created by August Joki on 1/19/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"

#import <ChatCore/MVFileTransfer.h>

@implementation CQFileTransferController

@synthesize transfer = _transfer;
@synthesize cell = _cell;

- (id) initWithTransfer:(MVFileTransfer *) transfer {
	if (!(self = [self init]))
		return nil;

	_transfer = [transfer retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileStarted:) name:MVFileTransferStartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileFinished:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileError:) name:MVFileTransferErrorOccurredNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

    [_transfer release];
	[_timer release];

    [super dealloc];
}

#pragma mark -

- (void) close {
	[_timer invalidate];
	[_timer release];
	_timer = nil;

	_cell = nil;

	[_transfer release];
	_transfer = nil;
}

#pragma mark -

- (void) _timerFired:(NSTimer *) timer {
	if (_transfer.status == MVFileTransferDoneStatus || _transfer.status == MVFileTransferStoppedStatus) {
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	} else {
		[_cell takeValuesFromController:self];
	}
}

- (void) _fileStarted:(NSNotification *)notification {
	if (!_cell || _timer)
		return;
	_timer = [[NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES] retain];
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

		if ([UIImage isValidImageFormat:path]) {
			UIImage *img = [UIImage imageWithContentsOfFile:path];
			UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
			return;
		}
	}

	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	[_timer invalidate];
	[_timer release];
	_timer = nil;
}

- (void) _fileError:(NSNotification *) notification {
	[_cell takeValuesFromController:self];

	if (_transfer.upload)
		[[NSFileManager defaultManager] removeItemAtPath:((MVUploadFileTransfer *)_transfer).source error:NULL];

	[_timer invalidate];
	[_timer release];
	_timer = nil;
}

- (void) image:(UIImage *) image didFinishSavingWithError:(NSError *) error contextInfo:(void *) contextInfo {
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

	if (![UIImage isValidImageFormat:path])
		return nil;

	UIImage *original = [UIImage imageWithContentsOfFile:path];

	UIGraphicsBeginImageContext(size);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(context, 0., size.height);
	CGContextScaleCTM(context, 1., -1.);
	CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), original.CGImage);
	UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return thumbnail;
}

#pragma mark -

- (void) setCell:(CQFileTransferTableCell *) cell {
	_cell = cell;

	if (_cell && !_timer && (_transfer.upload || (_transfer.download && _transfer.status == MVFileTransferNormalStatus))) {
		_timer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES] retain];
	} else {
		[_timer invalidate];
		[_timer release];
		_timer = nil;
	}
}
@end

#endif
