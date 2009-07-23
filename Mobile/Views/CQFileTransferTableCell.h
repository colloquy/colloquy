//
//  CQFileTransferTableCell.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <ChatCore/MVFileTransfer.h>

@class MVChatUser;
@class CQFileTransferController;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@class UIRemoveControl;
#endif

@interface CQFileTransferTableCell : UITableViewCell {
    @protected
	IBOutlet UIImageView *_iconImageView;
	IBOutlet UIProgressView *_progressView;
	IBOutlet UILabel *_userLabel;
	IBOutlet UILabel *_userTitle;
	IBOutlet UILabel *_fileLabel;
	IBOutlet UILabel *_fileTitle;
#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	UIRemoveControl *_removeControl;
	NSString *_removeConfirmationText;
#endif
	MVFileTransferStatus _status;
	CQFileTransferController *_controller;
	UIImage *_thumb;
	BOOL _upload;
}

@property (nonatomic) BOOL showsIcon;
@property (nonatomic) BOOL upload;
@property (nonatomic, copy) NSString *user;
@property (nonatomic, copy) NSString *file;
@property (nonatomic) float progress;
@property (nonatomic) MVFileTransferStatus status;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@property (nonatomic, copy) NSString *removeConfirmationText;
#endif

- (void) takeValuesFromController:(CQFileTransferController *) controller;

@end
