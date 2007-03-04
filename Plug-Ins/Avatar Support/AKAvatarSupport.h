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


@interface AKAvatarSupport : NSObject <MVChatPlugin> {

}

- (void) saveAvatar:(NSImage *)anImage forUser:(MVChatUser *)chatUser;
- (void) addAvatarToUser:(MVChatUser *)chatUser;
- (NSImage *) avatarForUser:(MVChatUser *)chatUser;

//TODO: remove this when testing is done
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end
