//
//  VoltageShiftTools.mm
//  VoltageShiftTools
//
//  Copyright © 2021 Charlie Jiang. All rights reserved.
//

#include "VoltageShiftTools.h"

void VoltageShiftTools::init()
{
    service = 0;
    connect = 0;
    
    m_CPU   = NULL;
    m_Power = NULL;
    
    isTurboEnabled = false;
    
    damagemode = false;
}

bool VoltageShiftTools::start()
{
    int count = 0;
    
    while (!service)
    {
        getService();
        
        if (!service)
        {
            loadKext();
        }
        
        ++count;
        
        //If the kext is still not loaded after 10 times, stop the process
        if (count > 10)
        {
            return false;
        }
    }
    
    if (IOServiceOpen(service, mach_task_self(), 0, &connect) != KERN_SUCCESS)
    {
        printf("Couldn't open IO Service\n");
        return false;
    }
    
    return true;
}

void VoltageShiftTools::stop()
{
    safe_delete(m_CPU);
    safe_delete(m_Power);
    unloadKext();
}

void VoltageShiftTools::info()
{
    printf("CPU Voltage Offset: %dmv\n", readOCMailBox(0));
    printf("GPU Voltage Offset: %dmv\n", readOCMailBox(1));
    printf("CPU Cache Voltage Offset: %dmv\n", readOCMailBox(2));
    printf("System Agency offset: %dmv\n", readOCMailBox(3));
    printf("Analogy I/O: %dmv\n", readOCMailBox(4));
    printf("Digital I/O: %dmv\n", readOCMailBox(5));
    getCPUInfo();
    printf("\n");
}

void VoltageShiftTools::monitor()
{
    while (1)
    {
        info();
        sleep(1);
    }
}

void VoltageShiftTools::offset(bool cpu, bool gpu, bool cache, bool sys, bool analogy, bool digital)
{
    //get from user interface
    int cpuOffset, gpuOffset, cpuCacheOffset, systemAgencyOffset, analogyIOOffset, digitalIOOffset;
    
    if (cpu)
    {
        setCPUOffset(cpuOffset);
    }
    if (gpu)
    {
        setGPUOffset(gpuOffset);
    }
    if (cache)
    {
        setCPUCacheOffset(cpuCacheOffset);
    }
    if (sys)
    {
        setSystemAgencyOffset(systemAgencyOffset);
    }
    if (analogy)
    {
        setAnalogyIOOffset(analogyIOOffset);
    }
    if (digital)
    {
        setDigitalIOOffset(digitalIOOffset);
    }
}

bool VoltageShiftTools::power(int p1, int p2)
{
    /*
     *
     *  PL1 - long term power limited
     *  PL2 - short term power limited
     *
     */
    
    inout in, out;
    size_t outsize = sizeof(out);

    in.action = kMethodRDMSR;
    in.param = 0;
    in.msr = 0x610;

    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
       printf("FAILED TO READ READ VOLTAGE 0x610!\n");
       return false;
    }
    
    m_Power->pl1Power = (double) (out.param       & 0x7FFF ) / 8;
    m_Power->pl2Power = (double) (out.param >> 32 & 0x7FFF ) / 8;
    
    printf("Current Setting: PL1(Long term): %.fW, PL2(Short term) %.fW\n", m_Power->pl1Power, m_Power->pl2Power);

    if (p1 < 40 || p2 < 40)
    {
       printf("Your setting is too low - set a new one higher than 5W.\n");
       return false;
    }

    for (int i = 0; i < 15; ++i)
    {
       out.param ^= (-(p1 >> i & 0x1) ^ out.param) & (1UL << i);
    }

    for (int i = 32; i < 47; ++i)
    {
       out.param ^= (-(p2 >> i & 0x1) ^ out.param) & (1UL << i);
    }

    in.action = kMethodWRMSR;
    in.param  = out.param;

    if (IOConnectCallStructMethod(connect, kMethodWRMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("Can't connect to StructMethod to send commands\n");
        return false;
    }
    printf("Modified Setting: PL1(Long term): %dW, PL2(Short term) %dW\n", p1 / 8, p2 / 8);
    return true;
}

bool VoltageShiftTools::turbo(bool isEnable)
{
    
    /*
     *
     *  isEnable: 0 - disable Intel Turbo
     *            1 - enable  Intel Turbo
     *
     */
    
    inout in, out;
    size_t outsize = sizeof(out);
    
    in.action = kMethodRDMSR;
    in.param = 0;
    in.msr = 0x1a0;
    
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x1A0!\n");
        return false;
    }
    isTurboEnabled = ((out.param >> 38 & 0x1) > 0) ? false : true;
    
    printf("Current Setting: Turbo Boost %s\n", isTurboEnabled ? "Enabled" : "Disabled");
    
    isTurboEnabled = isEnable;
    
    out.param ^= (-(isTurboEnabled >> 38 & 0x1) ^ out.param) & (1UL << 38);
    
    in.action = kMethodWRMSR;
    in.param = out.param;
    
    if (IOConnectCallStructMethod(connect, kMethodWRMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("Can't connect to StructMethod to send commands\n");
        return false;
    }
    printf("Modified Setting: Turbo Boost %s\n", isTurboEnabled ? "Enabled" : "Disabled");
    return true;
}

