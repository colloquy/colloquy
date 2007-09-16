#if( !defined(USE_ATTRIBUTED_CHAT_STRING) && !defined(USE_PLAIN_CHAT_STRING) )
#define USE_ATTRIBUTED_CHAT_STRING 1
#endif

#if( defined(USE_ATTRIBUTED_CHAT_STRING) && USE_ATTRIBUTED_CHAT_STRING )
typedef NSAttributedString MVChatString;
#elif( defined(USE_PLAIN_CHAT_STRING) && USE_PLAIN_CHAT_STRING )
typedef NSString MVChatString;
#endif
