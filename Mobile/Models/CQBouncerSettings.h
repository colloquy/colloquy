#import "MVChatConnection.h"

@interface CQBouncerSettings : NSObject {
	NSString *_identifier;
	NSString *_displayName;
	NSString *_server;
	NSString *_username;
	NSString *_password;
	unsigned short _serverPort;
	MVChatConnectionBouncer _type;
}
- (id) initWithDictionaryRepresentation:(NSDictionary *) info;

- (NSMutableDictionary *) dictionaryRepresentation;

@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, assign) MVChatConnectionBouncer type;

@property (nonatomic, copy) NSString *displayName;

@property (nonatomic, copy) NSString *server;
@property (nonatomic, assign) unsigned short serverPort;

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@end
