//
//  AKAvatarSupport.m
//  Avatar Support
//
//  Created by Alexander Kempgen on 27.02.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

//Avatar Support Header
#import "AKAvatarSupport.h"

//MVChatPlugin and MVChatPluginReloadSupport
#import "MVChatPluginManager.h"
//MVChatPluginDirectChatSupport
@class JVDirectChatPanel;
//MVChatPluginChatConnectionSupport
#import "MVChatConnection.h"

//some classes
#import "JVChatMessage.h"
#import "MVChatUser.h"
#import "JVChatRoomMember.h"

//the chat view controller protocol
@protocol JVChatViewController;

//The Subcode (CTCP) string that we react to
NSString *AKAvatarSupportCTCPCommand = @"AVATAR";
//Where we store our avatars
NSString *cacheDir = @"~/Library/Caches/info.colloquy.avatarSupport/";


@implementation AKAvatarSupport

#pragma mark -
#pragma mark MVChatPlugin

- (id) initWithManager:(MVChatPluginManager *)manager
{
	self = [super init];
	//NSLog(@"Avatar Support Plugin loaded");
	
	NSLog(cacheDir);
	if ([[NSFileManager defaultManager] fileExistsAtPath: [cacheDir stringByExpandingTildeInPath]] == NO)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: [cacheDir stringByExpandingTildeInPath] attributes: nil];
		NSLog(@"Avatar Cache Dir created");
	}
//	else
//	{
//		NSLog(@"Avatar Cache Dir exists");
//	}
	
	return self;
}

- (void) dealloc
{
	[super dealloc];
}

#pragma mark -
#pragma mark MVChatPluginReloadSupport

- (void) load
{
	
}

- (void) unload
{
	
}

#pragma mark -
#pragma mark MVChatPluginDirectChatSupport

- (void) processIncomingMessage:(JVMutableChatMessage *)message inView:(id <JVChatViewController>)view
{
	if([[message sender] isMemberOfClass:[JVChatRoomMember class]])
	{
		//TODO: check first if the user already has an icon, no need to do this over and over again. also: check for buddies.
		[self addAvatarToUser:[(JVChatRoomMember *)[message sender] user]];
	}
}

- (void) processOutgoingMessage:(JVMutableChatMessage *)message inView:(id <JVChatViewController>)view
{
	//TODO: do we need to implement this?
}

#pragma mark -
#pragma mark MVChatPluginChatConnectionSupport

- (BOOL) processSubcodeRequest:(NSString *)command withArguments:(NSData *)arguments fromUser:(MVChatUser *)user
{
	//TODO: remove NSLog
//	NSLog([@"AVATAR: Subcode Request: " stringByAppendingString:command]);
//	NSLog([user nickname]);
	
	if ([[command uppercaseString] isEqualToString:AKAvatarSupportCTCPCommand])
	{
		if (arguments)
		{
			NSLog(@"das war ein angebot von %@", [user nickname]);
			
			NSArray *argumentArray = [[[[NSString alloc] initWithData:arguments encoding:[[user connection] encoding]] autorelease] componentsSeparatedByString:@" "];
			NSLog(@"Arguments: %@",[argumentArray description]);
//			if (weWantToReceiveAvatarFromUser:user)
//			{
				NSLog(@"wir wollen annehmen");
				NSImage *receivedImage = [NSImage alloc];
				
				//TODO: do some checks first: filezise, evil filetypes...
				if ([receivedImage initWithContentsOfURL:[NSURL URLWithString:[argumentArray objectAtIndex:0]]])
				{
					[self saveAvatar:receivedImage forUser:user];
					[self addAvatarToUser:user];
					return YES;
				}
//				else
//				{
//					if (filesizeisokay)
//					{
						//NSLog(@"DCC Filetransfer required");
						//[18:39] <xenon> there is, just dont add it to the MVFileTransferManager
						//MVFileTransferController
						//MVFileTransfer
						//filetransfer <- requestAvatarFromUser:user
						//filetransferdelegate: [self addAvatarToUser:user];
//					}
//				}
//			}
		}
		else
		{
			//TODO: remove this!
			NSLog(@"%@ has requested our avatar", [user nickname]);
//			if (weWantToSendAvatarToUser:user)
//			{
				NSLog(@"wir schicken unseren avatar los!");
				return YES;
//			}
		}
	}
	
	return NO;
}

#pragma mark -
#pragma mark Plugin Methods

- (void) saveAvatar:(NSImage *)theImage forUser:(MVChatUser *)chatUser
{
	//TODO: add filetype extensions somehow, overwrite rules
	if([[theImage TIFFRepresentation] writeToFile:[[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]] atomically: NO])
	{
		NSLog(@"Avatar written for user %@.", [chatUser nickname]);
	}
}

- (void) addAvatarToUser:(MVChatUser *)chatUser
{
	if([self avatarForUser:chatUser])
	{
	//TODO This has no actual effect in the app yet
	[chatUser setAttribute:[self avatarForUser:chatUser] forKey:@"MVChatUserPictureAttribute"];
	
	//TODO: Remove this test output of the image
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Added avatar to user"];
	[alert setInformativeText:[chatUser nickname]];
	[alert setIcon:[self avatarForUser:chatUser]];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	//TODO: remove this here and in the header, just for testing
}

- (NSImage *) avatarForUser:(MVChatUser *)chatUser
{
	/*if ([[NSFileManager defaultManager] fileExistsAtPath: [[[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]] stringByAppendingPathExtension:@"png"]])
	{
		NSLog(@"Avatar exists for user %@", [chatUser nickname]);
	}*/
	
	//TODO: what about file type extenstions?
	return [[NSImage alloc]initWithContentsOfFile: [[[cacheDir stringByExpandingTildeInPath] stringByAppendingPathComponent:[chatUser serverAddress]] stringByAppendingPathComponent:[chatUser nickname]]];
}


/*
Context Menu:
Avatar >
Request Avatar
Manually Select Avatar
-
clear cache
-
set my avatar
*/

@end