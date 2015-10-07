@interface NSScriptCommand (NSScriptCommandAdditions)
@property (readonly, strong) id subjectParameter;
@property (strong) NSScriptObjectSpecifier *subjectSpecifier;
@property (readonly) BOOL subjectSupportsCommand;
- (id) executeCommandOnSubject;
- (id) evaluatedDirectParameter;
@end
