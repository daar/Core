{
Ultibo Device interface unit.

Copyright (C) 2015 - SoftOz Pty Ltd.

Arch
====

 <All>

Boards
======

 <All>

Licence
=======

 LGPLv2.1 with static linking exception (See COPYING.modifiedLGPL.txt)
 
Credits
=======

 Information for this unit was obtained from:

 
References
==========


Devices
=======


Notifiers
=========


Drivers
=======


Clock Devices
=============


Timer Devices
=============


Random Devices
==============


Mailbox Devices
===============


Watchdog Devices
================

}

//To Do //This should work on 2 (or more) layers:

//1 - The device consumer modules such as USB, Network, Filesystem, Keyboard, Mouse and Bluetooth which want to be notified
//    when a new device provider is registered.
//    They will register here as a consumer and be notified of a new driver being registered.

//2 - The device provider modules such as DWCOTG, MMC and SMSC95XX which will want the
//    consumers to be notified when they are registered.
//    They will register here as a provider and any interested consumers will be notified.
//    Some providers will register multiple interfaces:
//    eg SMSC95XX would register as a USBDEVICE provider and as a NETWORK provider
//       and both the USB and Network consumers would be notified.
//
//    Bluetooth would be a specific example of a consumer and many providers.
//    It would consume USB devices which are Bluetooth modules and then provide 
//    Keyboard, Mouse, Audio, Network ? and others to other consumers.

//    The Keyboard unit will include both the Keyboard consumer (ie Keyboard services) and
//    the generic USB Keyboard device driver. (For simplicity)

//    The Mouse unit will include both the Mouse consumer (ie Mouse services) and the 
//    generic USB Mouse device driver. (For simplicity)

//    The Storage unit will include both the Storage consumer (which in turn is consumed by Filesystem)
//    and the generic USB block storage device driver. (For simplicity)
//    The Storage unit will also provide basic RAM disk, virtual disk etc etc

//This model allows driver providers like SMSC95XX to only include the Devices unit and the
//relevant units of the consumers they provide drivers for (eg Usb and Network).

//More importantly, the core of Ultibo only need to include the Devices unit so that
//everything other than Console, Memory, Threads etc becomes optional.

//For example, including the Keyboard unit would auto include Usb (because the Keyboard unit
//will be both a consumer of USB and a provider of USB and KEYBOARD), the only other 
//unit required would be DWCOTG which could be auto included based on defines
//for the platform if needed ?

//Question: How do we get the compiler to set a DEFINE based on the ControllerType ?
//          We know there is one for the Target (ULTIBO) but what about the ControllerType ?


{$mode delphi} {Default to Delphi compatible syntax}
{$H+}          {Default to AnsiString}

unit Devices;

interface

uses GlobalConfig,GlobalConst,GlobalTypes,Platform,Threads,HeapManager,SysUtils;

//To Do //Do we need Hosts or not ? //Not Yet ?

{==============================================================================}
{Global definitions}
{$INCLUDE GlobalDefines.inc}

{==============================================================================}
const
 {Device specific constants}
 DEVICE_NAME_PREFIX = 'Device';  {Name prefix for Devices}
 
 {Device Signature}
 DEVICE_SIGNATURE = $AD03FE3C;
 
 {Device Busses}
 DEVICE_BUS_NONE             = 0;
 DEVICE_BUS_PCI              = 1;
 DEVICE_BUS_USB              = 2;
 DEVICE_BUS_ISA              = 3;
 DEVICE_BUS_PS2              = 4;
 DEVICE_BUS_FIREWIRE         = 5;
 DEVICE_BUS_SD               = 6; {SD/SDHC/SDXC/SDIO etc}
 DEVICE_BUS_MMC              = 7; {MMC/eMMC etc}
 DEVICE_BUS_ATA              = 8;
 DEVICE_BUS_IDE              = 9;
 DEVICE_BUS_SCSI             = 10;
 DEVICE_BUS_ATAPI            = 11;
 DEVICE_BUS_SATA             = 12;
 DEVICE_BUS_SERIAL           = 13;
 DEVICE_BUS_SPI              = 14; {Serial Peripheral Interface device}
 DEVICE_BUS_MMIO             = 15; {Memory Mapped IO device (No Bus)}
 DEVICE_BUS_PCIE             = 16;
 DEVICE_BUS_I2C              = 17; {I2C connected device}
 
 DEVICE_BUS_MAX              = 17;
 
 {Device Bus Names}
 DEVICE_BUS_NAMES:array[DEVICE_BUS_NONE..DEVICE_BUS_MAX] of String = (
  'DEVICE_BUS_NONE',
  'DEVICE_BUS_PCI',
  'DEVICE_BUS_USB',
  'DEVICE_BUS_ISA',
  'DEVICE_BUS_PS2',
  'DEVICE_BUS_FIREWIRE',
  'DEVICE_BUS_SD',
  'DEVICE_BUS_MMC',
  'DEVICE_BUS_ATA',
  'DEVICE_BUS_IDE',
  'DEVICE_BUS_SCSI',
  'DEVICE_BUS_ATAPI',
  'DEVICE_BUS_SATA',
  'DEVICE_BUS_SERIAL',
  'DEVICE_BUS_SPI',
  'DEVICE_BUS_MMIO',
  'DEVICE_BUS_PCIE',
  'DEVICE_BUS_I2C');
 
 {Device States}
 DEVICE_STATE_UNREGISTERED   = 0;
 DEVICE_STATE_REGISTERED     = 1;
 
 DEVICE_STATE_MAX            = 1;
 
 {Device State Names}
 DEVICE_STATE_NAMES:array[DEVICE_STATE_UNREGISTERED..DEVICE_STATE_MAX] of String = (
  'DEVICE_STATE_UNREGISTERED',
  'DEVICE_STATE_REGISTERED');
 
 {Device Ids}
 DEVICE_ID_ANY               = $FFFFFFFF; {Any Device (Pass to DeviceFind to match all devices)}
 
 {Device Classes}
 DEVICE_CLASS_NONE            = 0;  {No Device} 
 DEVICE_CLASS_USBHOST         = 1;  {A USB Host Controller (eg XHCI/EHCI/UHCI/OHCI or DWCOTG etc) (Implementing a standard USB host interface)}
 DEVICE_CLASS_PCIHOST         = 2;  {A PCI Host Controller (eg AHCI etc) (Implementing a standard PCI host interface)}
 DEVICE_CLASS_USB             = 3;  {A USB Device (eg Hub/Keyboard/Mouse/Mass Storage/Vendor Specific etc) (Implementing a standard USB device interface)}
 DEVICE_CLASS_PCI             = 4;  {A PCI Device (eg Graphics/Controller etc) (Implementing a standard PCI device interface)}
 DEVICE_CLASS_NETWORK         = 5;  {A Network Device (Implementing a standard Network device interface). May also be a USB or PCI device}
 DEVICE_CLASS_STORAGE         = 6;  {A Storage Device (Implementing a standard Storage device interface). May also be a USB, PCI, MMC, SCSI or ATA device}
 DEVICE_CLASS_BLOCK           = DEVICE_CLASS_STORAGE;
 DEVICE_CLASS_FILESYSTEM      = 7;  {A FileSystem Device (eg FAT/NTFS/CDFS/EXTFS etc)(Implementing a standard FileSystem device interface)}
 DEVICE_CLASS_PROTOCOL        = 8;  {A Protocol Device (eg TCP/UDP/IP/ICMP etc) (Implementing a standard Protocol device interface)}
 DEVICE_CLASS_TRANSPORT       = DEVICE_CLASS_PROTOCOL;
 DEVICE_CLASS_KEYBOARD        = 9;  {A Keyboard Device (Implementing a standard Keyboard device interface)}
 DEVICE_CLASS_MOUSE           = 10; {A Mouse Device (Implementing a standard Mouse device interface)}
 DEVICE_CLASS_BLUETOOTH       = 11; {A Bluetooth Device (Implementing a standard Bluetooth device interface)}
 DEVICE_CLASS_SERIAL          = 12; {A Serial Device (Implementing a standard Serial device interface)}
 DEVICE_CLASS_AUDIO           = 13; {An Audio Device (Implementing a standard Audio device interface)}
 DEVICE_CLASS_VIDEO           = 14; {A Video Device (Implementing a standard Video device interface)}
 DEVICE_CLASS_SCSI            = 15; {A SCSI Device (Implementing a standard SCSI device interface). May also be a PCI device}
 DEVICE_CLASS_ATA             = 16; {An ATA/ATAPI Device (Implementing a standard ATA/ATAPI device interface). May also be a PCI device}
 DEVICE_CLASS_IDE             = DEVICE_CLASS_ATA;
 DEVICE_CLASS_ATAPI           = DEVICE_CLASS_ATA;
 DEVICE_CLASS_IMAGE           = 17; {An Image Device (eg Camera) (Implementing a standard Image device interface)}
 DEVICE_CLASS_PRINTER         = 18; {A Printer Device (Implementing a standard Printer device interface)}
 DEVICE_CLASS_COMMUNICATIONS  = 19; {A Communications Device (Implementing a standard Communications device interface)}
 DEVICE_CLASS_SMART_CARD      = 20; {A Smart Card Device (Implementing a standard Smart Card device interface)}
 DEVICE_CLASS_MONITOR         = 21; {A Monitor Device (Implementing a standard Monitor device interface)}
 DEVICE_CLASS_DISPLAY         = 22; {A Display Device (eg Billboard) (Implementing a standard Display device interface)}
 DEVICE_CLASS_AUDIOVIDEO      = 23; {An Audio/Video Device (Implementing a standard Audio/Video device interface)}
 DEVICE_CLASS_IRDA            = 24; {An Infrared Device (Implementing a standard Infrared device interface)}
 DEVICE_CLASS_SPI             = 25; {An SPI Device (Implementing a standard SPI device interface)}
 DEVICE_CLASS_I2C             = 26; {An I2C Device (Implementing a standard I2C device interface)}
 DEVICE_CLASS_UART            = 27; {A UART Device (Implementing a standard UART device interface)}
 DEVICE_CLASS_MMC             = 28; {An MMC Device (Implementing a standard MMC device interface)}
 DEVICE_CLASS_SD              = 29; {An SD Device (Implementing a standard SD device interface)}
 DEVICE_CLASS_SDHCI           = 30; {An SD/MMC Host Controller (Implementing a standard SDHCI device interface)}
 DEVICE_CLASS_SDHOST          = DEVICE_CLASS_SDHCI;
 DEVICE_CLASS_DFU             = 31; {A Device Firmware Update Device (Implementing a standard DFU device interface)}
 DEVICE_CLASS_GPIO            = 32; {A GPIO Device (Implementing a standard GPIO device interface)}
 DEVICE_CLASS_MAILBOX         = 33; {A Mailbox Device}
 DEVICE_CLASS_OPENGL          = 34; {An OpenGL Device}
 DEVICE_CLASS_DVB             = 35; {A Digital Video Broadcast (DVB) Device}
 DEVICE_CLASS_DAB             = 36; {A Digital Audio Broadcast (DAB) Device}
 DEVICE_CLASS_DMA             = 37; {A DMA Controller Device (Implementing a standard DMA controller interface)}
 DEVICE_CLASS_SCSIHOST        = 38; {A SCSI Host Device (Implementing a standard SCSI host interface)}
 DEVICE_CLASS_ATAHOST         = 39; {An ATA Host Device (Implementing a standard ATA host interface)}
 DEVICE_CLASS_TIMER           = 40; {A Timer or Counter Device}
 DEVICE_CLASS_RANDOM          = 41; {A Random Number Generator Device}
 DEVICE_CLASS_FRAMEBUFFER     = 42; {A Frame Buffer Device}
 DEVICE_CLASS_WATCHDOG        = 43; {A Watchdog Timer Device}
 DEVICE_CLASS_CLOCK           = 44; {A Clock (Date/Time) Device}
 DEVICE_CLASS_CONSOLE         = 45; {A Console Device}
 DEVICE_CLASS_RTC             = 46; {A Real Time Clock (Battery Backed) Device}
 DEVICE_CLASS_USBHUB          = 47; {A USB Hub (Implementing a standard USB hub interface)}
 DEVICE_CLASS_LOGGING         = 48; {A Logging Device (Implementing a standard Logging device interface)}          
 DEVICE_CLASS_PCM             = 49; {A PCM Sound Device (Implementing a standard PCM device interface)}
 DEVICE_CLASS_I2S             = DEVICE_CLASS_PCM;
 DEVICE_CLASS_PWM             = 50; {A Pulse Width Modulation (PWM) Device}
 DEVICE_CLASS_1WIRE           = 51; {A 1-Wire Device (Implementing a standard W1 device interface)}
 DEVICE_CLASS_CLOCK_MANAGER   = 52; {A Clock Manager Device}

 DEVICE_CLASS_MAX             = 52;
 
 DEVICE_CLASS_ANY             = $FFFFFFFF; {Any Device (Pass to DeviceFind or DeviceEnumerate to match all devices)}
 
 {Device Class Names}
 DEVICE_CLASS_NAMES:array[DEVICE_CLASS_NONE..DEVICE_CLASS_MAX] of String = (
  'DEVICE_CLASS_NONE',
  'DEVICE_CLASS_USBHOST',
  'DEVICE_CLASS_PCIHOST',
  'DEVICE_CLASS_USB',
  'DEVICE_CLASS_PCI',
  'DEVICE_CLASS_NETWORK',
  'DEVICE_CLASS_STORAGE',
  'DEVICE_CLASS_FILESYSTEM',
  'DEVICE_CLASS_PROTOCOL', 
  'DEVICE_CLASS_KEYBOARD', 
  'DEVICE_CLASS_MOUSE',      
  'DEVICE_CLASS_BLUETOOTH', 
  'DEVICE_CLASS_SERIAL',    
  'DEVICE_CLASS_AUDIO',       
  'DEVICE_CLASS_VIDEO',        
  'DEVICE_CLASS_SCSI',         
  'DEVICE_CLASS_ATA',           
  'DEVICE_CLASS_IMAGE',          
  'DEVICE_CLASS_PRINTER',        
  'DEVICE_CLASS_COMMUNICATIONS', 
  'DEVICE_CLASS_SMART_CARD',    
  'DEVICE_CLASS_MONITOR',       
  'DEVICE_CLASS_DISPLAY',        
  'DEVICE_CLASS_AUDIOVIDEO',     
  'DEVICE_CLASS_IRDA',           
  'DEVICE_CLASS_SPI',            
  'DEVICE_CLASS_I2C',            
  'DEVICE_CLASS_UART',           
  'DEVICE_CLASS_MMC',            
  'DEVICE_CLASS_SD',             
  'DEVICE_CLASS_SDHCI',          
  'DEVICE_CLASS_DFU',            
  'DEVICE_CLASS_GPIO',           
  'DEVICE_CLASS_MAILBOX',        
  'DEVICE_CLASS_OPENGL',         
  'DEVICE_CLASS_DVB',            
  'DEVICE_CLASS_DAB',            
  'DEVICE_CLASS_DMA',            
  'DEVICE_CLASS_SCSIHOST',       
  'DEVICE_CLASS_ATAHOST',        
  'DEVICE_CLASS_TIMER',          
  'DEVICE_CLASS_RANDOM',         
  'DEVICE_CLASS_FRAMEBUFFER',    
  'DEVICE_CLASS_WATCHDOG',       
  'DEVICE_CLASS_CLOCK',          
  'DEVICE_CLASS_CONSOLE',        
  'DEVICE_CLASS_RTC',
  'DEVICE_CLASS_USBHUB',
  'DEVICE_CLASS_LOGGING',
  'DEVICE_CLASS_PCM',
  'DEVICE_CLASS_PWM',
  'DEVICE_CLASS_1WIRE',
  'DEVICE_CLASS_CLOCK_MANAGER');
 
 {Device Notification Flags}
 DEVICE_NOTIFICATION_NONE       = $00000000; {Pass to DeviceNotification to cancel an existing Notification}
 DEVICE_NOTIFICATION_REGISTER   = $00000001;
 DEVICE_NOTIFICATION_DEREGISTER = $00000002;
 DEVICE_NOTIFICATION_OPEN       = $00000004;
 DEVICE_NOTIFICATION_CLOSE      = $00000008;
 DEVICE_NOTIFICATION_UP         = $00000010;
 DEVICE_NOTIFICATION_DOWN       = $00000020;
 DEVICE_NOTIFICATION_INSERT     = $00000040;
 DEVICE_NOTIFICATION_EJECT      = $00000080;
 DEVICE_NOTIFICATION_ATTACH     = $00000100;
 DEVICE_NOTIFICATION_DETACH     = $00000200;
 DEVICE_NOTIFICATION_ENABLE     = $00000400;
 DEVICE_NOTIFICATION_DISABLE    = $00000800;
 DEVICE_NOTIFICATION_BIND       = $00001000;
 DEVICE_NOTIFICATION_UNBIND     = $00002000;
 DEVICE_NOTIFICATION_ATTACHING  = $00004000;
 DEVICE_NOTIFICATION_DETACHING  = $00008000;
 DEVICE_NOTIFICATION_INSERTING  = $00010000;
 DEVICE_NOTIFICATION_EJECTING   = $00020000;
 DEVICE_NOTIFICATION_OPENING    = $00040000;
 DEVICE_NOTIFICATION_CLOSING    = $00080000;
 DEVICE_NOTIFICATION_RESIZE     = $00100000;
 DEVICE_NOTIFICATION_RESIZING   = $00200000;
  
 {Notifier Signature}
 NOTIFIER_SIGNATURE = $6FA1BEC9;
 
 {Notifier States}
 NOTIFIER_STATE_UNREGISTERED   = 0;
 NOTIFIER_STATE_REGISTERED     = 1;
  
 {Notifier Flags}
 NOTIFIER_FLAG_NONE        = $00000000;
 NOTIFIER_FLAG_WORKER      = $00000001;  {If set, notification callback event will be scheduled on a worker thread}
 
 {Device logging}
 DEVICE_LOG_LEVEL_DEBUG     = LOG_LEVEL_DEBUG;  {Device debugging messages}
 DEVICE_LOG_LEVEL_INFO      = LOG_LEVEL_INFO;   {Device informational messages, such as a device being attached or detached}
 DEVICE_LOG_LEVEL_ERROR     = LOG_LEVEL_ERROR;  {Device error messages}
 DEVICE_LOG_LEVEL_NONE      = LOG_LEVEL_NONE;   {No Device messages}

var 
 DEVICE_DEFAULT_LOG_LEVEL:LongWord = DEVICE_LOG_LEVEL_DEBUG; {Minimum level for Device messages.  Only messages with level greater than or equal to this will be printed} 
 
var 
 {Device logging}
 DEVICE_LOG_ENABLED:Boolean; 

{==============================================================================}
const
 {Driver specific constants}
 DRIVER_NAME_PREFIX = 'Driver';  {Name prefix for Drivers}
 
 {Driver Signature}
 DRIVER_SIGNATURE = $1EB4980A;
 
 {Driver States}
 DRIVER_STATE_UNREGISTERED   = 0;
 DRIVER_STATE_REGISTERED     = 1;
 
 DRIVER_STATE_MAX            = 1;
 
 {Driver State Names}
 DRIVER_STATE_NAMES:array[DRIVER_STATE_UNREGISTERED..DRIVER_STATE_MAX] of String = (
  'DRIVER_STATE_UNREGISTERED',
  'DRIVER_STATE_REGISTERED');
 
 {Driver Ids}
 DRIVER_ID_ANY               = $FFFFFFFF; {Any Driver (Pass to DriverFind to match all drivers)}

 {Driver Classes}
 DRIVER_CLASS_NONE            = 0;  {No Driver} 
 DRIVER_CLASS_USB             = 1;  {A USB Driver (Implementing a standard USB driver interface)}
 DRIVER_CLASS_PCI             = 2;  {A PCI Driver (Implementing a standard PCI driver interface)}
 DRIVER_CLASS_SDIO            = 3;  {An SDIO Driver (Implementing a standard SDIO driver interface)}
 DRIVER_CLASS_BLUETOOTH       = 4;  {A Bluetooth Driver (Implementing a standard Bluetooth driver interface)}
 
 DRIVER_CLASS_MAX             = 4;
 
 DRIVER_CLASS_ANY             = $FFFFFFFF; {Any Driver (Pass to DriverFind or DriverEnumerate to match all drivers)}

 {Driver Class Names}
 DRIVER_CLASS_NAMES:array[DRIVER_CLASS_NONE..DRIVER_CLASS_MAX] of String = (
  'DRIVER_CLASS_NONE',
  'DRIVER_CLASS_USB',
  'DRIVER_CLASS_PCI',
  'DRIVER_CLASS_SDIO',
  'DRIVER_CLASS_BLUETOOTH');
 
