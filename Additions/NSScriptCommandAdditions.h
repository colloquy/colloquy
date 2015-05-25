NS_ASSUME_NONNULL_BEGIN

@interface NSScriptCommand (NSScriptCommandAdditions)
- (id) subjectParameter;
- (NSScriptObjectSpecifier *) subjectSpecifier;
- (void) setSubjectSpecifier:(NSScriptObjectSpecifier *) subject;
- (BOOL) subjectSupportsCommand;
- (id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end

NS_ASSUME_NONNULL_END