bool VoltageShiftTools::read(const char * msr)
{
    inout in, out;
    size_t outsize = sizeof(out);
    
    in.msr = (UInt32) hextoint(msr);
    in.action = kMethodRDMSR;
    in.param = 0;

    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("Can't connect to StructMethod to send commands\n");
        return false;
    }

    printf("RDMSR %x returns value 0x%llx\n", (unsigned int) in.msr, (unsigned long long) out.param);
    printBits(sizeof(out.param), &out.param);
    return true;
}

bool VoltageShiftTools::write(const char * msr, const char * regvalue)
{
    inout in, out;
    size_t outsize = sizeof(out);

    in.msr = (UInt32) hextoint(msr);
    in.action = kMethodWRMSR;
    in.param = hextoint(regvalue);

    printf("WRMSR %x with value 0x%llx\n", (unsigned int) in.msr, (unsigned long long) in.param);

    if (IOConnectCallStructMethod(connect, kMethodWRMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("Can't connect to StructMethod to send commands\n");
        return false;
    }
    
    return true;
}

void VoltageShiftTools::loadKext()
{
    std::stringstream output;
    
    output << "sudo kextload \" path  \" ";

    system(output.str().c_str());
}

void VoltageShiftTools::unloadKext()
{
    if (connect)
    {
        if (IOServiceClose(connect) != KERN_SUCCESS)
        {
            return;
        }
    }
    
    if (service)
    {
        IOObjectRelease(service);
    }
    
    std::stringstream output;
    output << "sudo kextunload \" path \" ";
    
    system(output.str().c_str());
}

bool VoltageShiftTools::getService()
{
    mach_port_t masterPort;
    io_iterator_t iter;
    io_string_t path;
    
    if (IOMasterPort(MACH_PORT_NULL, &masterPort) != KERN_SUCCESS)
    {
        printf("Can't get masterport\n");
        return false;
    }
    
    if (IOServiceGetMatchingServices(masterPort, IOServiceMatching(kClassName), &iter) != KERN_SUCCESS)
    {
        printf("VoltageShift.kext is not running\n");
        return false;
    }
    
    service = IOIteratorNext(iter);
    IOObjectRelease(iter);
    
    if (IORegistryEntryGetPath(service, kIOServicePlane, path) != KERN_SUCCESS)
    {
        printf("Can't get registry-entry path\n");
        return false;
    }
    
    return true;
}

int VoltageShiftTools::readOCMailBox(int domain)
{
    /*
     * Reference of Intel Turbo Boost Max Technology 3.0 legacy (non HWP) enumeration driver is in
     * https://github.com/torvalds/linux/blob/master/drivers/platform/x86/intel_turbo_max_3.c
     *
     * offset 0x40 is the OC Mailbox Domain bit relative for:
     * domain: 0 - CPU
     *         1 - GPU
     *         2 - CPU Cache
     *         3 - System Agency
     *         4 - Analogy I/O
     *         5 - Digital I/O
     *
     */
    
    inout in, out;
    
    size_t outsize = sizeof(out);
    
    /* Issue favored core read command */
    uint64 value = OC_MAILBOX_READ_VOLTAGE_CMD << MSR_OC_MAILBOX_CMD_OFFSET;
    /* Domain for the values set for */
    value |= ((uint64) domain) << MSR_OC_MAILBOX_DOMAIN_OFFSET;
    /* Set the busy bit to indicate OS is trying to issue command */
    value |= ((uint64) 0x1) << MSR_OC_MAILBOX_BUSY_BIT;
    
    in.msr = (UInt32) MSR_OC_MAILBOX;
    in.action = kMethodWRMSR;
    in.param = value;
  
    if (IOConnectCallStructMethod(connect, kMethodWRMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("OC MAILBOX WRITE FAILED!\n");
        return 0;
    }
    
    for (int i = 0; i < OC_MAILBOX_RETRY_COUNT; ++i)
    {
        in.msr = MSR_OC_MAILBOX;
        in.action = kMethodRDMSR;
        in.param = 0;

        if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
        {
            printf("OC MAILBOX READ FAILED!\n");
            break;
        }
        
        if (out.param & (((uint64)0x1) << MSR_OC_MAILBOX_BUSY_BIT))
        {
            printf("OC Mailbox is still processing...\n");
            continue;
        }
        
        if ((out.param >> MSR_OC_MAILBOX_RSP_OFFSET) & 0xff)
        {
            printf("OC MAILBOX COMMAND FAILED!\n");
            break;
        }
    }

    int ret = (int)(out.param >> 20) & 0xFFF;
    if (ret > 2047)
    {
        ret -= 0x1000;
    }
    return ret / 2;
}

bool VoltageShiftTools::writeOCMailBox(int domain, int offset)
{
    if (offset > 0 && !damagemode)
    {
        printf("Your setting requires overclocking. This may cause irreversible damage to your computer!!!\n");
        printf("Please use: voltageshift --damage offset\n");
        return false;
    }
    
    if (offset < -250  && !damagemode)
    {
        printf("Your settings are too low and thus very dangerous.\n");
        printf("Please use voltageshift --damage offset\n");
        return false;
    }
    
    uint64 offsetvalue;
    
    if (offset < 0)
    {
        offsetvalue = 0x1000 + ((offset) * 2);
    }
    else
    {
        offsetvalue = offset * 2;
    }
    
    uint64 value = offsetvalue << OC_MAILBOX_VALUE_OFFSET;
    
    inout in, out;
    size_t outsize = sizeof(out);
    
    /* Issue favored core read command */
    value |= OC_MAILBOX_WHITE_VOLTAGE_CMD << MSR_OC_MAILBOX_CMD_OFFSET;
    
     /* Domain for the values set for */
    value |= ((uint64) domain) << MSR_OC_MAILBOX_DOMAIN_OFFSET;
  
    /* Set the busy bit to indicate OS is trying to issue command */
    value |= ((uint64) 0x1) << MSR_OC_MAILBOX_BUSY_BIT;
    
    in.msr = (UInt32) MSR_OC_MAILBOX;
    in.action = kMethodWRMSR;
    in.param = value;
    
    if (IOConnectCallStructMethod(connect, kMethodWRMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("OC MAILBOX WRITE FAILED!\n");
        return false;
    }
    
    return true;
}

bool VoltageShiftTools::getCPUInfo()
{
    inout in, out;
    size_t outsize = sizeof(out);
    
    in.action = kMethodRDMSR;
    in.param = 0;
    in.msr = 0x610;
    
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x610!\n");
        return false;
    }
    
    double p1power = (double) (out.param       & 0x7FFF ) / 8;
    double p2power = (double) (out.param >> 32 & 0x7FFF ) / 8;

    in.msr = 0x1a0;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x1A0!\n");
        return false;
    }
    
    bool turbodisable = ((out.param >> 38 & 0x1) == 1);
    
    in.msr = 0x194;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x194\n");
        return false;
    }
    
    bool oclocked = ((out.param >> 20 & 0x1) == 1);
    
    in.msr = 0xce;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0xCE\n");
        return false;
    }
    
    double basefreq = (double)(out.param >> 8 & 0xFF) * 100;
    
    in.msr = 0x606;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x0606\n");
        return false;
    }
    
    double power_units = pow(0.5, (double) ((out.param >> 8) & 0x1f)) * 10;
    
    in.msr = 0x1AD;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x01AD\n");
        return false;
    }
    
    double maxturbofreq     = (double) (out.param       & 0xff) * 100.0;
    double secondturbofreq  = (double) (out.param >> 8  & 0xff) * 100.0;
    double fourthturbofreq  = (double) (out.param >> 24 & 0xff) * 100.0;
    double sixthturbofreq   = (double) (out.param >> 40 & 0xff) * 100.0;
    double eightthturbofreq = (double) (out.param >> 56 & 0xff) * 100.0;
    
    if (eightthturbofreq != 0)
    {
        printf("CPU BaseFreq: %.0f, CPU MaxFreq(1/2/4/6/8): %.0f/%.0f/%.0f/%.0f/%.0f (mhz)\n", basefreq, maxturbofreq, secondturbofreq, fourthturbofreq, sixthturbofreq, eightthturbofreq);
    }
    else if (sixthturbofreq != 0)
    {
         printf("CPU BaseFreq: %.0f, CPU MaxFreq(1/2/4/6): %.0f/%.0f/%.0f/%.0f (mhz)\n", basefreq, maxturbofreq, secondturbofreq, fourthturbofreq, sixthturbofreq);
    }
    else
    {
        printf("CPU BaseFreq: %.0f, CPU MaxFreq(1/2/4): %.0f/%.0f/%.0f (mhz)\n", basefreq, maxturbofreq, secondturbofreq, fourthturbofreq);
    }
    printf("%s %s PL1: %.0fW PL2: %.0fW\n", oclocked ? "OC_Locked" : "", turbodisable ? "Turbo_Disabled" : "", p1power, p2power);
    
    in.msr = 0x611;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x611\n");
        return false;
    }
        
    unsigned long long lastpowerpkg = out.param;
    
    in.msr = 0x639;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x639\n");
        return 1;
    }
    
    unsigned long long lastpowercore = out.param;
        
    uint64 firsttime = clock_gettime_nsec_np(CLOCK_REALTIME) / 1000;
    
    usleep(100000);
    
    uint64 secondtime = clock_gettime_nsec_np(CLOCK_REALTIME) / 1000 - firsttime;

    double second = (double) secondtime / 100000;
    
    in.msr = 0x611;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x611\n");
        return false;
    }
    
    m_CPU->powerpkg = power_units * ((double) out.param - lastpowerpkg) / second;
    
    in.msr = 0x639;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x639\n");
        return false;
    }
    
    m_CPU->powercore =  power_units * ((double)out.param - lastpowercore) / second;
    
    in.msr = 0x198;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x198\n");
        return false;
    }
    
    m_CPU->voltage  = (out.param >> 32 & 0xFFFF) / pow(2, 13);
    
    m_CPU->freq = (out.param >> 8 & 0xFF) / 10;
    
    in.msr = 0x1A2;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x1A2\n");
        return false;
    }
    
    uint64 dtsmax     = out.param >> 16 & 0xFF;
    uint64 tempoffset = out.param >> 24 & 0x3F;
    
    in.msr = 0x19C;
    if (IOConnectCallStructMethod(connect, kMethodRDMSR, &in, sizeof(in), &out, &outsize) != KERN_SUCCESS)
    {
        printf("FAILED TO READ READ VOLTAGE 0x19C\n");
        return false;
    }
    
    uint64 margintothrottle = out.param >> 16 & 0x3F;
    m_CPU->temp = dtsmax - margintothrottle;
    
    if (OFFSET_TEMP)
    {
        m_CPU->temp -= tempoffset;
    }
    
    printf("CPU Frequency: %2.1fghz, Voltage: %.4fv, Power:pkg %2.2fw /core %2.2fw,Temp: %llu c", m_CPU->freq, m_CPU->voltage, m_CPU->powerpkg, m_CPU->powercore, m_CPU->temp);
    return true;
}

