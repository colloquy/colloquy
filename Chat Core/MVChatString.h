#if( defined(USE_ATTRIBUTED_CHAT_STRING) && USE_ATTRIBUTED_CHAT_STRING )
typedef NSAttributedString MVChatString;
#elif( defined(USE_PLAIN_CHAT_STRING) && USE_PLAIN_CHAT_STRING )
typedef NSString MVChatString;
#else
#error No chat string type defined.
#endif