{==============================================================================}
const
 {Host specific constants}
 HOST_NAME_PREFIX = 'Host';  {Name prefix for Hosts}
 
 {Host Signature}
 HOST_SIGNATURE = $F45D30FE;
 
 {Host States}
 HOST_STATE_UNREGISTERED   = 0;
 HOST_STATE_REGISTERED     = 1;
 
 {Host Ids}
 HOST_ID_ANY               = $FFFFFFFF; {Any Host (Pass to HostFind to match all hosts)}
 
 {Host Classes}
 HOST_CLASS_NONE            = 0;  {No Host} 
 HOST_CLASS_USB             = 1;  {A USB Host (eg XHCI/EHCI/UHCI/OHCI or DWCOTG etc) (Implementing a standard USB host interface)}
 HOST_CLASS_PCI             = 2;  {A PCI Host (eg AHCI etc) (Implementing a standard PCI host interface)}
 HOST_CLASS_SD              = 3;  {An SD Host (eg MMC/SDIO etc) (Implementing a standard SD host interface)}
 HOST_CLASS_BLUETOOTH       = 4;  {A Bluetooth Host (Implementing a standard Bluetooth host interface)}

 HOST_CLASS_MAX             = 4;
 
 HOST_CLASS_ANY             = $FFFFFFFF; {Any Host (Pass to HostFind or HostEnumerate to match all hosts)}
 
 {Host Class Names}
 HOST_CLASS_NAMES:array[HOST_CLASS_NONE..HOST_CLASS_MAX] of String = (
  'HOST_CLASS_NONE',
  'HOST_CLASS_USB',
  'HOST_CLASS_PCI',
  'HOST_CLASS_SD',
  'HOST_CLASS_BLUETOOTH');
 
{==============================================================================}
const
 {Clock specific constants}
 CLOCK_NAME_PREFIX = 'Clock';    {Name prefix for Clock Devices}
 
 {Clock Device Types}
 CLOCK_TYPE_NONE      = 0;
 CLOCK_TYPE_HARDWARE  = 1;
  
 {Clock Device States}
 CLOCK_STATE_DISABLED   = 0;
 CLOCK_STATE_ENABLED    = 1;
 
 {Clock Device Flags}
 CLOCK_FLAG_NONE      = $00000000;
  
{==============================================================================}
const
 {Timer specific constants}
 TIMER_NAME_PREFIX = 'Timer';    {Name prefix for Timer Devices}

 {Timer Device Types}
 TIMER_TYPE_NONE      = 0;
 TIMER_TYPE_HARDWARE  = 1;
  
 {Timer Device States}
 TIMER_STATE_DISABLED   = 0;
 TIMER_STATE_ENABLED    = 1;
 
 {Timer Device Flags}
 TIMER_FLAG_NONE       = $00000000;
 TIMER_FLAG_WRAPPING   = $00000001; {Device provides a wrapping or self reloading counter}
 TIMER_FLAG_COUNTER    = $00000002; {Device will appear as a continuously incrementing counter when read}
 TIMER_FLAG_DOWN       = $00000004; {Device counts down from the starting value to zero (And optionally triggers an event)}
 
 {Timer Event Flags}
 TIMER_EVENT_FLAG_NONE      = $00000000;
 TIMER_EVENT_FLAG_REPEAT    = $00000001; {Event will be repeated until cancelled}
 TIMER_EVENT_FLAG_INTERRUPT = $00000002; {Event will be dispatched by interrupt handler (If applicable)}
                                         {Caution: Events called by the interrupt handler must obey interrupt rules with regard to locks, memory allocation and latency}
 
{==============================================================================}
const
 {Random specific constants}
 RANDOM_NAME_PREFIX = 'Random';    {Name prefix for Random Devices}
 
 {Random Device Types}
 RANDOM_TYPE_NONE      = 0;
 RANDOM_TYPE_HARDWARE  = 1;
 RANDOM_TYPE_SOFTWARE  = 2;
 
 {Random Device States}
 RANDOM_STATE_DISABLED   = 0;
 RANDOM_STATE_ENABLED    = 1;
 
 {Random Device Flags}
 RANDOM_FLAG_NONE      = $00000000;
  
{==============================================================================}
const
 {Mailbox specific constants}
 MAILBOX_NAME_PREFIX = 'Mailbox';    {Name prefix for Mailbox Devices}

 {Mailbox Device Types}
 MAILBOX_TYPE_NONE      = 0;
 MAILBOX_TYPE_GPU       = 1;
 MAILBOX_TYPE_LOCAL     = 2;
  
 {Mailbox Device States}
 MAILBOX_STATE_DISABLED   = 0;
 MAILBOX_STATE_ENABLED    = 1;
 
 {Mailbox Device Flags}
 MAILBOX_FLAG_NONE      = $00000000;
  
{==============================================================================}
const
 {Watchdog specific constants}
 WATCHDOG_NAME_PREFIX = 'Watchdog';    {Name prefix for Watchdog Devices}
  
 {Watchdog Device Types}
 WATCHDOG_TYPE_NONE      = 0;
 WATCHDOG_TYPE_HARDWARE  = 1;
 
 {Watchdog Device States}
 WATCHDOG_STATE_DISABLED   = 0;
 WATCHDOG_STATE_ENABLED    = 1;
 
 {Watchdog Device Flags}
 WATCHDOG_FLAG_NONE      = $00000000;
  
{==============================================================================}
type
 {Device specific types}
 PDevice = ^TDevice;

 {Device Enumeration Callback}
 TDeviceEnumerate = function(Device:PDevice;Data:Pointer):LongWord;
 {Device Notification Callback}
 TDeviceNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;

 {Device Entry}
 TDevice = record
  {Device Properties}
  Signature:LongWord;       {Signature for entry validation}
  DeviceId:LongWord;        {Unique Id of this Device in the Device table}
  DeviceState:LongWord;     {Device state (eg Registered/Unregistered)}
  DeviceName:String;        {The name of the Device (eg Keyboard0, Storage0 or Network0 etc)}
  DeviceClass:LongWord;     {The class of this Device (eg DEVICE_CLASS_USB, DEVICE_CLASS_NETWORK, DEVICE_CLASS_STORAGE etc)}
  DeviceBus:LongWord;       {The Bus type for the Device (eg DEVICE_BUS_USB)}
  DeviceType:LongWord;      {A class specific Device type (eg KEYBOARD_TYPE_USB, MOUSE_TYPE_USB, NETWORK_TYPE_ETHERNET etc)}
  DeviceFlags:LongWord;     {The class specific Device flags}
  DeviceData:Pointer;       {A pointer to a class specific Device interface (eg PUSBDevice, PNetworkDevice or PStorageDevice etc) (Used by Drivers)}
  DeviceDescription:String; {A description of the Device (eg BCM2835 PL011 UART)}
  {Internal Properties}
  Prev:PDevice;             {Previous entry in Device table}
  Next:PDevice;             {Next entry in Device table}
 end;
 
 {Notifier Entry}
 PNotifier = ^TNotifier;
 TNotifier = record
  {Notifier Properties}
  Signature:LongWord;            {Signature for entry validation}
  NotifierState:LongWord;        {Notifier state (eg Registered/Unregistered)}
  NotifierFlags:LongWord;        {Notifier flags (eg NOTIFIER_FLAG_WORKER)}
  Device:PDevice;                {The Device to notify on (or nil for all devices)}
  DeviceClass:LongWord;          {The Device class to notify on (or DEVICE_CLASS_ANY for all devices)}
  Callback:TDeviceNotification;  {The callback for device notifications}
  Data:Pointer;                  {A pointer to callback specific data to be passed with notifications (Optional)}
  Notification:LongWord;         {The mask of events to notify on (eg DEVICE_NOTIFICATION_REGISTER etc)}
  {Internal Properties}
  Prev:PNotifier;                {Previous entry in Notifier table}
  Next:PNotifier;                {Next entry in Notifier table}
 end;
 
 {Notifier Task}
 PNotifierTask = ^TNotifierTask;
 TNotifierTask = record
  Device:PDevice;
  Callback:TDeviceNotification;
  Data:Pointer; 
  Notification:LongWord;
 end;
 
{==============================================================================}
type
 {Driver specific types}
 PDriver = ^TDriver;
 
 {Driver Enumeration Callback}
 TDriverEnumerate = function(Driver:PDriver;Data:Pointer):LongWord;
 
 {Driver Entry}
 TDriver = record
  {Driver Properties}
  Signature:LongWord;        {Signature for entry validation}
  DriverId:LongWord;         {Unique Id of this Driver in the Driver table}
  DriverState:LongWord;      {Driver state (eg Registered/Unregistered)}
  DriverName:String;         {Descriptive name for the Driver (eg USB Mouse Driver)}
  DriverClass:LongWord;      {The class of this Driver (eg DRIVER_CLASS_USB etc)}
  {Internal Properties}
  Prev:PDriver;              {Previous entry in Driver table}
  Next:PDriver;              {Next entry in Driver table}
 end;

{==============================================================================}
type
 {Host specific types}
 PHost = ^THost;
 
 {Host Enumeration Callback}
 THostEnumerate = function(Host:PHost;Data:Pointer):LongWord;
 
 {Host Entry}
 THost = record
  {Host Properties}
  Signature:LongWord;        {Signature for entry validation}
  HostId:LongWord;           {Unique Id of this Host in the Host table}
  HostState:LongWord;        {Host state (eg Registered/Unregistered)}
  HostName:String;           {Descriptive name for the Host (eg DWC OTG Host)} 
  HostClass:LongWord;        {The class of this Host (eg HOST_CLASS_USB etc)}
  {Internal Properties}
  Prev:PHost;                {Previous entry in Host table}
  Next:PHost;                {Next entry in Host table}
 end;
 
{==============================================================================}
type
 {Clock specific types}
 PClockDevice = ^TClockDevice;
 
 {Clock Enumeration Callback}
 TClockEnumerate = function(Clock:PClockDevice;Data:Pointer):LongWord;
 {Clock Notification Callback}
 TClockNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;
 
 {Clock Device Methods}
 TClockDeviceStart = function(Clock:PClockDevice):LongWord;
 TClockDeviceStop = function(Clock:PClockDevice):LongWord;
 TClockDeviceRead = function(Clock:PClockDevice):LongWord;
 TClockDeviceRead64 = function(Clock:PClockDevice):Int64;
 TClockDeviceGetRate = function(Clock:PClockDevice):LongWord;
 
 {Clock Device}
 TClockDevice = record
  {Device Properties}
  Device:TDevice;                                {The Device entry for this Clock device}
  {Clock Properties}
  ClockId:LongWord;                              {Unique Id of this Clock device in the Clock device table}
  ClockState:LongWord;                           {Clock device state (eg CLOCK_STATE_ENABLED)}
  DeviceStart:TClockDeviceStart;                 {A device specific DeviceStart method implementing a standard clock device interface (Or nil if the default method is suitable)}
  DeviceStop:TClockDeviceStop;                   {A device specific DeviceStop method implementing a standard clock device interface (Or nil if the default method is suitable)}
  DeviceRead:TClockDeviceRead;                   {A device specific DeviceRead method implementing a standard clock device interface (Or nil if the default method is suitable)}
  DeviceRead64:TClockDeviceRead64;               {A device specific DeviceRead64 method implementing a standard clock device interface (Mandatory)}
  DeviceGetRate:TClockDeviceGetRate;             {A device specific DeviceGetRate method implementing a standard clock device interface (Or nil if the default method is suitable)}
  {Statistics Properties}
  ReadCount:LongWord;
  {Driver Properties}
  Lock:TMutexHandle;                             {Device lock}
  Address:Pointer;                               {Device register base address}
  Rate:LongWord;                                 {Device rate (Hz)}
  {Internal Properties}
  Prev:PClockDevice;                             {Previous entry in Clock device table}
  Next:PClockDevice;                             {Next entry in Clock device table}
 end;
 
