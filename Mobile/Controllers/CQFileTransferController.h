//
//  CQFileTransferController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/19/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CQChatController.h"

@class MVFileTransfer;
@class CQFileTransferTableCell;


@interface CQFileTransferController : UIViewController {
    @protected
    MVFileTransfer *_transfer;
	CQFileTransferTableCell *_cell;
	NSTimer *_timer;
}

@property (nonatomic, readonly) MVFileTransfer *transfer;
@property (nonatomic, assign) CQFileTransferTableCell *cell;

- (id) initWithTransfer:(MVFileTransfer *) transfer;

@end
