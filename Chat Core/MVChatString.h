#if( !defined(USE_ATTRIBUTED_CHAT_STRING) && !defined(USE_PLAIN_CHAT_STRING) )
#define USE_ATTRIBUTED_CHAT_STRING 1
#endif

#if( defined(USE_ATTRIBUTED_CHAT_STRING) && USE_ATTRIBUTED_CHAT_STRING )
#define MVChatString NSAttributedString
#elif( defined(USE_PLAIN_CHAT_STRING) && USE_PLAIN_CHAT_STRING )
#define MVChatString NSString
#endif
