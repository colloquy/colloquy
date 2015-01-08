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

- (instancetype) initLocalUserWithConnection:(MVIRCChatConnection *) connection;
- (instancetype) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection;
@end

@interface MVIRCChatUser (MVIRCChatUserPrivate)
- (void) persistLastActivityDate;
@end
