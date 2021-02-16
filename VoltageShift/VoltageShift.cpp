//
//  VoltageShift.cpp
//  VoltageShift
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#include "VoltageShift.hpp"

#define super IOService
OSDefineMetaClassAndStructors (VoltageShift, IOService)

bool VoltageShift::init(OSDictionary * dict)
{
    FuncLog("init");
    
    return super::init(dict);
}

void VoltageShift::free()
{
    FuncLog("free");

    super::free();
}

bool VoltageShift::start(IOService * provider)
{
    FuncLog("start");

    registerService();
    mPrefPanelMemoryBufSize = 4096;

    return super::start(provider);
}

void VoltageShift::stop(IOService * provider)
{
    FuncLog("stop");

    super::stop(provider);
}

inline uint64_t VoltageShift::a_rdmsr(uint32_t msr)
{
    return rdmsr64(msr);
}

inline void VoltageShift::a_wrmsr(uint32_t msr, uint64_t value)
{
    wrmsr64(msr, value);
}

IOReturn VoltageShift::newUserClient( task_t owningTask, void * securityID, UInt32 type, IOUserClient * * handler )
{
    if (mClientCount >= MAXUSERS)
    {
        ErrorLog("Already created 5 user clients!!!\n");
        return kIOReturnError;
    }
    
    VoltageShiftClient * client = (VoltageShiftClient *) VoltageShiftClient::withTask(owningTask);
    
    if (!client)
    {
        ErrorLog("Failed to create user client!!!\n");
        return kIOReturnNoResources;
    }
    
    if (!client->attach(this))
    {
        ErrorLog("Failed to attach user client!!!\n");
        OSSafeReleaseNULL(client);
        return kIOReturnError;
    }
        
    if (!client->start(this))
    {
        ErrorLog("Failed to start user client!!!\n");
        client->detach(this);
        OSSafeReleaseNULL(client);
        return kIOReturnError;
    }
    
    mClientPtr[mClientCount] = client;
        
    *handler = client;
    
    ++mClientCount;
    
    DebugLog("Created client %u: %p\n", mClientCount, mClientPtr[mClientCount]);
    
    return kIOReturnSuccess;
}

void VoltageShift::closeChildren(VoltageShiftClient *ptr)
{
    UInt8 i, index = 0;
    
    if (mClientCount == 0)
    {
        DebugLog("No clients available to close");
        return;
    }

    DebugLog("Closing: %p\n",ptr);
    
    for (i = 0; i < mClientCount; ++i)
    {
        DebugLog("userclient ref: %d %p\n", i, mClientPtr[i]);
        
        if (mClientPtr[i] == ptr)
        {
            --mClientCount;
            mClientPtr[i]->stop(this);
            mClientPtr[i]->free();
            OSSafeReleaseNULL(mClientPtr[i]);
            index = i;
            break;
        }
    }
    
    for (i = index; i < mClientCount; ++i)
    {
        mClientPtr[i] = mClientPtr[i+1];
    }
    
    mClientPtr[mClientCount + 1] = NULL;
}