{==============================================================================}
type
 {Timer specific types}
 TTimerCallback = TCounterCallback; {Counter callbck from Platform}
 
 {Timer Properties}
 PTimerProperties = ^TTimerProperties;
 TTimerProperties = record
  Flags:LongWord;        {Device flags (eg TIMER_FLAG_WRAPPING)}
  Bits:LongWord;         {Number of valid bits in timer read (eg 32 or 64)}
  MinRate:LongWord;      {Device minimum clock rate (Hz)}
  MaxRate:LongWord;      {Device maximum clock rate (Hz)}
  MinInterval:LongWord;  {Device minimum interval (Milliseconds)}
  MaxInterval:LongWord;  {Device maximum interval (Milliseconds)}
 end;
 
 {Timer Device}
 PTimerDevice = ^TTimerDevice;
 
 {Timer Enumeration Callback}
 TTimerEnumerate = function(Timer:PTimerDevice;Data:Pointer):LongWord;
 {Timer Notification Callback}
 TTimerNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;
 
 {Timer Device Methods}
 TTimerDeviceStart = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceStop = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceRead = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceRead64 = function(Timer:PTimerDevice):Int64;
 TTimerDeviceWait = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceEvent = function(Timer:PTimerDevice;Flags:LongWord;Callback:TTimerCallback;Data:Pointer):LongWord;
 TTimerDeviceGetRate = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceSetRate = function(Timer:PTimerDevice;Rate:LongWord):LongWord;
 TTimerDeviceGetInterval = function(Timer:PTimerDevice):LongWord;
 TTimerDeviceSetInterval = function(Timer:PTimerDevice;Interval:LongWord):LongWord;
 TTimerDeviceProperties = function(Timer:PTimerDevice;Properties:PTimerProperties):LongWord;
 
 TTimerDevice = record
  {Device Properties}
  Device:TDevice;                                {The Device entry for this Timer device}
  {Timer Properties}
  TimerId:LongWord;                              {Unique Id of this Timer device in the Timer device table}
  TimerState:LongWord;                           {Timer device state (eg TIMER_STATE_ENABLED)}
  DeviceStart:TTimerDeviceStart;                 {A device specific DeviceStart method implementing a standard random device interface (Mandatory)}
  DeviceStop:TTimerDeviceStop;                   {A device specific DeviceStop method implementing a standard random device interface (Mandatory)}
  DeviceRead:TTimerDeviceRead;                   {A device specific DeviceRead method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceRead64:TTimerDeviceRead64;               {A device specific DeviceRead64 method implementing a standard random device interface (Mandatory)}
  DeviceWait:TTimerDeviceWait;                   {A device specific DeviceWait method implementing a standard random device interface (Mandatory)}
  DeviceEvent:TTimerDeviceEvent;                 {A device specific DeviceEvent method implementing a standard random device interface (Mandatory)}
  DeviceGetRate:TTimerDeviceGetRate;             {A device specific DeviceGetRate method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceSetRate:TTimerDeviceSetRate;             {A device specific DeviceSetRate method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceGetInterval:TTimerDeviceGetInterval;     {A device specific DeviceGetInterval method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceSetInterval:TTimerDeviceSetInterval;     {A device specific DeviceSetInterval method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceProperties:TTimerDeviceProperties;       {A device specific DeviceProperties method implementing a standard random device interface (Or nil if the default method is suitable)}
  {Statistics Properties}
  ReadCount:LongWord;
  WaitCount:LongWord;
  EventCount:LongWord;
  {Driver Properties}
  Lock:TMutexHandle;                             {Device lock}
  Address:Pointer;                               {Device register base address}
  Rate:LongWord;                                 {Device rate (Hz)}
  Interval:LongWord;                             {Device interval (Milliseconds)}
  Properties:TTimerProperties;                   {Device properties}
  {Internal Properties}
  Prev:PTimerDevice;                             {Previous entry in Timer device table}
  Next:PTimerDevice;                             {Next entry in Timer device table}
 end;
 
{==============================================================================}
type
 {Random specific types}
 PRandomDevice = ^TRandomDevice;
 
 {Random Enumeration Callback}
 TRandomEnumerate = function(Random:PRandomDevice;Data:Pointer):LongWord;
 {Random Notification Callback}
 TRandomNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;
 
 {Random Device Methods}
 TRandomDeviceStart = function(Random:PRandomDevice):LongWord;
 TRandomDeviceStop = function(Random:PRandomDevice):LongWord;
 TRandomDeviceSeed = function(Random:PRandomDevice;Seed:LongWord):LongWord;
 TRandomDeviceReadByte = function(Random:PRandomDevice):Byte;
 TRandomDeviceReadWord = function(Random:PRandomDevice):Word;
 TRandomDeviceReadLongWord = function(Random:PRandomDevice):LongWord;
 TRandomDeviceReadQuadWord = function(Random:PRandomDevice):Int64;
 TRandomDeviceReadExtended = function(Random:PRandomDevice):Extended;
 
 {Random Device}
 TRandomDevice = record
  {Device Properties}         
  Device:TDevice;                                {The Device entry for this Random device}
  {Random Properties}
  RandomId:LongWord;                             {Unique Id of this Random device in the Random device table}
  RandomState:LongWord;                          {Random device state (eg RANDOM_STATE_ENABLED)}
  DeviceStart:TRandomDeviceStart;                {A device specific DeviceStart method implementing a standard random device interface (Mandatory)}
  DeviceStop:TRandomDeviceStop;                  {A device specific DeviceStop method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceSeed:TRandomDeviceSeed;                  {A device specific DeviceSeed method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceReadByte:TRandomDeviceReadByte;          {A device specific DeviceReadByte method implementing a standard random device interface (Or nil if the default method is suitable)}
  DeviceReadWord:TRandomDeviceReadWord;          {A device specific DeviceReadWord method implementing a standard random device interface (Or nil if the default method is suitable)}  
  DeviceReadLongWord:TRandomDeviceReadLongWord;  {A device specific DeviceReadLongWord method implementing a standard random device interface (Mandatory)}  
  DeviceReadQuadWord:TRandomDeviceReadQuadWord;  {A device specific DeviceReadQuadWord method implementing a standard random device interface (Or nil if the default method is suitable)}  
  DeviceReadExtended:TRandomDeviceReadExtended;  {A device specific DeviceReadExtended method implementing a standard random device interface (Or nil if the default method is suitable)}  
  {Statistics Properties}
  SeedCount:LongWord;
  ReadCount:LongWord;
  {Driver Properties}
  Lock:TMutexHandle;                             {Device lock}
  Address:Pointer;                               {Device register base address}
  {Internal Properties}
  Prev:PRandomDevice;                            {Previous entry in Random device table}
  Next:PRandomDevice;                            {Next entry in Random device table}
end;
 
{==============================================================================}
type
 {Mailbox specific types}
 PMailboxDevice = ^TMailboxDevice;
 
 {Mailbox Enumeration Callback}
 TMailboxEnumerate = function(Mailbox:PMailboxDevice;Data:Pointer):LongWord;
 {Mailbox Notification Callback}
 TMailboxNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;
 
 {Mailbox Device Methods}
 TMailboxDeviceStart = function(Mailbox:PMailboxDevice):LongWord;
 TMailboxDeviceStop = function(Mailbox:PMailboxDevice):LongWord;
 TMailboxDeviceReceive = function(Mailbox:PMailboxDevice;Channel:LongWord):LongWord;
 TMailboxDeviceSend = function(Mailbox:PMailboxDevice;Channel,Data:LongWord):LongWord;
 TMailboxDeviceCall = function(Mailbox:PMailboxDevice;Channel,Data:LongWord;var Response:LongWord):LongWord;
 TMailboxDeviceGetTimeout = function(Mailbox:PMailboxDevice):LongWord;
 TMailboxDeviceSetTimeout = function(Mailbox:PMailboxDevice;Timeout:LongWord):LongWord;
 
 {Mailbox Device}
 TMailboxDevice = record
  {Device Properties}
  Device:TDevice;                                {The Device entry for this Mailbox device}
  {Mailbox Properties}
  MailboxId:LongWord;                            {Unique Id of this Mailbox device in the Mailbox device table}
  MailboxState:LongWord;                         {Mailbox device state (eg MAILBOX_STATE_ENABLED)}
  DeviceStart:TMailboxDeviceStart;               {A device specific DeviceStart method implementing a standard mailbox device interface (Or nil if the default method is suitable)}
  DeviceStop:TMailboxDeviceStop;                 {A device specific DeviceStop method implementing a standard mailbox device interface (Or nil if the default method is suitable)}
  DeviceReceive:TMailboxDeviceReceive;           {A device specific DeviceReceive method implementing a standard mailbox device interface (Mandatory)}
  DeviceSend:TMailboxDeviceSend;                 {A device specific DeviceSend method implementing a standard mailbox device interface (Mandatory)}
  DeviceCall:TMailboxDeviceCall;                 {A device specific DeviceCall method implementing a standard mailbox device interface (Mandatory)}
  DeviceGetTimeout:TMailboxDeviceGetTimeout;     {A device specific DeviceGetTimeout method implementing a standard mailbox device interface (Or nil if the default method is suitable)}
  DeviceSetTimeout:TMailboxDeviceSetTimeout;     {A device specific DeviceSetTimeout method implementing a standard mailbox device interface (Or nil if the default method is suitable)}
  {Statistics Properties}
  ReceiveCount:LongWord;
  SendCount:LongWord;
  CallCount:LongWord;
  {Driver Properties}
  Lock:TMutexHandle;                             {Device lock}
  Address:Pointer;                               {Device register base address}
  Timeout:LongWord;                              {Device timeout (Milliseconds)}
  {Internal Properties}
  Prev:PMailboxDevice;                           {Previous entry in Mailbox device table}
  Next:PMailboxDevice;                           {Next entry in Mailbox device table}
 end;

{==============================================================================}
type
 {Watchdog specific types}
 PWatchdogDevice = ^TWatchdogDevice;
 
 {Watchdog Enumeration Callback}
 TWatchdogEnumerate = function(Watchdog:PWatchdogDevice;Data:Pointer):LongWord;
 {Watchdog Notification Callback}
 TWatchdogNotification = function(Device:PDevice;Data:Pointer;Notification:LongWord):LongWord;
 
 {Watchdog Device Methods}
 TWatchdogDeviceStart = function(Watchdog:PWatchdogDevice):LongWord;
 TWatchdogDeviceStop = function(Watchdog:PWatchdogDevice):LongWord;
 TWatchdogDeviceRefresh = function(Watchdog:PWatchdogDevice):LongWord;
 TWatchdogDeviceGetRemain = function(Watchdog:PWatchdogDevice):LongWord;
 TWatchdogDeviceGetTimeout = function(Watchdog:PWatchdogDevice):LongWord;
 TWatchdogDeviceSetTimeout = function(Watchdog:PWatchdogDevice;Timeout:LongWord):LongWord;
 
 {Watchdog Device}
 TWatchdogDevice = record
  {Device Properties}
  Device:TDevice;                                {The Device entry for this Watchdog device}
  {Watchdog Properties}
  WatchdogId:LongWord;                           {Unique Id of this Watchdog device in the Watchdog device table}
  WatchdogState:LongWord;                        {Watchdog device state (eg WATCHDOG_STATE_ENABLED)}
  DeviceStart:TWatchdogDeviceStart;              {A device specific DeviceStart method implementing a standard watchdog device interface (Mandatory)}
  DeviceStop:TWatchdogDeviceStop;                {A device specific DeviceStop method implementing a standard watchdog device interface (Mandatory)}
  DeviceRefresh:TWatchdogDeviceRefresh;          {A device specific DeviceRefresh method implementing a standard watchdog device interface (Mandatory)}
  DeviceGetRemain:TWatchdogDeviceGetRemain;      {A device specific DeviceGetRemain method implementing a standard watchdog device interface (Mandatory)}
  DeviceGetTimeout:TWatchdogDeviceGetTimeout;    {A device specific DeviceGetTimeout method implementing a standard watchdog device interface (Or nil if the default method is suitable)}
  DeviceSetTimeout:TWatchdogDeviceSetTimeout;    {A device specific DeviceSetTimeout method implementing a standard watchdog device interface (Or nil if the default method is suitable)}
  {Statistics Properties}
  StartCount:LongWord;
  StopCount:LongWord;
  RefreshCount:LongWord;
  {Driver Properties}
  Lock:TMutexHandle;                             {Device lock}
  Address:Pointer;                               {Device register base address}
  Timeout:LongWord;                              {Device timeout (Milliseconds)}
  {Internal Properties}
  Prev:PWatchdogDevice;                          {Previous entry in Watchdog device table}
  Next:PWatchdogDevice;                          {Next entry in Watchdog device table}
 end;
 
{==============================================================================}
{var}
 {Device specific variables}
 
{==============================================================================}
{var}
 {Clock specific variables}
 
{==============================================================================}
{var}
 {Timer specific variables}
 
{==============================================================================}
{var}
 {Random specific variables}
  
{==============================================================================}
{var}
 {Mailbox specific variables}

{==============================================================================}
{var}
 {Watchdog specific variables}
 
{==============================================================================}
{Initialization Functions}
procedure DevicesInit;

{==============================================================================}
{Device Functions}
function DeviceCreate:PDevice;
function DeviceCreateEx(Size:LongWord):PDevice;
function DeviceDestroy(Device:PDevice):LongWord;

function DeviceGetName(Device:PDevice):String;
function DeviceSetName(Device:PDevice;const Name:String):LongWord;

function DeviceGetDescription(Device:PDevice):String;
function DeviceSetDescription(Device:PDevice;const Description:String):LongWord;

function DeviceRegister(Device:PDevice):LongWord;
function DeviceDeregister(Device:PDevice):LongWord;

function DeviceFind(DeviceClass,DeviceId:LongWord):PDevice;
function DeviceFindByName(const Name:String):PDevice;
function DeviceFindByDescription(const Description:String):PDevice;
function DeviceEnumerate(DeviceClass:LongWord;Callback:TDeviceEnumerate;Data:Pointer):LongWord;

function DeviceNotification(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

function NotifierAllocate(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer;Notification,Flags:LongWord):PNotifier;
function NotifierRelease(Notifier:PNotifier):LongWord;

function NotifierFind(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer):PNotifier;
function NotifierNotify(Device:PDevice;Notification:LongWord):LongWord;

procedure NotifierWorker(Task:PNotifierTask);

{==============================================================================}
{Driver Functions}
function DriverCreate:PDriver;
function DriverCreateEx(Size:LongWord):PDriver;
function DriverDestroy(Driver:PDriver):LongWord;

function DriverGetName(Driver:PDriver):String;
function DriverSetName(Driver:PDriver;const Name:String):LongWord;

function DriverRegister(Driver:PDriver):LongWord;
function DriverDeregister(Driver:PDriver):LongWord;

function DriverFind(DriverClass,DriverId:LongWord):PDriver;
function DriverFindByName(const Name:String):PDriver;
function DriverEnumerate(DriverClass:LongWord;Callback:TDriverEnumerate;Data:Pointer):LongWord;

{==============================================================================}
{Clock Device Functions}
function ClockDeviceStart(Clock:PClockDevice):LongWord;
function ClockDeviceStop(Clock:PClockDevice):LongWord;

function ClockDeviceRead(Clock:PClockDevice):LongWord;
function ClockDeviceRead64(Clock:PClockDevice):Int64;
function ClockDeviceGetRate(Clock:PClockDevice):LongWord;

function ClockDeviceCreate:PClockDevice;
function ClockDeviceCreateEx(Size:LongWord):PClockDevice;
function ClockDeviceDestroy(Clock:PClockDevice):LongWord;

function ClockDeviceRegister(Clock:PClockDevice):LongWord;
function ClockDeviceDeregister(Clock:PClockDevice):LongWord;

function ClockDeviceFind(ClockId:LongWord):PClockDevice;
function ClockDeviceFindByName(const Name:String):PClockDevice; inline;
function ClockDeviceFindByDescription(const Description:String):PClockDevice; inline;
function ClockDeviceEnumerate(Callback:TClockEnumerate;Data:Pointer):LongWord;

function ClockDeviceNotification(Clock:PClockDevice;Callback:TClockNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

{==============================================================================}
{Timer Device Functions}
function TimerDeviceStart(Timer:PTimerDevice):LongWord;
function TimerDeviceStop(Timer:PTimerDevice):LongWord;
function TimerDeviceRead(Timer:PTimerDevice):LongWord;
function TimerDeviceRead64(Timer:PTimerDevice):Int64;
function TimerDeviceWait(Timer:PTimerDevice):LongWord;
function TimerDeviceEvent(Timer:PTimerDevice;Flags:LongWord;Callback:TTimerCallback;Data:Pointer):LongWord;
function TimerDeviceGetRate(Timer:PTimerDevice):LongWord;
function TimerDeviceSetRate(Timer:PTimerDevice;Rate:LongWord):LongWord;
function TimerDeviceGetInterval(Timer:PTimerDevice):LongWord;
function TimerDeviceSetInterval(Timer:PTimerDevice;Interval:LongWord):LongWord;
function TimerDeviceProperties(Timer:PTimerDevice;Properties:PTimerProperties):LongWord;

function TimerDeviceCreate:PTimerDevice;
function TimerDeviceCreateEx(Size:LongWord):PTimerDevice;
function TimerDeviceDestroy(Timer:PTimerDevice):LongWord;

function TimerDeviceRegister(Timer:PTimerDevice):LongWord;
function TimerDeviceDeregister(Timer:PTimerDevice):LongWord;

function TimerDeviceFind(TimerId:LongWord):PTimerDevice;
function TimerDeviceFindByName(const Name:String):PTimerDevice; inline;
function TimerDeviceFindByDescription(const Description:String):PTimerDevice; inline;
function TimerDeviceEnumerate(Callback:TTimerEnumerate;Data:Pointer):LongWord;

function TimerDeviceNotification(Timer:PTimerDevice;Callback:TTimerNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

{==============================================================================}
{Random Device Functions}
function RandomDeviceStart(Random:PRandomDevice):LongWord;
function RandomDeviceStop(Random:PRandomDevice):LongWord;

function RandomDeviceSeed(Random:PRandomDevice;Seed:LongWord):LongWord;
function RandomDeviceReadByte(Random:PRandomDevice):Byte;
function RandomDeviceReadWord(Random:PRandomDevice):Word;
function RandomDeviceReadLongWord(Random:PRandomDevice):LongWord;
function RandomDeviceReadQuadWord(Random:PRandomDevice):Int64;
function RandomDeviceReadExtended(Random:PRandomDevice):Extended;

function RandomDeviceCreate:PRandomDevice;
function RandomDeviceCreateEx(Size:LongWord):PRandomDevice;
function RandomDeviceDestroy(Random:PRandomDevice):LongWord;

function RandomDeviceRegister(Random:PRandomDevice):LongWord;
function RandomDeviceDeregister(Random:PRandomDevice):LongWord;

function RandomDeviceFind(RandomId:LongWord):PRandomDevice;
function RandomDeviceFindByName(const Name:String):PRandomDevice; inline;
function RandomDeviceFindByDescription(const Description:String):PRandomDevice; inline;
function RandomDeviceEnumerate(Callback:TRandomEnumerate;Data:Pointer):LongWord;

function RandomDeviceNotification(Random:PRandomDevice;Callback:TRandomNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

{==============================================================================}
{Mailbox Device Functions}
function MailboxDeviceStart(Mailbox:PMailboxDevice):LongWord;
function MailboxDeviceStop(Mailbox:PMailboxDevice):LongWord;
function MailboxDeviceReceive(Mailbox:PMailboxDevice;Channel:LongWord):LongWord;
function MailboxDeviceSend(Mailbox:PMailboxDevice;Channel,Data:LongWord):LongWord;
function MailboxDeviceCall(Mailbox:PMailboxDevice;Channel,Data:LongWord;var Response:LongWord):LongWord;
function MailboxDeviceGetTimeout(Mailbox:PMailboxDevice):LongWord;
function MailboxDeviceSetTimeout(Mailbox:PMailboxDevice;Timeout:LongWord):LongWord;

function MailboxDeviceCreate:PMailboxDevice;
function MailboxDeviceCreateEx(Size:LongWord):PMailboxDevice;
function MailboxDeviceDestroy(Mailbox:PMailboxDevice):LongWord;

function MailboxDeviceRegister(Mailbox:PMailboxDevice):LongWord;
function MailboxDeviceDeregister(Mailbox:PMailboxDevice):LongWord;

function MailboxDeviceFind(MailboxId:LongWord):PMailboxDevice;
function MailboxDeviceFindByName(const Name:String):PMailboxDevice; inline;
function MailboxDeviceFindByDescription(const Description:String):PMailboxDevice; inline;
function MailboxDeviceEnumerate(Callback:TMailboxEnumerate;Data:Pointer):LongWord;

function MailboxDeviceNotification(Mailbox:PMailboxDevice;Callback:TMailboxNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

{==============================================================================}
{Watchdog Device Functions}
function WatchdogDeviceStart(Watchdog:PWatchdogDevice):LongWord;
function WatchdogDeviceStop(Watchdog:PWatchdogDevice):LongWord;
function WatchdogDeviceRefresh(Watchdog:PWatchdogDevice):LongWord;

function WatchdogDeviceGetRemain(Watchdog:PWatchdogDevice):LongWord;
function WatchdogDeviceGetTimeout(Watchdog:PWatchdogDevice):LongWord;
function WatchdogDeviceSetTimeout(Watchdog:PWatchdogDevice;Timeout:LongWord):LongWord;

function WatchdogDeviceCreate:PWatchdogDevice;
function WatchdogDeviceCreateEx(Size:LongWord):PWatchdogDevice;
function WatchdogDeviceDestroy(Watchdog:PWatchdogDevice):LongWord;

function WatchdogDeviceRegister(Watchdog:PWatchdogDevice):LongWord;
function WatchdogDeviceDeregister(Watchdog:PWatchdogDevice):LongWord;

function WatchdogDeviceFind(WatchdogId:LongWord):PWatchdogDevice;
function WatchdogDeviceFindByName(const Name:String):PWatchdogDevice; inline;
function WatchdogDeviceFindByDescription(const Description:String):PWatchdogDevice; inline;
function WatchdogDeviceEnumerate(Callback:TWatchdogEnumerate;Data:Pointer):LongWord;

function WatchdogDeviceNotification(Watchdog:PWatchdogDevice;Callback:TWatchdogNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;

{==============================================================================}
{RTL Clock Functions}
function SysClockRead:LongWord;
function SysClockRead64:Int64;

{==============================================================================}
{RTL Timer (Counter) Functions}
function SysTimerAvailable:Boolean;

function SysTimerRead:LongWord;
function SysTimerRead64:Int64;
function SysTimerWait:LongWord;
function SysTimerEvent(Callback:TTimerCallback;Data:Pointer):LongWord;

function SysTimerGetRate:LongWord;
function SysTimerSetRate(Rate:LongWord):LongWord;

function SysTimerGetInterval:LongWord;
function SysTimerSetInterval(Interval:LongWord):LongWord;

{==============================================================================}
{RTL Random Functions}
function SysRandomAvailable:Boolean;

procedure SysRandomize;
procedure SysRandomSeed(Seed:LongWord);

function SysRandomReadLongInt(Limit:LongInt):LongInt;
function SysRandomReadInt64(Limit:Int64):Int64;
function SysRandomReadExtended:Extended;

{==============================================================================}
{RTL Mailbox Functions}
//To Do

{==============================================================================}
{RTL Watchdog Functions}
function SysWatchdogAvailable:Boolean; 

function SysWatchdogStart(Milliseconds:LongWord):LongWord; 
function SysWatchdogStop:LongWord;
function SysWatchdogRefresh(Milliseconds:LongWord):LongWord;

{==============================================================================}
{Device Helper Functions}
function DeviceGetCount:LongWord; inline;

function DeviceCheck(Device:PDevice):PDevice;

function NotifierGetCount:LongWord; inline;

function NotifierCheck(Notifier:PNotifier):PNotifier;

function DeviceBusToString(DeviceBus:LongWord):String;
function DeviceStateToString(DeviceState:LongWord):String;
function DeviceClassToString(DeviceClass:LongWord):String;

function NotificationToString(Notification:LongWord):String;

procedure DeviceLog(Level:LongWord;Device:PDevice;const AText:String);
procedure DeviceLogInfo(Device:PDevice;const AText:String);
procedure DeviceLogError(Device:PDevice;const AText:String);
procedure DeviceLogDebug(Device:PDevice;const AText:String);

{==============================================================================}
{Driver Helper Functions}
function DriverGetCount:LongWord; inline;

function DriverCheck(Driver:PDriver):PDriver;

function DriverStateToString(DriverState:LongWord):String;
function DriverClassToString(DriverClass:LongWord):String;

{==============================================================================}
{Clock Device Helper Functions}
function ClockDeviceGetCount:LongWord; inline;
function ClockDeviceGetDefault:PClockDevice; inline;
function ClockDeviceSetDefault(Clock:PClockDevice):LongWord; 

function ClockDeviceCheck(Clock:PClockDevice):PClockDevice;

{==============================================================================}
{Timer Device Helper Functions}
function TimerDeviceGetCount:LongWord; inline;
function TimerDeviceGetDefault:PTimerDevice; inline;
function TimerDeviceSetDefault(Timer:PTimerDevice):LongWord; 

function TimerDeviceCheck(Timer:PTimerDevice):PTimerDevice;

{==============================================================================}
{Random Device Helper Functions}
function RandomDeviceGetCount:LongWord; inline;
function RandomDeviceGetDefault:PRandomDevice; inline;
function RandomDeviceSetDefault(Random:PRandomDevice):LongWord; 

function RandomDeviceCheck(Random:PRandomDevice):PRandomDevice;

{==============================================================================}
{Mailbox Device Helper Functions}
function MailboxDeviceGetCount:LongWord; inline;
function MailboxDeviceGetDefault:PMailboxDevice; inline;
function MailboxDeviceSetDefault(Mailbox:PMailboxDevice):LongWord; 

function MailboxDeviceCheck(Mailbox:PMailboxDevice):PMailboxDevice;

{==============================================================================}
{Watchdog Device Helper Functions}
function WatchdogDeviceGetCount:LongWord; inline;
function WatchdogDeviceGetDefault:PWatchdogDevice; inline;
function WatchdogDeviceSetDefault(Watchdog:PWatchdogDevice):LongWord; 

function WatchdogDeviceCheck(Watchdog:PWatchdogDevice):PWatchdogDevice;

{==============================================================================}
{==============================================================================}

implementation

{==============================================================================}
{==============================================================================}
var
 {Device specific variables}
 DevicesInitialized:Boolean;
 
 DeviceTable:PDevice;
 DeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 DeviceTableCount:LongWord;
 
 NotifierTable:PNotifier;
 NotifierTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 NotifierTableCount:LongWord;
 
{==============================================================================}
var
 {Driver specific variables}
 DriverTable:PDriver;
 DriverTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 DriverTableCount:LongWord;
 
{==============================================================================}
var
 {Clock specific variables}
 ClockDeviceTable:PClockDevice;
 ClockDeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 ClockDeviceTableCount:LongWord;
 
 ClockDeviceDefault:PClockDevice;
 
{==============================================================================}
var
 {Timer specific variables}
 TimerDeviceTable:PTimerDevice;
 TimerDeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 TimerDeviceTableCount:LongWord;
 
 TimerDeviceDefault:PTimerDevice;
 
{==============================================================================}
var
 {Random specific variables}
 RandomDeviceTable:PRandomDevice;
 RandomDeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 RandomDeviceTableCount:LongWord;

 RandomDeviceDefault:PRandomDevice;
 
{==============================================================================}
var
 {Mailbox specific variables}
 MailboxDeviceTable:PMailboxDevice;
 MailboxDeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 MailboxDeviceTableCount:LongWord;

 MailboxDeviceDefault:PMailboxDevice;
 
{==============================================================================}
var
 {Watchdog specific variables}
 WatchdogDeviceTable:PWatchdogDevice;
 WatchdogDeviceTableLock:TCriticalSectionHandle = INVALID_HANDLE_VALUE;
 WatchdogDeviceTableCount:LongWord;
 
 WatchdogDeviceDefault:PWatchdogDevice;
 
{==============================================================================}
{==============================================================================}
{Initialization Functions}
procedure DevicesInit;
{Initialize the Devices unit and device, notifier and driver tables}

{Note: Called only during system startup}
begin
 {}
 {Check Initialized}
 if DevicesInitialized then Exit;
 
 {Initialize Logging}
 DEVICE_LOG_ENABLED:=(DEVICE_DEFAULT_LOG_LEVEL <> DEVICE_LOG_LEVEL_NONE); 
 
 {Initialize Device Table}
 DeviceTable:=nil;
 DeviceTableLock:=CriticalSectionCreate; 
 DeviceTableCount:=0;
 if DeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create device table lock');
  end;
 
 {Initialize Notifier Table}
 NotifierTable:=nil;
 NotifierTableLock:=CriticalSectionCreate; 
 NotifierTableCount:=0;
 if NotifierTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create notifier table lock');
  end;

 {Initialize Driver Table}
 DriverTable:=nil;
 DriverTableLock:=CriticalSectionCreate; 
 DriverTableCount:=0;
 if DriverTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create driver table lock');
  end;
 
 {Initialize Clock Device Table}
 ClockDeviceTable:=nil;
 ClockDeviceTableLock:=CriticalSectionCreate; 
 ClockDeviceTableCount:=0;
 if ClockDeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create clock device table lock');
  end;
 ClockDeviceDefault:=nil;
 
 {Initialize Timer Device Table}
 TimerDeviceTable:=nil;
 TimerDeviceTableLock:=CriticalSectionCreate; 
 TimerDeviceTableCount:=0;
 if TimerDeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create timer device table lock');
  end;
 TimerDeviceDefault:=nil;
 
 {Initialize Random Device Table}
 RandomDeviceTable:=nil;
 RandomDeviceTableLock:=CriticalSectionCreate; 
 RandomDeviceTableCount:=0;
 if RandomDeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create random device table lock');
  end;
 RandomDeviceDefault:=nil;
 
 {Initialize Mailbox Device Table}
 MailboxDeviceTable:=nil;
 MailboxDeviceTableLock:=CriticalSectionCreate; 
 MailboxDeviceTableCount:=0;
 if MailboxDeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create mailbox device table lock');
  end;
 MailboxDeviceDefault:=nil;
 
 {Initialize Watchdog Device Table}
 WatchdogDeviceTable:=nil;
 WatchdogDeviceTableLock:=CriticalSectionCreate; 
 WatchdogDeviceTableCount:=0;
 if WatchdogDeviceTableLock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create watchdog device table lock');
  end;
 WatchdogDeviceDefault:=nil;
 
 {Register Platform Clock Handlers}
 if DEVICE_REGISTER_CLOCK then
  begin
   ClockGetCountHandler:=SysClockRead;
   ClockGetTotalHandler:=SysClockRead64;
  end; 

 {Register Platform Timer Handlers}
 if DEVICE_REGISTER_TIMER then
  begin
   CounterAvailableHandler:=SysTimerAvailable;
   CounterReadHandler:=SysTimerRead;
   CounterRead64Handler:=SysTimerRead64;
   CounterWaitHandler:=SysTimerWait;
   CounterEventHandler:=SysTimerEvent;
   CounterGetRateHandler:=SysTimerGetRate;
   CounterSetRateHandler:=SysTimerSetRate;
   CounterGetIntervalHandler:=SysTimerGetInterval;
   CounterSetIntervalHandler:=SysTimerSetInterval;
  end; 
 
 {Register Platform Random Handlers}
 if DEVICE_REGISTER_RANDOM then
  begin
   RandomAvailableHandler:=SysRandomAvailable;
   RandomSeedHandler:=SysRandomSeed;
   RandomReadLongIntHandler:=SysRandomReadLongInt;
   RandomReadInt64Handler:=SysRandomReadInt64;
   RandomReadExtendedHandler:=SysRandomReadExtended;
  end; 

 {Register Platform Mailbox Handlers}
 if DEVICE_REGISTER_MAILBOX then
  begin
   //To Do 
  end; 
 
 {Register Platform Watchdog Handlers}
 if DEVICE_REGISTER_WATCHDOG then
  begin
   WatchdogAvailableHandler:=SysWatchdogAvailable;
   WatchdogStartHandler:=SysWatchdogStart;
   WatchdogStopHandler:=SysWatchdogStop;
   WatchdogRefreshHandler:=SysWatchdogRefresh;
  end; 

 DevicesInitialized:=True;
end;

{==============================================================================}
{==============================================================================}
{Device Functions}
function DeviceCreate:PDevice;
{Create a new Device entry}
{Return: Pointer to new Device entry or nil if device could not be created}
begin
 {}
 Result:=DeviceCreateEx(SizeOf(TDevice));
end;

{==============================================================================}

function DeviceCreateEx(Size:LongWord):PDevice;
{Create a new Device entry}
{Size: Size in bytes to allocate for new device (Including the device entry)}
{Return: Pointer to new Device entry or nil if device could not be created}
var
 Device:PDevice;
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TDevice) then Exit;
 
 {Create Device}
 if DEVICE_SHARED_MEMORY then
  begin
   Device:=AllocSharedMem(Size);
  end
 else
  begin
   Device:=AllocMem(Size);
  end;
 if Device = nil then Exit;
 
 {Update Device}
 Device.Signature:=DEVICE_SIGNATURE;
 Device.DeviceId:=DEVICE_ID_ANY;
 Device.DeviceState:=DEVICE_STATE_UNREGISTERED;
 Device.DeviceName:=''; 
 Device.DeviceClass:=DEVICE_CLASS_ANY;
 Device.DeviceDescription:='';

 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Created device (Handle=' + IntToHex(LongWord(Device),8) + ' Size=' + IntToStr(Size) + ')');
 {$ENDIF}
 
 {Return Result}
 Result:=Device; 
end;

{==============================================================================}

function DeviceDestroy(Device:PDevice):LongWord;
{Destroy an existing Device entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Device}
 Result:=ERROR_IN_USE;
 if DeviceCheck(Device) = Device then Exit;
 
 {Check State}
 if Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Invalidate Device}
 Device.Signature:=0;
 
 {Free the Description}
 SetLength(Device.DeviceDescription,0);
 
 {Free the Name}
 SetLength(Device.DeviceName,0);
 
 {Free Device}
 FreeMem(Device);
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Destroyed device (Handle=' + IntToHex(LongWord(Device),8) + ')');
 {$ENDIF}
 
 {Return Result}
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function DeviceGetName(Device:PDevice):String;
{Get the name of the supplied Device}
begin
 {}
 Result:='';

 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Name}
    Result:=Device.DeviceName;
    
    {Return Result}
    UniqueString(Result);
   finally
    {Release Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceSetName(Device:PDevice;const Name:String):LongWord;
{Set the name of the supplied Device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;

 {Check Name}
 if Length(Name) = 0 then Exit;
 
 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Set Name}
    Device.DeviceName:=Name;
    UniqueString(Device.DeviceName);

    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceGetDescription(Device:PDevice):String;
{Get the description of the supplied Device}
begin
 {}
 Result:='';

 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Description}
    Result:=Device.DeviceDescription;
    
    {Return Result}
    UniqueString(Result);
   finally
    {Release Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceSetDescription(Device:PDevice;const Description:String):LongWord;
{Set the description of the supplied Device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;

 {Check Description}
 if Length(Description) = 0 then Exit;
 
 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Set Description}
    Device.DeviceDescription:=Description;
    UniqueString(Device.DeviceDescription);

    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceRegister(Device:PDevice):LongWord;
{Register a new Device in the Device table}
var
 DeviceId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;

 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 if Device.DeviceId <> DEVICE_ID_ANY then Exit;
 if Length(Device.DeviceName) = 0 then Exit; 
 if Device.DeviceClass = DEVICE_CLASS_ANY then Exit;
 
 {Check Device}
 Result:=ERROR_ALREADY_EXISTS;
 if DeviceCheck(Device) = Device then Exit;

 {Check State}
 if Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Device}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Link Device}
    if DeviceTable = nil then
     begin
      DeviceTable:=Device;
     end
    else
     begin
      Device.Next:=DeviceTable;
      DeviceTable.Prev:=Device;
      DeviceTable:=Device;
     end;
    
    {Increment Count}
    Inc(DeviceTableCount);
    
    {Update Device}
    DeviceId:=0;
    while DeviceFind(DEVICE_CLASS_ANY,DeviceId) <> nil do
     begin
      Inc(DeviceId);
     end;
    Device.DeviceId:=DeviceId;
    
    {Register Device}
    Device.DeviceState:=DEVICE_STATE_REGISTERED;
 
    {Notify Register}
    Result:=NotifierNotify(Device,DEVICE_NOTIFICATION_REGISTER);
    if Result <> ERROR_SUCCESS then Exit;
   
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Registered device (Handle=' + IntToHex(LongWord(Device),8) + ' Class=' + DeviceClassToString(Device.DeviceClass) + ' Name=' + DeviceGetName(Device) + ')');
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function DeviceDeregister(Device:PDevice):LongWord;
{Deregister a Device from the Device table}
var
 Prev:PDevice;
 Next:PDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 if Device.DeviceId = DEVICE_ID_ANY then Exit;
 if Device.DeviceClass = DEVICE_CLASS_ANY then Exit;
 
 {Check Device}
 Result:=ERROR_NOT_FOUND;
 if DeviceCheck(Device) <> Device then Exit;

 {Check State}
 if Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;

 {Remove Device}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Notify Deregister}
    Result:=NotifierNotify(Device,DEVICE_NOTIFICATION_DEREGISTER);
    if Result <> ERROR_SUCCESS then Exit;
 
    {Deregister Device}
    Device.DeviceState:=DEVICE_STATE_UNREGISTERED;
 
    {Unlink Device}
    Prev:=Device.Prev;
    Next:=Device.Next;
    if Prev = nil then
     begin
      DeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
    
    {Decrement Count}
    Dec(DeviceTableCount);
 
    {Update Device}
    Device.DeviceId:=DEVICE_ID_ANY;
 
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Deregistered device (Handle=' + IntToHex(LongWord(Device),8) + ' Class=' + DeviceClassToString(Device.DeviceClass) + ' Name=' + DeviceGetName(Device) + ')');
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function DeviceFind(DeviceClass,DeviceId:LongWord):PDevice;
var
 Device:PDevice;
begin
 {}
 Result:=nil;
 
 {Acquire the Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Device}
    Device:=DeviceTable;
    while Device <> nil do
     begin
      {Check State}
      if Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if DeviceId <> DEVICE_ID_ANY then
         begin
          {Check Id}
          if Device.DeviceId = DeviceId then
           begin
            {Check Class}
            if (DeviceClass = DEVICE_CLASS_ANY) or (Device.DeviceClass = DeviceClass) then
             begin
              Result:=Device;
              Exit;
             end;
           end;  
         end
        else
         begin
          {Check Class}
          if (DeviceClass = DEVICE_CLASS_ANY) or (Device.DeviceClass = DeviceClass) then
           begin
            Result:=Device;
            Exit;
           end;
         end;       
       end;
       
      {Get Next}
      Device:=Device.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceFindByName(const Name:String):PDevice;
var
 Device:PDevice;
begin
 {}
 Result:=nil;
 
 {Acquire the Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Device}
    Device:=DeviceTable;
    while Device <> nil do
     begin
      {Check State}
      if Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Name}
        if Uppercase(Device.DeviceName) = Uppercase(Name) then
         begin
          Result:=Device;
          Exit;
         end;
       end;
       
      {Get Next}
      Device:=Device.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;
       
{==============================================================================}

function DeviceFindByDescription(const Description:String):PDevice;
var
 Device:PDevice;
begin
 {}
 Result:=nil;
 
 {Acquire the Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Device}
    Device:=DeviceTable;
    while Device <> nil do
     begin
      {Check State}
      if Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Description}
        if Uppercase(Device.DeviceDescription) = Uppercase(Description) then
         begin
          Result:=Device;
          Exit;
         end;
       end;
       
      {Get Next}
      Device:=Device.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceEnumerate(DeviceClass:LongWord;Callback:TDeviceEnumerate;Data:Pointer):LongWord;
var
 Device:PDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Device}
    Device:=DeviceTable;
    while Device <> nil do
     begin
      {Check State}
      if Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Class}
        if (DeviceClass = DEVICE_CLASS_ANY) or (Device.DeviceClass = DeviceClass) then
         begin
          if Callback(Device,Data) <> ERROR_SUCCESS then Exit;
         end;
       end;
      
      {Get Next}
      Device:=Device.Next;
     end;
  
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function DeviceNotification(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
var
 Notifier:PNotifier;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;

 {Check Notification}
 if Notification <> DEVICE_NOTIFICATION_NONE then
  begin
   {Acquire the Lock}
   if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
    begin
     try
      {Get Notifier}
      Notifier:=NotifierFind(Device,DeviceClass,Callback,Data);
      if Notifier = nil then
       begin
        {Allocate Notifier}
        Notifier:=NotifierAllocate(Device,DeviceClass,Callback,Data,Notification,Flags);
        if Notifier = nil then Exit;
       end
      else
       begin
        {Update Notifier}
        Notifier.Notification:=Notifier.Notification or Notification; {Add to existing}
       end;       
  
      {Register Notifier}
      Notifier.NotifierState:=NOTIFIER_STATE_REGISTERED;
   
      {Return Result}
      Result:=ERROR_SUCCESS;
     finally
      {Release the Lock}
      CriticalSectionUnlock(NotifierTableLock);
     end;
    end
   else
    begin
     Result:=ERROR_CAN_NOT_COMPLETE;
    end;  
  end
 else
  begin
   {Acquire the Lock}
   if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
    begin
     try
      Result:=ERROR_NOT_FOUND;
   
      {Get Notifier}
      Notifier:=NotifierFind(Device,DeviceClass,Callback,Data);
      if Notifier = nil then Exit;
   
      {Deregister Notifier}
      Notifier.NotifierState:=NOTIFIER_STATE_UNREGISTERED;
   
      {Release Notifier}
      Result:=NotifierRelease(Notifier);
     finally
      {Release the Lock}
      CriticalSectionUnlock(NotifierTableLock);
     end;
    end
   else
    begin
     Result:=ERROR_CAN_NOT_COMPLETE;
    end;  
  end;
end;

{==============================================================================}

function NotifierAllocate(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer;Notification,Flags:LongWord):PNotifier;
{Create and Register a new Notifier entry in the Notifier table}
var
 Notifier:PNotifier;
begin
 {}
 Result:=nil;

 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Create Notifier}
 Notifier:=AllocMem(SizeOf(TNotifier));
 if Notifier = nil then Exit;
 
 {Update Notifier}
 Notifier.Signature:=NOTIFIER_SIGNATURE;
 Notifier.NotifierState:=NOTIFIER_STATE_UNREGISTERED;
 Notifier.NotifierFlags:=Flags;
 Notifier.Device:=Device;
 Notifier.DeviceClass:=DeviceClass;
 Notifier.Callback:=Callback;
 Notifier.Data:=Data;
 Notifier.Notification:=Notification;
 
 {Insert Notifier}
 if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
  begin
   try
    {Link Notifier}
    if NotifierTable = nil then
     begin
      NotifierTable:=Notifier;
     end
    else
     begin
      Notifier.Next:=NotifierTable;
      NotifierTable.Prev:=Notifier;
      NotifierTable:=Notifier;
     end;
    
    {Increment Count}
    Inc(NotifierTableCount);
 
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Allocated device notification (Handle=' + IntToHex(LongWord(Notifier),8) + ' Device=' + IntToHex(LongWord(Notifier.Device),8) + ' Class=' + DeviceClassToString(Notifier.DeviceClass) + ' Notification=' + NotificationToString(Notifier.Notification) + ')');
    {Return Result}
    Result:=Notifier;
   finally
    CriticalSectionUnlock(NotifierTableLock);
   end;
  end;
end;

{==============================================================================}

function NotifierRelease(Notifier:PNotifier):LongWord;
{Deregister and Destroy a Notifier from the Notifier table}
var
 Prev:PNotifier;
 Next:PNotifier;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Notifier}
 if Notifier = nil then Exit;
 if Notifier.Signature <> NOTIFIER_SIGNATURE then Exit;
 
 {Check Notifier}
 if NotifierCheck(Notifier) <> Notifier then Exit;
 
 {Check State}
 if Notifier.NotifierState <> NOTIFIER_STATE_UNREGISTERED then Exit;

 {Remove Notifier}
 if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
  begin
   try
    {Unlink Notifier}
    Prev:=Notifier.Prev;
    Next:=Notifier.Next;
    if Prev = nil then
     begin
      NotifierTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
    
    {Decrement Count}
    Dec(NotifierTableCount);

    {Invalidate Notifier}
    Notifier.Signature:=0;
 
    {Free Notifier}
    FreeMem(Notifier);
    
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Released device notification (Handle=' + IntToHex(LongWord(Notifier),8) + ')');
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(NotifierTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function NotifierFind(Device:PDevice;DeviceClass:LongWord;Callback:TDeviceNotification;Data:Pointer):PNotifier;
var
 Notifier:PNotifier;
begin
 {}
 Result:=nil;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Notifier}
    Notifier:=NotifierTable;
    while Notifier <> nil do
     begin
      {Check State}
      if Notifier.NotifierState = NOTIFIER_STATE_REGISTERED then
       begin
        {Check Device/DeviceClass/Callback}
        if (Notifier.Device = Device) and (Notifier.DeviceClass = DeviceClass) and (@Notifier.Callback = @Callback) and (Notifier.Data = Data) then
         begin
          Result:=Notifier;
          Exit;
         end;
       end;  
       
      {Get Next}
      Notifier:=Notifier.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(NotifierTableLock);
   end;
  end;
end;

{==============================================================================}

function NotifierNotify(Device:PDevice;Notification:LongWord):LongWord;
var
 Status:LongWord;
 Notifier:PNotifier;
 Task:PNotifierTask;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Device}
 if Device = nil then Exit;

 if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Sending device notification (Name=' + DeviceGetName(Device) + ' Class=' + DeviceClassToString(Device.DeviceClass) + ' Notification=' + NotificationToString(Notification) + ')');
 
 {Acquire the Lock}
 if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
  begin
   try
    Result:=ERROR_SUCCESS;
    
    {Get Notifier}
    Notifier:=NotifierTable;
    while Notifier <> nil do
     begin
      {Check State}
      if Notifier.NotifierState = NOTIFIER_STATE_REGISTERED then
       begin
        {Check Notification}
        if (Notifier.Notification and Notification) <> 0 then
         begin
          {Check Device}
          if (Notifier.Device <> nil) then
           begin
            {Check Device}
            if Notifier.Device = Device then
             begin
              if (Notifier.NotifierFlags and NOTIFIER_FLAG_WORKER) = 0 then
               begin
                Status:=Notifier.Callback(Device,Notifier.Data,Notification);
                if Status <> ERROR_SUCCESS then Result:=Status;
               end
              else
               begin
                {Create Task}
                Task:=AllocMem(SizeOf(TNotifierTask));
                if Task <> nil then
                 begin
                  {Setup Task}
                  Task.Device:=Device;
                  Task.Callback:=Notifier.Callback;
                  Task.Data:=Notifier.Data;
                  Task.Notification:=Notification;
                  
                  {Schedule Worker}
                  if WorkerSchedule(0,TWorkerTask(NotifierWorker),Task,nil) <> ERROR_SUCCESS then
                   begin
                    FreeMem(Task);
                   end;
                 end;
               end; 
             end; 
           end
          else
           begin
            {Check Device Class}
            if (Notifier.DeviceClass = DEVICE_CLASS_ANY) or (Notifier.DeviceClass = Device.DeviceClass) then
             begin
              if (Notifier.NotifierFlags and NOTIFIER_FLAG_WORKER) = 0 then
               begin
                Status:=Notifier.Callback(Device,Notifier.Data,Notification);
                if Status <> ERROR_SUCCESS then Result:=Status;
               end
              else
               begin
                {Create Task}
                Task:=AllocMem(SizeOf(TNotifierTask));
                if Task <> nil then
                 begin
                  {Setup Task}
                  Task.Device:=Device;
                  Task.Callback:=Notifier.Callback;
                  Task.Data:=Notifier.Data;
                  Task.Notification:=Notification;
                  
                  {Schedule Worker}
                  if WorkerSchedule(0,TWorkerTask(NotifierWorker),Task,nil) <> ERROR_SUCCESS then
                   begin
                    FreeMem(Task);
                   end;
                 end;
               end;
             end;
           end;         
         end;
       end;  
     
      {Get Next}
      Notifier:=Notifier.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(NotifierTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

procedure NotifierWorker(Task:PNotifierTask);
begin
 {}
 {Check Task}
 if Task = nil then Exit;
 
 {Check Callback}
 if Assigned(Task.Callback) then
  begin
   {Call the Callback}
   Task.Callback(Task.Device,Task.Data,Task.Notification);
  end;
 
 {Destroy Task}
 FreeMem(Task); 
end;

{==============================================================================}
{==============================================================================}
{Driver Functions}
function DriverCreate:PDriver;
{Create a new Driver entry}
{Return: Pointer to new Driver entry or nil if driver could not be created}
begin
 {}
 Result:=DriverCreateEx(SizeOf(TDriver));
end;

{==============================================================================}

function DriverCreateEx(Size:LongWord):PDriver;
{Create a new Driver entry}
{Size: Size in bytes to allocate for new driver (Including the driver entry)}
{Return: Pointer to new Driver entry or nil if driver could not be created}
var
 Driver:PDriver;
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TDriver) then Exit;
 
 {Create Driver}
 if DRIVER_SHARED_MEMORY then
  begin
   Driver:=AllocSharedMem(Size);
  end
 else
  begin
   Driver:=AllocMem(Size);
  end; 
 if Driver = nil then Exit;
 
 {Update Driver}
 Driver.Signature:=DRIVER_SIGNATURE;
 Driver.DriverId:=DRIVER_ID_ANY;
 Driver.DriverState:=DRIVER_STATE_UNREGISTERED;
 Driver.DriverName:=''; 
 Driver.DriverClass:=DRIVER_CLASS_ANY;

 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Created driver (Driver=' + IntToHex(LongWord(Driver),8) + ' Size=' + IntToStr(Size) + ')');
 {$ENDIF}
 
 {Return Result}
 Result:=Driver; 
end;

{==============================================================================}

function DriverDestroy(Driver:PDriver):LongWord;
{Destroy an existing Driver entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 
 {Check Driver}
 Result:=ERROR_IN_USE;
 if DriverCheck(Driver) = Driver then Exit;
 
 {Check State}
 if Driver.DriverState <> DRIVER_STATE_UNREGISTERED then Exit;
 
 {Invalidate Driver}
 Driver.Signature:=0;
 
 {Free the Name}
 SetLength(Driver.DriverName,0);
 
 {Free Driver}
 FreeMem(Driver);
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Destroyed driver (Driver=' + IntToHex(LongWord(Driver),8) + ')');
 {$ENDIF}
 
 {Return Result}
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function DriverGetName(Driver:PDriver):String;
{Get the name of the supplied Driver}
begin
 {}
 Result:='';

 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Name}
    Result:=Driver.DriverName;
    
    {Return Result}
    UniqueString(Result);
   finally
    {Release Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end;
end;

{==============================================================================}

function DriverSetName(Driver:PDriver;const Name:String):LongWord;
{Set the name of the supplied Driver}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;

 {Check Name}
 if Length(Name) = 0 then Exit;
 
 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 
 {Acquire Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Set Name}
    Driver.DriverName:=Name;
    UniqueString(Driver.DriverName);

    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end;
end;

{==============================================================================}

function DriverRegister(Driver:PDriver):LongWord;
{Register a new Driver in the Driver table}
var
 DriverId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;

 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 if Driver.DriverId <> DRIVER_ID_ANY then Exit;
 if Length(Driver.DriverName) = 0 then Exit; 
 if Driver.DriverClass = DRIVER_CLASS_ANY then Exit;
 
 {Check Driver}
 Result:=ERROR_ALREADY_EXISTS;
 if DriverCheck(Driver) = Driver then Exit;

 {Check State}
 if Driver.DriverState <> DRIVER_STATE_UNREGISTERED then Exit;
 
 {Insert Driver}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Link Driver}
    if DriverTable = nil then
     begin
      DriverTable:=Driver;
     end
    else
     begin
      Driver.Next:=DriverTable;
      DriverTable.Prev:=Driver;
      DriverTable:=Driver;
     end;
    
    {Increment Count}
    Inc(DriverTableCount);
    
    {Update Driver}
    DriverId:=0;
    while DriverFind(DRIVER_CLASS_ANY,DriverId) <> nil do
     begin
      Inc(DriverId);
     end;
    Driver.DriverId:=DriverId;
    
    {Register Driver}
    Driver.DriverState:=DRIVER_STATE_REGISTERED;
  
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Registered driver (Driver=' + IntToHex(LongWord(Driver),8) + ' Class=' + DriverClassToString(Driver.DriverClass) + ' Name=' + DriverGetName(Driver) + ')');
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(DriverTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function DriverDeregister(Driver:PDriver):LongWord;
{Deregister a Driver from the Driver table}
var
 Prev:PDriver;
 Next:PDriver;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 if Driver.DriverId = DRIVER_ID_ANY then Exit;
 if Driver.DriverClass = DRIVER_CLASS_ANY then Exit;
 
 {Check Driver}
 Result:=ERROR_NOT_FOUND;
 if DriverCheck(Driver) <> Driver then Exit;

 {Check State}
 if Driver.DriverState <> DRIVER_STATE_REGISTERED then Exit;

 {Remove Driver}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Driver}
    Driver.DriverState:=DRIVER_STATE_UNREGISTERED;
 
    {Unlink Driver}
    Prev:=Driver.Prev;
    Next:=Driver.Next;
    if Prev = nil then
     begin
      DriverTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
    
    {Decrement Count}
    Dec(DriverTableCount);
 
    {Update Driver}
    Driver.DriverId:=DRIVER_ID_ANY;
 
    if DEVICE_LOG_ENABLED then DeviceLogInfo(nil,'Deregistered driver (Driver=' + IntToHex(LongWord(Driver),8) + ' Class=' + DriverClassToString(Driver.DriverClass) + ' Name=' + DriverGetName(Driver) + ')');
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(DriverTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function DriverFind(DriverClass,DriverId:LongWord):PDriver;
var
 Driver:PDriver;
begin
 {}
 Result:=nil;
 
 {Acquire the Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Driver}
    Driver:=DriverTable;
    while Driver <> nil do
     begin
      {Check State}
      if Driver.DriverState = DRIVER_STATE_REGISTERED then
       begin
        {Check Id}
        if DriverId <> DRIVER_ID_ANY then
         begin
          {Check Id}
          if Driver.DriverId = DriverId then
           begin
            {Check Class}
            if (DriverClass = DRIVER_CLASS_ANY) or (Driver.DriverClass = DriverClass) then
             begin
              Result:=Driver;
              Exit;
             end;
           end;  
         end
        else
         begin
          {Check Class}
          if (DriverClass = DRIVER_CLASS_ANY) or (Driver.DriverClass = DriverClass) then
           begin
            Result:=Driver;
            Exit;
           end;
         end;       
       end;
       
      {Get Next}
      Driver:=Driver.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end;
end;

{==============================================================================}

function DriverFindByName(const Name:String):PDriver;
var
 Driver:PDriver;
begin
 {}
 Result:=nil;
 
 {Acquire the Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Driver}
    Driver:=DriverTable;
    while Driver <> nil do
     begin
      {Check State}
      if Driver.DriverState = DRIVER_STATE_REGISTERED then
       begin
        {Check Name}
        if Uppercase(Driver.DriverName) = Uppercase(Name) then
         begin
          Result:=Driver;
          Exit;
         end;
       end;
       
      {Get Next}
      Driver:=Driver.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end;
end;

{==============================================================================}

function DriverEnumerate(DriverClass:LongWord;Callback:TDriverEnumerate;Data:Pointer):LongWord;
var
 Driver:PDriver;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Driver}
    Driver:=DriverTable;
    while Driver <> nil do
     begin
      {Check State}
      if Driver.DriverState = DRIVER_STATE_REGISTERED then
       begin
        {Check Class}
        if (DriverClass = DRIVER_CLASS_ANY) or (Driver.DriverClass = DriverClass) then
         begin
          if Callback(Driver,Data) <> ERROR_SUCCESS then Exit;
         end;
       end;
      
      {Get Next}
      Driver:=Driver.Next;
     end;
  
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}
{==============================================================================}
{Clock Device Functions}
function ClockDeviceStart(Clock:PClockDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Clock Device Start');
 {$ENDIF}

 {Check Disabled}
 Result:=ERROR_SUCCESS;
 if Clock.ClockState <> CLOCK_STATE_DISABLED then Exit;

 {Check Start}
 Result:=ERROR_INVALID_PARAMETER;
 if Assigned(Clock.DeviceStart) then
  begin
   {Call Device Start}
   Result:=Clock.DeviceStart(Clock);
   if Result <> ERROR_SUCCESS then Exit;
  end; 
 
 {Enable Device}
 Clock.ClockState:=CLOCK_STATE_ENABLED;

 {Notify Enable}
 NotifierNotify(@Clock.Device,DEVICE_NOTIFICATION_ENABLE);
 
 Result:=ERROR_SUCCESS;
end;
 
{==============================================================================}

function ClockDeviceStop(Clock:PClockDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Clock Device Stop');
 {$ENDIF}

 {Check Enabled}
 Result:=ERROR_SUCCESS;
 if Clock.ClockState <> CLOCK_STATE_ENABLED then Exit;
 
 {Check Stop}
 if Assigned(Clock.DeviceStop) then
  begin
   {Call Device Stop}
   Result:=Clock.DeviceStop(Clock);
   if Result <> ERROR_SUCCESS then Exit;
  end; 
 
 {Disable Device}
 Clock.ClockState:=CLOCK_STATE_DISABLED;

 {Notify Disable}
 NotifierNotify(@Clock.Device,DEVICE_NOTIFICATION_DISABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function ClockDeviceRead(Clock:PClockDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {Check Enabled}
 if Clock.ClockState <> CLOCK_STATE_ENABLED then Exit;
 
 if Assigned(Clock.DeviceRead) then
  begin
   Result:=Clock.DeviceRead(Clock);
  end
 else
  begin
   Result:=ClockDeviceRead64(Clock);
  end;  
end;

{==============================================================================}

function ClockDeviceRead64(Clock:PClockDevice):Int64;
begin
 {}
 Result:=0;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {Check Enabled}
 if Clock.ClockState <> CLOCK_STATE_ENABLED then Exit;
 
 if Assigned(Clock.DeviceRead64) then
  begin
   Result:=Clock.DeviceRead64(Clock);
  end;
end;

{==============================================================================}

function ClockDeviceGetRate(Clock:PClockDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Clock Device Get Rate');
 {$ENDIF}

 {Check Enabled}
 {if Clock.ClockState <> CLOCK_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Clock.DeviceGetRate) then
  begin
   Result:=Clock.DeviceGetRate(Clock);
  end
 else
  begin
   if MutexLock(Clock.Lock) <> ERROR_SUCCESS then Exit;
   
   Result:=Clock.Rate;
   
   MutexUnlock(Clock.Lock);
  end;  
end;

{==============================================================================}

function ClockDeviceCreate:PClockDevice;
{Create a new Clock entry}
{Return: Pointer to new Clock entry or nil if Clock could not be created}
begin
 {}
 Result:=ClockDeviceCreateEx(SizeOf(TClockDevice));
end;

{==============================================================================}

function ClockDeviceCreateEx(Size:LongWord):PClockDevice;
{Create a new Clock entry}
{Size: Size in bytes to allocate for new Clock (Including the Clock entry)}
{Return: Pointer to new Clock entry or nil if Clock could not be created}
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TClockDevice) then Exit;
 
 {Create Clock}
 Result:=PClockDevice(DeviceCreateEx(Size));
 if Result = nil then Exit;
 
 {Update Device}
 Result.Device.DeviceBus:=DEVICE_BUS_NONE;   
 Result.Device.DeviceType:=CLOCK_TYPE_NONE;
 Result.Device.DeviceFlags:=CLOCK_FLAG_NONE;
 Result.Device.DeviceData:=nil;

 {Update Clock}
 Result.ClockId:=DEVICE_ID_ANY;
 Result.ClockState:=CLOCK_STATE_DISABLED;
 Result.DeviceStart:=nil;
 Result.DeviceStop:=nil;
 Result.DeviceRead:=nil;
 Result.DeviceRead64:=nil;
 Result.DeviceGetRate:=nil;
 Result.Lock:=INVALID_HANDLE_VALUE;
 Result.Address:=nil;
 Result.Rate:=0;
 
 {Create Lock}
 Result.Lock:=MutexCreate;
 if Result.Lock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create lock for clock device');
   ClockDeviceDestroy(Result);
   Result:=nil;
   Exit;
  end;
end;

{==============================================================================}

function ClockDeviceDestroy(Clock:PClockDevice):LongWord;
{Destroy an existing Clock entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Clock}
 Result:=ERROR_IN_USE;
 if ClockDeviceCheck(Clock) = Clock then Exit;

 {Check State}
 if Clock.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Destroy Lock}
 if Clock.Lock <> INVALID_HANDLE_VALUE then
  begin
   MutexDestroy(Clock.Lock);
  end;
 
 {Destroy Clock} 
 Result:=DeviceDestroy(@Clock.Device);
end;

{==============================================================================}

function ClockDeviceRegister(Clock:PClockDevice):LongWord;
{Register a new Clock in the Clock table}
var
 ClockId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.ClockId <> DEVICE_ID_ANY then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Interfaces}
 if not(Assigned(Clock.DeviceRead64)) then Exit;
 
 {Check Clock}
 Result:=ERROR_ALREADY_EXISTS;
 if ClockDeviceCheck(Clock) = Clock then Exit;
 
 {Check State}
 if Clock.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Clock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Update Clock}
    ClockId:=0;
    while ClockDeviceFind(ClockId) <> nil do
     begin
      Inc(ClockId);
     end;
    Clock.ClockId:=ClockId;
    
    {Update Device}
    Clock.Device.DeviceName:=CLOCK_NAME_PREFIX + IntToStr(Clock.ClockId);
    Clock.Device.DeviceClass:=DEVICE_CLASS_CLOCK;
    
    {Register Device}
    Result:=DeviceRegister(@Clock.Device);
    if Result <> ERROR_SUCCESS then
     begin
      Clock.ClockId:=DEVICE_ID_ANY;
      Exit;
     end; 
    
    {Link Clock}
    if ClockDeviceTable = nil then
     begin
      ClockDeviceTable:=Clock;
     end
    else
     begin
      Clock.Next:=ClockDeviceTable;
      ClockDeviceTable.Prev:=Clock;
      ClockDeviceTable:=Clock;
     end;
 
    {Increment Count}
    Inc(ClockDeviceTableCount);
    
    {Check Default}
    if ClockDeviceDefault = nil then
     begin
      ClockDeviceDefault:=Clock;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function ClockDeviceDeregister(Clock:PClockDevice):LongWord;
{Deregister a Clock from the Clock table}
var
 Prev:PClockDevice;
 Next:PClockDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.ClockId = DEVICE_ID_ANY then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Clock}
 Result:=ERROR_NOT_FOUND;
 if ClockDeviceCheck(Clock) <> Clock then Exit;
 
 {Check State}
 if Clock.Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;
 
 {Remove Clock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Device}
    Result:=DeviceDeregister(@Clock.Device);
    if Result <> ERROR_SUCCESS then Exit;
    
    {Unlink Clock}
    Prev:=Clock.Prev;
    Next:=Clock.Next;
    if Prev = nil then
     begin
      ClockDeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
 
    {Decrement Count}
    Dec(ClockDeviceTableCount);
 
    {Check Default}
    if ClockDeviceDefault = Clock then
     begin
      ClockDeviceDefault:=ClockDeviceTable;
     end;
     
    {Update Clock}
    Clock.ClockId:=DEVICE_ID_ANY;
 
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function ClockDeviceFind(ClockId:LongWord):PClockDevice;
var
 Clock:PClockDevice;
begin
 {}
 Result:=nil;
 
 {Check Id}
 if ClockId = DEVICE_ID_ANY then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Clock}
    Clock:=ClockDeviceTable;
    while Clock <> nil do
     begin
      {Check State}
      if Clock.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if Clock.ClockId = ClockId then
         begin
          Result:=Clock;
          Exit;
         end;
       end;

       {Get Next}
      Clock:=Clock.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function ClockDeviceFindByName(const Name:String):PClockDevice; inline;
