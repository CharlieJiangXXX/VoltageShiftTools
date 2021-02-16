//
//  VoltageShiftClient.hpp
//  VoltageShift
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#ifndef VoltageShiftClient_hpp
#define VoltageShiftClient_hpp

#include "Common.h"

class VoltageShift;

class VoltageShiftClient : public IOUserClient
{
    OSDeclareDefaultStructors(VoltageShiftClient);

public:
    virtual bool                    start(
                                        IOService               *       provider                 ) override;
    virtual void                    stop(
                                        IOService               *       provider                 ) override;
    virtual void                    free(                                                        ) override;
    virtual bool                    initWithTask(
                                        task_t                          owningTask,
                                        void                    *       securityID,
                                        UInt32                          type,
                                        OSDictionary            *       properties               ) override;
    virtual IOReturn                clientClose(                                                 ) override;
    virtual IOReturn                clientDied(                                                  ) override;
    virtual bool                    willTerminate(
                                        IOService               *       provider,
                                        IOOptionBits                    options                  ) override;
    virtual bool                    didTerminate(
                                        IOService * provider,
                                        IOOptionBits options,
                                        bool                    *       defer                    ) override;
    virtual bool                    terminate(
                                        IOOptionBits                    options  =  0            ) override;
    virtual IOExternalMethod    *   getTargetAndMethodForIndex(
                                        IOService               *   *   targetP,
                                        UInt32                          index                    ) override;
    virtual IOReturn                clientMemoryForType(
                                        UInt32 type,
                                        IOOptionBits            *       options,
                                        IOMemoryDescriptor      *   *   memory                   ) override;

public:
    void                            messageHandler(
                                        UInt32 type,
                                        const char              *       format,
                                        ...                                                      ) __attribute__ ((format (printf, 3, 4)));
    static const VoltageShiftClient  *  withTask(task_t owningTask);
    virtual IOReturn                    actionMethodRDMSR(UInt32 *dataIn, UInt32 *dataOut, IOByteCount inputSize, IOByteCount *outputSize);
    virtual IOReturn                    actionMethodWRMSR(UInt32 *dataIn, UInt32 *dataOut, IOByteCount inputSize, IOByteCount *outputSize);

public:
    task_t fTask;
    
protected:
    VoltageShift *mDevice;
};

#endif /* VoltageShiftClient_hpp */
