@class JVChatTranscript;
@class JVChatMessage;
@class JVChatEvent;
@class JVChatSession;

extern NSString *JVChatTranscriptUpdatedNotification;

@protocol JVChatTranscriptElement <NSObject>
- (/* xmlNode */ void *) node;
- (JVChatTranscript *) transcript;
@end

@interface JVChatTranscript : NSObject {
	NSScriptObjectSpecifier *_objectSpecifier;
	void *_xmlLog; /* xmlDoc * */
	NSMutableArray *_messages;
	NSString *_filePath;
	NSFileHandle *_logFile;
	BOOL _autoWriteChanges;
	BOOL _requiresNewEnvelope;
	unsigned long long _previousLogOffset;
	NSUInteger _elementLimit;
}
+ (id) chatTranscript;
+ (id) chatTranscriptWithChatTranscript:(JVChatTranscript *) transcript;
+ (id) chatTranscriptWithElements:(NSArray *) elements;
+ (id) chatTranscriptWithContentsOfFile:(NSString *) path;
+ (id) chatTranscriptWithContentsOfURL:(NSURL *) url;

- (id) init;
- (id) initWithChatTranscript:(JVChatTranscript *) transcript;
- (id) initWithElements:(NSArray *) elements;
- (id) initWithContentsOfFile:(NSString *) path;
- (id) initWithContentsOfURL:(NSURL *) url;

- (/* xmlDoc */ void *) document;

- (BOOL) isEmpty;
- (NSUInteger) elementCount;
- (NSUInteger) sessionCount;
- (NSUInteger) messageCount;
- (NSUInteger) eventCount;

- (void) setElementLimit:(NSUInteger) limit;
- (NSUInteger) elementLimit;

- (NSArray *) elements;
- (NSArray *) elementsInRange:(NSRange) range;
- (id) elementAtIndex:(NSUInteger) index;
- (id) lastElement;

- (NSArray *) appendElements:(NSArray *) elements;
- (void) appendChatTranscript:(JVChatTranscript *) transcript;

- (NSArray *) messages;
- (NSArray *) messagesInRange:(NSRange) range;
- (JVChatMessage *) messageAtIndex:(NSUInteger) index;
- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier;
- (JVChatMessage *) lastMessage;

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier;

- (JVChatMessage *) appendMessage:(JVChatMessage *) message;
- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope;
- (NSArray *) appendMessages:(NSArray *) messages;
- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope;

- (NSArray *) sessions;
- (NSArray *) sessionsInRange:(NSRange) range;
- (JVChatSession *) sessionAtIndex:(NSUInteger) index;
- (JVChatSession *) lastSession;

- (JVChatSession *) startNewSession;
- (JVChatSession *) appendSession:(JVChatSession *) session;

- (NSArray *) events;
- (NSArray *) eventsInRange:(NSRange) range;
- (JVChatEvent *) eventAtIndex:(NSUInteger) index;
- (JVChatEvent *) lastEvent;

- (BOOL) containsEventWithIdentifier:(NSString *) identifier;

- (JVChatEvent *) appendEvent:(JVChatEvent *) event;

- (NSString *) filePath;
- (void) setFilePath:(NSString *) filePath;

- (NSDateComponents *) dateBegan;

- (NSURL *) source;
- (void) setSource:(NSURL *) source;

- (BOOL) automaticallyWritesChangesToFile;
- (void) setAutomaticallyWritesChangesToFile:(BOOL) option;

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
