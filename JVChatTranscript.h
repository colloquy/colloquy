@class JVChatTranscript;
@class JVChatMessage;
@class JVChatEvent;
@class JVChatSession;

@protocol JVChatTranscriptElement
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
	unsigned long _elementLimit;
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
- (unsigned long) elementCount;
- (unsigned long) sessionCount;
- (unsigned long) messageCount;
- (unsigned long) eventCount;

- (void) setElementLimit:(unsigned int) limit;
- (unsigned int) elementLimit;

- (NSArray *) elements;
- (NSArray *) elementsInRange:(NSRange) range;
- (id) elementAtIndex:(unsigned long) index;
- (id) lastElement;

- (NSArray *) appendElements:(NSArray *) elements;
- (void) appendChatTranscript:(JVChatTranscript *) transcript;

- (NSArray *) messages;
- (NSArray *) messagesInRange:(NSRange) range;
- (JVChatMessage *) messageAtIndex:(unsigned long) index;
- (JVChatMessage *) messageWithIdentifier:(NSString *) identifier;
- (NSArray *) messagesInEnvelopeWithMessage:(JVChatMessage *) message;
- (JVChatMessage *) lastMessage;

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier;

- (JVChatMessage *) appendMessage:(JVChatMessage *) message;
- (JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope;
- (NSArray *) appendMessages:(NSArray *) messages;
- (NSArray *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope;

- (NSArray *) sessions;
- (NSArray *) sessionsInRange:(NSRange) range;
- (JVChatSession *) sessionAtIndex:(unsigned long) index;
- (JVChatSession *) lastSession;

- (JVChatSession *) startNewSession;
- (JVChatSession *) appendSessionWithStartDate:(NSDate *) startDate;

- (NSArray *) events;
- (NSArray *) eventsInRange:(NSRange) range;
- (JVChatEvent *) eventAtIndex:(unsigned long) index;
- (JVChatEvent *) lastEvent;

- (BOOL) containsEventWithIdentifier:(NSString *) identifier;

- (JVChatEvent *) appendEvent:(JVChatEvent *) event;

- (NSString *) filePath;
- (void) setFilePath:(NSString *) filePath;

- (BOOL) automaticallyWritesChangesToFile;
- (BOOL) setAutomaticallyWritesChangesToFile:(BOOL) option;

- (BOOL) writeToFile:(NSString *) path atomically:(BOOL) useAuxiliaryFile;
- (BOOL) writeToURL:(NSURL *) url atomically:(BOOL) atomically;

- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier;
@end