#import <libxml/xinclude.h>
#import "JVChatTranscript.h"

@interface JVChatTranscript (JVChatTranscriptPrivate)
+ (void) _scanForEmoticons;

- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;

- (void) _switchingStyleEnded:(in NSString *) html;
- (oneway void) _switchStyle:(id) sender;
- (void) _changeChatStyleMenuSelection;
- (void) _updateChatStylesMenu;

- (NSMenu *) _emoticonsMenu;
- (void) _changeChatEmoticonsMenuSelection;
- (void) _updateChatEmoticonsMenu;
- (NSString *) _chatEmoticonsMappingFilePath;
- (NSString *) _chatEmoticonsCSSFileURL;

- (BOOL) _usingSpecificStyle;
- (BOOL) _usingSpecificEmoticons;
@end
