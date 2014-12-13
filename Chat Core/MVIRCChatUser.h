#import "MVChatUser.h"
#import "MVChatUserPrivate.h"

@class MVIRCChatConnection;

extern NSString *MVMetadataKeyForAttributeName(NSString *attributeName);
extern NSString *MVAttributeNameForMetadataKey(NSString *metadataKey);

@interface MVIRCChatUser : MVChatUser {
@private
	BOOL _hasPendingRefreshInformationRequest;
}

+ (NSArray *) servicesNicknames;

- (id) initLocalUserWithConnection:(MVIRCChatConnection *) connection;
- (id) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection;
@end
