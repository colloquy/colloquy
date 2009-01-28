//
//  CQFileTransferTableCell.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ChatCore/MVFileTransfer.h>

@class MVChatUser;
@class CQFileTransferController;

#ifdef ENABLE_SECRETS
@class UIRemoveControl;
#endif


@interface CQFileTransferTableCell : UITableViewCell {
    @protected
	UIImageView *_iconImageView;
	UIProgressView *_progressView;
	UILabel *_userLabel;
	UILabel *_userTitle;
	UILabel *_fileLabel;
	UILabel *_fileTitle;
	BOOL _upload;
#ifdef ENABLE_SECRETS
	UIRemoveControl *_removeControl;
	NSString *_removeConfirmationText;
#endif
	MVFileTransferStatus _status;
}

@property (nonatomic) BOOL showsIcon;
@property (nonatomic) BOOL upload;
@property (nonatomic, copy) NSString *user;
@property (nonatomic, copy) NSString *file;
@property (nonatomic) float progress;
#ifdef ENABLE_SECRETS
@property (nonatomic, copy) NSString *removeConfirmationText;
#endif
@property (nonatomic) MVFileTransferStatus status;

- (void) takeValuesFromController:(CQFileTransferController *) controller;

@end
