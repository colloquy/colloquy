#import <Foundation/Foundation.h>
#import "JVTunes.h"
#import "MVChatPluginManager.h"
#import "MVChatConnection.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"

@implementation JVTunes
- (id) initWithManager:(MVChatPluginManager *) manager {
	self = [super init];
	_script = [[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"iTunes" ofType:@"applescript"]] retain];
	return self;
}

- (void) dealloc {
	[_script release];
	_script = nil;
	[super dealloc];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room {
	if( [command isEqualToString:@"itunes"] ) {
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[[room connection] sendMessageToChatRoom:[room target] attributedMessage:status withEncoding:[room encoding] asAction:YES];
		[room echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toChat:(JVDirectChat *) chat {
	if( [command isEqualToString:@"itunes"] ) {
		NSAttributedString *status = [[[NSAttributedString alloc] initWithString:[[self class] executeAppleScriptString:_script]] autorelease];
		[[chat connection] sendMessageToUser:[chat target] attributedMessage:status withEncoding:[chat encoding] asAction:YES];
		[chat echoSentMessageToDisplay:status asAction:YES];
		return YES;
	}
	return NO;
}

+ (NSString *) executeAppleScriptString:(NSString *) string {
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:string] autorelease];
	NSAppleEventDescriptor *result = [script executeAndReturnError:NULL];

	if( [result numberOfItems] )
		return [result stringValue];

	return nil;
}
@end
