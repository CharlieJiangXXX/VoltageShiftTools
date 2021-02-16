//
//  Common.h
//  VoltageShift
//
//  Copyright © 2021 cjiang. All rights reserved.
//

#ifndef Common_h
#define Common_h

#include <IOKit/IOUserClient.h>
#include <IOKit/IOLib.h>
#include <IOKit/IOBufferMemoryDescriptor.h>

#include <i386/proc_reg.h>

#include "VoltageShiftClient.hpp"
#include "VoltageShift.hpp"

#define safe_delete(x) do { if (x) { delete x; x = NULL; } } while (0)

#define DRIVER_NAME "VoltageShift"

#ifdef DEBUG
#define DebugLog(args...) do { IOLog(DRIVER_NAME ": " args); } while (0)
#else
#define DebugLog(args...) do { } while (0)
#endif /* DEBUG */

#define AlwaysLog(args...) do { IOLog(DRIVER_NAME ": " args); } while (0)

#define ErrorLog(args...) AlwaysLog("Error! " args)
#define InfoLog(args...) AlwaysLog(args)
#define WarningLog(args...) DebugLog("Warning! " args)
#define FuncLog(args...) DebugLog(args "()\n")

#endif /* Common_h */
