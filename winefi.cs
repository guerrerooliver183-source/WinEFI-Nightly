using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Globalization;
using System.Threading;

public class WinEFI
{
    private static void SetEnglishCulture()
    {
        CultureInfo enUS = new CultureInfo("en-US");
        Thread.CurrentThread.CurrentCulture = enUS;
        Thread.CurrentThread.CurrentUICulture = enUS;
    }

    // Win32 API declarations for resource extraction
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hReservedNull, uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FreeLibrary(IntPtr hModule);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr FindResource(IntPtr hModule, string lpName, string lpType);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr LoadResource(IntPtr hModule, IntPtr hResInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr LockResource(IntPtr hResData);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint SizeofResource(IntPtr hModule, IntPtr hResInfo);

    const uint LOAD_LIBRARY_AS_DATAFILE = 0x00000002;
    const string RT_RCDATA = "RCDATA"; // Resource type for raw data

    private static void Log(string message)
    {
        string logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WinEFI_Debug.log");
        try {
            File.AppendAllText(logPath, $"[{DateTime.Now}] {message}{Environment.NewLine}");
        } catch {}
    }

    public static void Main(string[] args)
    {
        SetEnglishCulture();
        Log("--- WinEFI Started ---");
        string installDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "WinEFI");
        string tempDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Temp", "WinEFI-Temp");
        string bootresDllPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Boot", "Resources", "bootres.dll");
        string extractedBootresDir = Path.Combine(tempDir, "bootres_extracted");
        string winlogo3BmpPath = Path.Combine(extractedBootresDir, "winlogo3.bmp");
        string hackBGRTSplashBmpPath = Path.Combine(installDir, "splash.bmp");
        string hackBGRTSetupExe = Path.Combine(installDir, "setup.exe");

        // Ensure directories exist
        Directory.CreateDirectory(tempDir);
        Directory.CreateDirectory(extractedBootresDir);

        // 1. Copy bootres.dll to a temporary location
        string tempBootresDllPath = Path.Combine(tempDir, "bootres.dll");
        try
        {
            if (File.Exists(bootresDllPath)) {
                File.Copy(bootresDllPath, tempBootresDllPath, true);
                Console.WriteLine($"Copied bootres.dll to {tempBootresDllPath}");
            } else {
                Console.WriteLine("Warning: bootres.dll not found at standard path. Skipping extraction.");
            }
        }
        catch (Exception ex)
        {
            Log($"Error copying bootres.dll: {ex.Message}");
            Console.WriteLine($"Warning: Could not copy bootres.dll: {ex.Message}. Proceeding with manual configuration if available.");
        }

        // 2. Extract winlogo3.bmp from the copied bootres.dll
        // This is the most complex part due to embedded WIM. We'll attempt to extract a raw resource.
        // Note: Direct extraction of winlogo3.bmp from bootres.dll's embedded WIM is highly complex
        // and usually requires specialized tools or a more involved DISM integration. For this example,
        // we'll assume winlogo3.bmp is directly available as an RCDATA resource named "winlogo3.bmp".
        // If it's embedded in a WIM, this approach will fail, and a more robust solution involving DISM
        // or a custom WIM parser would be needed.
        try
        {
            IntPtr hModule = LoadLibraryEx(tempBootresDllPath, IntPtr.Zero, LOAD_LIBRARY_AS_DATAFILE);
            if (hModule != IntPtr.Zero)
            {
                // The resource name might be different, or it might be an integer ID.
                // Based on research, "winlogo3.bmp" is a common name.
                IntPtr hResInfo = FindResource(hModule, "winlogo3.bmp", RT_RCDATA);
                if (hResInfo == IntPtr.Zero)
                {
                    // Fallback: Try common integer IDs if string name fails. (e.g., "1" or other BMP IDs)
                    // This part would require more specific knowledge of bootres.dll's resource structure.
                    // For now, we'll log and proceed without extraction if not found by name.
                    Console.WriteLine("Resource 'winlogo3.bmp' not found by name. Attempting generic BMP extraction (may not work).");
                    // Example for integer ID 1 (common for some boot logos)
                    hResInfo = FindResource(hModule, "1", "BMP"); // Assuming type BMP for ID 1
                }

                if (hResInfo != IntPtr.Zero)
                {
                    IntPtr hResData = LoadResource(hModule, hResInfo);
                    if (hResData != IntPtr.Zero)
                    {
                        IntPtr pResData = LockResource(hResData);
                        uint size = SizeofResource(hModule, hResInfo);

                        if (pResData != IntPtr.Zero && size > 0)
                        {
                            byte[] resourceBytes = new byte[size];
                            Marshal.Copy(pResData, resourceBytes, 0, (int)size);
                            File.WriteAllBytes(winlogo3BmpPath, resourceBytes);
                            Log($"Successfully extracted resource to {winlogo3BmpPath}");
                        }
                        else
                        {
                            Log("Failed to lock resource or size is zero.");
                        }
                    }
                    else
                    {
                        Log("Failed to load resource.");
                    }
                }
                else
                {
                    Log("Resource 'winlogo3.bmp' or ID 1 not found in DLL.");
                }
                FreeLibrary(hModule);
            }
            else
            {
                Console.WriteLine("Failed to load bootres.dll as data file.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error extracting winlogo3.bmp: {ex.Message}");
            // Do not abort, as HackBGRT might still work with its default splash.bmp or a user-provided one.
        }

        // 3. Replace splash.bmp in HackBGRT installation directory with extracted winlogo3.bmp
        if (File.Exists(winlogo3BmpPath))
        {
            try
            {
                if (File.Exists(hackBGRTSplashBmpPath)) File.Delete(hackBGRTSplashBmpPath);
                File.Copy(winlogo3BmpPath, hackBGRTSplashBmpPath, true);
                Console.WriteLine($"Replaced {hackBGRTSplashBmpPath} with {winlogo3BmpPath}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error replacing splash.bmp: {ex.Message}");
                MessageBox.Show($"Error replacing splash.bmp: {ex.Message}", "WinEFI Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        else
        {
            Console.WriteLine("winlogo3.bmp not found for replacement. HackBGRT might use its default.");
        }

        // 4. Reinstall HackBGRT (UEFI) using setup.exe
        if (File.Exists(hackBGRTSetupExe))
        {
            try
            {
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = hackBGRTSetupExe;
                startInfo.Arguments = "batch install enable-bcdedit allow-secure-boot";
                startInfo.Verb = "runas"; // Request elevation
                startInfo.UseShellExecute = true;
                startInfo.CreateNoWindow = true;
                startInfo.WindowStyle = ProcessWindowStyle.Hidden;

                Log("Launching HackBGRT setup.exe...");
                Process process = Process.Start(startInfo);
                process.WaitForExit();
                Log($"HackBGRT setup.exe finished with exit code {process.ExitCode}");
            }
            catch (Exception ex)
            {
                Log($"Critical error during HackBGRT setup: {ex.Message}");
                MessageBox.Show($"Error reinstalling HackBGRT: {ex.Message}", "WinEFI Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        else
        {
            Console.WriteLine("HackBGRT setup.exe not found. Cannot reinstall HackBGRT.");
            MessageBox.Show("HackBGRT setup.exe not found. Cannot reinstall HackBGRT.", "WinEFI Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        // Clean up temporary files (optional, but good practice)
        try
        {
            if (Directory.Exists(tempDir)) Directory.Delete(tempDir, true);
            Console.WriteLine($"Cleaned up temporary directory: {tempDir}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error cleaning up temporary directory: {ex.Message}");
        }
    }
}
