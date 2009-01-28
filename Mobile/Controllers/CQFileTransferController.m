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
    [super dealloc];
}

#pragma mark -

- (void) _timerFired:(NSTimer *) timer {
	[_cell takeValuesFromController:self];
}

- (void) _fileStarted:(NSNotification *)notification {
	[_cell takeValuesFromController:self];
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
}

- (void) _fileError:(NSNotification *) notification {
	[_cell takeValuesFromController:self];
	
	if (_transfer.upload) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeItemAtPath:((MVUploadFileTransfer *)_transfer).source error:NULL];
	}
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
{
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:(NSString *)contextInfo error:NULL];
}

#pragma mark -

- (void) setCell:(CQFileTransferTableCell *) cell {
	_cell = cell;
	
	if (_cell) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:5000 target:self selector:@selector(_timerFired:) userInfo:nil repeats:YES];
	}
	else {
		[_timer invalidate];
	}
}

@end