begin
 {}
 Result:=PClockDevice(DeviceFindByName(Name));
end;

{==============================================================================}

function ClockDeviceFindByDescription(const Description:String):PClockDevice; inline;
begin
 {}
 Result:=PClockDevice(DeviceFindByDescription(Description));
end;

{==============================================================================}

function ClockDeviceEnumerate(Callback:TClockEnumerate;Data:Pointer):LongWord;
var
 Clock:PClockDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Clock}
    Clock:=ClockDeviceTable;
    while Clock <> nil do
     begin
      {Check State}
      if Clock.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        if Callback(Clock,Data) <> ERROR_SUCCESS then Exit;
       end;
       
      {Get Next}
      Clock:=Clock.Next;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function ClockDeviceNotification(Clock:PClockDevice;Callback:TClockNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then
  begin
   Result:=DeviceNotification(nil,DEVICE_CLASS_CLOCK,Callback,Data,Notification,Flags);
  end
 else
  begin 
   {Check Clock}
   if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;

   Result:=DeviceNotification(@Clock.Device,DEVICE_CLASS_CLOCK,Callback,Data,Notification,Flags);
  end; 
end;

{==============================================================================}
{==============================================================================}
{Timer Device Functions}
function TimerDeviceStart(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Start');
 {$ENDIF}

 {Check Disabled}
 Result:=ERROR_SUCCESS;
 if Timer.TimerState <> TIMER_STATE_DISABLED then Exit;

 {Check Start}
 Result:=ERROR_INVALID_PARAMETER;
 if not(Assigned(Timer.DeviceStart)) then Exit;
 
 {Call Device Start}
 Result:=Timer.DeviceStart(Timer);
 if Result <> ERROR_SUCCESS then Exit;
 
 {Enable Device}
 Timer.TimerState:=TIMER_STATE_ENABLED;

 {Notify Enable}
 NotifierNotify(@Timer.Device,DEVICE_NOTIFICATION_ENABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function TimerDeviceStop(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Stop');
 {$ENDIF}

 {Check Enabled}
 Result:=ERROR_SUCCESS;
 if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;
 
 {Check Stop}
 if not(Assigned(Timer.DeviceStop)) then Exit;

 {Call Device Stop}
 Result:=Timer.DeviceStop(Timer);
 if Result <> ERROR_SUCCESS then Exit;
 
 {Disable Device}
 Timer.TimerState:=TIMER_STATE_DISABLED;

 {Notify Disable}
 NotifierNotify(@Timer.Device,DEVICE_NOTIFICATION_DISABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function TimerDeviceRead(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Read');
 {$ENDIF}
 
 {Check Enabled}
 if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;
 
 if Assigned(Timer.DeviceRead) then
  begin
   Result:=Timer.DeviceRead(Timer);
  end
 else
  begin
   Result:=TimerDeviceRead64(Timer);
  end;
end;

{==============================================================================}

function TimerDeviceRead64(Timer:PTimerDevice):Int64;
begin
 {}
 Result:=0;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Read64');
 {$ENDIF}
 
 {Check Enabled}
 if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;
 
 if Assigned(Timer.DeviceRead64) then
  begin
   Result:=Timer.DeviceRead64(Timer);
  end
 else
  begin
   Result:=TimerDeviceRead(Timer);
  end;  
end;

{==============================================================================}

function TimerDeviceWait(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Wait');
 {$ENDIF}
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;
 
 if Assigned(Timer.DeviceWait) then
  begin
   Result:=Timer.DeviceWait(Timer);
  end;
end;

{==============================================================================}

function TimerDeviceEvent(Timer:PTimerDevice;Flags:LongWord;Callback:TTimerCallback;Data:Pointer):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Event');
 {$ENDIF}
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;
 
 if Assigned(Timer.DeviceEvent) then
  begin
   Result:=Timer.DeviceEvent(Timer,Flags,Callback,Data);
  end;
end;

{==============================================================================}

function TimerDeviceGetRate(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Get Rate');
 {$ENDIF}
 
 {Check Enabled}
 {if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Timer.DeviceGetRate) then
  begin
   Result:=Timer.DeviceGetRate(Timer);
  end
 else
  begin
   if MutexLock(Timer.Lock) <> ERROR_SUCCESS then Exit;
   
   Result:=Timer.Rate;
   
   MutexUnlock(Timer.Lock);
  end;  
end;

{==============================================================================}

function TimerDeviceSetRate(Timer:PTimerDevice;Rate:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Set Rate');
 {$ENDIF}
 
 {Check Enabled}
 {if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Timer.DeviceSetRate) then
  begin
   Result:=Timer.DeviceSetRate(Timer,Rate);
  end
 else
  begin
   if MutexLock(Timer.Lock) <> ERROR_SUCCESS then Exit;
   
   Timer.Rate:=Rate;
   
   Result:=ERROR_SUCCESS;
   
   MutexUnlock(Timer.Lock);
  end;  
end;

{==============================================================================}

function TimerDeviceGetInterval(Timer:PTimerDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Get Interval');
 {$ENDIF}
 
 {Check Enabled}
 {if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Timer.DeviceGetInterval) then
  begin
   Result:=Timer.DeviceGetInterval(Timer);
  end
 else
  begin
   if MutexLock(Timer.Lock) <> ERROR_SUCCESS then Exit;
   
   Result:=Timer.Interval;
   
   MutexUnlock(Timer.Lock);
  end;  
end;

{==============================================================================}

function TimerDeviceSetInterval(Timer:PTimerDevice;Interval:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Set Interval');
 {$ENDIF}
 
 {Check Enabled}
 {if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Timer.DeviceSetInterval) then
  begin
   Result:=Timer.DeviceSetInterval(Timer,Interval);
  end
 else
  begin
   if MutexLock(Timer.Lock) <> ERROR_SUCCESS then Exit;
   
   Timer.Interval:=Interval;
   
   Result:=ERROR_SUCCESS;
   
   MutexUnlock(Timer.Lock);
  end;  
end;

{==============================================================================}

function TimerDeviceProperties(Timer:PTimerDevice;Properties:PTimerProperties):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Properties}
 if Properties = nil then Exit;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Timer Device Properties');
 {$ENDIF}
 
 {Check Enabled}
 {if Timer.TimerState <> TIMER_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Timer.DeviceProperties) then
  begin
   Result:=Timer.DeviceProperties(Timer,Properties);
  end
 else
  begin
   if MutexLock(Timer.Lock) <> ERROR_SUCCESS then Exit;
   
   {Get Properties}
   System.Move(Timer.Properties,Properties^,SizeOf(TTimerProperties));

   {Return Result}
   Result:=ERROR_SUCCESS;
   
   MutexUnlock(Timer.Lock);
  end;  
end;

{==============================================================================}

function TimerDeviceCreate:PTimerDevice;
{Create a new Timer entry}
{Return: Pointer to new Timer entry or nil if Timer could not be created}
begin
 {}
 Result:=TimerDeviceCreateEx(SizeOf(TTimerDevice));
end;

{==============================================================================}

function TimerDeviceCreateEx(Size:LongWord):PTimerDevice;
{Create a new Timer entry}
{Size: Size in bytes to allocate for new Timer (Including the Timer entry)}
{Return: Pointer to new Timer entry or nil if Timer could not be created}
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TTimerDevice) then Exit;
 
 {Create Timer}
 Result:=PTimerDevice(DeviceCreateEx(Size));
 if Result = nil then Exit;
 
 {Update Device}
 Result.Device.DeviceBus:=DEVICE_BUS_NONE;   
 Result.Device.DeviceType:=TIMER_TYPE_NONE;
 Result.Device.DeviceFlags:=TIMER_FLAG_NONE;
 Result.Device.DeviceData:=nil;

 {Update Timer}
 Result.TimerId:=DEVICE_ID_ANY;
 Result.TimerState:=TIMER_STATE_DISABLED;
 Result.DeviceStart:=nil;
 Result.DeviceStop:=nil;
 Result.DeviceRead:=nil;
 Result.DeviceRead64:=nil;
 Result.DeviceWait:=nil;
 Result.DeviceEvent:=nil;
 Result.DeviceGetRate:=nil;
 Result.DeviceSetRate:=nil;
 Result.DeviceGetInterval:=nil;
 Result.DeviceSetInterval:=nil;
 Result.DeviceProperties:=nil;
 Result.Lock:=INVALID_HANDLE_VALUE;
 Result.Address:=nil;
 Result.Rate:=0;
 Result.Interval:=0;
 
 {Create Lock}
 Result.Lock:=MutexCreate;
 if Result.Lock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create lock for Timer device');
   TimerDeviceDestroy(Result);
   Result:=nil;
   Exit;
  end;
end;

{==============================================================================}

function TimerDeviceDestroy(Timer:PTimerDevice):LongWord;
{Destroy an existing Timer entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Timer}
 Result:=ERROR_IN_USE;
 if TimerDeviceCheck(Timer) = Timer then Exit;

 {Check State}
 if Timer.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Destroy Lock}
 if Timer.Lock <> INVALID_HANDLE_VALUE then
  begin
   MutexDestroy(Timer.Lock);
  end;
 
 {Destroy Timer} 
 Result:=DeviceDestroy(@Timer.Device);
end;

{==============================================================================}

function TimerDeviceRegister(Timer:PTimerDevice):LongWord;
{Register a new Timer in the Timer table}
var
 TimerId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.TimerId <> DEVICE_ID_ANY then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Interfaces}
 if not(Assigned(Timer.DeviceStart)) then Exit;
 if not(Assigned(Timer.DeviceStop)) then Exit;
 if not(Assigned(Timer.DeviceRead)) and not(Assigned(Timer.DeviceRead64)) then Exit;
 
 {Check Timer}
 Result:=ERROR_ALREADY_EXISTS;
 if TimerDeviceCheck(Timer) = Timer then Exit;
 
 {Check State}
 if Timer.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Timer}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Update Timer}
    TimerId:=0;
    while TimerDeviceFind(TimerId) <> nil do
     begin
      Inc(TimerId);
     end;
    Timer.TimerId:=TimerId;
    
    {Update Device}
    Timer.Device.DeviceName:=TIMER_NAME_PREFIX + IntToStr(Timer.TimerId);
    Timer.Device.DeviceClass:=DEVICE_CLASS_TIMER;
    
    {Register Device}
    Result:=DeviceRegister(@Timer.Device);
    if Result <> ERROR_SUCCESS then
     begin
      Timer.TimerId:=DEVICE_ID_ANY;
      Exit;
     end; 
    
    {Link Timer}
    if TimerDeviceTable = nil then
     begin
      TimerDeviceTable:=Timer;
     end
    else
     begin
      Timer.Next:=TimerDeviceTable;
      TimerDeviceTable.Prev:=Timer;
      TimerDeviceTable:=Timer;
     end;
 
    {Increment Count}
    Inc(TimerDeviceTableCount);
    
    {Check Default}
    if TimerDeviceDefault = nil then
     begin
      TimerDeviceDefault:=Timer;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function TimerDeviceDeregister(Timer:PTimerDevice):LongWord;
{Deregister a Timer from the Timer table}
var
 Prev:PTimerDevice;
 Next:PTimerDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.TimerId = DEVICE_ID_ANY then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Timer}
 Result:=ERROR_NOT_FOUND;
 if TimerDeviceCheck(Timer) <> Timer then Exit;
 
 {Check State}
 if Timer.Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;
 
 {Remove Timer}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Device}
    Result:=DeviceDeregister(@Timer.Device);
    if Result <> ERROR_SUCCESS then Exit;
    
    {Unlink Timer}
    Prev:=Timer.Prev;
    Next:=Timer.Next;
    if Prev = nil then
     begin
      TimerDeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
 
    {Decrement Count}
    Dec(TimerDeviceTableCount);
 
    {Check Default}
    if TimerDeviceDefault = Timer then
     begin
      TimerDeviceDefault:=TimerDeviceTable;
     end;
     
    {Update Timer}
    Timer.TimerId:=DEVICE_ID_ANY;
 
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function TimerDeviceFind(TimerId:LongWord):PTimerDevice;
var
 Timer:PTimerDevice;
begin
 {}
 Result:=nil;
 
 {Check Id}
 if TimerId = DEVICE_ID_ANY then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Timer}
    Timer:=TimerDeviceTable;
    while Timer <> nil do
     begin
      {Check State}
      if Timer.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if Timer.TimerId = TimerId then
         begin
          Result:=Timer;
          Exit;
         end;
       end;

       {Get Next}
      Timer:=Timer.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function TimerDeviceFindByName(const Name:String):PTimerDevice; inline;
begin
 {}
 Result:=PTimerDevice(DeviceFindByName(Name));
end;

{==============================================================================}

function TimerDeviceFindByDescription(const Description:String):PTimerDevice; inline;
begin
 {}
 Result:=PTimerDevice(DeviceFindByDescription(Description));
end;

{==============================================================================}

function TimerDeviceEnumerate(Callback:TTimerEnumerate;Data:Pointer):LongWord;
var
 Timer:PTimerDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Timer}
    Timer:=TimerDeviceTable;
    while Timer <> nil do
     begin
      {Check State}
      if Timer.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        if Callback(Timer,Data) <> ERROR_SUCCESS then Exit;
       end;
       
      {Get Next}
      Timer:=Timer.Next;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function TimerDeviceNotification(Timer:PTimerDevice;Callback:TTimerNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then
  begin
   Result:=DeviceNotification(nil,DEVICE_CLASS_TIMER,Callback,Data,Notification,Flags);
  end
 else
  begin 
   {Check Timer}
   if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;

   Result:=DeviceNotification(@Timer.Device,DEVICE_CLASS_TIMER,Callback,Data,Notification,Flags);
  end; 
end;

{==============================================================================}
{==============================================================================}
{Random Device Functions}
function RandomDeviceStart(Random:PRandomDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Start');
 {$ENDIF}

 {Check Disabled}
 Result:=ERROR_SUCCESS;
 if Random.RandomState <> RANDOM_STATE_DISABLED then Exit;
 
 {Check Start}
 Result:=ERROR_INVALID_PARAMETER;
 if not(Assigned(Random.DeviceStart)) then Exit;
 
 {Call Device Start}
 Result:=Random.DeviceStart(Random);
 if Result <> ERROR_SUCCESS then Exit;
 
 {Enable Device}
 Random.RandomState:=RANDOM_STATE_ENABLED;

 {Notify Enable}
 NotifierNotify(@Random.Device,DEVICE_NOTIFICATION_ENABLE);
 
 Result:=ERROR_SUCCESS;
end;
 
{==============================================================================}
 
function RandomDeviceStop(Random:PRandomDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Stop');
 {$ENDIF}

 {Check Enabled}
 Result:=ERROR_SUCCESS;
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 {Check Stop}
 if Assigned(Random.DeviceStop) then
  begin
   {Call Device Stop}
   Result:=Random.DeviceStop(Random);
   if Result <> ERROR_SUCCESS then Exit;
  end; 
 
 {Disable Device}
 Random.RandomState:=RANDOM_STATE_DISABLED;

 {Notify Disable}
 NotifierNotify(@Random.Device,DEVICE_NOTIFICATION_DISABLE);
 
 Result:=ERROR_SUCCESS;
end;
 
{==============================================================================}

function RandomDeviceSeed(Random:PRandomDevice;Seed:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Seed');
 {$ENDIF}
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceSeed) then
  begin
   Result:=Random.DeviceSeed(Random,Seed);
  end
 else
  begin
   Result:=ERROR_SUCCESS;
  end;  
end;

{==============================================================================}

function RandomDeviceReadByte(Random:PRandomDevice):Byte;
begin
 {}
 Result:=0;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Read Byte');
 {$ENDIF}
 
 {Check Enabled}
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceReadByte) then
  begin
   Result:=Random.DeviceReadByte(Random);
  end
 else
  begin
   Result:=RandomDeviceReadLongWord(Random);
  end;  
end;

{==============================================================================}

function RandomDeviceReadWord(Random:PRandomDevice):Word;
begin
 {}
 Result:=0;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Read Word');
 {$ENDIF}
 
 {Check Enabled}
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceReadWord) then
  begin
   Result:=Random.DeviceReadWord(Random);
  end
 else
  begin
   Result:=RandomDeviceReadLongWord(Random);
  end;  
end;

{==============================================================================}

function RandomDeviceReadLongWord(Random:PRandomDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Read LongWord');
 {$ENDIF}
 
 {Check Enabled}
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceReadLongWord) then
  begin
   Result:=Random.DeviceReadLongWord(Random);
  end;
end;

{==============================================================================}

function RandomDeviceReadQuadWord(Random:PRandomDevice):Int64;
begin
 {}
 Result:=0;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 

 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Read QuadWord');
 {$ENDIF}
 
 {Check Enabled}
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceReadQuadWord) then
  begin
   Result:=Random.DeviceReadQuadWord(Random);
  end
 else
  begin
   Int64Rec(Result).Lo:=RandomDeviceReadLongWord(Random);
   Int64Rec(Result).Hi:=RandomDeviceReadLongWord(Random);
  end;  
end;

{==============================================================================}

function RandomDeviceReadExtended(Random:PRandomDevice):Extended;
begin
 {}
 Result:=0;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Random Device Read Extended');
 {$ENDIF}
 
 {Check Enabled}
 if Random.RandomState <> RANDOM_STATE_ENABLED then Exit;
 
 if Assigned(Random.DeviceReadExtended) then
  begin
   Result:=Random.DeviceReadExtended(Random);
  end
 else
  begin
   Result:=Frac(RandomDeviceReadLongWord(Random) / 1000000);
  end;  
end;

{==============================================================================}

function RandomDeviceCreate:PRandomDevice;
{Create a new Random entry}
{Return: Pointer to new Random entry or nil if Random could not be created}
begin
 {}
 Result:=RandomDeviceCreateEx(SizeOf(TRandomDevice));
end;

{==============================================================================}

function RandomDeviceCreateEx(Size:LongWord):PRandomDevice;
{Create a new Random entry}
{Size: Size in bytes to allocate for new Random (Including the Random entry)}
{Return: Pointer to new Random entry or nil if Random could not be created}
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TRandomDevice) then Exit;
 
 {Create Random}
 Result:=PRandomDevice(DeviceCreateEx(Size));
 if Result = nil then Exit;
 
 {Update Device}
 Result.Device.DeviceBus:=DEVICE_BUS_NONE;   
 Result.Device.DeviceType:=RANDOM_TYPE_NONE;
 Result.Device.DeviceFlags:=RANDOM_FLAG_NONE;
 Result.Device.DeviceData:=nil;

 {Update Random}
 Result.RandomId:=DEVICE_ID_ANY;
 Result.RandomState:=RANDOM_STATE_DISABLED;
 Result.DeviceStart:=nil;
 Result.DeviceStop:=nil;
 Result.DeviceSeed:=nil;
 Result.DeviceReadByte:=nil;
 Result.DeviceReadWord:=nil;
 Result.DeviceReadLongWord:=nil;
 Result.DeviceReadQuadWord:=nil;
 Result.DeviceReadExtended:=nil;
 Result.Lock:=INVALID_HANDLE_VALUE;
 Result.Address:=nil;
 
 {Create Lock}
 Result.Lock:=MutexCreate;
 if Result.Lock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create lock for random device');
   RandomDeviceDestroy(Result);
   Result:=nil;
   Exit;
  end;
