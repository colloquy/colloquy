NS_ASSUME_NONNULL_BEGIN

@interface NSScriptCommand (NSScriptCommandAdditions)
@property (readonly, strong) id subjectParameter;
@property (strong) NSScriptObjectSpecifier *subjectSpecifier;
@property (readonly) BOOL subjectSupportsCommand;
- (id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end

NS_ASSUME_NONNULL_END
