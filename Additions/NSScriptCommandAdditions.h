#import <Foundation/NSScriptCommand.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSScriptCommand (NSScriptCommandAdditions)
@property (readonly, strong, nullable) id subjectParameter;
@property (strong) NSScriptObjectSpecifier *subjectSpecifier;
@property (readonly) BOOL subjectSupportsCommand;
- (nullable id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end

NS_ASSUME_NONNULL_END
