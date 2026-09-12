#requires -Version 7.2
# Read-only Core Audio session diagnostics. No mixer/device mutations.
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace CatabaseAudio {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class DeviceEnumerator {}
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IDevices {
    int EnumAudioEndpoints(int flow, int mask, out object devices);
    int GetDefaultAudioEndpoint(int flow, int role, out IDevice device);
  }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IDevice {
    int Activate(ref Guid id, uint context, IntPtr parameters, [MarshalAs(UnmanagedType.IUnknown)] out object result);
    int OpenPropertyStore(int mode, out object store);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int state);
  }
  [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IManager {
    int GetAudioSessionControl(IntPtr id, uint flags, out object control);
    int GetSimpleAudioVolume(IntPtr id, uint flags, out object volume);
    int GetSessionEnumerator(out ISessions sessions);
  }
  [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISessions {
    int GetCount(out int count);
    int GetSession(int index, out ISession session);
  }
  [ComImport, Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISession {}
  [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface ISession2 {
    int GetState(out int state);
    int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
    int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr context);
    int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string name);
    int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string name, IntPtr context);
    int GetGroupingParam(out Guid id);
    int SetGroupingParam(ref Guid id, IntPtr context);
    int RegisterAudioSessionNotification(IntPtr client);
    int UnregisterAudioSessionNotification(IntPtr client);
    int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetProcessId(out uint pid);
  }
  [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IVolume {
    int SetMasterVolume(float level, ref Guid context);
    int GetMasterVolume(out float level);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
  }
  [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IEndpointVolume {
    int RegisterControlChangeNotify(IntPtr client);
    int UnregisterControlChangeNotify(IntPtr client);
    int GetChannelCount(out uint count);
    int SetMasterVolumeLevel(float level, ref Guid context);
    int SetMasterVolumeLevelScalar(float level, ref Guid context);
    int GetMasterVolumeLevel(out float level);
    int GetMasterVolumeLevelScalar(out float level);
    int SetChannelVolumeLevel(uint channel, float level, ref Guid context);
    int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid context);
    int GetChannelVolumeLevel(uint channel, out float level);
    int GetChannelVolumeLevelScalar(uint channel, out float level);
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
  }
  public static class Inspect {
    public static object[] Read() {
      var result = new List<object>();
      var enumerator = (IDevices)new DeviceEnumerator();
      IDevice device; Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0,1,out device));
      string endpoint; device.GetId(out endpoint);
      var endpointIid = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
      object endpointObj; Marshal.ThrowExceptionForHR(device.Activate(ref endpointIid,23,IntPtr.Zero,out endpointObj));
      var endpointVolume = (IEndpointVolume)endpointObj;
      float endpointLevel; bool endpointMute;
      endpointVolume.GetMasterVolumeLevelScalar(out endpointLevel); endpointVolume.GetMute(out endpointMute);
      result.Add(new { kind="device", volume=endpointLevel, muted=endpointMute, endpoint=endpoint });
      var iid = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
      object obj; Marshal.ThrowExceptionForHR(device.Activate(ref iid,23,IntPtr.Zero,out obj));
      var manager = (IManager)obj;
      ISessions sessions; manager.GetSessionEnumerator(out sessions);
      int count; sessions.GetCount(out count);
      for(int i=0;i<count;i++) {
        ISession session; sessions.GetSession(i,out session);
        var control = (ISession2)session;
        uint pid; int state; control.GetProcessId(out pid); control.GetState(out state);
        var volume = (IVolume)session;
        float level; bool mute; volume.GetMasterVolume(out level); volume.GetMute(out mute);
        result.Add(new { process_id=pid, volume=level, muted=mute, state=state, endpoint=endpoint });
      }
      return result.ToArray();
    }
  }
}
'@
[CatabaseAudio.Inspect]::Read() | ConvertTo-Json -Depth 4
