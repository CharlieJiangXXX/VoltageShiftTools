//
//  VoltageShiftTools.h
//  VoltageShiftTools
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#ifndef VoltageShiftTools_h
#define VoltageShiftTools_h

#import <Foundation/Foundation.h>
#import <sstream>
#import <vector>
#include "TargetConditionals.h"

// SET TRUE WHEN YOUR SYSTEM REQUIRE OFFSET
#define OFFSET_TEMP 0

#define kClassName "VoltageShift"

#define MSR_OC_MAILBOX                      0x150
#define MSR_OC_MAILBOX_CMD_OFFSET           32
#define MSR_OC_MAILBOX_RSP_OFFSET           32
#define MSR_OC_MAILBOX_DOMAIN_OFFSET        40
#define MSR_OC_MAILBOX_BUSY_BIT             63
#define OC_MAILBOX_READ_VOLTAGE_CMD         0x10
#define OC_MAILBOX_WHITE_VOLTAGE_CMD        0x11
#define OC_MAILBOX_VALUE_OFFSET             20
#define OC_MAILBOX_RETRY_COUNT              5

#define safe_delete(x) do { if (x) { delete x; x = NULL; } } while (0)

enum kMethods
{
    kMethodRDMSR,
    kMethodWRMSR
};

struct inout
{
    UInt32 action;
    UInt32 msr;
    UInt64 param;
};

struct CPUInfo
{
    double freq;
    double voltage;
    double powerpkg;
    double powercore;
    uint64 temp;
};

struct PowerInfo
{
    double pl1Power;
    double pl2Power;
};

typedef bool TurboStatus;

static inline long long hextoint(const char * s)
{
    return strtoull(s, NULL, 16);
}

/*
* set voltage:  offset <CPU> <GPU> <CPUCache> <SA> <AI/O> <DI/O>
* get info of current setting:    info
* continuous monitor of CPU:      mon
* set Power Limit:                power <PL1> <PL2>
* set Turbo Enabled:              turbo <0/1>
* read MSR:                       read <HEX_MSR>
* write MSR:                      write <HEX_MSR> <HEX_VALUE>
*
*/

class VoltageShiftTools
{
public:
    void init();
    bool start();
    void stop();
    void info();
    void monitor();
    void offset(bool cpu, bool gpu, bool cache, bool sys, bool analogy, bool digital);
    bool power(int p1, int p2);
    bool turbo(bool isEnable);
    bool read(const char * msr);
    bool write(const char * msr, const char * regvalue);
    
protected:
    void loadKext();
    void unloadKext();
    bool getService();
    
    int  readOCMailBox(int domain);
    bool writeOCMailBox(int domain, int offset);
    
    bool getCPUInfo();
    
    void setCPUOffset(int cpuOffset);
    void setGPUOffset(int gpuOffset);
    void setCPUCacheOffset(int cpuCacheOffset);
    void setSystemAgencyOffset(int systemAgencyOffset);
    void setAnalogyIOOffset(int analogyIOOffset);
    void setDigitalIOOffset(int digitalIOOffset);

private:
    void printBits(size_t const size, void const * const ptr);
    
protected:
    io_service_t service;
    io_connect_t connect;
    
    CPUInfo   * m_CPU;
    PowerInfo * m_Power;
    TurboStatus isTurboEnabled;
    
    bool damagemode; //to remove
};

#endif /* VoltageShiftTools_h */
