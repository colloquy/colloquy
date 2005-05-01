#include <AvailabilityMacros.h>

#ifdef MAC_OS_X_VERSION_10_4

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>

#define PLUGIN_ID "04A856E0-880E-41BA-ABFA-35F147710AFC"

// The import function to be implemented in GetMetadataForFile.c
Boolean GetMetadataForFile(void *thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile);
			   
// The layout for an instance of MetaDataImporterPlugIn 
typedef struct __MetadataImporterPluginType
{
	MDImporterInterfaceStruct *conduitInterface;
	CFUUIDRef                 factoryID;
	UInt32                    refCount;
} MetadataImporterPluginType;


MetadataImporterPluginType  *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID);
void                      DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance);
HRESULT                   MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv);
void                     *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID);
ULONG                     MetadataImporterPluginAddRef(void *thisInstance);
ULONG                     MetadataImporterPluginRelease(void *thisInstance);

static MDImporterInterfaceStruct testInterfaceFtbl = {
	NULL,
	MetadataImporterQueryInterface,
	MetadataImporterPluginAddRef,
	MetadataImporterPluginRelease,
	GetMetadataForFile
};

MetadataImporterPluginType *AllocMetadataImporterPluginType(CFUUIDRef inFactoryID)
{
	MetadataImporterPluginType *theNewInstance;

	theNewInstance = (MetadataImporterPluginType *)malloc(sizeof(MetadataImporterPluginType));
	memset(theNewInstance,0,sizeof(MetadataImporterPluginType));

		/* Point to the function table */
	theNewInstance->conduitInterface = &testInterfaceFtbl;

		/*  Retain and keep an open instance refcount for each factory. */
	theNewInstance->factoryID = CFRetain(inFactoryID);
	CFPlugInAddInstanceForFactory(inFactoryID);

		/* This function returns the IUnknown interface so set the refCount to one. */
	theNewInstance->refCount = 1;
	return theNewInstance;
}

void DeallocMetadataImporterPluginType(MetadataImporterPluginType *thisInstance)
{
	CFUUIDRef theFactoryID;

	theFactoryID = thisInstance->factoryID;
	free(thisInstance);
	if (theFactoryID){
		CFPlugInRemoveInstanceForFactory(theFactoryID);
		CFRelease(theFactoryID);
	}
}

HRESULT MetadataImporterQueryInterface(void *thisInstance,REFIID iid,LPVOID *ppv)
{
	CFUUIDRef interfaceID;

	interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault,iid);

	if (CFEqual(interfaceID,kMDImporterInterfaceID)){
			/* If the Right interface was requested, bump the ref count,
			 * set the ppv parameter equal to the instance, and
			 * return good status.
			 */
		((MetadataImporterPluginType*)thisInstance)->conduitInterface->AddRef(thisInstance);
		*ppv = thisInstance;
		CFRelease(interfaceID);
		return S_OK;
	}else{
		if (CFEqual(interfaceID,IUnknownUUID)){
				/* If the IUnknown interface was requested, same as above. */
			((MetadataImporterPluginType*)thisInstance )->conduitInterface->AddRef(thisInstance);
			*ppv = thisInstance;
			CFRelease(interfaceID);
			return S_OK;
		}else{
				/* Requested interface unknown, bail with error. */
			*ppv = NULL;
			CFRelease(interfaceID);
			return E_NOINTERFACE;
		}
	}
}

ULONG MetadataImporterPluginAddRef(void *thisInstance)
{
	((MetadataImporterPluginType *)thisInstance )->refCount += 1;
	return ((MetadataImporterPluginType*) thisInstance)->refCount;
}

ULONG MetadataImporterPluginRelease(void *thisInstance)
{
	((MetadataImporterPluginType*)thisInstance)->refCount -= 1;
	if (((MetadataImporterPluginType*)thisInstance)->refCount == 0){
		DeallocMetadataImporterPluginType((MetadataImporterPluginType*)thisInstance );
		return 0;
	}else{
		return ((MetadataImporterPluginType*) thisInstance )->refCount;
	}
}

void *MetadataImporterPluginFactory(CFAllocatorRef allocator,CFUUIDRef typeID)
{
	MetadataImporterPluginType *result;
	CFUUIDRef                 uuid;

		/* If correct type is being requested, allocate an
		 * instance of TestType and return the IUnknown interface.
		 */
	if (CFEqual(typeID,kMDImporterTypeID)){
		uuid = CFUUIDCreateFromString(kCFAllocatorDefault,CFSTR(PLUGIN_ID));
		result = AllocMetadataImporterPluginType(uuid);
		CFRelease(uuid);
		return result;
	}
		/* If the requested type is incorrect, return NULL. */
	return NULL;
}

#endif