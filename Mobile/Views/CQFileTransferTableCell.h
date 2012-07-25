//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import <ChatCore/MVFileTransfer.h>

@class MVChatUser;
@class CQFileTransferController;

@interface CQFileTransferTableCell : UITableViewCell {
@private
	IBOutlet UIImageView *_iconImageView;
	IBOutlet UIProgressView *_progressView;
	IBOutlet UILabel *_userLabel;
	IBOutlet UILabel *_userTitle;
	IBOutlet UILabel *_fileLabel;
	IBOutlet UILabel *_fileTitle;
	MVFileTransferStatus _status;
	CQFileTransferController *_controller;
	UIImage *_thumb;
	BOOL _upload;
}

@property (nonatomic) BOOL showsIcon;

- (void) takeValuesFromController:(CQFileTransferController *) controller;
@end