end;

{==============================================================================}

function RandomDeviceDestroy(Random:PRandomDevice):LongWord;
{Destroy an existing Random entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Random}
 Result:=ERROR_IN_USE;
 if RandomDeviceCheck(Random) = Random then Exit;

 {Check State}
 if Random.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Destroy Lock}
 if Random.Lock <> INVALID_HANDLE_VALUE then
  begin
   MutexDestroy(Random.Lock);
  end;
 
 {Destroy Random} 
 Result:=DeviceDestroy(@Random.Device);
end;

{==============================================================================}

function RandomDeviceRegister(Random:PRandomDevice):LongWord;
{Register a new Random in the Random table}
var
 RandomId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.RandomId <> DEVICE_ID_ANY then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Interfaces}
 if not(Assigned(Random.DeviceStart)) then Exit;
 if not(Assigned(Random.DeviceReadLongWord)) then Exit;
 
 {Check Random}
 Result:=ERROR_ALREADY_EXISTS;
 if RandomDeviceCheck(Random) = Random then Exit;
 
 {Check State}
 if Random.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Random}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Update Random}
    RandomId:=0;
    while RandomDeviceFind(RandomId) <> nil do
     begin
      Inc(RandomId);
     end;
    Random.RandomId:=RandomId;
    
    {Update Device}
    Random.Device.DeviceName:=RANDOM_NAME_PREFIX + IntToStr(Random.RandomId);
    Random.Device.DeviceClass:=DEVICE_CLASS_RANDOM;
    
    {Register Device}
    Result:=DeviceRegister(@Random.Device);
    if Result <> ERROR_SUCCESS then
     begin
      Random.RandomId:=DEVICE_ID_ANY;
      Exit;
     end; 
    
    {Link Random}
    if RandomDeviceTable = nil then
     begin
      RandomDeviceTable:=Random;
     end
    else
     begin
      Random.Next:=RandomDeviceTable;
      RandomDeviceTable.Prev:=Random;
      RandomDeviceTable:=Random;
     end;
 
    {Increment Count}
    Inc(RandomDeviceTableCount);
    
    {Check Default}
    if RandomDeviceDefault = nil then
     begin
      RandomDeviceDefault:=Random;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function RandomDeviceDeregister(Random:PRandomDevice):LongWord;
{Deregister a Random from the Random table}
var
 Prev:PRandomDevice;
 Next:PRandomDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.RandomId = DEVICE_ID_ANY then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Random}
 Result:=ERROR_NOT_FOUND;
 if RandomDeviceCheck(Random) <> Random then Exit;
 
 {Check State}
 if Random.Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;
 
 {Remove Random}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Device}
    Result:=DeviceDeregister(@Random.Device);
    if Result <> ERROR_SUCCESS then Exit;
    
    {Unlink Random}
    Prev:=Random.Prev;
    Next:=Random.Next;
    if Prev = nil then
     begin
      RandomDeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
 
    {Decrement Count}
    Dec(RandomDeviceTableCount);
 
    {Check Default}
    if RandomDeviceDefault = Random then
     begin
      RandomDeviceDefault:=RandomDeviceTable;
     end;
     
    {Update Random}
    Random.RandomId:=DEVICE_ID_ANY;
 
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function RandomDeviceFind(RandomId:LongWord):PRandomDevice;
var
 Random:PRandomDevice;
