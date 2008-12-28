#if( !defined(USE_ATTRIBUTED_CHAT_STRING) && !defined(USE_PLAIN_CHAT_STRING) && !defined(USE_HTML_CHAT_STRING) )
#define USE_ATTRIBUTED_CHAT_STRING 1
#endif

#if( defined(USE_ATTRIBUTED_CHAT_STRING) && USE_ATTRIBUTED_CHAT_STRING )
#define MVChatString NSAttributedString
#define MVChatStringAsString(s) [(s) string]
#elif( defined(USE_HTML_CHAT_STRING) && USE_HTML_CHAT_STRING )
#define MVChatString NSString
#define MVChatStringAsString(s) (s)
#elif( defined(USE_PLAIN_CHAT_STRING) && USE_PLAIN_CHAT_STRING )
#define MVChatString NSString
#define MVChatStringAsString(s) (s)
#endif
