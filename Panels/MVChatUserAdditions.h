#import <ChatCore/MVChatUser.h>

@interface MVChatUser (MVChatUserAdditions)
- (NSString *) xmlDescription;
- (NSString *) xmlDescriptionWithTagName:(NSString *) tag;
@end
