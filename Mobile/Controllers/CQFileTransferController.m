//
//  CQFileTransferController.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/19/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#import <ChatCore/MVFileTransfer.h>
#import "UIImageAdditions.h"


@implementation CQFileTransferController

@synthesize transfer = _transfer, cell = _cell;

- (id) initWithTransfer:(MVFileTransfer *) transfer {
	if (!(self = [self init])) {
		return nil;
	}
	
	_transfer = [transfer retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileStarted:) name:MVFileTransferStartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileFinished:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileError:) name:MVFileTransferErrorOccurredNotification object:nil];
	
	return self;
}

- (void) dealloc {
    [_transfer release];
	if (_timer.isValid) {
		[_timer invalidate];
	}
    [super dealloc];
}

#pragma mark -

- (void) close {
	if (_timer.isValid) {
		[_timer invalidate];
		_timer = nil;
	}
	_cell = nil;
	[_transfer release];
	_transfer = nil;
}

#pragma mark -

- (void) _timerFired:(NSTimer *) timer {
	if (_transfer.status == MVFileTransferDoneStatus || _transfer.status == MVFileTransferStoppedStatus) {
		[_timer invalidate];
		_timer = nil;
	}
	else {
		[_cell takeValuesFromController:self];
	}
}

- (void) _fileStarted:(NSNotification *)notification {
	if (_cell && !_timer.isValid) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES];
	}
}

- (void) _fileFinished:(NSNotification *) notification {
	[_cell takeValuesFromController:self];
	
	NSString *path;
	if (_transfer.upload) {
		MVUploadFileTransfer *upload = (MVUploadFileTransfer *) _transfer;
		path = upload.source;
	}
	else {
		MVDownloadFileTransfer *download = (MVDownloadFileTransfer *) _transfer;
		path = download.destination;
		
		if ([UIImage isValidImageFormat:path]) {
			UIImage *img = [UIImage imageWithContentsOfFile:path];
			UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), path);
			return;
		}
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:path error:NULL];
	
	[_timer invalidate];
	_timer = nil;
}

- (void) _fileError:(NSNotification *) notification {
	[_cell takeValuesFromController:self];
	
	if (_transfer.upload) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeItemAtPath:((MVUploadFileTransfer *)_transfer).source error:NULL];
	}
	
	[_timer invalidate];
	_timer = nil;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
{
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:(NSString *)contextInfo error:NULL];
}

#pragma mark -

- (BOOL) thumbnailAvailable {
	return (_transfer.upload || (_transfer.download && _transfer.status == MVFileTransferDoneStatus));
}

- (UIImage *) thumbnailWithSize:(CGSize) size {
	NSString *path;
	if (_transfer.upload) {
		path = ((MVUploadFileTransfer *)_transfer).source;
		if (![UIImage isValidImageFormat:path]) {
			return nil;
		}
	}
	else {
		if (_transfer.status == MVFileTransferDoneStatus) {
			path = ((MVDownloadFileTransfer *)_transfer).destination;
		}
		else {
			return nil;
		}
	}
	
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
	
	if (_cell && !_timer.isValid && (_transfer.upload || (_transfer.download && _transfer.status == MVFileTransferNormalStatus))) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES];
	}
	else if (_cell == nil) {
		[_timer invalidate];
		_timer = nil;
	}
}

@end
