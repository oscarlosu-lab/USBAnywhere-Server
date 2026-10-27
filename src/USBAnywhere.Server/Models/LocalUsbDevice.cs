// USBAnywhere Server - github.com/oscarlosu-lab/USBAnywhere-Server
// Copyright (c) 2025-2026 oscarlosu-lab - GPL v3

using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace USBAnywhere.Server.Models;

/// <summary>
/// Represents a local USB device that can be shared over the network.
/// Implements INotifyPropertyChanged for smooth UI updates without flicker.
/// </summary>
public class LocalUsbDevice : INotifyPropertyChanged
{
    private int _vendorId;
    private int _productId;
    private string _busId = "";
    private string _name = "";
    private string _description = "";
    private string _status = "Not shared";
    private bool _isExported;
    private bool _isNotShared = true;
    private string _currentLanguage = "en";

    public event PropertyChangedEventHandler? PropertyChanged;

    protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    public void SetLanguage(string language)
    {
        _currentLanguage = language;
        OnPropertyChanged(nameof(ShareButtonText));
        OnPropertyChanged(nameof(StopButtonText));
        OnPropertyChanged(nameof(LocalizedTypeName));
        OnPropertyChanged(nameof(LocalizedStatus));
    }

    public int VendorId
    {
        get => _vendorId;
        set
        {
            if (_vendorId != value)
            {
                _vendorId = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(VidPid));
                OnPropertyChanged(nameof(Icon));
                OnPropertyChanged(nameof(TypeName));
                OnPropertyChanged(nameof(LocalizedTypeName));
                OnPropertyChanged(nameof(DisplayName));
            }
        }
    }

    public int ProductId
    {
        get => _productId;
        set
        {
            if (_productId != value)
            {
                _productId = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(VidPid));
                OnPropertyChanged(nameof(Icon));
                OnPropertyChanged(nameof(TypeName));
                OnPropertyChanged(nameof(LocalizedTypeName));
                OnPropertyChanged(nameof(DisplayName));
            }
        }
    }

    public string BusId
    {
        get => _busId;
        set
        {
            if (_busId != value)
            {
                _busId = value;
                OnPropertyChanged();
            }
        }
    }

    public string Name
    {
        get => _name;
        set
        {
            if (_name != value)
            {
                _name = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(DisplayName));
            }
        }
    }

    public string Description
    {
        get => _description;
        set
        {
            if (_description != value)
            {
                _description = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(Icon));
                OnPropertyChanged(nameof(TypeName));
                OnPropertyChanged(nameof(LocalizedTypeName));
            }
        }
    }

    public string Status
    {
        get => _status;
        set
        {
            if (_status != value)
            {
                _status = value;
                OnPropertyChanged(nameof(LocalizedStatus));
                OnPropertyChanged();
            }
        }
    }

    public bool IsExported
    {
        get => _isExported;
        set
        {
            if (_isExported != value)
            {
                _isExported = value;
                OnPropertyChanged();
            }
        }
    }

    public bool IsNotShared
    {
        get => _isNotShared;
        set
        {
            if (_isNotShared != value)
            {
                _isNotShared = value;
                OnPropertyChanged();
            }
        }
    }

    public string VidPid => $"{VendorId:X4}:{ProductId:X4}";
    public string Icon => Services.DeviceIconHelper.GetIcon(VendorId, ProductId, Description);
    public string TypeName => Services.DeviceIconHelper.GetTypeName(VendorId, ProductId, Description);
    public string LocalizedTypeName => Services.DeviceIconHelper.GetLocalizedTypeName(VendorId, ProductId, Description, _currentLanguage);
    public string DisplayName => $"{Icon} {Name}";

    public string ShareButtonText => _currentLanguage == "es" ? "📤 Compartir" : "📤 Share";
    public string StopButtonText => _currentLanguage == "es" ? "🚫 Detener" : "🚫 Stop";

    public string LocalizedStatus
    {
        get
        {
            if (_currentLanguage != "es") return Status;
            if (Status.StartsWith("Not shared", StringComparison.OrdinalIgnoreCase)) return "No compartido";
            if (Status.Equals("Shared", StringComparison.OrdinalIgnoreCase)) return "Compartido";
            if (Status.Contains("forced", StringComparison.OrdinalIgnoreCase)) return "Compartido (forzado)";
            if (Status.StartsWith("Attached", StringComparison.OrdinalIgnoreCase)) return "Conectado (Cliente)";
            return Status;
        }
    }

    public override string ToString() => $"{BusId}: {Name} ({VidPid})";
}
