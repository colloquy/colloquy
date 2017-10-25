#import <Foundation/Foundation.h>

#import "MVChatUser.h"
#import "MVChatUserPrivate.h"


NS_ASSUME_NONNULL_BEGIN

@class MVIRCChatConnection;

@interface MVIRCChatUser : MVChatUser
#if __has_feature(objc_class_property)
@property (readonly, class, copy) NSArray<NSString*> *servicesNicknames;
#else
+ (NSArray <NSString *> *) servicesNicknames;
#endif

- (instancetype) initLocalUserWithConnection:(MVIRCChatConnection *) connection;
- (instancetype) initWithNickname:(NSString *) nickname andConnection:(MVIRCChatConnection *) connection;
@end

@interface MVIRCChatUser (MVIRCChatUserPrivate)
- (void) persistLastActivityDate;
@end

NS_ASSUME_NONNULL_END
