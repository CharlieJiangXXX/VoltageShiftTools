//
//  VoltageShift.hpp
//  VoltageShift
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#ifndef VoltageShift_hpp
#define VoltageShift_hpp

#include "Common.h"

#define BUFSIZE         512
#define MAXENTRIES      500
#define MAXUSERS        5

#define kMethodObjectUserClient ((IOService *) 0)

class VoltageShiftClient;

struct inout
{
    UInt32 action;
    UInt32 msr;
    UInt64 param;
};

class VoltageShift : public IOService
{
    OSDeclareDefaultStructors(VoltageShift)
    
public:
    virtual bool        init(OSDictionary *dictionary = 0) override;
    virtual void        free() override;
    virtual bool        start(IOService *provider) override;
    virtual void        stop(IOService *provider) override;
    virtual IOReturn    newUserClient(task_t owningTask, void * securityID, UInt32 type, IOUserClient ** handler) override;

public:
    virtual uint64_t    a_rdmsr(uint32_t msr);
    virtual void        a_wrmsr(uint32_t msr, uint64_t value);
    virtual void        closeChildren(VoltageShiftClient *ptr);

public:
    size_t                      mPrefPanelMemoryBufSize;
    uint32_t                    mPrefPanelMemoryBuf[2];
    UInt16                      mClientCount;
    VoltageShiftClient  *       mClientPtr[MAXUSERS + 1];
};

#endif /* VoltageShift_hpp */
