//
//  VoltageShiftClient.cpp
//  VoltageShift
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#include "VoltageShiftClient.hpp"

#define super IOUserClient
OSDefineMetaClassAndAbstractStructors(VoltageShiftClient, IOUserClient);

const VoltageShiftClient *VoltageShiftClient::withTask(task_t owningTask)
{
    VoltageShiftClient * client = new VoltageShiftClient;
    
    if (client)
    {
        if (!client->init())
        {
            OSSafeReleaseNULL(client);
        }
        client->fTask = owningTask;
    }
    return client;
}

void VoltageShiftClient::messageHandler(UInt32 type, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
}

bool VoltageShiftClient::initWithTask(task_t owningTask, void *securityID, UInt32 type, OSDictionary *properties)
{
    FuncLog("initWithTask");
    
    return super::initWithTask(owningTask, securityID, type, properties);
}

bool VoltageShiftClient::start(IOService *provider)
{
    FuncLog("start");
    
    if (!super::start(provider))
    {
        return false;
    }
    
    mDevice = OSDynamicCast(VoltageShift, provider);
    
    if (mDevice)
    {
        mDevice->retain();
        return true;
    }
    
    return false;
}

bool VoltageShiftClient::willTerminate(IOService *provider, IOOptionBits options)
{
    FuncLog("willTerminate");
    
    return super::willTerminate(provider, options);
}

bool VoltageShiftClient::didTerminate(IOService *provider, IOOptionBits options, bool * defer)
{
    FuncLog("didTerminate");
    
    //If defer is true, stop will not be called on the user client.
    *defer = false;
    
    return super::didTerminate(provider, options, defer);
}

bool VoltageShiftClient::terminate(IOOptionBits options)
{
    FuncLog("terminate");
    
    return super::terminate(options);
}

// clientClose is called when the user process calls IOServiceClose
IOReturn VoltageShiftClient::clientClose()
{
    FuncLog("clientClose");

    if (mDevice)
    {
        mDevice->closeChildren(this);
    }

    if (!isInactive())
    {
        terminate();
    }
    
    return kIOReturnSuccess;
}

// clientDied is called when the user process terminates unexpectedly, the default implementation simply calls clientClose
IOReturn VoltageShiftClient::clientDied()
{
    FuncLog("clientDied");
    
    return super::clientClose();
}

void VoltageShiftClient::free()
{
    FuncLog("free");
    
    mDevice->release();

    super::free();
}

// stop will be called during the termination process, and should free all resources associated with this client
void VoltageShiftClient::stop(IOService *provider)
{
    FuncLog("stop");
    
    super::stop(provider);
}

// getTargetAndMethodForIndex looks up the external methods - supply a description of the parameters available to be called
IOExternalMethod * VoltageShiftClient::getTargetAndMethodForIndex(IOService * * target, UInt32 index)
{
    static const IOExternalMethod methodDescs[3] =
    {
        { NULL, (IOMethod) &VoltageShiftClient::actionMethodRDMSR, kIOUCStructIStructO, kIOUCVariableStructureSize, kIOUCVariableStructureSize },
        { NULL, (IOMethod) &VoltageShiftClient::actionMethodWRMSR, kIOUCStructIStructO, kIOUCVariableStructureSize, kIOUCVariableStructureSize },
    };
    
    *target = this;
    
    if (index < 3)
    {
        return (IOExternalMethod *) (methodDescs + index);
    }

    return NULL;
}

IOReturn VoltageShiftClient::actionMethodRDMSR(UInt32 *dataIn, UInt32 *dataOut, IOByteCount inputSize, IOByteCount *outputSize)
{
    FuncLog("actionMethodRDMSR");
    
    if (!dataIn || !dataOut)
    {
        return kIOReturnUnsupported;
    }
    
    inout * msrdata    = (inout *) dataIn;
    inout * msroutdata = (inout *) dataOut;
    
    msrdata->param = mDevice->a_rdmsr(msrdata->msr);
    msroutdata->param = msrdata->param;

    DebugLog("RDMSR %X: 0x%llX\n", msrdata->msr, msrdata->param);

    return kIOReturnSuccess;
}

IOReturn VoltageShiftClient::actionMethodWRMSR(UInt32 *dataIn, UInt32 *dataOut, IOByteCount inputSize, IOByteCount *outputSize)
{
    FuncLog("actionMethodWRMSR");
    
    if (!dataIn)
    {
        return kIOReturnUnsupported;
    }
    
    inout * msrdata = (inout *)dataIn;

    mDevice->a_wrmsr(msrdata->msr, msrdata->param);
    
    DebugLog("WRMSR 0x%llX to %X\n", msrdata->param, msrdata->msr);

    return kIOReturnSuccess;
}

IOReturn VoltageShiftClient::clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor * * memory)
{
    *options = 0;
    
    IOBufferMemoryDescriptor * memDesc = IOBufferMemoryDescriptor::withOptions(kIOMemoryKernelUserShared, mDevice->mPrefPanelMemoryBufSize);
    
    if (!memDesc)
    {
        return kIOReturnUnsupported;
    }
    
    bcopy(mDevice->mPrefPanelMemoryBuf, (char *) memDesc->getBytesNoCopy(), mDevice->mPrefPanelMemoryBufSize);
    *memory = memDesc; //Automatically released after memory is mapped into task

    return kIOReturnSuccess;
}
