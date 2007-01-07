@interface MVChatUser (MVChatUserAdditions)
- (NSString *) xmlDescription;
- (NSString *) xmlDescriptionWithTagName:(NSString *) tag;

- (NSArray *) standardMenuItems;

- (IBAction) getInfo:(id) sender;

- (IBAction) startChat:(id) sender;
- (IBAction) startDirectChat:(id) sender;
- (IBAction) sendFile:(id) sender;
- (IBAction) addBuddy:(id) sender;

- (IBAction) toggleIgnore:(id) sender;
@end
