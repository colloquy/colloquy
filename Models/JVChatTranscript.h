@class JVChatTranscript;
@class JVChatMessage;
@class JVChatEvent;
@class JVChatSession;

extern NSString *JVChatTranscriptUpdatedNotification;

@protocol JVChatTranscriptElement <NSObject>
@property (readonly) struct _xmlNode *node;
- (JVChatTranscript *) transcript;
@end

@interface JVChatTranscript : NSObject {
	NSScriptObjectSpecifier *_objectSpecifier;
	struct _xmlDoc *_xmlLog; /* xmlDoc * */
	NSMutableArray *_messages;
	NSString *_filePath;
	NSFileHandle *_logFile;
	BOOL _autoWriteChanges;
	BOOL _requiresNewEnvelope;
	unsigned long long _previousLogOffset;
	NSUInteger _elementLimit;
}
+ (instancetype) chatTranscript;
+ (instancetype) chatTranscriptWithChatTranscript:(JVChatTranscript *) transcript;
+ (instancetype) chatTranscriptWithElements:(NSArray *) elements;
+ (instancetype) chatTranscriptWithContentsOfFile:(NSString *) path;
+ (instancetype) chatTranscriptWithContentsOfURL:(NSURL *) url;

- (instancetype) init;
- (instancetype) initWithChatTranscript:(JVChatTranscript *) transcript;
- (instancetype) initWithElements:(NSArray *) elements;
- (instancetype) initWithContentsOfFile:(NSString *) path;
- (instancetype) initWithContentsOfURL:(NSURL *) url;

- (struct _xmlDoc *) document;

@property (readonly, getter=isEmpty) BOOL empty;
@property (readonly) NSUInteger elementCount;
@property (readonly) NSUInteger sessionCount;
@property (readonly) NSUInteger messageCount;
@property (readonly) NSUInteger eventCount;

@property NSUInteger elementLimit;

@property (readonly, copy) NSArray *elements;
- (NSArray *) elementsInRange:(NSRange) range;
- (id) elementAtIndex:(NSUInteger) index;
@property (readonly, strong) id lastElement;

- (NSArray *) appendElements:(NSArray *) elements;
- (void) appendChatTranscript:(JVChatTranscript *) transcript;

@property (readonly, copy) NSArray *messages;
- (NSArray *) messagesInRange:(NSRange) range;
- (JVChatMessage *) messageAtIndex:(NSUInteger) index;
- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier;
@property (readonly, strong) JVChatMessage *lastMessage;

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier;

- (JVChatMessage *) appendMessage:(JVChatMessage *) message;
- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope;
- (NSArray *) appendMessages:(NSArray *) messages;
- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope;

@property (readonly, copy) NSArray *sessions;
- (NSArray *) sessionsInRange:(NSRange) range;
- (JVChatSession *) sessionAtIndex:(NSUInteger) index;
@property (readonly, strong) JVChatSession *lastSession;

@property (readonly, strong) JVChatSession *startNewSession;
- (JVChatSession *) appendSession:(JVChatSession *) session;

@property (readonly, copy) NSArray *events;
- (NSArray *) eventsInRange:(NSRange) range;
- (JVChatEvent *) eventAtIndex:(NSUInteger) index;
@property (readonly, strong) JVChatEvent *lastEvent;

- (BOOL) containsEventWithIdentifier:(NSString *) identifier;

- (JVChatEvent *) appendEvent:(JVChatEvent *) event;

@property (copy) NSString *filePath;
@property (readonly, copy) NSCalendarDate *dateBegan;
@property (strong) NSURL *source;
@property BOOL automaticallyWritesChangesToFile;

- (BOOL) writeToFile:(NSString *) path atomically:(BOOL) atomically;
- (BOOL) writeToURL:(NSURL *) url atomically:(BOOL) atomically;

- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier;
@end

#pragma mark -

typedef struct _xmlNode xmlNode;
typedef xmlNode *xmlNodePtr;
@interface JVChatTranscript (Private)
- (void) _enforceElementLimit;
- (void) _incrementalWriteToLog:(xmlNodePtr) node continuation:(BOOL) cont;
- (void) _changeFileAttributesAtPath:(NSString *) path;
- (void) _loadMessage:(JVChatMessage *) message;
- (void) _loadSenderForMessage:(JVChatMessage *) message;
- (void) _loadBodyForMessage:(JVChatMessage *) message;
@end
