#import <Foundation/Foundation.h>

@class JVChatTranscript;
@class JVChatMessage;
@class JVChatEvent;
@class JVChatSession;

NS_ASSUME_NONNULL_BEGIN

extern NSString *JVChatTranscriptUpdatedNotification;

@protocol JVChatTranscriptElement <NSObject>
@property (nullable, readonly) struct _xmlNode *node;
- (nullable JVChatTranscript *) transcript;
@end

@interface JVChatTranscript : NSObject {
	NSScriptObjectSpecifier *_objectSpecifier;
	struct _xmlDoc *_xmlLog;
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
+ (nullable instancetype) chatTranscriptWithContentsOfFile:(NSString *) path;
+ (nullable instancetype) chatTranscriptWithContentsOfURL:(NSURL *) url;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithChatTranscript:(JVChatTranscript *) transcript;
- (instancetype) initWithElements:(NSArray *) elements;
- (nullable instancetype) initWithContentsOfFile:(NSString *) path;
- (nullable instancetype) initWithContentsOfURL:(NSURL *) url;

- (struct _xmlDoc *) document;

@property (readonly, getter=isEmpty) BOOL empty;
@property (readonly) NSUInteger elementCount;
@property (readonly) NSUInteger sessionCount;
@property (readonly) NSUInteger messageCount;
@property (readonly) NSUInteger eventCount;

@property NSUInteger elementLimit;

@property (readonly, copy, nullable) NSArray *elements;
- (nullable NSArray *) elementsInRange:(NSRange) range;
- (nullable id) elementAtIndex:(NSUInteger) index;
@property (readonly, strong, nullable) id lastElement;

- (NSArray *) appendElements:(NSArray *) elements;
- (void) appendChatTranscript:(JVChatTranscript *) transcript;

@property (readonly, copy, nullable) NSArray<JVChatMessage*> *messages;
- (nullable NSArray<JVChatMessage*> *) messagesInRange:(NSRange) range;
- (nullable JVChatMessage *) messageAtIndex:(NSUInteger) index;
- (nullable JVChatMessage *) messageWithIdentifier:(NSString *) identifier;
@property (readonly, strong, nullable) JVChatMessage *lastMessage;

- (BOOL) containsMessageWithIdentifier:(NSString *) identifier;

- (nullable JVChatMessage *) appendMessage:(JVChatMessage *) message;
- (nullable JVChatMessage *) appendMessage:(JVChatMessage *) message forceNewEnvelope:(BOOL) forceEnvelope;
- (NSArray<JVChatMessage*> *) appendMessages:(NSArray *) messages;
- (NSArray<JVChatMessage*> *) appendMessages:(NSArray *) messages forceNewEnvelope:(BOOL) forceEnvelope;

@property (readonly, copy) NSArray<JVChatSession*> *sessions;
- (NSArray<JVChatSession*> *) sessionsInRange:(NSRange) range;
- (JVChatSession *) sessionAtIndex:(NSUInteger) index;
@property (readonly, strong, nullable) JVChatSession *lastSession;

- (nullable JVChatSession *) startNewSession;
- (JVChatSession *) appendSession:(JVChatSession *) session;

@property (readonly, copy) NSArray<JVChatEvent*> *events;
- (NSArray<JVChatEvent*> *) eventsInRange:(NSRange) range;
- (JVChatEvent *) eventAtIndex:(NSUInteger) index;
@property (readonly, strong, nullable) JVChatEvent *lastEvent;

- (BOOL) containsEventWithIdentifier:(NSString *) identifier;

- (JVChatEvent *) appendEvent:(JVChatEvent *) event;

@property (nonatomic, copy, nullable) NSString *filePath;
@property (readonly, copy, nullable) NSCalendarDate *dateBegan;
@property (strong, null_unspecified) NSURL *source;
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

NS_ASSUME_NONNULL_END
