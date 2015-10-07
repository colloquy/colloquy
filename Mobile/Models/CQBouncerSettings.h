#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQBouncerSettings : NSObject
- (instancetype) initWithDictionaryRepresentation:(NSDictionary *) info NS_DESIGNATED_INITIALIZER;

- (NSMutableDictionary *) dictionaryRepresentation;

@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic) MVChatConnectionBouncer type;

@property (nonatomic, copy) NSString *displayName;

@property (nonatomic, copy) NSString *server;
@property (nonatomic) unsigned short serverPort;

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

@property (nonatomic) BOOL pushNotifications;
@end

NS_ASSUME_NONNULL_END