begin
 {}
 Result:=nil;
 
 {Check Id}
 if RandomId = DEVICE_ID_ANY then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Random}
    Random:=RandomDeviceTable;
    while Random <> nil do
     begin
      {Check State}
      if Random.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if Random.RandomId = RandomId then
         begin
          Result:=Random;
          Exit;
         end;
       end;

       {Get Next}
      Random:=Random.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function RandomDeviceFindByName(const Name:String):PRandomDevice; inline;
begin
 {}
 Result:=PRandomDevice(DeviceFindByName(Name));
end;

{==============================================================================}

function RandomDeviceFindByDescription(const Description:String):PRandomDevice; inline;
begin
 {}
 Result:=PRandomDevice(DeviceFindByDescription(Description));
end;

{==============================================================================}

function RandomDeviceEnumerate(Callback:TRandomEnumerate;Data:Pointer):LongWord;
var
 Random:PRandomDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Random}
    Random:=RandomDeviceTable;
    while Random <> nil do
     begin
      {Check State}
      if Random.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        if Callback(Random,Data) <> ERROR_SUCCESS then Exit;
       end;
       
      {Get Next}
      Random:=Random.Next;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function RandomDeviceNotification(Random:PRandomDevice;Callback:TRandomNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then
  begin
   Result:=DeviceNotification(nil,DEVICE_CLASS_RANDOM,Callback,Data,Notification,Flags);
  end
 else
  begin 
   {Check Random}
   if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;

   Result:=DeviceNotification(@Random.Device,DEVICE_CLASS_RANDOM,Callback,Data,Notification,Flags);
  end; 
end;

{==============================================================================}
{==============================================================================}
{Mailbox Device Functions}
function MailboxDeviceStart(Mailbox:PMailboxDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Start');
 {$ENDIF}

 {Check Disabled}
 Result:=ERROR_SUCCESS;
 if Mailbox.MailboxState <> MAILBOX_STATE_DISABLED then Exit;

 {Check Start}
 Result:=ERROR_INVALID_PARAMETER;
 if Assigned(Mailbox.DeviceStart) then
  begin
   {Call Device Start}
   Result:=Mailbox.DeviceStart(Mailbox);
   if Result <> ERROR_SUCCESS then Exit;
  end; 
 
 {Enable Device}
 Mailbox.MailboxState:=MAILBOX_STATE_ENABLED;

 {Notify Enable}
 NotifierNotify(@Mailbox.Device,DEVICE_NOTIFICATION_ENABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function MailboxDeviceStop(Mailbox:PMailboxDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Stop');
 {$ENDIF}

 {Check Enabled}
 Result:=ERROR_SUCCESS;
 if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;
 
 {Check Stop}
 if Assigned(Mailbox.DeviceStop) then
  begin
   {Call Device Stop}
   Result:=Mailbox.DeviceStop(Mailbox);
   if Result <> ERROR_SUCCESS then Exit;
  end; 
 
 {Disable Device}
 Mailbox.MailboxState:=MAILBOX_STATE_DISABLED;

 {Notify Disable}
 NotifierNotify(@Mailbox.Device,DEVICE_NOTIFICATION_DISABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function MailboxDeviceReceive(Mailbox:PMailboxDevice;Channel:LongWord):LongWord;
begin
 {}
 Result:=0;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Receive');
 {$ENDIF}
 
 {Check Enabled}
 if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;
 
 if Assigned(Mailbox.DeviceReceive) then
  begin
   Result:=Mailbox.DeviceReceive(Mailbox,Channel);
  end;
end;

{==============================================================================}

function MailboxDeviceSend(Mailbox:PMailboxDevice;Channel,Data:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Send');
 {$ENDIF}
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;
 
 if Assigned(Mailbox.DeviceSend) then
  begin
   Result:=Mailbox.DeviceSend(Mailbox,Channel,Data);
  end;
end;

{==============================================================================}

function MailboxDeviceCall(Mailbox:PMailboxDevice;Channel,Data:LongWord;var Response:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit; 
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Call');
 {$ENDIF}
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;
 
 if Assigned(Mailbox.DeviceCall) then
  begin
   Result:=Mailbox.DeviceCall(Mailbox,Channel,Data,Response);
  end;
end;

{==============================================================================}

function MailboxDeviceGetTimeout(Mailbox:PMailboxDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Get Timeout');
 {$ENDIF}
 
 {Check Enabled}
 {if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Mailbox.DeviceGetTimeout) then
  begin
   Result:=Mailbox.DeviceGetTimeout(Mailbox);
  end
 else
  begin
   if MutexLock(Mailbox.Lock) <> ERROR_SUCCESS then Exit;
   
   Result:=Mailbox.Timeout;
   
   MutexUnlock(Mailbox.Lock);
  end;  
end;

{==============================================================================}

function MailboxDeviceSetTimeout(Mailbox:PMailboxDevice;Timeout:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Mailbox Device Set Timeout');
 {$ENDIF}
 
 {Check Enabled}
 {Result:=ERROR_NOT_SUPPORTED;}
 {if Mailbox.MailboxState <> MAILBOX_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Mailbox.DeviceSetTimeout) then
  begin
   Result:=Mailbox.DeviceSetTimeout(Mailbox,Timeout);
  end
 else
  begin
   if MutexLock(Mailbox.Lock) <> ERROR_SUCCESS then Exit;

   Mailbox.Timeout:=Timeout;
   
   Result:=ERROR_SUCCESS;
   
   MutexUnlock(Mailbox.Lock);
  end;  
end;

{==============================================================================}

function MailboxDeviceCreate:PMailboxDevice;
{Create a new Mailbox entry}
{Return: Pointer to new Mailbox entry or nil if Mailbox could not be created}
begin
 {}
 Result:=MailboxDeviceCreateEx(SizeOf(TMailboxDevice));
end;

{==============================================================================}

function MailboxDeviceCreateEx(Size:LongWord):PMailboxDevice;
{Create a new Mailbox entry}
{Size: Size in bytes to allocate for new Mailbox (Including the Mailbox entry)}
{Return: Pointer to new Mailbox entry or nil if Mailbox could not be created}
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TMailboxDevice) then Exit;
 
 {Create Mailbox}
 Result:=PMailboxDevice(DeviceCreateEx(Size));
 if Result = nil then Exit;
 
 {Update Device}
 Result.Device.DeviceBus:=DEVICE_BUS_NONE;   
 Result.Device.DeviceType:=MAILBOX_TYPE_NONE;
 Result.Device.DeviceFlags:=MAILBOX_FLAG_NONE;
 Result.Device.DeviceData:=nil;

 {Update Mailbox}
 Result.MailboxId:=DEVICE_ID_ANY;
 Result.MailboxState:=MAILBOX_STATE_DISABLED;
 Result.DeviceStart:=nil;
 Result.DeviceStop:=nil;
 Result.DeviceReceive:=nil;
 Result.DeviceSend:=nil;
 Result.DeviceCall:=nil;
 Result.DeviceGetTimeout:=nil;
 Result.DeviceSetTimeout:=nil;
 Result.Lock:=INVALID_HANDLE_VALUE;
 Result.Address:=nil;
 Result.Timeout:=0;
 
 {Create Lock}
 Result.Lock:=MutexCreate;
 if Result.Lock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create lock for mailbox device');
   MailboxDeviceDestroy(Result);
   Result:=nil;
   Exit;
  end;
end;

{==============================================================================}

function MailboxDeviceDestroy(Mailbox:PMailboxDevice):LongWord;
{Destroy an existing Mailbox entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Mailbox}
 Result:=ERROR_IN_USE;
 if MailboxDeviceCheck(Mailbox) = Mailbox then Exit;

 {Check State}
 if Mailbox.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Destroy Lock}
 if Mailbox.Lock <> INVALID_HANDLE_VALUE then
  begin
   MutexDestroy(Mailbox.Lock);
  end;
 
 {Destroy Mailbox} 
 Result:=DeviceDestroy(@Mailbox.Device);
end;

{==============================================================================}

function MailboxDeviceRegister(Mailbox:PMailboxDevice):LongWord;
{Register a new Mailbox in the Mailbox table}
var
 MailboxId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.MailboxId <> DEVICE_ID_ANY then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Interfaces}
 if not(Assigned(Mailbox.DeviceReceive)) then Exit;
 if not(Assigned(Mailbox.DeviceSend)) then Exit;
 if not(Assigned(Mailbox.DeviceCall)) then Exit;
 
 {Check Mailbox}
 Result:=ERROR_ALREADY_EXISTS;
 if MailboxDeviceCheck(Mailbox) = Mailbox then Exit;
 
 {Check State}
 if Mailbox.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Mailbox}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Update Mailbox}
    MailboxId:=0;
    while MailboxDeviceFind(MailboxId) <> nil do
     begin
      Inc(MailboxId);
     end;
    Mailbox.MailboxId:=MailboxId;
    
    {Update Device}
    Mailbox.Device.DeviceName:=MAILBOX_NAME_PREFIX + IntToStr(Mailbox.MailboxId);
    Mailbox.Device.DeviceClass:=DEVICE_CLASS_MAILBOX;
    
    {Register Device}
    Result:=DeviceRegister(@Mailbox.Device);
    if Result <> ERROR_SUCCESS then
     begin
      Mailbox.MailboxId:=DEVICE_ID_ANY;
      Exit;
     end; 
    
    {Link Mailbox}
    if MailboxDeviceTable = nil then
     begin
      MailboxDeviceTable:=Mailbox;
     end
    else
     begin
      Mailbox.Next:=MailboxDeviceTable;
      MailboxDeviceTable.Prev:=Mailbox;
      MailboxDeviceTable:=Mailbox;
     end;
 
    {Increment Count}
    Inc(MailboxDeviceTableCount);
    
    {Check Default}
    if MailboxDeviceDefault = nil then
     begin
      MailboxDeviceDefault:=Mailbox;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function MailboxDeviceDeregister(Mailbox:PMailboxDevice):LongWord;
{Deregister a Mailbox from the Mailbox table}
var
 Prev:PMailboxDevice;
 Next:PMailboxDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.MailboxId = DEVICE_ID_ANY then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Mailbox}
 Result:=ERROR_NOT_FOUND;
 if MailboxDeviceCheck(Mailbox) <> Mailbox then Exit;
 
 {Check State}
 if Mailbox.Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;
 
 {Remove Mailbox}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Device}
    Result:=DeviceDeregister(@Mailbox.Device);
    if Result <> ERROR_SUCCESS then Exit;
    
    {Unlink Mailbox}
    Prev:=Mailbox.Prev;
    Next:=Mailbox.Next;
    if Prev = nil then
     begin
      MailboxDeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
 
    {Decrement Count}
    Dec(MailboxDeviceTableCount);
 
    {Check Default}
    if MailboxDeviceDefault = Mailbox then
     begin
      MailboxDeviceDefault:=MailboxDeviceTable;
     end;
     
    {Update Mailbox}
    Mailbox.MailboxId:=DEVICE_ID_ANY;
 
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function MailboxDeviceFind(MailboxId:LongWord):PMailboxDevice;
var
 Mailbox:PMailboxDevice;
begin
 {}
 Result:=nil;
 
 {Check Id}
 if MailboxId = DEVICE_ID_ANY then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Mailbox}
    Mailbox:=MailboxDeviceTable;
    while Mailbox <> nil do
     begin
      {Check State}
      if Mailbox.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if Mailbox.MailboxId = MailboxId then
         begin
          Result:=Mailbox;
          Exit;
         end;
       end;

       {Get Next}
      Mailbox:=Mailbox.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function MailboxDeviceFindByName(const Name:String):PMailboxDevice; inline;
begin
 {}
 Result:=PMailboxDevice(DeviceFindByName(Name));
end;

{==============================================================================}

function MailboxDeviceFindByDescription(const Description:String):PMailboxDevice; inline;
begin
 {}
 Result:=PMailboxDevice(DeviceFindByDescription(Description));
end;

{==============================================================================}

function MailboxDeviceEnumerate(Callback:TMailboxEnumerate;Data:Pointer):LongWord;
var
 Mailbox:PMailboxDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Mailbox}
    Mailbox:=MailboxDeviceTable;
    while Mailbox <> nil do
     begin
      {Check State}
      if Mailbox.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        if Callback(Mailbox,Data) <> ERROR_SUCCESS then Exit;
       end;
       
      {Get Next}
      Mailbox:=Mailbox.Next;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function MailboxDeviceNotification(Mailbox:PMailboxDevice;Callback:TMailboxNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then
  begin
   Result:=DeviceNotification(nil,DEVICE_CLASS_MAILBOX,Callback,Data,Notification,Flags);
  end
 else
  begin 
   {Check Mailbox}
   if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;

   Result:=DeviceNotification(@Mailbox.Device,DEVICE_CLASS_MAILBOX,Callback,Data,Notification,Flags);
  end; 
end;

{==============================================================================}
{==============================================================================}
{Watchdog Device Functions}
function WatchdogDeviceStart(Watchdog:PWatchdogDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Start');
 {$ENDIF}

 {Check Disabled}
 Result:=ERROR_SUCCESS;
 if Watchdog.WatchdogState <> WATCHDOG_STATE_DISABLED then Exit;
 
 {Check Start}
 Result:=ERROR_INVALID_PARAMETER;
 if not(Assigned(Watchdog.DeviceStart)) then Exit;
 
 {Call Device Start}
 Result:=Watchdog.DeviceStart(Watchdog);
 if Result <> ERROR_SUCCESS then Exit;
 
 {Enable Device}
 Watchdog.WatchdogState:=WATCHDOG_STATE_ENABLED;

 {Notify Enable}
 NotifierNotify(@Watchdog.Device,DEVICE_NOTIFICATION_ENABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function WatchdogDeviceStop(Watchdog:PWatchdogDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Stop');
 {$ENDIF}

 {Check Enabled}
 Result:=ERROR_SUCCESS;
 if Watchdog.WatchdogState <> WATCHDOG_STATE_ENABLED then Exit;
 
 {Check Stop}
 if not(Assigned(Watchdog.DeviceStop)) then Exit;

 {Call Device Stop}
 Result:=Watchdog.DeviceStop(Watchdog);
 if Result <> ERROR_SUCCESS then Exit;
 
 {Disable Device}
 Watchdog.WatchdogState:=WATCHDOG_STATE_DISABLED;

 {Notify Disable}
 NotifierNotify(@Watchdog.Device,DEVICE_NOTIFICATION_DISABLE);
 
 Result:=ERROR_SUCCESS;
end;

{==============================================================================}

function WatchdogDeviceRefresh(Watchdog:PWatchdogDevice):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Refresh');
 {$ENDIF}
 
 {Check Enabled}
 Result:=ERROR_NOT_SUPPORTED;
 if Watchdog.WatchdogState <> WATCHDOG_STATE_ENABLED then Exit;
 
 if Assigned(Watchdog.DeviceRefresh) then
  begin
   Result:=Watchdog.DeviceRefresh(Watchdog);
  end;
end;

{==============================================================================}

function WatchdogDeviceGetRemain(Watchdog:PWatchdogDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Get Remain');
 {$ENDIF}
 
 {Check Enabled}
 if Watchdog.WatchdogState <> WATCHDOG_STATE_ENABLED then Exit;
 
 if Assigned(Watchdog.DeviceGetRemain) then
  begin
   Result:=Watchdog.DeviceGetRemain(Watchdog);
  end;
end;

{==============================================================================}

function WatchdogDeviceGetTimeout(Watchdog:PWatchdogDevice):LongWord;
begin
 {}
 Result:=0;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Get Timeout');
 {$ENDIF}
 
 {Check Enabled}
 {if Watchdog.WatchdogState <> WATCHDOG_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Watchdog.DeviceGetTimeout) then
  begin
   Result:=Watchdog.DeviceGetTimeout(Watchdog);
  end
 else
  begin
   if MutexLock(Watchdog.Lock) <> ERROR_SUCCESS then Exit;
   
   Result:=Watchdog.Timeout;
   
   MutexUnlock(Watchdog.Lock);
  end;  
end;

{==============================================================================}

function WatchdogDeviceSetTimeout(Watchdog:PWatchdogDevice;Timeout:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {$IFDEF DEVICE_DEBUG}
 if DEVICE_LOG_ENABLED then DeviceLogDebug(nil,'Watchdog Device Set Timeout');
 {$ENDIF}
 
 {Check Enabled}
 {Result:=ERROR_NOT_SUPPORTED;}
 {if Watchdog.WatchdogState <> WATCHDOG_STATE_ENABLED then Exit;} {Allow when disabled}
 
 if Assigned(Watchdog.DeviceSetTimeout) then
  begin
   Result:=Watchdog.DeviceSetTimeout(Watchdog,Timeout);
  end
 else
  begin
   if MutexLock(Watchdog.Lock) <> ERROR_SUCCESS then Exit;

   Watchdog.Timeout:=Timeout;
   
   Result:=ERROR_SUCCESS;
   
   MutexUnlock(Watchdog.Lock);
  end;  
end;

{==============================================================================}

function WatchdogDeviceCreate:PWatchdogDevice;
{Create a new Watchdog entry}
{Return: Pointer to new Watchdog entry or nil if Watchdog could not be created}
begin
 {}
 Result:=WatchdogDeviceCreateEx(SizeOf(TWatchdogDevice));
end;

{==============================================================================}

function WatchdogDeviceCreateEx(Size:LongWord):PWatchdogDevice;
{Create a new Watchdog entry}
{Size: Size in bytes to allocate for new Watchdog (Including the Watchdog entry)}
{Return: Pointer to new Watchdog entry or nil if Watchdog could not be created}
begin
 {}
 Result:=nil;
 
 {Check Size}
 if Size < SizeOf(TWatchdogDevice) then Exit;
 
 {Create Watchdog}
 Result:=PWatchdogDevice(DeviceCreateEx(Size));
 if Result = nil then Exit;
 
 {Update Device}
 Result.Device.DeviceBus:=DEVICE_BUS_NONE;   
 Result.Device.DeviceType:=WATCHDOG_TYPE_NONE;
 Result.Device.DeviceFlags:=WATCHDOG_FLAG_NONE;
 Result.Device.DeviceData:=nil;

 {Update Watchdog}
 Result.WatchdogId:=DEVICE_ID_ANY;
 Result.WatchdogState:=WATCHDOG_STATE_DISABLED;
 Result.DeviceStart:=nil;
 Result.DeviceStop:=nil;
 Result.DeviceRefresh:=nil;
 Result.DeviceGetRemain:=nil;
 Result.DeviceGetTimeout:=nil;
 Result.DeviceSetTimeout:=nil;
 Result.Lock:=INVALID_HANDLE_VALUE;
 Result.Address:=nil;
 Result.Timeout:=0;
 
 {Create Lock}
 Result.Lock:=MutexCreate;
 if Result.Lock = INVALID_HANDLE_VALUE then
  begin
   if DEVICE_LOG_ENABLED then DeviceLogError(nil,'Failed to create lock for watchdog device');
   WatchdogDeviceDestroy(Result);
   Result:=nil;
   Exit;
  end;
end;

{==============================================================================}

function WatchdogDeviceDestroy(Watchdog:PWatchdogDevice):LongWord;
{Destroy an existing Watchdog entry}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Watchdog}
 Result:=ERROR_IN_USE;
 if WatchdogDeviceCheck(Watchdog) = Watchdog then Exit;

 {Check State}
 if Watchdog.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Destroy Lock}
 if Watchdog.Lock <> INVALID_HANDLE_VALUE then
  begin
   MutexDestroy(Watchdog.Lock);
  end;
 
 {Destroy Watchdog} 
 Result:=DeviceDestroy(@Watchdog.Device);
end;

{==============================================================================}

function WatchdogDeviceRegister(Watchdog:PWatchdogDevice):LongWord;
{Register a new Watchdog in the Watchdog table}
var
 WatchdogId:LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.WatchdogId <> DEVICE_ID_ANY then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Interfaces}
 if not(Assigned(Watchdog.DeviceStart)) then Exit;
 if not(Assigned(Watchdog.DeviceStop)) then Exit;
 if not(Assigned(Watchdog.DeviceRefresh)) then Exit;
 if not(Assigned(Watchdog.DeviceGetRemain)) then Exit;
 
 {Check Watchdog}
 Result:=ERROR_ALREADY_EXISTS;
 if WatchdogDeviceCheck(Watchdog) = Watchdog then Exit;
 
 {Check State}
 if Watchdog.Device.DeviceState <> DEVICE_STATE_UNREGISTERED then Exit;
 
 {Insert Watchdog}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Update Watchdog}
    WatchdogId:=0;
    while WatchdogDeviceFind(WatchdogId) <> nil do
     begin
      Inc(WatchdogId);
     end;
    Watchdog.WatchdogId:=WatchdogId;
    
    {Update Device}
    Watchdog.Device.DeviceName:=WATCHDOG_NAME_PREFIX + IntToStr(Watchdog.WatchdogId);
    Watchdog.Device.DeviceClass:=DEVICE_CLASS_WATCHDOG;
    
    {Register Device}
    Result:=DeviceRegister(@Watchdog.Device);
    if Result <> ERROR_SUCCESS then
     begin
      Watchdog.WatchdogId:=DEVICE_ID_ANY;
      Exit;
     end; 
    
    {Link Watchdog}
    if WatchdogDeviceTable = nil then
     begin
      WatchdogDeviceTable:=Watchdog;
     end
    else
     begin
      Watchdog.Next:=WatchdogDeviceTable;
      WatchdogDeviceTable.Prev:=Watchdog;
      WatchdogDeviceTable:=Watchdog;
     end;
 
    {Increment Count}
    Inc(WatchdogDeviceTableCount);
    
    {Check Default}
    if WatchdogDeviceDefault = nil then
     begin
      WatchdogDeviceDefault:=Watchdog;
     end;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function WatchdogDeviceDeregister(Watchdog:PWatchdogDevice):LongWord;
{Deregister a Watchdog from the Watchdog table}
var
 Prev:PWatchdogDevice;
 Next:PWatchdogDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.WatchdogId = DEVICE_ID_ANY then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Check Watchdog}
 Result:=ERROR_NOT_FOUND;
 if WatchdogDeviceCheck(Watchdog) <> Watchdog then Exit;
 
 {Check State}
 if Watchdog.Device.DeviceState <> DEVICE_STATE_REGISTERED then Exit;
 
 {Remove Watchdog}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Deregister Device}
    Result:=DeviceDeregister(@Watchdog.Device);
    if Result <> ERROR_SUCCESS then Exit;
    
    {Unlink Watchdog}
    Prev:=Watchdog.Prev;
    Next:=Watchdog.Next;
    if Prev = nil then
     begin
      WatchdogDeviceTable:=Next;
      if Next <> nil then
       begin
        Next.Prev:=nil;
       end;       
     end
    else
     begin
      Prev.Next:=Next;
      if Next <> nil then
       begin
        Next.Prev:=Prev;
       end;       
     end;     
 
    {Decrement Count}
    Dec(WatchdogDeviceTableCount);
 
    {Check Default}
    if WatchdogDeviceDefault = Watchdog then
     begin
      WatchdogDeviceDefault:=WatchdogDeviceTable;
     end;
 
    {Update Watchdog}
    Watchdog.WatchdogId:=DEVICE_ID_ANY;
 
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function WatchdogDeviceFind(WatchdogId:LongWord):PWatchdogDevice;
var
 Watchdog:PWatchdogDevice;
