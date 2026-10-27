using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class SecurityHelperTests
{
    [Theory]
    [InlineData("1-1", true)]
    [InlineData("1-2.3", true)]
    [InlineData("2-1.4.5", true)]
    [InlineData("", false)]
    [InlineData(null, false)]
    [InlineData("1-1; rm -rf", false)]
    [InlineData("1-1 & calc.exe", false)]
    [InlineData("invalid", false)]
    [InlineData("1-", false)]
    public void IsValidBusId_ValidatesCorrectly(string? busId, bool expected)
    {
        bool result = SecurityHelper.IsValidBusId(busId);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData("1-1", "1-1")]
    [InlineData("1-1;calc", "1-1calc")]
    [InlineData("test$(id)", "testid")]
    [InlineData(null, "")]
    [InlineData("", "")]
    [InlineData("safe-bus_id.1", "safe-bus_id.1")]
    public void SanitizeArgument_RemovesUnsafeCharacters(string? input, string expected)
    {
        string result = SecurityHelper.SanitizeArgument(input);
        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData(@"C:\Tools\test.txt", true)]
    [InlineData(@"..\..\Windows\system32", false)]
    [InlineData(@"C:\dir;rmdir", false)]
    [InlineData(@"C:\dir&calc", false)]
    [InlineData(null, false)]
    [InlineData("", false)]
    public void IsSafePath_DetectsTraversalsAndInjections(string? path, bool expected)
    {
        bool result = SecurityHelper.IsSafePath(path);
        Assert.Equal(expected, result);
    }
}
