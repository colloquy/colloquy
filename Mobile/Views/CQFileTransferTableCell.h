//  Created by August Joki on 1/21/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

#import <ChatCore/MVFileTransfer.h>

@class CQFileTransferController;

NS_ASSUME_NONNULL_BEGIN

@interface CQFileTransferTableCell : UITableViewCell
@property (nonatomic) BOOL showsIcon;

- (void) takeValuesFromController:(CQFileTransferController *) controller;
@end

NS_ASSUME_NONNULL_END

#endif