begin
 {}
 Result:=nil;
 
 {Check Id}
 if WatchdogId = DEVICE_ID_ANY then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Watchdog}
    Watchdog:=WatchdogDeviceTable;
    while Watchdog <> nil do
     begin
      {Check State}
      if Watchdog.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        {Check Id}
        if Watchdog.WatchdogId = WatchdogId then
         begin
          Result:=Watchdog;
          Exit;
         end;
       end;

       {Get Next}
      Watchdog:=Watchdog.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function WatchdogDeviceFindByName(const Name:String):PWatchdogDevice; inline;
begin
 {}
 Result:=PWatchdogDevice(DeviceFindByName(Name));
end;

{==============================================================================}

function WatchdogDeviceFindByDescription(const Description:String):PWatchdogDevice; inline;
begin
 {}
 Result:=PWatchdogDevice(DeviceFindByDescription(Description));
end;

{==============================================================================}

function WatchdogDeviceEnumerate(Callback:TWatchdogEnumerate;Data:Pointer):LongWord;
var
 Watchdog:PWatchdogDevice;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Callback}
 if not Assigned(Callback) then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Watchdog}
    Watchdog:=WatchdogDeviceTable;
    while Watchdog <> nil do
     begin
      {Check State}
      if Watchdog.Device.DeviceState = DEVICE_STATE_REGISTERED then
       begin
        if Callback(Watchdog,Data) <> ERROR_SUCCESS then Exit;
       end;
       
      {Get Next}
      Watchdog:=Watchdog.Next;
     end;
     
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;  
end;

{==============================================================================}

function WatchdogDeviceNotification(Watchdog:PWatchdogDevice;Callback:TWatchdogNotification;Data:Pointer;Notification,Flags:LongWord):LongWord;
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then
  begin
   Result:=DeviceNotification(nil,DEVICE_CLASS_WATCHDOG,Callback,Data,Notification,Flags);
  end
 else
  begin 
   {Check Watchdog}
   if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;

   Result:=DeviceNotification(@Watchdog.Device,DEVICE_CLASS_WATCHDOG,Callback,Data,Notification,Flags);
  end; 
end;