inline void VoltageShiftTools::setCPUOffset(int cpuOffset)
{
    printf("Old CPU Voltage Offset: %dmv\n", readOCMailBox(0));
    writeOCMailBox(0, cpuOffset);
    printf("New CPU Voltage Offset: %dmv\n", readOCMailBox(0));
}

inline void VoltageShiftTools::setGPUOffset(int gpuOffset)
{
    printf("Old GPU Voltage Offset: %dmv\n", readOCMailBox(1));
    writeOCMailBox(1, gpuOffset);
    printf("New GPU Voltage Offset: %dmv\n", readOCMailBox(1));
}

inline void VoltageShiftTools::setCPUCacheOffset(int cpuCacheOffset)
{
    printf("Old CPU Cache Voltage Offset: %dmv\n", readOCMailBox(2));
    writeOCMailBox(2, cpuCacheOffset);
    printf("New CPU Cache Voltage Offset: %dmv\n", readOCMailBox(2));
}

inline void VoltageShiftTools::setSystemAgencyOffset(int systemAgencyOffset)
{
    printf("Old System Agency Voltage Offset: %dmv\n", readOCMailBox(3));
    writeOCMailBox(3, systemAgencyOffset);
    printf("New System Agency Voltage Offset: %dmv\n", readOCMailBox(3));
}

inline void VoltageShiftTools::setAnalogyIOOffset(int analogyIOOffset)
{
    printf("Old Analogy I/O Offset: %dmv\n",readOCMailBox(4));
    writeOCMailBox(4, analogyIOOffset);
    printf("New Analogy I/O Offset: %dmv\n",readOCMailBox(4));
}

inline void VoltageShiftTools::setDigitalIOOffset(int digitalIOOffset)
{
    printf("Old Digital I/O Offset: %dmv\n",readOCMailBox(5));
    writeOCMailBox(5, digitalIOOffset);
    printf("New Digital I/O Offset: %dmv\n",readOCMailBox(5));
}

void VoltageShiftTools::printBits(size_t const size, void const * const ptr)
{
    unsigned char * b = (unsigned char *) ptr;
    unsigned char byte;
    
    printf("(");
    for (int i = size - 1; i >= 0; --i)
    {
        for (int j = 7; j >= 0; --j)
        {
            byte = (b[i] >> j) & 1;
            printf("%u", byte);
        }
        if (i != 0)
        {
            printf(" ");
        }
        else
        {
            printf(")\n");
        }
    }
}
