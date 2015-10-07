#undef ENABLE
#define ENABLE(CHAT_FEATURE) (defined(ENABLE_##CHAT_FEATURE) && ENABLE_##CHAT_FEATURE)
#define USE(CHAT_FEATURE) (defined(USE_##CHAT_FEATURE) && USE_##CHAT_FEATURE)

#ifndef ENABLE_AUTO_PORT_MAPPING
#define ENABLE_AUTO_PORT_MAPPING 1
#endif

#ifndef ENABLE_SCRIPTING
#define ENABLE_SCRIPTING 1
#endif

#ifndef ENABLE_PLUGINS
#define ENABLE_PLUGINS 1
#endif

#ifndef ENABLE_IRC
#define ENABLE_IRC 1
#endif

#ifndef ENABLE_SILC
#define ENABLE_SILC 1
#endif

#ifndef ENABLE_ICB
#define ENABLE_ICB 1
#endif

#ifndef ENABLE_XMPP
#define ENABLE_XMPP 1
#endif

#ifndef ENABLE_CHAT_CENTER
#define ENABLE_CHAT_CENTER 1
#endif