{==============================================================================}
{==============================================================================}
{RTL Clock Functions}
function SysClockRead:LongWord;
begin
 {}
 Result:=0;
 
 if ClockDeviceDefault = nil then Exit;

 Result:=ClockDeviceRead(ClockDeviceDefault);
end;

{==============================================================================}

function SysClockRead64:Int64;
begin
 {}
 Result:=0;
 
 if ClockDeviceDefault = nil then Exit;

 Result:=ClockDeviceRead64(ClockDeviceDefault);
end;

{==============================================================================}
{==============================================================================}
{RTL Timer (Counter) Functions}
function SysTimerAvailable:Boolean;
{Check if a timer device is available}
begin
 {}
 Result:=(TimerDeviceDefault <> nil);
end;

{==============================================================================}

function SysTimerRead:LongWord;
{Read the current value of the default counter}
{Return: The 32 bit current value of the current or 0 on failure}
begin
 {}
 Result:=0;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceRead(TimerDeviceDefault);
end;

{==============================================================================}

function SysTimerRead64:Int64;
{Read the current value of the default counter}
{Return: The 64 bit current value of the current or 0 on failure}
begin
 {}
 Result:=0;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceRead64(TimerDeviceDefault);
end;

{==============================================================================}

function SysTimerWait:LongWord;
{Wait for the current interval to expire on the default counter}
{Return: ERROR_SUCCESS if the interval expired or another error code on failure}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceWait(TimerDeviceDefault);
end;

{==============================================================================}

function SysTimerEvent(Callback:TTimerCallback;Data:Pointer):LongWord;
{Schedule a function to be called when the current interval expires on the default counter}
{Callback: The function to be called when the interval expires}
{Data: A pointer to be pass to the function when the interval expires (Optional)}
{Return: ERROR_SUCCESS if the callback was scheduled successfully or another error code on failure}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceEvent(TimerDeviceDefault,TIMER_EVENT_FLAG_NONE,Callback,Data);
end;

{==============================================================================}

function SysTimerGetRate:LongWord;
{Get the current clock rate in Hz of the default counter}
{Return: The current clock rate in Hz or 0 on failure}
begin
 {}
 Result:=0;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceGetRate(TimerDeviceDefault);
end;

{==============================================================================}

function SysTimerSetRate(Rate:LongWord):LongWord;
{Set the current clock rate in Hz of the default counter}
{Rate: The clock rate in Hz to set}
{Return: ERROR_SUCCESS if the clock rate was set or another error code on failure}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceSetRate(TimerDeviceDefault,Rate);
end;

{==============================================================================}

function SysTimerGetInterval:LongWord;
{Get the current interval in milliseconds of the default counter}
{Return: The current interval in milliseconds or 0 on failure (or not set)}
begin
 {}
 Result:=0;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceGetInterval(TimerDeviceDefault);
end;

{==============================================================================}

function SysTimerSetInterval(Interval:LongWord):LongWord;
{Set the current interval in milliseconds of the default counter}
{Interval: The interval in milliseconds to set}
{Return: ERROR_SUCCESS if the interval was set or another error code on failure}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 if TimerDeviceDefault = nil then Exit;

 Result:=TimerDeviceSetInterval(TimerDeviceDefault,Interval);
end;

{==============================================================================}
{==============================================================================}
{RTL Random Functions}
function SysRandomAvailable:Boolean;
{Check if a random (RNG) device is available}
begin
 {}
 Result:=(RandomDeviceDefault <> nil);
end;

{==============================================================================}

procedure SysRandomize;
begin
 {}
 if RandomDeviceDefault = nil then Exit;

 RandomDeviceSeed(RandomDeviceDefault,ClockGetCount);
end;

{==============================================================================}

procedure SysRandomSeed(Seed:LongWord);
begin
 {}
 if RandomDeviceDefault = nil then Exit;

 RandomDeviceSeed(RandomDeviceDefault,Seed);
end;

{==============================================================================}

function SysRandomReadLongInt(Limit:LongInt):LongInt;
begin
 {}
 Result:=Limit;
 
 if RandomDeviceDefault = nil then Exit;

 Result:=RandomDeviceReadLongWord(RandomDeviceDefault);
 
 if Limit <> 0 then Result:=(Result mod Limit);
end;
 
{==============================================================================}

function SysRandomReadInt64(Limit:Int64):Int64;
begin
 {}
 Result:=Limit;
 
 if RandomDeviceDefault = nil then Exit;

 Result:=RandomDeviceReadQuadWord(RandomDeviceDefault);
 
 if Limit <> 0 then Result:=(Result mod Limit);
end;

{==============================================================================}

function SysRandomReadExtended:Extended;
begin
 {}
 Result:=0;
 
 if RandomDeviceDefault = nil then Exit;

 Result:=RandomDeviceReadExtended(RandomDeviceDefault);
end;

{==============================================================================}
{==============================================================================}
{RTL Mailbox Functions}

{==============================================================================}
{==============================================================================}
{RTL Watchdog Functions}
function SysWatchdogAvailable:Boolean; 
{Check if a watchdog timer device is available}
begin
 {}
 Result:=(WatchdogDeviceDefault <> nil);
end;

{==============================================================================}

function SysWatchdogStart(Milliseconds:LongWord):LongWord; 
begin
 {}
 Result:=ERROR_DEV_NOT_EXIST;
 
 if WatchdogDeviceDefault = nil then Exit;

 Result:=WatchdogDeviceSetTimeout(WatchdogDeviceDefault,Milliseconds);
 if Result = ERROR_SUCCESS then
  begin
   Result:=WatchdogDeviceStart(WatchdogDeviceDefault);
  end; 
end;

{==============================================================================}

function SysWatchdogStop:LongWord;
begin
 {}
 Result:=ERROR_DEV_NOT_EXIST;
 
 if WatchdogDeviceDefault = nil then Exit;

 Result:=WatchdogDeviceStop(WatchdogDeviceDefault);
end;

{==============================================================================}

function SysWatchdogRefresh(Milliseconds:LongWord):LongWord;
begin
 {}
 Result:=ERROR_DEV_NOT_EXIST;
 
 if WatchdogDeviceDefault = nil then Exit;

 if WatchdogDeviceGetTimeout(WatchdogDeviceDefault) <> Milliseconds then
  begin
   Result:=WatchdogDeviceSetTimeout(WatchdogDeviceDefault,Milliseconds);
   if Result <> ERROR_SUCCESS then Exit;
  end;
  
 Result:=WatchdogDeviceRefresh(WatchdogDeviceDefault);
end;

{==============================================================================}
{==============================================================================}
{Device Helper Functions}
function DeviceGetCount:LongWord; inline;
{Get the current device count}
begin
 {}
 Result:=DeviceTableCount;
end;

{==============================================================================}

function DeviceCheck(Device:PDevice):PDevice;
{Check if the supplied Device is in the device table}
var
 Current:PDevice;
begin
 {}
 Result:=nil;
 
 {Check Device}
 if Device = nil then Exit;
 if Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(DeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Device}
    Current:=DeviceTable;
    while Current <> nil do
     begin
      {Check Device}
      if Current = Device then
       begin
        Result:=Device;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DeviceTableLock);
   end;
  end;
end;

{==============================================================================}

function NotifierGetCount:LongWord; inline;
{Get the current notifier count}
begin
 {}
 Result:=NotifierTableCount;
end;

{==============================================================================}

function NotifierCheck(Notifier:PNotifier):PNotifier;
{Check if the supplied Notifier is in the notifier table}
var
 Current:PNotifier;
begin
 {}
 Result:=nil;
 
 {Check Notifier}
 if Notifier = nil then Exit;
 if Notifier.Signature <> NOTIFIER_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(NotifierTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Notifier}
    Current:=NotifierTable;
    while Current <> nil do
     begin
      {Check Notifier}
      if Current = Notifier then
       begin
        Result:=Notifier;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(NotifierTableLock);
   end;
  end;
end;

{==============================================================================}

function DeviceBusToString(DeviceBus:LongWord):String;
begin
 {}
 Result:='DEVICE_BUS_UNKNOWN';
 
 if DeviceBus <= DEVICE_BUS_MAX then
  begin
   Result:=DEVICE_BUS_NAMES[DeviceBus];
  end;
end;

{==============================================================================}

function DeviceStateToString(DeviceState:LongWord):String;
begin
 {}
 Result:='DEVICE_STATE_UNKNOWN';
 
 if DeviceState <= DEVICE_STATE_MAX then
  begin
   Result:=DEVICE_STATE_NAMES[DeviceState];
  end;
end;

{==============================================================================}

function DeviceClassToString(DeviceClass:LongWord):String;
begin
 {}
 Result:='DEVICE_CLASS_UNKNOWN';
 
 if DeviceClass <= DEVICE_CLASS_MAX then
  begin
   Result:=DEVICE_CLASS_NAMES[DeviceClass];
  end;
end;

{==============================================================================}

function NotificationToString(Notification:LongWord):String;
begin
 {}
 Result:='';
 
 {Check Notification}
 if (Notification and DEVICE_NOTIFICATION_REGISTER) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_REGISTER';
  end;

 if (Notification and DEVICE_NOTIFICATION_DEREGISTER) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_DEREGISTER';
  end;

 if (Notification and DEVICE_NOTIFICATION_OPEN) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_OPEN';
  end;
 
 if (Notification and DEVICE_NOTIFICATION_CLOSE) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_CLOSE';
  end;
 
 if (Notification and DEVICE_NOTIFICATION_UP) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_UP';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_DOWN) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_DOWN';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_INSERT) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_INSERT';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_EJECT) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_EJECT';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_ATTACH) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_ATTACH';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_DETACH) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_DETACH';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_ENABLE) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_ENABLE';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_DISABLE) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_DISABLE';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_BIND) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_BIND';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_UNBIND) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_UNBIND';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_ATTACHING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_ATTACHING';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_DETACHING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_DETACHING';
  end;

 if (Notification and DEVICE_NOTIFICATION_INSERTING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_INSERTING';
  end;

 if (Notification and DEVICE_NOTIFICATION_EJECTING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_EJECTING';
  end;
  
 if (Notification and DEVICE_NOTIFICATION_OPENING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_OPENING';
  end;

 if (Notification and DEVICE_NOTIFICATION_CLOSING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_CLOSING';
  end;

 if (Notification and DEVICE_NOTIFICATION_RESIZE) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_RESIZE';
  end;

 if (Notification and DEVICE_NOTIFICATION_RESIZING) <> 0 then
  begin
   if Length(Result) > 0 then Result:=Result + ', ';
   Result:=Result + 'DEVICE_NOTIFICATION_RESIZING';
  end;
end;

{==============================================================================}

procedure DeviceLog(Level:LongWord;Device:PDevice;const AText:String);
var
 WorkBuffer:String;
begin
 {}
 {Check Level}
 if Level < DEVICE_DEFAULT_LOG_LEVEL then Exit;
 
 WorkBuffer:='';
 {Check Level}
 if Level = DEVICE_LOG_LEVEL_DEBUG then
  begin
   WorkBuffer:=WorkBuffer + '[DEBUG] ';
  end
 else if Level = DEVICE_LOG_LEVEL_ERROR then
  begin
   WorkBuffer:=WorkBuffer + '[ERROR] ';
  end;
 
 {Add Prefix}
 WorkBuffer:=WorkBuffer + 'Device: ';
 
 {Check Device}
 if Device <> nil then
  begin
   WorkBuffer:=WorkBuffer + DEVICE_NAME_PREFIX + IntToStr(Device.DeviceId) + ': ';
  end;
  
 {Output Logging}
 LoggingOutputEx(LOGGING_FACILITY_DEVICES,LogLevelToLoggingSeverity(Level),'Device',WorkBuffer + AText);
end;

{==============================================================================}

procedure DeviceLogInfo(Device:PDevice;const AText:String);
begin
 {}
 DeviceLog(DEVICE_LOG_LEVEL_INFO,Device,AText);
end;

{==============================================================================}

procedure DeviceLogError(Device:PDevice;const AText:String);
begin
 {}
 DeviceLog(DEVICE_LOG_LEVEL_ERROR,Device,AText);
end;

{==============================================================================}

procedure DeviceLogDebug(Device:PDevice;const AText:String);
begin
 {}
 DeviceLog(DEVICE_LOG_LEVEL_DEBUG,Device,AText);
end;

{==============================================================================}
{==============================================================================}
{Driver Helper Functions}
function DriverGetCount:LongWord; inline;
{Get the current driver count}
begin
 {}
 Result:=DriverTableCount;
end;

{==============================================================================}

function DriverCheck(Driver:PDriver):PDriver;
{Check if the supplied Driver is in the driver table}
var
 Current:PDriver;
begin
 {}
 Result:=nil;
 
 {Check Driver}
 if Driver = nil then Exit;
 if Driver.Signature <> DRIVER_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(DriverTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Driver}
    Current:=DriverTable;
    while Current <> nil do
     begin
      {Check Driver}
      if Current = Driver then
       begin
        Result:=Driver;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(DriverTableLock);
   end;
  end;
end;

{==============================================================================}

function DriverStateToString(DriverState:LongWord):String;
begin
 {}
 Result:='DRIVER_STATE_UNKNOWN';
 
 if DriverState <= DRIVER_STATE_MAX then
  begin
   Result:=DRIVER_STATE_NAMES[DriverState];
  end;
end;

{==============================================================================}

function DriverClassToString(DriverClass:LongWord):String;
begin
 {}
 Result:='DRIVER_CLASS_UNKNOWN';
 
 if DriverClass <= DRIVER_CLASS_MAX then
  begin
   Result:=DRIVER_CLASS_NAMES[DriverClass];
  end;
end;

{==============================================================================}
{==============================================================================}
{Clock Device Helper Functions}
function ClockDeviceGetCount:LongWord; inline;
{Get the current clock device count}
begin
 {}
 Result:=ClockDeviceTableCount;
end;

{==============================================================================}

function ClockDeviceGetDefault:PClockDevice; inline;
{Get the current default clock device}
begin
 {}
 Result:=ClockDeviceDefault;
end;

{==============================================================================}

function ClockDeviceSetDefault(Clock:PClockDevice):LongWord; 
{Set the current default clock device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Check Clock}
    if ClockDeviceCheck(Clock) <> Clock then Exit;
    
    {Set Clock Default}
    ClockDeviceDefault:=Clock;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;
end;

{==============================================================================}

function ClockDeviceCheck(Clock:PClockDevice):PClockDevice;
{Check if the supplied Clock is in the Clock table}
var
 Current:PClockDevice;
begin
 {}
 Result:=nil;
 
 {Check Clock}
 if Clock = nil then Exit;
 if Clock.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(ClockDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Clock}
    Current:=ClockDeviceTable;
    while Current <> nil do
     begin
      {Check Clock}
      if Current = Clock then
       begin
        Result:=Clock;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(ClockDeviceTableLock);
   end;
  end;
end;

{==============================================================================}
{==============================================================================}
{Timer Device Helper Functions}
function TimerDeviceGetCount:LongWord; inline;
{Get the current timer device count}
begin
 {}
 Result:=TimerDeviceTableCount;
end;

{==============================================================================}

function TimerDeviceGetDefault:PTimerDevice; inline;
{Get the current default timer device}
begin
 {}
 Result:=TimerDeviceDefault;
end;

{==============================================================================}

function TimerDeviceSetDefault(Timer:PTimerDevice):LongWord; 
{Set the current default timer device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Check Timer}
    if TimerDeviceCheck(Timer) <> Timer then Exit;
    
    {Set Timer Default}
    TimerDeviceDefault:=Timer;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;
end;

{==============================================================================}

function TimerDeviceCheck(Timer:PTimerDevice):PTimerDevice;
{Check if the supplied Timer is in the Timer table}
var
 Current:PTimerDevice;
begin
 {}
 Result:=nil;
 
 {Check Timer}
 if Timer = nil then Exit;
 if Timer.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(TimerDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Timer}
    Current:=TimerDeviceTable;
    while Current <> nil do
     begin
      {Check Timer}
      if Current = Timer then
       begin
        Result:=Timer;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(TimerDeviceTableLock);
   end;
  end;
end;

{==============================================================================}
{==============================================================================}
{Random Device Helper Functions}
function RandomDeviceGetCount:LongWord; inline;
{Get the current random device count}
begin
 {}
 Result:=RandomDeviceTableCount;
end;

{==============================================================================}

function RandomDeviceGetDefault:PRandomDevice; inline;
{Get the current default random device}
begin
 {}
 Result:=RandomDeviceDefault;
end;

{==============================================================================}

function RandomDeviceSetDefault(Random:PRandomDevice):LongWord; 
{Set the current default random device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Check Random}
    if RandomDeviceCheck(Random) <> Random then Exit;
    
    {Set Random Default}
    RandomDeviceDefault:=Random;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;
end;

{==============================================================================}

function RandomDeviceCheck(Random:PRandomDevice):PRandomDevice;
{Check if the supplied Random is in the Random table}
var
 Current:PRandomDevice;
begin
 {}
 Result:=nil;
 
 {Check Random}
 if Random = nil then Exit;
 if Random.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(RandomDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Random}
    Current:=RandomDeviceTable;
    while Current <> nil do
     begin
      {Check Random}
      if Current = Random then
       begin
        Result:=Random;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(RandomDeviceTableLock);
   end;
  end;
end;

{==============================================================================}
{==============================================================================}
{Mailbox Device Helper Functions}
function MailboxDeviceGetCount:LongWord; inline;
{Get the current mailbox device count}
begin
 {}
 Result:=MailboxDeviceTableCount;
end;

{==============================================================================}

function MailboxDeviceGetDefault:PMailboxDevice; inline;
{Get the current default mailbox device}
begin
 {}
 Result:=MailboxDeviceDefault;
end;

{==============================================================================}

function MailboxDeviceSetDefault(Mailbox:PMailboxDevice):LongWord; 
{Set the current default mailbox device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Check Mailbox}
    if MailboxDeviceCheck(Mailbox) <> Mailbox then Exit;
    
    {Set Mailbox Default}
    MailboxDeviceDefault:=Mailbox;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;
end;

{==============================================================================}

function MailboxDeviceCheck(Mailbox:PMailboxDevice):PMailboxDevice;
{Check if the supplied Mailbox is in the Mailbox table}
var
 Current:PMailboxDevice;
begin
 {}
 Result:=nil;
 
 {Check Mailbox}
 if Mailbox = nil then Exit;
 if Mailbox.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(MailboxDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Mailbox}
    Current:=MailboxDeviceTable;
    while Current <> nil do
     begin
      {Check Mailbox}
      if Current = Mailbox then
       begin
        Result:=Mailbox;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(MailboxDeviceTableLock);
   end;
  end;
end;

{==============================================================================}
{==============================================================================}
{Watchdog Device Helper Functions}
function WatchdogDeviceGetCount:LongWord; inline;
{Get the current watchdog device count}
begin
 {}
 Result:=WatchdogDeviceTableCount;
end;

{==============================================================================}

function WatchdogDeviceGetDefault:PWatchdogDevice; inline;
{Get the current default watchdog device}
begin
 {}
 Result:=WatchdogDeviceDefault;
end;

{==============================================================================}

function WatchdogDeviceSetDefault(Watchdog:PWatchdogDevice):LongWord; 
{Set the current default watchdog device}
begin
 {}
 Result:=ERROR_INVALID_PARAMETER;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Check Watchdog}
    if WatchdogDeviceCheck(Watchdog) <> Watchdog then Exit;
    
    {Set Watchdog Default}
    WatchdogDeviceDefault:=Watchdog;
    
    {Return Result}
    Result:=ERROR_SUCCESS;
   finally
    {Release the Lock}
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end
 else
  begin
   Result:=ERROR_CAN_NOT_COMPLETE;
  end;
end;

{==============================================================================}

function WatchdogDeviceCheck(Watchdog:PWatchdogDevice):PWatchdogDevice;
{Check if the supplied Watchdog is in the Watchdog table}
var
 Current:PWatchdogDevice;
begin
 {}
 Result:=nil;
 
 {Check Watchdog}
 if Watchdog = nil then Exit;
 if Watchdog.Device.Signature <> DEVICE_SIGNATURE then Exit;
 
 {Acquire the Lock}
 if CriticalSectionLock(WatchdogDeviceTableLock) = ERROR_SUCCESS then
  begin
   try
    {Get Watchdog}
    Current:=WatchdogDeviceTable;
    while Current <> nil do
     begin
      {Check Watchdog}
      if Current = Watchdog then
       begin
        Result:=Watchdog;
        Exit;
       end;
      
      {Get Next}
      Current:=Current.Next;
     end;
   finally
    {Release the Lock}
    CriticalSectionUnlock(WatchdogDeviceTableLock);
   end;
  end;
end;

{==============================================================================}
{==============================================================================}

initialization
 DevicesInit;
 
{==============================================================================}
 
finalization
 {Nothing}

{==============================================================================}
{==============================================================================}

end.
