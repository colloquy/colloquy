NS_ASSUME_NONNULL_BEGIN

@interface MVChatUser (MVChatUserAdditions)
@property (readonly, copy) NSString *xmlDescription;
- (NSString *) xmlDescriptionWithTagName:(NSString *) tag;

- (NSArray *) standardMenuItems;

- (IBAction) getInfo:(nullable id) sender;

- (IBAction) startChat:(nullable id) sender;
- (IBAction) startDirectChat:(nullable id) sender;
- (IBAction) sendFile:(nullable id) sender;
- (IBAction) addBuddy:(nullable id) sender;

- (IBAction) toggleIgnore:(nullable id) sender;
@end

NS_ASSUME_NONNULL_END
