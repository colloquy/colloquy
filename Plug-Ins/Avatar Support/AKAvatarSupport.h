//
//  AKAvatarSupport.h
//  Avatar Support
//
//  Created by Alexander Kempgen on 27.02.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MVChatPlugin;

@class MVChatUser;


@interface AKAvatarSupport : NSObject <MVChatPlugin>
{
	//NSMutableSet *_throttledRequests;
}
- (IBAction) requestAvatarMenuItemAction:(id) sender;
- (IBAction) offerAvatarMenuItemAction:(id) sender;

- (void) requestAvatarFromUser:(MVChatUser *)chatUser;
- (void) offerAvatarToUser:(MVChatUser *)chatUser;

- (void) saveAvatar:(NSImage *)anImage forUser:(MVChatUser *)chatUser;
- (void) addAvatarToUser:(MVChatUser *)chatUser;
- (NSImage *) avatarForUser:(MVChatUser *)chatUser;

@end
